export class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
export function endpoint(run) {
  return async request => {
    if (request.method === 'OPTIONS') return new Response(null, { headers });
    try {
      if (request.method !== 'POST') throw new HttpError(405, 'Gunakan POST.');
      const value = await run(request);
      return new Response(JSON.stringify(value), { headers });
    } catch (error) {
      // Never expose provider responses, tokens, URLs, or internal exceptions.
      const status = error instanceof HttpError ? error.status : 502;
      return new Response(JSON.stringify({ error: error instanceof HttpError
        ? error.message : 'Layanan server gagal. Silakan coba lagi.' }), { status, headers });
    }
  };
}
export async function body(request) {
  const raw = await request.text();
  if (raw.length > 24000) throw new HttpError(413, 'Request terlalu besar.');
  try {
    const value = JSON.parse(raw);
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error();
    return value;
  } catch { throw new HttpError(400, 'JSON tidak valid.'); }
}
export function text(value, max = 4000) {
  if (typeof value !== 'string' || !value.trim() || value.length > max)
    throw new HttpError(400, 'Teks kosong atau terlalu panjang.');
  return value.trim();
}
export function id(value) {
  if (!Number.isSafeInteger(value) || value < 1) throw new HttpError(400, 'ID tidak valid.');
  return value;
}
