import { backend } from '../_shared/backend.mjs';
import { cleanupHandler, objectPath } from './handler.mjs';

const env = (name: string) => Deno.env.get(name) ?? '';
const db = backend(env);
Deno.serve(cleanupHandler({
  authorize: db.authorize, supabaseUrl: db.url,
  claim: () => db.rpc('claim_surat_cleanup', {}),
  finish: (id: number, token: string, success: boolean, error: string | null) =>
    db.rpc('finish_surat_cleanup', { p_id: id, p_token: token, p_success: success, p_error: error }),
  isReferenced: async (path: string) => {
    let offset = 0;
    for (;;) {
      const rows = await db.call(`/rest/v1/surat?select=file_url&id=gt.0&file_url=not.is.null&order=id&limit=500&offset=${offset}`);
      if (!rows.length) return false;
      for (const row of rows) {
        try { if (objectPath(row.file_url, db.url) === path) return true; } catch { /* Other hosts are never cleaned. */ }
      }
      offset += rows.length;
    }
  },
  remove: async (path: string) => {
    await db.call('/storage/v1/object/surat_keterangan', { method: 'DELETE', payload: { prefixes: [path] } });
  },
  summary: async () => {
    const response = await db.call('/rest/v1/surat_deletion_jobs?select=state&state=neq.done&limit=1');
    return { pending: response.length > 0 };
  },
}));
