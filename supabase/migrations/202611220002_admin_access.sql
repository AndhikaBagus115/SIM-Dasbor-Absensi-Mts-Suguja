-- DEPLOYMENT GATE: NIS-only parent login must be replaced before applying this.
-- See docs/SECURITY-ROLLOUT.md. This migration intentionally denies anonymous data access.
begin;

create or replace function public.is_attendance_staff()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.guru where id=auth.uid() and role::text in ('guru','admin')) $$;
revoke all on function public.is_attendance_staff() from public;
grant execute on function public.is_attendance_staff() to authenticated;

-- Only a trusted operator/admin can link an authenticated parent to a student.
create table if not exists public.orang_tua_siswa (
  user_id uuid not null references auth.users(id) on delete cascade,
  siswa_id integer not null references public.siswa(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,siswa_id)
);
alter table public.orang_tua_siswa enable row level security;
revoke all on public.orang_tua_siswa from anon, authenticated;
grant select,insert,update,delete on public.orang_tua_siswa to authenticated;
drop policy if exists parent_links_read on public.orang_tua_siswa;
create policy parent_links_read on public.orang_tua_siswa for select to authenticated
  using(user_id=auth.uid() or public.is_attendance_admin());
drop policy if exists parent_links_admin on public.orang_tua_siswa;
create policy parent_links_admin on public.orang_tua_siswa for all to authenticated
  using(public.is_attendance_admin()) with check(public.is_attendance_admin());

create or replace function public.is_student_parent(p_siswa_id integer)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.orang_tua_siswa where user_id=auth.uid() and siswa_id=p_siswa_id) $$;
revoke all on function public.is_student_parent(integer) from public;
grant execute on function public.is_student_parent(integer) to authenticated;

-- Existing self-update policies also allowed modifying role and assigned classes.
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

-- Review fields may only be written by the SECURITY DEFINER review_surat workflow.
create or replace function public.protect_surat_review()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon','authenticated') then
    if tg_op='INSERT' then
      if coalesce(new.status,'menunggu') <> 'menunggu' or new.reviewed_by is not null
        or new.reviewed_at is not null or new.catatan_guru is not null then
        raise exception 'Gunakan alur verifikasi surat' using errcode='42501';
      end if;
    elsif new.status is distinct from old.status or new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at or new.catatan_guru is distinct from old.catatan_guru then
      raise exception 'Gunakan alur verifikasi surat' using errcode='42501';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists protect_surat_review on public.surat;
create trigger protect_surat_review before insert or update on public.surat
  for each row execute function public.protect_surat_review();

-- Replace permissive policies on these application tables as one transaction.
do $$ declare p record; begin
  for p in select tablename,policyname from pg_policies
    where schemaname='public' and tablename in ('guru','siswa','kelas','absensi','surat','pengumuman')
  loop execute format('drop policy %I on public.%I',p.policyname,p.tablename); end loop;
end $$;
alter table public.guru enable row level security;
alter table public.siswa enable row level security;
alter table public.kelas enable row level security;
alter table public.absensi enable row level security;
alter table public.surat enable row level security;
alter table public.pengumuman enable row level security;
revoke all on public.guru,public.siswa,public.kelas,public.absensi,public.surat,public.pengumuman from anon;
grant select,insert,update,delete on public.guru,public.siswa,public.kelas,public.absensi,public.surat,public.pengumuman to authenticated;
grant usage,select on sequence public.siswa_id_seq,public.kelas_id_seq,public.absensi_id_seq,public.surat_id_seq to authenticated;

create policy guru_read on public.guru for select to authenticated using(public.is_attendance_staff());
create policy guru_admin on public.guru for all to authenticated
  using(public.is_attendance_admin()) with check(public.is_attendance_admin());
create policy guru_self_profile on public.guru for update to authenticated
  using(id=auth.uid()) with check(id=auth.uid());
create policy siswa_read on public.siswa for select to authenticated
  using(public.is_attendance_staff() or public.is_student_parent(id));
create policy siswa_admin on public.siswa for all to authenticated
  using(public.is_attendance_admin()) with check(public.is_attendance_admin());
create policy kelas_read on public.kelas for select to authenticated
  using(public.is_attendance_staff() or exists(select 1 from public.siswa s
    where s.kelas_id=kelas.id and public.is_student_parent(s.id)));
create policy kelas_admin on public.kelas for all to authenticated
  using(public.is_attendance_admin()) with check(public.is_attendance_admin());
create policy absensi_read on public.absensi for select to authenticated
  using(public.is_attendance_staff() or public.is_student_parent(siswa_id));
-- Teachers retain attendance input used by the companion application.
create policy absensi_staff_insert on public.absensi for insert to authenticated
  with check(public.is_attendance_admin() or (public.is_attendance_staff()
    and tanggal=(now() at time zone 'Asia/Jakarta')::date));
create policy absensi_staff_update on public.absensi for update to authenticated
  using(public.is_attendance_admin() or (public.is_attendance_staff()
    and tanggal=(now() at time zone 'Asia/Jakarta')::date))
  with check(public.is_attendance_admin() or (public.is_attendance_staff()
    and tanggal=(now() at time zone 'Asia/Jakarta')::date));
create policy absensi_admin_delete on public.absensi for delete to authenticated using(public.is_attendance_admin());

-- Scanning today remains available to teachers; historical corrections use the admin workflow.
create or replace function public.protect_teacher_absensi()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user='authenticated' and not public.is_attendance_admin() then
    if tg_op='UPDATE' and (new.id is distinct from old.id or
      new.siswa_id is distinct from old.siswa_id or new.tanggal is distinct from old.tanggal) then
      raise exception 'Identitas presensi tidak dapat dipindahkan' using errcode='42501';
    end if;
    new.updated_by=auth.uid();
    new.updated_at=clock_timestamp();
  end if;
  return new;
end; $$;
drop trigger if exists protect_teacher_absensi on public.absensi;
create trigger protect_teacher_absensi before insert or update on public.absensi
  for each row execute function public.protect_teacher_absensi();
create policy surat_read on public.surat for select to authenticated
  using(public.is_attendance_staff() or public.is_student_parent(siswa_id));
create policy surat_submit on public.surat for insert to authenticated
  with check((public.is_attendance_staff() or (public.is_student_parent(siswa_id)
    and (file_url is null or split_part(file_url,'/storage/v1/object/public/surat_keterangan/',2) like auth.uid()::text||'/%')))
    and coalesce(status,'menunggu')='menunggu' and reviewed_by is null and reviewed_at is null and catatan_guru is null);
create policy surat_pending_edit on public.surat for update to authenticated
  using(status='menunggu' and (public.is_attendance_admin() or public.is_student_parent(siswa_id)))
  with check(status='menunggu' and (public.is_attendance_admin() or (public.is_student_parent(siswa_id)
    and (file_url is null or split_part(file_url,'/storage/v1/object/public/surat_keterangan/',2) like auth.uid()::text||'/%'))));
-- No direct DELETE policy: enqueue_surat_deletion is the only client deletion route.
create policy pengumuman_admin on public.pengumuman for all to authenticated
  using(public.is_attendance_admin()) with check(public.is_attendance_admin());
create policy pengumuman_read on public.pengumuman for select to authenticated
  using(public.is_attendance_staff() or (
    exists(select 1 from public.orang_tua_siswa p where p.user_id=auth.uid()) and (
      target_tipe='semua' or exists(select 1 from public.siswa s where public.is_student_parent(s.id) and
      ((target_tipe='siswa' and target_id::text=s.id::text) or
       (target_tipe='kelas' and target_id::text=s.kelas_id::text))))));

-- These existing reporting RPCs must obey the caller's RLS, including parent scope.
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in
      ('get_rekap_absensi','get_statistik_harian','get_statistik_mingguan','get_statistik_bulanan','get_statistik_tahunan')
  loop
    execute format('alter function %s security invoker',f.signature);
    execute format('revoke all on function %s from public,anon',f.signature);
    execute format('grant execute on function %s to authenticated',f.signature);
  end loop;
end $$;

-- Remove the supplied global and bucket-specific legacy Storage policies.
drop policy if exists "Allow anonymous update 1oj01fe_0" on storage.objects;
drop policy if exists "Allow anonymous uploads 1oj01fe_0" on storage.objects;
drop policy if exists "Authenticated can upload" on storage.objects;
drop policy if exists "Public read access" on storage.objects;
drop policy if exists "surat tgyv8c_0" on storage.objects;
drop policy if exists "surat tgyv8c_1" on storage.objects;
drop policy if exists "surat tgyv8c_2" on storage.objects;
drop policy if exists "surat tgyv8c_3" on storage.objects;
drop policy if exists attendance_storage_read on storage.objects;
create policy attendance_storage_read on storage.objects for select to authenticated
  using((bucket_id='avatars') or (bucket_id='surat_keterangan' and (
    public.is_attendance_staff() or (storage.foldername(name))[1]=auth.uid()::text)));
drop policy if exists attendance_storage_insert on storage.objects;
create policy attendance_storage_insert on storage.objects for insert to authenticated
  with check(bucket_id in ('avatars','surat_keterangan')
    and (public.is_attendance_staff() or exists(select 1 from public.orang_tua_siswa p where p.user_id=auth.uid())) and (
    public.is_attendance_admin() or (storage.foldername(name))[1]=auth.uid()::text));
drop policy if exists attendance_avatar_update on storage.objects;
create policy attendance_avatar_update on storage.objects for update to authenticated
  using(bucket_id='avatars' and (public.is_attendance_admin() or (storage.foldername(name))[1]=auth.uid()::text))
  with check(bucket_id='avatars' and (public.is_attendance_admin() or (storage.foldername(name))[1]=auth.uid()::text));
drop policy if exists attendance_avatar_delete on storage.objects;
create policy attendance_avatar_delete on storage.objects for delete to authenticated
  using(bucket_id='avatars' and (public.is_attendance_admin() or (storage.foldername(name))[1]=auth.uid()::text));
-- Avatars are intentionally public; letter attachments contain private student data.
update storage.buckets set public=false where id='surat_keterangan';
notify pgrst,'reload schema';
commit;
