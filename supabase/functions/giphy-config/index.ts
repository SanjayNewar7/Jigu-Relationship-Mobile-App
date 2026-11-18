import { createClient } from 'npm:@supabase/supabase-js@2.106.1';
// GIPHY requires client-side API requests. This is a client API key,
// delivered only to authenticated members; it is not a server credential.
Deno.serve(async request => {
  if(request.method!=='POST') return new Response('Method not allowed',{status:405});
  const authorization=request.headers.get('authorization');
  if(!authorization) return new Response('Sign in required',{status:401});
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}}});
  const {data:identity,error}=await db.auth.getUser();
  if(error||!identity.user) return new Response('Sign in required',{status:401});
  const {data:profile}=await db.from('profiles').select('couple_id').eq('id',identity.user.id).maybeSingle();
  if(!profile?.couple_id) return new Response('Join your shared space first',{status:403});
  const key=Deno.env.get('GIPHY_API_KEY');
  if(!key) return Response.json({message:'GIF search is not configured yet.'},{status:503});
  return Response.json({key},{headers:{'Cache-Control':'no-store'}});
});
