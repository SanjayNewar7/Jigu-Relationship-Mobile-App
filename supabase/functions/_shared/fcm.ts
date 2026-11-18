const encode = (value: Uint8Array) => btoa(String.fromCharCode(...value)).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');
let cached: {token:string; expires:number} | undefined;
export async function accessToken(account: {client_email:string;private_key:string}) {
  if (cached && cached.expires>Date.now()) return cached.token;
  const now=Math.floor(Date.now()/1000);
  const text=new TextEncoder();
  const header=encode(text.encode(JSON.stringify({alg:'RS256',typ:'JWT'})));
  const payload=encode(text.encode(JSON.stringify({iss:account.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})));
  const pem=account.private_key.replace(/-----[^-]+-----/g,'').replace(/\s/g,'');
  const key=await crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(pem),c=>c.charCodeAt(0)),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
  const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,text.encode(`${header}.${payload}`));
  const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:`${header}.${payload}.${encode(new Uint8Array(signature))}`})});
  const data=await response.json();
  if (!response.ok) throw new Error('FCM authentication failed');
  cached={token:data.access_token,expires:Date.now()+3300000};
  return cached.token;
}

