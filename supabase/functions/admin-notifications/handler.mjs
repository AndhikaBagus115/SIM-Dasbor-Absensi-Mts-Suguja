import { body, endpoint, HttpError, id, text } from '../_shared/http.mjs';

function target(input) {
  if (!input || !['semua', 'kelas', 'siswa'].includes(input.type))
    throw new HttpError(400, 'Target wajib dipilih.');
  return { type: input.type, ...(input.type === 'semua' ? {} : { id: id(input.id) }) };
}
export function phone(value) {
  let number = String(value ?? '').replace(/[^0-9]/g, '');
  if (number.startsWith('0')) number = `62${number.slice(1)}`;
  else if (number.startsWith('8')) number = `62${number}`;
  if (!/^62[0-9]{8,13}$/.test(number)) throw new HttpError(400, 'Nomor WhatsApp tidak valid.');
  return number;
}

export function notificationHandler(deps) {
  return endpoint(async request => {
    await deps.authorize(request); // Before querying audiences or touching a provider.
    const input = await body(request);
    if (input.action === 'status') return deps.status();
    if (input.action === 'verify') return { success: await deps.verify() };
    const message = text(input.message);
    if (input.action === 'whatsapp-test') {
      return { success: await deps.whatsapp(phone(input.phone), message) };
    }
    if (!['push', 'whatsapp'].includes(input.action)) throw new HttpError(400, 'Aksi tidak valid.');
    const audience = target(input.target);
    const title = input.action === 'push' ? text(input.title, 200) : null;
    if (input.action === 'whatsapp' && audience.type === 'semua')
      throw new HttpError(400, 'WhatsApp memerlukan siswa atau kelas tujuan.');
    // Client-supplied aliases, phone lists, and segment names are never used.
    const students = audience.type === 'semua' ? [] : await deps.listStudents(audience);
    if (audience.type !== 'semua' && !students.length)
      throw new HttpError(400, 'Tidak ada siswa aktif pada target ini.');
    if (input.action === 'push') {
      const result = await deps.push({ title, message,
        aliases: audience.type === 'semua' ? null : students.map(row => String(row.id)),
        data: { ...(input.data && typeof input.data === 'object' && !Array.isArray(input.data) ? input.data : {}),
          ...(audience.type === 'siswa' ? { siswa_id: audience.id } : {}),
          ...(audience.type === 'kelas' ? { kelas_id: audience.id } : {}) },
      });
      const created = typeof result.id === 'string' && result.id.trim().length > 0;
      const errors = result.errors;
      const partial = created && (Array.isArray(errors) ? errors.length > 0
        : errors && typeof errors === 'object' ? Object.keys(errors).length > 0 : !!errors);
      // Return safe result fields only; never return the raw provider response.
      return { success: created, partial: !!partial, id: created ? result.id.trim() : null,
        recipients: Number.isFinite(result.recipients) ? result.recipients : 0,
        message: !created ? 'Pesan tidak dibuat; periksa penerima aktif.' : partial
          ? 'Pesan dibuat, sebagian target belum diterima.' : 'Permintaan push diterima layanan.' };
    }
    const numbers = new Set();
    let failed = 0;
    for (const student of students) {
      try { numbers.add(phone(student.orang_tua_nomor)); } catch { failed++; }
    }
    let accepted = 0;
    for (const number of numbers) {
      try { if (await deps.whatsapp(number, message)) accepted++; else failed++; }
      catch { failed++; }
    }
    return { success: accepted > 0 && failed === 0, partial: accepted > 0 && failed > 0, accepted, failed };
  });
}
