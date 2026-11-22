// Local PostgreSQL only. Install the pinned test dependency with:
// npm install --prefix .dart_tool/sql_checks --no-save --no-package-lock --ignore-scripts @electric-sql/pglite@0.5.17
// Then: node tools/test_attendance_workflows.mjs
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const { PGlite } = await import(new URL('../.dart_tool/sql_checks/node_modules/@electric-sql/pglite/dist/index.js', import.meta.url));
const db = new PGlite();
const admin = '11111111-1111-4111-8111-111111111111';
const teacher = '22222222-2222-4222-8222-222222222222';
let passed = 0;

async function rows(sql, params = []) { return (await db.query(sql, params)).rows; }
async function sqlError(sql, params, code) {
  await db.exec('savepoint expected_failure');
  let failure;
  try { await db.query(sql, params); } catch (error) { failure = error; }
  await db.exec('rollback to savepoint expected_failure; release savepoint expected_failure');
  assert.ok(failure, 'Expected SQL to reject the operation');
  if (code) assert.equal(failure.code, code);
}
async function test(name, run) {
  await db.exec('begin');
  try {
    await db.query("select set_config('request.jwt.claim.sub', $1, true)", [admin]);
    await db.exec('delete from public.webhook_events');
    await run();
    passed++;
    console.log(`PASS ${name}`);
  } finally { await db.exec('rollback'); }
}
const review = 'select public.review_surat($1,$2,$3) as result';
const correct = 'select public.correct_absensi($1,$2,$3,$4,$5,$6,$7::jsonb) as result';

try {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    create type public.role_type as enum('guru','admin');
    create type public.jenis_surat as enum('izin','sakit');
    create type public.status_absensi as enum('hadir','terlambat','izin','sakit','alfa','pulang');
    create table public.siswa(id serial primary key, nama text);
    create table public.guru(id uuid primary key references auth.users(id) on delete cascade,
      nama varchar(100) not null, email varchar(100) unique not null,
      role public.role_type not null default 'guru', created_at timestamptz default now(),
      kelas_diampu jsonb, avatar_url text, no_hp text, foto_url text);
    create table public.surat(id serial primary key, siswa_id integer references siswa(id) on delete cascade,
      tanggal date not null, jenis public.jenis_surat not null, file_url text,
      created_at timestamptz default now(), status text default 'menunggu',
      keterangan text, catatan_guru text, tanggal_selesai date, unique(siswa_id,tanggal));
    create table public.absensi(id serial primary key, siswa_id integer references siswa(id) on delete cascade,
      tanggal date not null default current_date, status public.status_absensi not null default 'hadir',
      waktu_masuk time, waktu_pulang time, updated_by uuid references guru(id) on delete set null,
      created_at timestamptz default now(), updated_at timestamptz default now(), keterangan text,
      unique(siswa_id,tanggal));
    create table public.webhook_events(tanggal date);
    create function public.fixture_http_request() returns trigger language plpgsql as $$
      begin insert into public.webhook_events values(new.tanggal); return new; end; $$;
    create trigger trigger_notifikasi_absensi after insert or update on public.absensi
      for each row execute function public.fixture_http_request('fixture-only');
    insert into auth.users values ('${admin}'),('${teacher}');
    insert into public.guru(id,nama,email,role) values
      ('${admin}','Admin fixture','admin@example.invalid','admin'),
      ('${teacher}','Teacher fixture','teacher@example.invalid','guru');
    insert into public.siswa(nama) values('Student fixture');
  `);
  const migration = await readFile(new URL('../supabase/migrations/202611220001_attendance_workflows.sql', import.meta.url), 'utf8');
  await db.exec(migration);
  await db.exec(migration); // Reapplying must preserve existing data and policies.
  await db.exec(`
    insert into public.absensi(siswa_id,tanggal,status) values(1,(now() at time zone 'Asia/Jakarta')::date,'alfa');
    insert into public.surat(siswa_id,tanggal,tanggal_selesai,jenis)
      values(1,(now() at time zone 'Asia/Jakarta')::date-2,(now() at time zone 'Asia/Jakarta')::date,'izin');
  `);

  await test('approval synchronizes all dates, audits before/after, and is idempotent', async () => {
    const result = await rows(review, [1, true, 'Verified fixture']);
    assert.equal(result[0].result.status, 'disetujui');
    assert.equal(result[0].result.reviewed_by, admin);
    assert.equal((await rows("select count(*)::int n from public.absensi where status='izin'"))[0].n, 3);
    const audit = await rows('select * from public.absensi_audit order by id');
    assert.equal(audit.length, 3);
    assert.equal(audit.filter(row => row.before_data === null).length, 2);
    assert.ok(audit.every(row => row.actor_id === admin && row.after_data.updated_by === admin));
    await rows(review, [1, true, 'Retry']);
    assert.equal((await rows('select count(*)::int n from public.absensi_audit'))[0].n, 3);
    await sqlError(review, [1, false, 'Changed decision'], '40001');
    assert.equal((await rows('select count(*)::int n from public.webhook_events'))[0].n, 1);
  });

  await test('rejection requires a reason and leaves attendance unchanged', async () => {
    await sqlError(review, [1, false, ' '], '22023');
    const result = await rows(review, [1, false, 'Invalid document fixture']);
    assert.equal(result[0].result.status, 'ditolak');
    assert.equal((await rows('select status from public.absensi where id=1'))[0].status, 'alfa');
    assert.equal((await rows('select count(*)::int n from public.absensi_audit'))[0].n, 0);
  });

  await test('status options follow the actual database enum, including alpa variants', async () => {
    await db.exec("alter type public.status_absensi rename value 'alfa' to 'alpa'");
    const options = (await rows('select public.attendance_status_options() as options'))[0].options;
    assert.ok(options.includes('alpa'));
    assert.ok(!options.includes('alfa'));
    const original = (await rows('select * from public.absensi where id=1'))[0];
    const result = await rows(correct, [1,'alpa',null,null,null,'Enum variant fixture',original]);
    assert.equal(result[0].result.status, 'alpa');
  });

  await test('future approval never triggers an immediate attendance notification', async () => {
    await db.exec("update public.surat set tanggal=(now() at time zone 'Asia/Jakarta')::date+1, tanggal_selesai=(now() at time zone 'Asia/Jakarta')::date+2 where id=1");
    await rows(review, [1,true,'Future leave fixture']);
    assert.equal((await rows("select count(*)::int n from public.absensi where status='izin'"))[0].n, 2);
    assert.equal((await rows('select count(*)::int n from public.webhook_events'))[0].n, 0);
  });

  await test('approval refuses to overwrite actual presence', async () => {
    await db.exec("update public.absensi set status='hadir',waktu_masuk='07:00' where id=1");
    await sqlError(review, [1, true, 'Review'], 'P0001');
    assert.equal((await rows('select status from public.surat where id=1'))[0].status, 'menunggu');
    assert.equal((await rows('select count(*)::int n from public.absensi'))[0].n, 1);
  });

  await test('audit failure rolls back approval and all attendance changes', async () => {
    await db.exec(`create function public.fixture_reject_audit() returns trigger language plpgsql as
      $$ begin raise exception 'Fixture audit failure'; end; $$;
      create trigger fixture_audit_failure before insert on public.absensi_audit
      for each row execute function public.fixture_reject_audit();`);
    await sqlError(review, [1, true, 'Review'], 'P0001');
    assert.equal((await rows('select status from public.surat where id=1'))[0].status, 'menunggu');
    assert.equal((await rows('select count(*)::int n from public.absensi'))[0].n, 1);
    assert.equal((await rows('select status from public.absensi where id=1'))[0].status, 'alfa');
  });

  await test('manual correction records actor and rejects stale snapshots', async () => {
    const original = (await rows('select * from public.absensi where id=1'))[0];
    const result = await rows(correct, [1,'hadir','07:00',null,'Corrected fixture','Verified arrival',original]);
    assert.equal(result[0].result.updated_by, admin);
    const audit = (await rows('select * from public.absensi_audit'))[0];
    assert.equal(audit.before_data.status, 'alfa');
    assert.equal(audit.after_data.status, 'hadir');
    assert.equal(audit.actor_name, 'Admin fixture');
    await sqlError(correct, [1,'sakit',null,null,null,'Stale edit',original], '40001');
    assert.equal((await rows('select count(*)::int n from public.absensi_audit'))[0].n, 1);
  });

  await test('invalid times and missing reason/snapshot cannot mutate attendance', async () => {
    const original = (await rows('select * from public.absensi where id=1'))[0];
    await sqlError(correct, [1,'hadir','08:00','07:00',null,'Invalid order',original], '22023');
    await sqlError(correct, [1,'hadir',null,null,null,'No arrival time',original], '22023');
    await sqlError(correct, [1,'izin','07:00',null,null,'Absent with time',original], '22023');
    await sqlError(correct, [1,'sakit',null,null,null,' ',original], '22023');
    await sqlError(correct, [1,'sakit',null,null,null,'Missing snapshot',{}], '22023');
    assert.equal((await rows('select status from public.absensi where id=1'))[0].status, 'alfa');
  });

  await test('teacher cannot approve, correct, or write audit records', async () => {
    const original = (await rows('select * from public.absensi where id=1'))[0];
    await db.query("select set_config('request.jwt.claim.sub', $1, true)", [teacher]);
    await db.exec('set local role authenticated');
    await sqlError(review, [1,true,'Denied'], '42501');
    await sqlError(correct, [1,'sakit',null,null,null,'Denied',original], '42501');
    assert.equal((await rows('select count(*)::int n from public.absensi_audit'))[0].n, 0);
    await sqlError("insert into public.absensi_audit(actor_id,actor_name,source,reason,after_data) values($1,'Fake','manual','Fake','{}')", [teacher], '42501');
  });

  await test('anonymous callers cannot execute either workflow', async () => {
    await db.exec('set local role anon');
    await sqlError(review, [1,true,'Denied'], '42501');
    await sqlError(correct, [1,'sakit',null,null,null,'Denied',{}], '42501');
  });
  console.log(`${passed} PostgreSQL workflow tests passed.`);
} finally { await db.close(); }
