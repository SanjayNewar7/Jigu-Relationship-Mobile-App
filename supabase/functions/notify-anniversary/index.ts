import { createClient } from 'npm:@supabase/supabase-js@2.106.1';
import { accessToken } from '../_shared/fcm.ts';

import messages from '../_shared/notification_copy.json' with { type: 'json' };
const copy = messages as Record<string, {title:string;body:string}>;
Deno.serve(async request => {
  const secret=Deno.env.get('JIGU_NOTIFICATION_SECRET');
  if (!secret || request.headers.get('x-jigu-notification-secret')!==secret) return new Response('Unauthorized',{status:401});
  if (request.method!=='POST') return new Response('Method not allowed',{status:405});
  const encoded=Deno.env.get('FCM_SERVICE_ACCOUNT_B64');
  if (!encoded) return new Response('Sender not configured',{status:503});
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  try {
    const account=JSON.parse(atob(encoded));
    const token=await accessToken(account);
    const {data:jobs,error}=await db.rpc('claim_anniversary_notifications');
    if (error) throw error;
    let sent=0;
    for (const job of jobs ?? []) {
      const {data:couple}=await db.from('couples').select('id,started_on').eq('id',job.couple_id).maybeSingle();
      const {data:members}=await db.from('profiles').select('id').eq('couple_id',job.couple_id);
      const valid=couple?.started_on && members?.length===2 && members.some(p=>p.id===job.recipient_id);
      if (!valid) { await db.from('anniversary_notifications').update({delivered_at:new Date().toISOString()}).eq('id',job.id); continue; }
      const {data:devices,error:deviceError}=await db.from('notification_devices').select('token').eq('user_id',job.recipient_id);
      if (deviceError) continue;
      let complete=true;
      const ttl=3600;
      for (const device of devices ?? []) {
        const response=await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({message:{token:device.token,notification:copy[`anniversary_${job.kind}`],data:{anniversary_date:job.anniversary_date,notification_id:job.id,screen:'anniversary'},android:{priority:'high',ttl:`${ttl}s`,notification:{channel_id:'jigu_anniversaries',tag:job.id}},apns:{headers:{'apns-collapse-id':job.id,'apns-expiration':String(Math.floor(Date.now()/1000)+ttl)},payload:{aps:{sound:'default'}}}}})});
        if (response.ok) {sent++;continue;}
        const failure=await response.json();
        if (failure.error?.details?.some((d:{errorCode?:string})=>d.errorCode==='UNREGISTERED')) await db.from('notification_devices').delete().eq('token',device.token);
        else complete=false;
      }
      if (complete) await db.from('anniversary_notifications').update({delivered_at:new Date().toISOString()}).eq('id',job.id);
    }
    return Response.json({processed:jobs?.length ?? 0,sent});
  } catch { return new Response('Anniversary delivery will retry',{status:503}); }
});
