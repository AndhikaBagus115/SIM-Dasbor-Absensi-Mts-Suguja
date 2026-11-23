-- Apply AFTER attendance_workflows (001), BEFORE exposing admin Edge Functions.
-- This first phase protects the role source without changing NIS parent data reads.
-- It is NOT a replacement for 002_admin_access: anonymous school access remains until then.
begin;
create or replace function public.is_attendance_staff()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.guru where id=auth.uid() and role::text in ('guru','admin')) $$;
revoke all on function public.is_attendance_staff() from public;
grant execute on function public.is_attendance_staff() to authenticated;
create or replace function public.protect_guru_authorization()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon','authenticated') and not public.is_attendance_admin() and
    (new.id is distinct from old.id or new.role is distinct from old.role or
     new.kelas_diampu is distinct from old.kelas_diampu) then
    raise exception 'Role dan penugasan guru hanya dapat diubah admin' using errcode='42501';
  end if;
  return new;
end; $$;
drop trigger if exists protect_guru_authorization on public.guru;
create trigger protect_guru_authorization before update on public.guru
  for each row execute function public.protect_guru_authorization();
do $$ declare p record; begin
  for p in select policyname from pg_policies where schemaname='public' and tablename='guru'
    and cmd in ('ALL','INSERT','UPDATE','DELETE')
  loop execute format('drop policy %I on public.guru',p.policyname); end loop;
end $$;
alter table public.guru enable row level security;
create policy guru_admin on public.guru for all to authenticated
  using(public.is_attendance_admin()) with check(public.is_attendance_admin());
create policy guru_self_profile on public.guru for update to authenticated
  using(id=auth.uid()) with check(id=auth.uid());
-- Preserve teacher directory reads formerly supplied by guru_all.
drop policy if exists guru_directory_authenticated on public.guru;
create policy guru_directory_authenticated on public.guru for select to authenticated using(public.is_attendance_staff());
commit;
