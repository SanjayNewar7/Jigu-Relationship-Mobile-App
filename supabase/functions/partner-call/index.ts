import {createClient} from 'npm:@supabase/supabase-js@2.106.1';
import {AccessToken, TrackSource} from 'npm:livekit-server-sdk@2.20.0';
import {mediaConfig,roomName,closeRoom} from '../_shared/calls.ts';
import {accessToken} from '../_shared/fcm.ts';
const json=(data:unknown,status=200)=>Response.json(data,{status,headers:{'Cache-Control':'no-store'}});
Deno.serve(async request=>{
 if(request.method!=='POST') return json({message:'Method not allowed'},405);
 const auth=request.headers.get('authorization');
 if(!auth) return json({message:'Please sign in again.'},401);
 const userDb=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}}});
 const {data:identity,error:authError}=await userDb.auth.getUser();
 if(authError||!identity.user) return json({message:'Please sign in again.'},401);
 let input;try {input=await request.json();}catch {return json({message:'Invalid request'},400);}
 const action=input.action;
 if(!['start','accept','decline','end','status','token','heartbeat'].includes(action)) return json({message:'Invalid action'},400);
 if(action==='start'&&!['audio','video'].includes(input.kind))return json({message:'Invalid call type'},400);
 if(action!=='start'&&!/^[0-9a-f-]{36}$/i.test(input.call_id??''))return json({message:'Invalid call'},400);
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
 try {
  if(['start','accept','token'].includes(action))mediaConfig();
  const {data:call,error}=await db.rpc('manage_partner_call',{actor:identity.user.id,operation:action,call_id:input.call_id??null,call_kind:input.kind??'audio'});
  if(error) {
   const allowed=['Join your shared space first','Your person has not joined this space yet','A call is already in progress','Please wait a moment before calling again','Call unavailable'];
   return json({message:allowed.includes(error.message)?error.message:'Could not update this call. Please retry.'},error.code==='42501'?403:409);
  }
  if(action==='start') {
   // FCM contains no room token; answering always requires a fresh auth check.
   const encoded=Deno.env.get('FCM_SERVICE_ACCOUNT_B64');
   if(encoded) {
    try {
     const account=JSON.parse(atob(encoded));const token=await accessToken(account);
     const {data:devices}=await db.from('notification_devices').select('token').eq('user_id',call.callee_id);
     await Promise.all((devices??[]).map(async d=>{
      const payload={message:{token:d.token,
       notification:{title:call.kind==='video'?'Your person is video calling':'Your person is calling',body:'Open Jigu to answer.'},
       data:{screen:'calls',notification_id:call.id,call_id:call.id},
       android:{priority:'high',ttl:'40s',notification:{channel_id:'jigu_calls',tag:call.id}},
       apns:{headers:{'apns-expiration':String(Math.floor(Date.now()/1000)+40)},payload:{aps:{sound:'default'}}}
      }};
      const response=await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(payload)});
      if(!response.ok) console.warn('Call push delivery failed',response.status);
     }));
    }catch {console.warn('Call push unavailable');}
   }
  }
  if(['ended','declined','missed'].includes(call.status)) {
   try {await closeRoom(call.id);await db.from('partner_calls').update({media_closed:true}).eq('id',call.id);}catch {/* scheduled cleanup retries */}
  }
  if(action==='token') {
   if(call.status!=='accepted') return json({message:'This call is not active.'},409);
   const c=mediaConfig();
   const token=new AccessToken(c.key,c.secret,{identity:identity.user.id,ttl:120});
   token.addGrant({roomJoin:true,room:roomName(call.id),canPublish:true,canSubscribe:true,canPublishData:false,canPublishSources:call.kind==='video'?[TrackSource.CAMERA,TrackSource.MICROPHONE]:[TrackSource.MICROPHONE]});
   return json({call,url:c.url,token:await token.toJwt()});
  }
  return json({call});
 }catch(error) {
  const message=error instanceof Error && error.message.startsWith('Calls are not configured')?error.message:'Call service is unavailable. Please try again.';
  return json({message},503);
 }
});
