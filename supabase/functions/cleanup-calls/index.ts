import {createClient} from 'npm:@supabase/supabase-js@2.106.1';
import {closeRoom} from '../_shared/calls.ts';
Deno.serve(async request=>{
 const secret=Deno.env.get('JIGU_NOTIFICATION_SECRET');
 if(request.method!=='POST'||!secret||request.headers.get('x-jigu-notification-secret')!==secret)return new Response('Unauthorized',{status:401});
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
 const {error}=await db.rpc('expire_partner_calls');if(error)return new Response('Retry',{status:503});
 const {data}=await db.from('partner_calls').select('id').in('status',['ended','declined','missed']).eq('media_closed',false).limit(100);
 let closed=0;
 for(const call of data??[]) {try {await closeRoom(call.id);await db.from('partner_calls').update({media_closed:true}).eq('id',call.id);closed++;}catch {}}
 // Keep minimal call history for 30 days; no recordings are made.
 await db.from('partner_calls').delete().eq('media_closed',true).lt('created_at',new Date(Date.now()-30*86400000).toISOString());
 return Response.json({closed});
});
