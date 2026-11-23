import { body, endpoint, HttpError } from '../_shared/http.mjs';

export function objectPath(fileUrl, supabaseUrl) {
  const url = new URL(fileUrl);
  const project = new URL(supabaseUrl);
  if (url.origin !== project.origin || url.username || url.password) throw new Error('Foreign object URL');
  const prefix = '/storage/v1/object/public/surat_keterangan/';
  if (!url.pathname.startsWith(prefix)) throw new Error('Unexpected bucket');
  const path = decodeURIComponent(url.pathname.slice(prefix.length));
  if (!path || path.split('/').some(part => !part || part === '.' || part === '..') || path.includes('\\'))
    throw new Error('Invalid object path');
  return path;
}

export function cleanupHandler(deps) {
  return endpoint(async request => {
    await deps.authorize(request);
    const input = await body(request);
    if (input.action !== 'retry') throw new HttpError(400, 'Aksi tidak valid.');
    let completed = 0;
    let failed = 0;
    // Bound one invocation; all remaining jobs survive for another invocation.
    const until = Date.now() + 20000;
    for (let i = 0; i < 10 && Date.now() < until; i++) {
      const jobs = await deps.claim();
      if (!jobs.length) break;
      const job = jobs[0];
      let success = false;
      try {
        const path = objectPath(job.file_url, deps.supabaseUrl);
        // Never delete an attachment still referenced by another letter.
        if (!await deps.isReferenced(path)) await deps.remove(path);
        success = true;
      } catch { failed++; }
      // A failed completion retains the lease; expiration permits safe retry.
      await deps.finish(job.id, job.lease_token, success,
        success ? null : 'Lampiran belum dibersihkan; periksa URL dan layanan Storage.');
      if (success) completed++;
    }
    return { completed, failed, ...(await deps.summary()) };
  });
}
