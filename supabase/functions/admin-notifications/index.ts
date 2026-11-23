import { backend } from '../_shared/backend.mjs';
import { notificationHandler } from './handler.mjs';

const env = (name: string) => Deno.env.get(name) ?? '';
const db = backend(env);
const wahaUrl = () => {
  try {
    const url = new URL('/api/sendText', env('WAHA_BASE_URL'));
    return url.protocol === 'https:' && !url.username && !url.password ? url : null;
  } catch { return null; }
};
const configured = () => ({
  onesignal: !!(env('ONESIGNAL_APP_ID') && env('ONESIGNAL_REST_API_KEY')),
  whatsapp: !!(wahaUrl() && env('WAHA_API_KEY') && env('WAHA_SESSION')),
});
const providerFetch = (url: string, options: RequestInit) => fetch(url,
  { ...options, signal: AbortSignal.timeout(12000), redirect: 'error' });

Deno.serve(notificationHandler({
  authorize: db.authorize, listStudents: db.listStudents, status: configured,
  verify: async () => {
    if (!configured().onesignal) return false;
    const response = await providerFetch(`https://api.onesignal.com/apps/${encodeURIComponent(env('ONESIGNAL_APP_ID'))}`,
      { headers: { Authorization: `Key ${env('ONESIGNAL_REST_API_KEY')}` } });
    return response.ok;
  },
  push: async ({ title, message, aliases, data }: {
    title: string; message: string; aliases: string[] | null; data: Record<string, unknown>;
  }) => {
    if (!configured().onesignal) throw new Error('Provider not configured');
    // OneSignal accepts at most 20,000 aliases per create-message request.
    if (aliases && aliases.length > 20000) throw new Error('Audience too large');
    const response = await providerFetch('https://api.onesignal.com/notifications', {
      method: 'POST', headers: { 'Content-Type': 'application/json',
        Authorization: `Key ${env('ONESIGNAL_REST_API_KEY')}` },
      body: JSON.stringify({ app_id: env('ONESIGNAL_APP_ID'), target_channel: 'push',
        headings: { en: title }, contents: { en: message }, data,
        ...(aliases ? { include_aliases: { external_id: aliases } }
          : { included_segments: ['Total Subscriptions'] }) }),
    });
    if (!response.ok) throw new Error('Provider rejected');
    return response.json();
  },
  whatsapp: async (number: string, message: string) => {
    if (!configured().whatsapp) return false;
    const url = wahaUrl();
    if (!url) return false;
    const response = await providerFetch(url.toString(), {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Api-Key': env('WAHA_API_KEY') },
      body: JSON.stringify({ session: env('WAHA_SESSION'), chatId: `${number}@c.us`, text: message }),
    });
    return response.ok;
  },
}));
