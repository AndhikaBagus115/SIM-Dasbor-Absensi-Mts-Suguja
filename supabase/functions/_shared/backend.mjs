import { HttpError } from './http.mjs';

// All secrets live in Edge Function environment variables, never in Flutter assets.
export function backend(env, fetcher = fetch) {
  const url = env('SUPABASE_URL');
  const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY');
  const anonKey = env('SUPABASE_ANON_KEY');
  /** @param {string} path
   * @param {{method?: string, payload?: unknown, token?: string}} [options] */
  async function call(path, { method = 'GET', payload, token = serviceKey } = {}) {
    const response = await fetcher(`${url}${path}`, {
      method, signal: AbortSignal.timeout(15000),
      headers: { apikey: token === serviceKey ? serviceKey : anonKey,
        Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      ...(payload === undefined ? {} : { body: JSON.stringify(payload) }),
    });
    if (!response.ok) throw new HttpError(502, 'Operasi database gagal.');
    const raw = await response.text();
    return raw ? JSON.parse(raw) : null;
  }
  async function authorize(request) {
    const header = request.headers.get('authorization') ?? '';
    if (!/^Bearer \S+$/i.test(header)) throw new HttpError(401, 'Login diperlukan.');
    const token = header.slice(7);
    const response = await fetcher(`${url}/auth/v1/user`, {
      headers: { apikey: anonKey, Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw new HttpError(401, 'Sesi tidak valid. Login kembali.');
    const user = await response.json();
    if (!user.id) throw new HttpError(401, 'Sesi tidak valid.');
    const rows = await call(`/rest/v1/guru?select=role&id=eq.${encodeURIComponent(user.id)}`);
    if (rows.length !== 1 || rows[0].role !== 'admin')
      throw new HttpError(403, 'Hanya admin yang dapat melakukan tindakan ini.');
    return { id: user.id, token };
  }
  const rpc = (name, payload, token) => call(`/rest/v1/rpc/${name}`, { method: 'POST', payload, token });
  async function listStudents(target) {
    let filter = 'status=eq.aktif';
    if (target.type === 'siswa') filter += `&id=eq.${target.id}`;
    if (target.type === 'kelas') filter += `&kelas_id=eq.${target.id}`;
    const result = [];
    // Advance by actual returned count, including servers configured below 1000 rows.
    for (;;) {
      const rows = await call(`/rest/v1/siswa?select=id,orang_tua_nomor&${filter}&order=id&limit=500&offset=${result.length}`);
      if (!rows.length) return result;
      result.push(...rows);
      if (result.length > 20000) throw new HttpError(413, 'Penerima terlalu banyak. Pilih kelas.');
    }
  }
  return { url, call, rpc, authorize, listStudents };
}
