import { createClient } from 'npm:@supabase/supabase-js@2.106.1';

import { accessToken } from '../_shared/fcm.ts';

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
    const {data:jobs,error}=await db.rpc('claim_moment_notifications');
    if(error) throw error;
    let sent=0;
    for(const job of jobs ?? []) {
      const {data:moment}=await db.from('moments').select('couple_id,author_id,expires_at,deleted_at').eq('id',job.moment_id).maybeSingle();
      const {data:members}=await db.from('profiles').select('id,couple_id').in('id',[job.recipient_id,moment?.author_id ?? job.recipient_id]);
      const available=moment && !moment.deleted_at && Date.parse(moment.expires_at)>Date.now() && members?.length===2 && members.every(p=>p.couple_id===moment.couple_id);
      if(!available) {
        await db.from('moment_notifications').update({delivered_at:new Date().toISOString()}).eq('id',job.id);
        continue;
      }
      const {data:devices,error:deviceError}=await db.from('notification_devices').select('token').eq('user_id',job.recipient_id);
      if(deviceError) continue;
      let complete=true;
      for(const device of devices ?? []) {
        const response=await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,{
          method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
          body:JSON.stringify({message:{token:device.token,
            notification:{title:'A little moment for you',body:'Your person shared a photo. Open your space to see it.'},
            data:{moment_id:job.moment_id,screen:'moments'},
            android:{priority:'high',ttl:'3600s',notification:{channel_id:'jigu_moments',tag:job.moment_id}},
            apns:{headers:{'apns-collapse-id':job.moment_id},payload:{aps:{sound:'default'}}},
          }}),
        });
        if(response.ok) { sent++; continue; }
        const failure=await response.json();
        const invalid=failure.error?.details?.some((d:{errorCode?:string})=>d.errorCode==='UNREGISTERED');
        if(invalid) await db.from('notification_devices').delete().eq('token',device.token);
        else complete=false;
      }
      if(complete) await db.from('moment_notifications').update({delivered_at:new Date().toISOString()}).eq('id',job.id);
    }
    return Response.json({processed:jobs?.length ?? 0,sent});
  } catch (_) { return new Response('Notification delivery will retry',{status:503}); }
});
