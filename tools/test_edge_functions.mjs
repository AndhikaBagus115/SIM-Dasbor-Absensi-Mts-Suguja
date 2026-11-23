import assert from 'node:assert/strict';
import test from 'node:test';
import { backend } from '../supabase/functions/_shared/backend.mjs';
import { HttpError } from '../supabase/functions/_shared/http.mjs';
import { notificationHandler } from '../supabase/functions/admin-notifications/handler.mjs';

const request = payload => new Request('https://fixture.test', { method: 'POST',
  headers: { authorization: 'Bearer fixture-user-token', 'Content-Type': 'application/json' },
  body: JSON.stringify(payload) });
const json = value => new Response(JSON.stringify(value), { status: 200 });
const input = { action: 'push', title: 'Pengumuman', message: 'Isi', target: { type: 'kelas', id: 7 } };
const defaults = () => ({
  authorize: async () => ({ id: 'admin' }),
  listStudents: async () => [{ id: 11 }, { id: 12 }],
  push: async () => ({ id: 'notification-fixture' }),
  whatsapp: async () => true,
  status: () => ({ onesignal: true, whatsapp: false }), verify: async () => true,
});

test('real authorization rejects missing/invalid JWT before reading role', async () => {
  let calls = 0;
  const db = backend(name => ({ SUPABASE_URL: 'https://fixture.test',
    SUPABASE_ANON_KEY: 'fixture-public', SUPABASE_SERVICE_ROLE_KEY: 'fixture-private' })[name],
    async () => { calls++; return new Response('{}', { status: 401 }); });
  await assert.rejects(db.authorize(new Request('https://fixture.test')), e => e.status === 401);
  assert.equal(calls, 0);
  await assert.rejects(db.authorize(request(input)), e => e.status === 401);
  assert.equal(calls, 1);
});
test('role comes from database, never user metadata; private headers stay server-side', async () => {
  let calls = 0;
  const db = backend(name => ({ SUPABASE_URL: 'https://fixture.test',
    SUPABASE_ANON_KEY: 'fixture-public', SUPABASE_SERVICE_ROLE_KEY: 'fixture-private' })[name],
    async (url, options) => {
      calls++;
      if (url.endsWith('/auth/v1/user')) {
        assert.equal(options.headers.Authorization, 'Bearer fixture-user-token');
        return json({ id: 'teacher', user_metadata: { role: 'admin' } });
      }
      assert.equal(options.headers.Authorization, 'Bearer fixture-private');
      return json([{ role: 'guru' }]);
    });
  await assert.rejects(db.authorize(request(input)), e => e.status === 403);
  assert.equal(calls, 2);
});
test('denied user never reaches audiences or notification providers', async () => {
  let touched = false;
  const handler = notificationHandler({ ...defaults(),
    authorize: async () => { throw new HttpError(403,'Admin diperlukan'); },
    listStudents: async () => { touched = true; return []; },
    push: async () => { touched = true; return {}; },
  });
  assert.equal((await handler(request(input))).status,403);
  assert.equal(touched,false);
});
test('class recipients are recomputed server-side; forged aliases are ignored', async () => {
  let sent;
  const handler = notificationHandler({ ...defaults(), push: async payload => {
    sent=payload; return { id: 'created' };
  } });
  const result = await handler(request({ ...input, studentExternalIds: ['victim'],
    targetSegments: ['Total Subscriptions'] }));
  assert.equal(result.status,200);
  assert.deepEqual(sent.aliases,['11','12']);
  assert.equal((await result.json()).success,true);
});
test('missing/empty target fails without accidentally broadcasting', async () => {
  let sends = 0;
  const handler = notificationHandler({ ...defaults(), listStudents: async () => [],
    push: async () => { sends++; return {}; } });
  assert.equal((await handler(request({ ...input, target: undefined }))).status,400);
  assert.equal((await handler(request({ ...input, target: { type: 'kelas', id: null } }))).status,400);
  assert.equal((await handler(request(input))).status,400);
  assert.equal(sends,0);
});
test('HTTP 200 without nonblank provider ID stays failed, warnings stay partial', async () => {
  for (const provider of [{}, { id: '' }, { id: '  ', errors: ['No subscription'] }]) {
    const handler=notificationHandler({ ...defaults(), push: async () => provider });
    const result=await (await handler(request(input))).json();
    assert.equal(result.success,false);
    assert.equal(result.id,null);
  }
  const handler=notificationHandler({ ...defaults(), push: async () => ({
    id: 'created', errors: { invalid_aliases: ['12'] }, provider_secret: 'must-not-return',
  }) });
  const result=await (await handler(request(input))).json();
  assert.equal(result.partial,true);
  assert.equal(result.provider_secret,undefined);
});
test('WhatsApp class numbers come from server, normalize/deduplicate, report partial', async () => {
  const sent=[];
  const handler=notificationHandler({ ...defaults(),
    listStudents: async () => [{ id:1,orang_tua_nomor:'081234567890' },
      { id:2,orang_tua_nomor:'+6281234567890' }, { id:3,orang_tua_nomor:null }],
    whatsapp: async number => { sent.push(number); return true; },
  });
  const result=await (await handler(request({ ...input, action:'whatsapp',
    phones:['fake-client-phone'] }))).json();
  assert.deepEqual(sent,['6281234567890']);
  assert.equal(result.accepted,1);
  assert.equal(result.failed,1);
  assert.equal(result.partial,true);
});
test('diagnostics expose booleans; provider exceptions are sanitized', async () => {
  let sends=0;
  const handler=notificationHandler({ ...defaults(), push: async () => {
    sends++; throw new Error('fixture-secret-and-private-host');
  } });
  assert.deepEqual(await (await handler(request({ action:'status' }))).json(),
    { onesignal:true,whatsapp:false });
  assert.equal(sends,0);
  const response=await handler(request(input));
  assert.equal(response.status,502);
  assert.ok(!(await response.text()).includes('fixture-secret'));
});
