#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uCurrent;
uniform float uNext;
uniform float uProgress;
uniform float uDirection;
uniform float uIntensity;
uniform sampler2D uImage;
out vec4 fragColor;

vec3 rgbToHsv(vec3 c) {
  vec4 K=vec4(0.,-1./3.,2./3.,-1.);
  vec4 p=mix(vec4(c.bg,K.wz),vec4(c.gb,K.xy),step(c.b,c.g));
  vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
  float d=q.x-min(q.w,q.y);
  return vec3(abs(q.z+(q.w-q.y)/(6.*d+0.00001)),d/(q.x+0.00001),q.x);
}
vec3 hsvToRgb(vec3 c) {
  vec3 p=abs(fract(c.xxx+vec3(0.,2./3.,1./3.))*6.-3.);
  return c.z*mix(vec3(1.),clamp(p-1.,0.,1.),c.y);
}
float hueMask(float h,float center,float width) {
  float d=abs(h-center); d=min(d,1.-d);
  return 1.-smoothstep(width*.5,width,d);
}
vec3 grade(vec3 c,float id) {
  if(id<.5) return c;
  float exposure=0.,contrast=0.,highlights=0.,shadows=0.,blacks=0.;
  float temp=0.,tint=0.,sat=0.;
  vec3 hi=vec3(1.),lo=vec3(0.);
  float hiStrength=0.,loStrength=0.;
  if(id<1.5){exposure=.15;contrast=-.12;highlights=-.18;shadows=.22;blacks=.05;temp=.04;tint=.02;sat=-.08;hi=vec3(1.,.992,.969);lo=vec3(.918,.902,.875);hiStrength=.10;loStrength=.08;}
  else if(id<2.5){exposure=.08;contrast=-.10;highlights=-.12;shadows=.14;blacks=.04;temp=.10;tint=.16;hi=vec3(1.,.894,.902);lo=vec3(.290,.173,.192);hiStrength=.14;loStrength=.10;}
  else if(id<3.5){exposure=.05;contrast=.12;highlights=-.05;shadows=.05;temp=.06;tint=.12;sat=.20;hi=vec3(1.,.839,.875);lo=vec3(.169,.106,.141);hiStrength=.10;loStrength=.12;}
  else if(id<4.5){exposure=.10;contrast=.06;highlights=.08;shadows=.10;blacks=.06;temp=.22;tint=.04;hi=vec3(.988,.878,.608);lo=vec3(.239,.169,.098);hiStrength=.18;loStrength=.14;}
  else if(id<5.5){contrast=.14;highlights=-.10;shadows=-.08;blacks=.10;temp=.26;tint=.10;hi=vec3(1.,.620,.427);lo=vec3(.220,.086,.149);hiStrength=.22;loStrength=.18;}
  else if(id<6.5){exposure=-.05;contrast=.08;highlights=-.15;shadows=.08;blacks=.14;temp=.14;tint=.05;sat=-.18;hi=vec3(.937,.878,.820);lo=vec3(.169,.106,.078);hiStrength=.12;loStrength=.20;}
  else if(id<7.5){exposure=.04;contrast=-.10;highlights=-.12;shadows=.12;blacks=.15;temp=-.04;tint=-.06;hi=vec3(.902,.929,.910);lo=vec3(.137,.188,.161);hiStrength=.10;loStrength=.15;}
  else if(id<8.5){exposure=-.08;contrast=.16;highlights=-.10;shadows=-.12;temp=-.06;tint=-.04;hi=vec3(.843,.918,.878);lo=vec3(.075,.161,.118);hiStrength=.08;loStrength=.18;}
  else if(id<9.5){exposure=.06;contrast=.14;highlights=.05;shadows=.08;temp=-.14;tint=-.04;hi=vec3(.890,.957,.973);lo=vec3(.071,.180,.231);hiStrength=.10;loStrength=.16;}
  else if(id<10.5){exposure=.05;contrast=-.06;highlights=.12;shadows=.12;blacks=.06;temp=-.10;sat=-.38;hi=vec3(.933,.949,.961);lo=vec3(.145,.169,.192);hiStrength=.08;loStrength=.12;}
  else if(id<11.5){exposure=.06;contrast=-.16;highlights=-.10;shadows=.16;blacks=.18;temp=-.08;tint=.22;sat=-.10;hi=vec3(.929,.878,1.);lo=vec3(.173,.133,.239);hiStrength=.16;loStrength=.16;}
  else {exposure=-.22;contrast=.20;highlights=.10;shadows=-.24;blacks=-.08;temp=-.20;tint=.04;hi=vec3(.863,.902,.949);lo=vec3(.039,.082,.161);hiStrength=.10;loStrength=.24;}
  vec3 hsv=rgbToHsv(c);
  float orange=hueMask(hsv.x,.075,.09),yellow=hueMask(hsv.x,.16,.10);
  float green=hueMask(hsv.x,.33,.17),blue=hueMask(hsv.x,.60,.16);
  float red=hueMask(hsv.x,.98,.10),purple=hueMask(hsv.x,.80,.15);
  float guard=1.;
  if(id>6.5) guard-=.3*hueMask(hsv.x,25./360.,12./360.)*smoothstep(.15,.20,hsv.y)*(1.-smoothstep(.70,.75,hsv.y));
  float hue=0.,channelSat=0.,value=0.;
  if(id<1.5) channelSat=-.10*max(orange,yellow);
  else if(id<2.5){hue=.0167*red;value=.10*orange;}
  else if(id<3.5)channelSat=.18*max(red,purple)-.10*green;
  else if(id<4.5){hue=-.0222*yellow;channelSat=.16*max(orange,yellow)-.20*blue;}
  else if(id<5.5)hue=-.0167*orange-.0417*blue;
  else if(id<6.5)channelSat=.08*max(red,orange)-.30*max(green,blue);
  else if(id<7.5){hue=.05*green;channelSat=-.26*green-.15*yellow;}
  else if(id<8.5){hue=.0417*yellow;channelSat=.18*green;value=-.10*green;}
  else if(id<9.5){hue=-.0278*blue;channelSat=.18*blue-.08*orange;}
  else if(id<10.5)channelSat=-.15*blue-.25*max(red,orange);
  else if(id<11.5){hue=.0417*blue;channelSat=.16*purple;}
  else channelSat=.14*blue-.25*max(yellow,green);
  hsv.x=fract(hsv.x+hue*guard);
  hsv.y=clamp(hsv.y*(1.+(sat+channelSat)*guard),0.,1.);
  hsv.z=clamp(hsv.z+value*.25,0.,1.);
  vec3 outColor=hsvToRgb(hsv)*exp2(exposure);
  float luma=dot(c,vec3(.2126,.7152,.0722));
  outColor=(outColor-.5)*(1.+contrast)+.5;
  outColor+=shadows*.35*pow(1.-luma,2.)+highlights*.25*luma*luma;
  outColor=mix(vec3(blacks*.35),outColor,1.-max(blacks,0.)*.35);
  outColor+=vec3(temp*.12+tint*.025,-tint*.05,-temp*.12+tint*.025)*guard;
  outColor=mix(outColor,lo,loStrength*pow(1.-luma,2.)*.6);
  outColor=mix(outColor,hi,hiStrength*luma*luma*.6);
  return mix(c,clamp(outColor,0.,1.),uIntensity);
}
void main(){
  vec2 uv=FlutterFragCoord().xy/uSize;
  vec4 base=texture(uImage,uv);
  float id=uCurrent;
  if(uDirection<0. && uv.x>1.-uProgress) id=uNext;
  if(uDirection>0. && uv.x<uProgress) id=uNext;
  fragColor=vec4(grade(base.rgb,id),base.a);
}
