begin;
create table if not exists public.surat_deletion_batches (
  id uuid primary key,
  actor_id uuid not null,
  requested_ids integer[] not null,
  deleted_count integer not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists public.surat_deletion_jobs (
  id bigint generated always as identity primary key,
  batch_id uuid not null references public.surat_deletion_batches(id),
  surat_id integer not null,
  snapshot jsonb not null,
  file_url text,
  state text not null default 'pending' check(state in ('pending','processing','done')),
  attempts integer not null default 0,
  lease_token uuid,
  lease_until timestamptz,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  completed_at timestamptz,
  unique(batch_id,surat_id)
);
alter table public.surat_deletion_batches enable row level security;
alter table public.surat_deletion_jobs enable row level security;
revoke all on public.surat_deletion_batches,public.surat_deletion_jobs from anon,authenticated;
grant select on public.surat_deletion_batches,public.surat_deletion_jobs to authenticated;
grant select,insert,update,delete on public.surat_deletion_batches,public.surat_deletion_jobs to service_role;
grant usage,select on sequence public.surat_deletion_jobs_id_seq to service_role;
drop policy if exists surat_deletion_batches_admin on public.surat_deletion_batches;
create policy surat_deletion_batches_admin on public.surat_deletion_batches for select to authenticated using(public.is_attendance_admin());
drop policy if exists surat_deletion_jobs_admin on public.surat_deletion_jobs;
create policy surat_deletion_jobs_admin on public.surat_deletion_jobs for select to authenticated using(public.is_attendance_admin());

create or replace function public.enqueue_surat_deletion(p_batch_id uuid,p_ids integer[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_count integer; v_existing public.surat_deletion_batches%rowtype; v_ids integer[];
begin
  if not public.is_attendance_admin() then raise exception 'Admin diperlukan' using errcode='42501'; end if;
  if p_batch_id is null or p_ids is null or cardinality(p_ids)=0 or cardinality(p_ids)>20000 then
    raise exception 'Batch tidak valid' using errcode='22023';
  end if;
  select array_agg(distinct x order by x) into v_ids from unnest(p_ids) x where x>0;
  if v_ids is null or array_position(p_ids,null) is not null or exists(select 1 from unnest(p_ids) x where x<=0) then
    raise exception 'ID tidak valid' using errcode='22023';
  end if;
  -- Serialize retries of the same request, including requests from another admin.
  perform pg_advisory_xact_lock(hashtextextended(p_batch_id::text,0));
  select * into v_existing from public.surat_deletion_batches where id=p_batch_id;
  if found then
    if v_existing.requested_ids <> v_ids or v_existing.actor_id <> auth.uid() then
      raise exception 'Batch ID sudah digunakan' using errcode='22023';
    end if;
    return jsonb_build_object('batch_id',p_batch_id,'deleted',v_existing.deleted_count);
  end if;
  insert into public.surat_deletion_batches(id,actor_id,requested_ids) values(p_batch_id,auth.uid(),v_ids);
  -- The deleted rows become the durable cleanup records in the SAME SQL transaction.
  with deleted as (delete from public.surat where id=any(v_ids) returning *)
  insert into public.surat_deletion_jobs(batch_id,surat_id,snapshot,file_url,state,completed_at)
    select p_batch_id,d.id,to_jsonb(d),d.file_url,
      case when nullif(trim(d.file_url),'') is null then 'done' else 'pending' end,
      case when nullif(trim(d.file_url),'') is null then now() end from deleted d;
  get diagnostics v_count=row_count;
  update public.surat_deletion_batches set deleted_count=v_count where id=p_batch_id;
  return jsonb_build_object('batch_id',p_batch_id,'deleted',v_count);
end; $$;
revoke all on function public.enqueue_surat_deletion(uuid,integer[]) from public;
grant execute on function public.enqueue_surat_deletion(uuid,integer[]) to authenticated;

-- A leased job can be resumed after a worker crash. Completion requires its lease token.
create or replace function public.claim_surat_cleanup()
returns setof public.surat_deletion_jobs language plpgsql security definer set search_path = '' as $$
begin
  return query with picked as (
    select id from public.surat_deletion_jobs
    where (state='pending' and next_attempt_at<=now()) or (state='processing' and lease_until<now())
    order by next_attempt_at,id for update skip locked limit 1
  ) update public.surat_deletion_jobs j set state='processing', attempts=attempts+1,
    lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes'
    from picked where j.id=picked.id returning j.*;
end; $$;
create or replace function public.finish_surat_cleanup(p_id bigint,p_token uuid,p_success boolean,p_error text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.surat_deletion_jobs set
    state=case when p_success then 'done' else 'pending' end,
    completed_at=case when p_success then now() end,
    last_error=case when p_success then null else left(coalesce(p_error,'Storage cleanup failed'),200) end,
    next_attempt_at=now()+least(interval '1 hour', interval '30 seconds'*power(2,least(attempts,7))),
    lease_token=null,lease_until=null
    where id=p_id and state='processing' and lease_token=p_token;
  if not found then raise exception 'Lease tidak valid' using errcode='40001'; end if;
end; $$;
revoke all on function public.claim_surat_cleanup() from public,anon,authenticated;
revoke all on function public.finish_surat_cleanup(bigint,uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.claim_surat_cleanup() to service_role;
grant execute on function public.finish_surat_cleanup(bigint,uuid,boolean,text) to service_role;
notify pgrst,'reload schema';
commit;
