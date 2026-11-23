// Local PostgreSQL only; no credentials or production requests.
// Uses the same pinned PGlite installation as test_attendance_workflows.mjs.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const { PGlite } = await import(new URL('../.dart_tool/sql_checks/node_modules/@electric-sql/pglite/dist/index.js', import.meta.url));
const db = new PGlite();
const admin = '11111111-1111-4111-8111-111111111111';
const teacher = '22222222-2222-4222-8222-222222222222';
const parent = '33333333-3333-4333-8333-333333333333';
const stranger = '44444444-4444-4444-8444-444444444444';
const batch = '55555555-5555-4555-8555-555555555555';
let passed = 0;
const rows = async (sql, params = []) => (await db.query(sql, params)).rows;
async function as(user, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [user ?? '']);
  await db.exec(`set local role ${role}`);
}
async function rejects(sql, params = [], code = '42501') {
  await db.exec('savepoint expected');
  let error;
  try { await db.query(sql, params); } catch (e) { error = e; }
  await db.exec('rollback to savepoint expected; release savepoint expected');
  assert.ok(error, 'Operation must be denied');
  assert.equal(error.code, code);
}
async function test(name, run) {
  await db.exec('begin');
  try {
    await run(); passed++; console.log('PASS ' + name);
  } finally { await db.exec('rollback; reset role'); }
}
const enqueue = 'select public.enqueue_surat_deletion($1,$2) result';

try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth to anon,authenticated,service_role;
    create type public.role_type as enum('guru','admin');
    create type public.jenis_surat as enum('izin','sakit');
    create type public.status_absensi as enum('hadir','terlambat','izin','sakit','alfa','pulang');
    create table public.guru(id uuid primary key references auth.users(id), nama text not null,
      email text unique not null, role public.role_type not null default 'guru', kelas_diampu jsonb);
    create table public.kelas(id serial primary key,nama_kelas text,wali_kelas uuid);
    create table public.siswa(id serial primary key,nis text,nama text,kelas_id integer,
      orang_tua_nomor text,status text default 'aktif');
    create table public.surat(id serial primary key,siswa_id integer references siswa(id),
      tanggal date not null,jenis public.jenis_surat not null,file_url text,
      created_at timestamptz default now(),status text default 'menunggu',
      keterangan text,catatan_guru text,tanggal_selesai date,unique(siswa_id,tanggal));
    create table public.absensi(id serial primary key,siswa_id integer references siswa(id),
      tanggal date not null default current_date,status public.status_absensi not null default 'hadir',
      waktu_masuk time,waktu_pulang time,updated_by uuid references guru(id),
      created_at timestamptz default now(),updated_at timestamptz default now(),keterangan text,unique(siswa_id,tanggal));
    create table public.pengumuman(id serial primary key,judul text,isi text,target_tipe text,target_id text);
    create function public.get_statistik_harian() returns bigint language sql security definer
      as $$ select count(*) from public.absensi $$;
    create schema storage;
    create table storage.objects(id serial primary key,bucket_id text,name text);
    create table storage.buckets(id text primary key,public boolean);
    create function storage.foldername(name text) returns text[] language sql immutable as
      $$ select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1] $$;
    grant usage on schema storage to anon,authenticated,service_role;
    grant all on storage.objects to anon,authenticated,service_role;
    grant usage on sequence storage.objects_id_seq to authenticated;
    alter table storage.objects enable row level security;
    create policy "Allow anonymous uploads 1oj01fe_0" on storage.objects for insert to anon with check(true);
    create policy "Public read access" on storage.objects for select to public using(true);
    grant all on public.guru,public.kelas,public.siswa,public.absensi,public.surat,public.pengumuman to anon,authenticated;
    alter table public.guru enable row level security;
    create policy guru_all on public.guru for all to authenticated using(true) with check(true);
    insert into auth.users values('${admin}'),('${teacher}'),('${parent}'),('${stranger}');
    insert into public.guru values('${admin}','Admin','admin@example.test','admin',null),
      ('${teacher}','Guru','guru@example.test','guru','[1]');
    insert into public.kelas(nama_kelas) values('7A'),('7B');
    insert into public.siswa(nis,nama,kelas_id) values('001','Anak sendiri',1),('002','Anak lain',2);
    insert into public.absensi(siswa_id,tanggal,status) values
      (1,(now() at time zone 'Asia/Jakarta')::date,'alfa'),
      (2,(now() at time zone 'Asia/Jakarta')::date,'hadir');
    insert into public.surat(siswa_id,tanggal,jenis,file_url) values
      (1,current_date,'izin','https://project.test/storage/v1/object/public/surat_keterangan/one.jpg'),
      (2,current_date,'sakit','https://project.test/storage/v1/object/public/surat_keterangan/two.jpg');
    insert into public.pengumuman(judul,target_tipe,target_id) values
      ('Semua','semua',null),('Anak sendiri','siswa','1'),('Kelas sendiri','kelas','1'),('Kelas lain','kelas','2');
    insert into storage.buckets values('avatars',true),('surat_keterangan',true);
    insert into storage.objects(bucket_id,name) values('surat_keterangan','${parent}/one.jpg'),
      ('surat_keterangan','${stranger}/two.jpg');
  `);
  for (const name of ['202611220001_attendance_workflows.sql',
    ...(process.argv.includes('--baseline') ? [] : ['../preflight/lock_guru_roles.sql',
      '202611220002_admin_access.sql'])]) {
    const migration = await readFile(new URL('../supabase/migrations/' + name, import.meta.url), 'utf8');
    await db.exec(migration);
    await db.exec(migration);
    if (name.includes('lock_guru_roles')) {
      await test('preflight blocks role promotion, self-insertion, and deletion before full policy rollout', async () => {
        await as(teacher);
        await rejects("update public.guru set role='admin' where id=$1",[teacher]);
        assert.equal((await rows('delete from public.guru where id=$1 returning id',[admin])).length,0);
        await as(stranger);
        await rejects("insert into public.guru(id,nama,email,role) values($1,'Fake','fake@example.test','admin')",[stranger]);
      });
    }
  }
  await test('teacher cannot promote their own role or assignments', async () => {
    await as(teacher);
    await rejects("update public.guru set role='admin' where id=$1", [teacher]);
    await rejects("update public.guru set kelas_diampu='[1,2]' where id=$1", [teacher]);
    assert.equal((await rows("select role from public.guru where id=$1",[teacher]))[0].role,'guru');
    await rows("update public.guru set nama='Profil diperbarui' where id=$1",[teacher]);
  });
  if (process.argv.includes('--baseline')) throw new Error('Baseline unexpectedly passed');
  await db.exec(`insert into public.orang_tua_siswa(user_id,siswa_id) values('${parent}',1)`);

  await test('anonymous callers cannot read school data, edit letters, or upload files', async () => {
    await as(null,'anon');
    for (const table of ['guru','siswa','absensi','kelas','surat','pengumuman'])
      await rejects(`select * from public.${table}`);
    await rejects("update public.surat set status='disetujui' where id=1");
    await rejects("insert into storage.objects(bucket_id,name) values('surat_keterangan','public.jpg')");
    await rejects('select public.is_attendance_admin()');
  });
  await test('unlinked authenticated account has no school access', async () => {
    await as(stranger);
    for (const table of ['guru','siswa','absensi','kelas','surat','pengumuman'])
      assert.equal((await rows(`select * from public.${table}`)).length,0,table);
    await rejects("insert into public.guru(id,nama,email,role) values($1,'Fake','fake@example.test','admin')",[stranger]);
    await rejects("insert into public.orang_tua_siswa values($1,2,now())",[stranger]);
    assert.equal((await rows('select public.get_statistik_harian() n'))[0].n,0);
    await rejects("insert into storage.objects(bucket_id,name) values('surat_keterangan',$1)",[stranger+'/fake.jpg']);
  });
  await test('parent reads only linked child, class, attendance, and announcements', async () => {
    await as(parent);
    for (const table of ['siswa','kelas','absensi','surat'])
      assert.deepEqual((await rows(`select id from public.${table}`)).map(r=>r.id),[1],table);
    assert.deepEqual((await rows('select id from public.pengumuman order by id')).map(r=>r.id),[1,2,3]);
    await rejects("insert into public.surat(siswa_id,tanggal,jenis) values(2,current_date+1,'izin')");
    await rejects("insert into public.surat(siswa_id,tanggal,jenis,status) values(1,current_date+1,'izin','disetujui')");
    await rejects("insert into public.surat(siswa_id,tanggal,jenis,file_url) values(1,current_date+1,'izin',$1)",
      ['https://project.test/storage/v1/object/public/surat_keterangan/'+stranger+'/private.jpg']);
    await rows("insert into public.surat(siswa_id,tanggal,jenis) values(1,current_date+1,'izin')");
    assert.equal((await rows('select * from storage.objects')).length,1);
    await rejects("insert into storage.objects(bucket_id,name) values('surat_keterangan',$1)",[stranger+'/fake.jpg']);
    await rows("insert into storage.objects(bucket_id,name) values('surat_keterangan',$1)",[parent+'/new.jpg']);
  });
  await test('staff attendance input is preserved, direct review bypass is refused', async () => {
    await as(teacher);
    assert.equal((await rows('select * from public.siswa')).length,2);
    await rejects("insert into public.absensi(siswa_id,tanggal,status) values(1,(now() at time zone 'Asia/Jakarta')::date+1,'hadir')");
    await rejects("update public.absensi set siswa_id=2 where id=1");
    await rows("update public.absensi set waktu_masuk='07:00',updated_by=$1 where id=1",[admin]);
    assert.equal((await rows('select updated_by from public.absensi where id=1'))[0].updated_by,teacher);
    await db.exec('reset role');
    await rows("insert into public.absensi(siswa_id,tanggal,status) values(1,(now() at time zone 'Asia/Jakarta')::date-1,'alfa')");
    await as(teacher);
    assert.equal((await rows("update public.absensi set status='hadir' where tanggal<(now() at time zone 'Asia/Jakarta')::date returning id")).length,0);
    await rows("update public.absensi set status='alfa' where id=2");
    await as(admin);
    await rejects("update public.surat set status='disetujui' where id=1");
    const approved = await rows('select public.review_surat(2,true,$1) result',['Verified']);
    assert.equal(approved[0].result.status,'disetujui');
  });
  console.log(`${passed} security and deletion PostgreSQL tests passed.`);
} catch (error) {
  console.error(error.message, error.code ?? '', error.where ?? '');
  process.exitCode = 1;
} finally { await db.close(); }
