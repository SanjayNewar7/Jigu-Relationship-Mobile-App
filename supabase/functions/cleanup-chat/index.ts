// Server-only cleanup of photo bytes queued by private.expire_moments().
const url = Deno.env.get('SUPABASE_URL');
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const cleanupSecret = Deno.env.get('JIGU_CLEANUP_SECRET');

function response(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { 'content-type': 'application/json' },
  });
}
async function equalSecret(given: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(given)),
    crypto.subtle.digest('SHA-256', encoder.encode(expected)),
  ]);
  const one = new Uint8Array(a), two = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < one.length; i++) diff |= one[i] ^ two[i];
  return diff === 0 && given.length === expected.length;
}
async function rpc(name: string, body: Record<string, unknown>) {
  const result = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', apikey: serviceKey!, authorization: `Bearer ${serviceKey}` },
    body: JSON.stringify(body),
  });
  if (!result.ok) throw new Error(`${name} returned ${result.status}`);
  return result.json();
}
Deno.serve(async (request) => {
  if (request.method !== 'POST') return response(405, { error: 'Method not allowed' });
  if (!url || !serviceKey || !cleanupSecret) return response(503, { error: 'Cleanup is not configured' });
  if (!await equalSecret(request.headers.get('x-jigu-cleanup-secret') ?? '', cleanupSecret)) {
    return response(401, { error: 'Unauthorized' });
  }
  try {
    const pending = await rpc('pending_chat_cleanup', {});
    if (!Array.isArray(pending)) throw new Error('Invalid cleanup queue');
    const paths = pending.map((item) => item?.storage_path).filter((path): path is string => typeof path === 'string');
    if (paths.length === 0) return response(200, { removed: 0 });
    const deleted = await fetch(`${url}/storage/v1/object/chat-media`, {
      method: 'DELETE',
      headers: { 'content-type': 'application/json', apikey: serviceKey, authorization: `Bearer ${serviceKey}` },
      body: JSON.stringify({ prefixes: paths }),
    });
    if (!deleted.ok) throw new Error(`Storage deletion returned ${deleted.status}`);
    await rpc('complete_chat_cleanup', { paths });
    return response(200, { removed: paths.length });
  } catch (error) {
    console.error('Chat cleanup failed', error instanceof Error ? error.message : 'unknown error');
    return response(500, { error: 'Cleanup will retry' });
  }
});

