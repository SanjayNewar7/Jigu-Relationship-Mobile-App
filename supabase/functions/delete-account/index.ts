import { createClient } from 'npm:@supabase/supabase-js@2.106.1';

const reply = (message: string, status: number) =>
  Response.json({ message }, { status, headers: { 'Cache-Control': 'no-store' } });

Deno.serve(async (request) => {
  if (request.method !== 'POST') return reply('Method not allowed', 405);
  const jwt = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!jwt) return reply('Sign in required', 401);
  const url = Deno.env.get('SUPABASE_URL')!;
  const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin = createClient(url, secret, { auth: { persistSession: false } });
  const { data: identity, error: identityError } = await admin.auth.getUser(jwt);
  if (identityError || !identity.user?.email) return reply('Sign in required', 401);

  let body: { password?: unknown; confirmation?: unknown };
  try { body = await request.json(); } catch { return reply('Invalid request', 400); }
  if (body.confirmation !== 'DELETE' || typeof body.password !== 'string' ||
      body.password.length < 1 || body.password.length > 1024) {
    return reply('Enter your password and type DELETE to confirm', 400);
  }

  // Verify the password through GoTrue without changing the admin client session.
  const verify = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: secret, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: identity.user.email, password: body.password }),
  });
  if (!verify.ok) return reply('Current password is incorrect', 403);
  const verified = await verify.json();
  if (verified.user?.id !== identity.user.id) return reply('Account verification failed', 403);

  try {
    const { data: assets, error: assetsError } = await admin.rpc(
      'account_deletion_assets', { target_user: identity.user.id },
    );
    if (assetsError) throw assetsError;
    for (const bucket of ['moments', 'date-memories', 'chat-media']) {
      const paths: string[] = (assets ?? [])
        .filter((asset: { bucket_id: string }) => asset.bucket_id === bucket)
        .map((asset: { object_name: string }) => asset.object_name);
      for (let index = 0; index < paths.length; index += 100) {
        const { error } = await admin.storage.from(bucket).remove(paths.slice(index, index + 100));
        if (error) throw error;
      }
    }
    const { error: cleanupError } = await admin.rpc(
      'remove_account_data', { target_user: identity.user.id },
    );
    if (cleanupError) throw cleanupError;
    const { error: deleteError } = await admin.auth.admin.deleteUser(identity.user.id);
    if (deleteError) throw deleteError;
    return Response.json({ deleted: true }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    console.error('Account deletion failed', error);
    return reply('Deletion could not finish. Please try again or contact support.', 503);
  }
});

