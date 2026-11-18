// UV2.x selects a material family; UV2.y stores roughness. Colors are linear.
#include "gpu_motion.gdshaderinc"
#ifdef SURFACE_RESIDENT
#include "resident_motion.gdshaderinc"
#endif
#ifdef SURFACE_DRIVER
#include "driver_deformation.gdshaderinc"
#endif
#if defined(SURFACE_VEHICLE) || defined(SURFACE_RESIDENT)
varying vec3 portrait_position;
varying vec3 portrait_normal;
uniform int ir_material_species=-1;
uniform vec3 ir_skin_average=vec3(.3);
uniform sampler2D organic_frog_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D organic_pig_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D organic_iris_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#endif
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roof_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D linen_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blossom_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tea_bark_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool boat_motion = false;
uniform bool floating_motion = false;
#ifdef SURFACE_VEHICLE
varying vec3 local_position;
varying vec3 local_normal;
#endif
varying vec4 paint_color;
varying vec2 material_data;
varying float authored_height;

vec3 mapped_normal(vec3 normal, vec3 position, float height) {
 vec3 sx=dFdx(position),sy=dFdy(position);
 vec3 r1=cross(sy,normal),r2=cross(normal,sx);
 float determinant=dot(sx,r1);
 if(abs(determinant)<1e-12) { return normal; }
 vec3 gradient=sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2);
 return normalize(abs(determinant)*normal-gradient);
}

void vertex() {
 authored_height=VERTEX.y;
 material_data=UV2;
 paint_color=COLOR;
#if defined(SURFACE_VEHICLE) || defined(SURFACE_RESIDENT)
 portrait_position=VERTEX;
 portrait_normal=NORMAL;
#endif
#ifdef SURFACE_RESIDENT
 float blink_clock=mod(ir_graphics_time()+INSTANCE_CUSTOM.x*.31,5.4);
 float face_blink=smoothstep(4.94,5.04,blink_clock)*(1.0-smoothstep(5.09,5.23,blink_clock));
 float face_family=floor(UV2.x+.5);
 if(int(BONE_INDICES.x)==1 && (face_family==31.0 || face_family==32.0 || face_family==42.0 || face_family==43.0)) {
  float squish=face_family==43.0 ? 1.0-face_blink : mix(1.0,.025,face_blink);
  VERTEX.y=1.835+(VERTEX.y-1.835)*squish;
  NORMAL=normalize(NORMAL*vec3(1.0,1.0/max(squish,.025),1.0));
 }
 resident_animate(VERTEX,NORMAL,int(BONE_INDICES.x),INSTANCE_CUSTOM);
#endif
#ifdef SURFACE_VEHICLE
 local_position=VERTEX;
 local_normal=NORMAL;
#endif
#ifdef SURFACE_DRIVER
 ir_driver_deform(VERTEX,NORMAL,BONE_INDICES,BONE_WEIGHTS,UV,UV2,COLOR.a);
#endif
 ir_animate(VERTEX,NORMAL);
 float kind=floor(UV2.x+.5);
 vec3 origin=MODEL_MATRIX[3].xyz;
#ifdef SURFACE_WORLD
 if(kind==37.0) {
  float t=ir_graphics_time();
  float phase=origin.x*.14+origin.z*.11+VERTEX.x*.6+VERTEX.z*.4;
  float gust=sin(t*.77+phase)*.08+sin(t*1.37+phase*.6)*.035;
  VERTEX.x+=gust*clamp(VERTEX.y*.085,0.0,1.4);
  VERTEX.y+=sin(t*2.1+phase*3.0)*.035*UV.y;
  NORMAL=normalize(NORMAL+vec3(gust*.25,0.0,0.0));
 }
 if(floating_motion) {
  VERTEX.y+=sin(ir_graphics_time()*.16+origin.x*.03)*.8;
  VERTEX.x+=sin(ir_graphics_time()*.11+origin.z*.023)*.45;
 }
 if(kind==9.0 || kind==10.0) {
  float wind=sin(ir_graphics_time()*.72+origin.x*.07+origin.z*.11+VERTEX.y*.6);
  VERTEX.x+=wind*max(VERTEX.y-3.0,0.0)*.012;
 }
 if(kind>=14.0 && kind<=16.0) {
  float sway=sin(ir_graphics_time()*.95+origin.x*.11+origin.z*.14+VERTEX.y*.15);
  VERTEX.x+=sway*min(abs(VERTEX.y),3.0)*.025;
  VERTEX.z+=cos(ir_graphics_time()*.72+origin.z*.17)*min(abs(VERTEX.y),3.0)*.012;
 }
 if(kind==19.0) {
  VERTEX.z+=sin(ir_graphics_time()*1.8+VERTEX.x*2.2+VERTEX.y*.8)*UV.x*.14;
 }
 if(kind==24.0) {
  vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
  VERTEX.y+=sin(p.x*.055+ir_graphics_time()*.7)*.16+cos(p.z*.08-ir_graphics_time()*.55)*.10;
 }
#endif
#ifdef SURFACE_VEHICLE
 if(boat_motion) {
  float phase=origin.x*.17+origin.z*.12;
  VERTEX.y+=sin(ir_graphics_time()*1.15+phase)*.11;
  VERTEX.x+=sin(ir_graphics_time()*.9+phase)*VERTEX.y*.012;
 }
 if(kind==7.0) {
  VERTEX.x+=sin(ir_graphics_time()*1.4+origin.x*.12+UV.y*3.0)*UV.x*sin(UV.y*3.14159)*.035;
 }
#endif
}

void fragment() {
 if(!FRONT_FACING) { NORMAL=-NORMAL; }
 float kind=floor(material_data.x+.5);
 vec3 color=paint_color.rgb;
 float roughness=clamp(material_data.y,.08,1.0);
 float height=0.0;
 if(false) { }
#if defined(SURFACE_VEHICLE) || defined(SURFACE_RESIDENT)
 else if(ir_material_species>=0 && (kind==50.0 || kind==54.0 || kind==55.0 || kind==57.0 || kind==58.0 || kind==30.0)) {
  vec3 p=portrait_position*1.7;
  vec3 w=pow(abs(normalize(portrait_normal)),vec3(4.0));
  w/=max(w.x+w.y+w.z,.0001);
  vec3 detail;
  if(ir_material_species==0) {
   detail=texture(organic_frog_tex,p.zy).rgb*w.x+texture(organic_frog_tex,p.xz).rgb*w.y+texture(organic_frog_tex,p.xy).rgb*w.z;
  } else {
   detail=texture(organic_pig_tex,p.zy).rgb*w.x+texture(organic_pig_tex,p.xz).rgb*w.y+texture(organic_pig_tex,p.xy).rgb*w.z;
  }
  vec3 relative=clamp(detail/max(ir_skin_average,vec3(.015)),vec3(.68),vec3(1.32));
  float grain=dot(relative,vec3(.28,.54,.18))-1.0;
  color*=mix(vec3(1.0),relative,ir_material_species==0 ? .72 : .48);
  roughness=clamp((ir_material_species==0 ? .64 : .70)-grain*.20,.53,.82);
  BACKLIGHT=color*(ir_material_species==0 ? .085 : .12);
  height=(grain+.32)*.0007;
 } else if(kind==65.0) {
  float edge=smoothstep(.60,1.0,length(UV*2.0-1.0));
  color*=mix(vec3(1.0),vec3(.76,.69,.61),edge*.42);
  roughness=.49;
 } else if(kind==66.0) {
  vec3 iris=texture(organic_iris_tex,UV).rgb;
  float value=dot(iris,vec3(.28,.54,.18));
  iris=mix(iris,value*vec3(1.48,.91,.42),.28);
  iris=mix(iris,vec3(.19,.095,.030),.22);
  color*=iris*mix(.63,1.0,smoothstep(.0,1.0,1.0-UV.y));
  roughness=.58;
 } else if(kind==67.0) {
  roughness=.58;
 } else if(kind==69.0) {
  roughness=.23;
 } else if(kind==70.0) {
  roughness=.36;
 } else if(kind==50.0 || kind==54.0 || kind==55.0 || kind==57.0 || kind==58.0) {
  vec3 p=portrait_position;
  float mottled=sin(p.x*29.0+sin(p.y*37.0)*.8)*sin(p.z*31.0+p.y*19.0);
  float pores=sin(p.x*237.0+p.z*53.0)*sin(p.y*211.0-p.z*67.0);
  float filtered=1.0-smoothstep(.3,1.8,fwidth(p.x*237.0));
  float green=smoothstep(0.0,.035,color.g-color.r);
  color*=1.0+mottled*mix(.014,.065,green)+pores*.009*filtered;
  roughness=mix(.52,.49,green);
  BACKLIGHT=color*.16;
  height=pores*.00012*filtered;
 } else if(kind==51.0) {
  roughness=.22;
 } else if(kind==52.0) {
  vec2 q=UV*2.0-1.0;
  float radius=length(q),angle=atan(q.y,q.x);
  float fiber=sin(angle*73.0+sin(radius*33.0)*1.7)*sin(angle*117.0-radius*11.0);
  float filtered=1.0-smoothstep(.3,2.0,fwidth(angle*73.0));
  color*=mix(.25,.95+fiber*.14*filtered,1.0-smoothstep(.81,.99,radius));
  color+=vec3(.024,.007,.001)*(1.0-smoothstep(.25,.62,radius));
  roughness=.21;
 } else if(kind==53.0) {
  roughness=.16;
 } else if(kind==56.0 || kind==60.0) {
  roughness=.78;
 } else if(kind==59.0) {
  roughness=.70;
 } else if(kind==30.0 || kind==33.0 || kind==43.0 || kind==44.0) {
  float pores=sin(portrait_position.x*175.0+portrait_position.z*43.0)*sin(portrait_position.y*193.0);
  float filtered=1.0-smoothstep(.25,1.5,fwidth(portrait_position.x*175.0));
  color*=.985+pores*.012*filtered;
  roughness=kind==44.0 ? .88 : .53;
  BACKLIGHT=color*(kind==44.0 ? .055 : .11);
  height=max(pores,0.0)*.00025*filtered;
 } else if(kind==31.0) {
  float edge=smoothstep(.55,.98,length(UV*2.0-1.0));
  color*=mix(vec3(1.0),vec3(.87,.77,.69),edge*.38);
  roughness=.25;
 } else if(kind==32.0) {
  roughness=.20;
 } else if(kind==42.0) {
  vec2 q=UV*2.0-1.0;
  float radius=length(q),angle=atan(q.y,q.x);
  float fiber=sin(angle*67.0+sin(radius*29.0)*1.8)*sin(angle*113.0-radius*8.0);
  float filtered=1.0-smoothstep(.3,2.0,fwidth(angle*67.0));
  float limbal=1.0-smoothstep(.78,.99,radius);
  color*=mix(.32,.83+fiber*.14*filtered,limbal);
  color+=vec3(.035,.012,.001)*(1.0-smoothstep(.25,.62,radius));
  roughness=.24;
 } else if(kind==34.0 || kind==35.0) {
  float grain=dot(texture(linen_tex,portrait_position.xy*3.0+portrait_position.z*.4).rgb,vec3(.3,.5,.2));
  color*=.87+grain*.18;
  roughness=kind==34.0 ? .95 : .82;
  height=grain*.0007;
 }
#endif
#ifdef SURFACE_WORLD
 else if(kind==36.0) {
  vec3 bark=texture(tea_bark_tex,UV*vec2(1.4,.28)).rgb;
  color*=mix(bark,vec3(dot(bark,vec3(.3,.5,.2))),.24)*vec3(.86,.93,.94);
  height=dot(bark,vec3(.3,.5,.2))*.085;
  roughness=.91;
 } else if(kind==37.0) {
  float vein=exp(-abs(UV.x-.5)*65.0);
  float edge=smoothstep(.30,.48,abs(UV.x-.5));
  color*=1.0+vein*.09-edge*.08;
  BACKLIGHT=color*.30;
  roughness=.88;
 } else if(kind==40.0) {
  float brush=sin(UV.x*17.0+UV.y*9.0)*sin(UV.y*31.0)*.015;
  color*=.94+UV.y*.06+brush;
  height=brush*.05;
  roughness=.86;
 }
 else if(kind==1.0 || kind==12.0) {
  vec3 world_position=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
  vec3 world_normal=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
  vec3 w=abs(normalize(world_normal));
  vec2 mapping=w.x>w.y && w.x>w.z ? world_position.zy : (w.y>w.z ? world_position.xz : world_position.xy);
  vec3 texel;
  if(kind==12.0) {
   vec3 blend=pow(w,vec3(4.0)); blend/=max(blend.x+blend.y+blend.z,.0001);
   texel=texture(cliff_tex,world_position.zy*.12).rgb*blend.x+texture(cliff_tex,world_position.xz*.12).rgb*blend.y+texture(cliff_tex,world_position.xy*.12).rgb*blend.z;
   float moss=smoothstep(.35,.78,world_normal.y);
   texel*=mix(vec3(1.0),vec3(.40,.58,.29),moss*.68);
  } else {
   texel=texture(stone_tex,mapping*.18).rgb;
  }
  color*=mix(vec3(1.0),texel,.86);
  float damp=1.0-smoothstep(-7.2,-6.5,world_position.y);
  color*=mix(vec3(1.0),vec3(.72,.79,.70),damp*.55);
  roughness=mix(roughness,.55,damp*.5);
  height=dot(texel,vec3(.3,.5,.2))*.025;
 } else if(kind==4.0) {
  float reflected=clamp(1.0-UV.y,0.0,1.0);
  vec3 glass=color*mix(vec3(.62,.72,.84),vec3(1.35,1.36,1.28),reflected);
  float curtain_width=.12+.18*smoothstep(.10,1.0,abs(UV.y-.5)*2.0);
  float curtain=1.0-smoothstep(curtain_width,curtain_width+.025,min(UV.x,1.0-UV.x));
  vec3 interior=mix(vec3(.10,.067,.038),vec3(.62,.53,.38)*(.90+.10*cos(UV.x*90.0)),curtain);
  float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),5.0);
  color=mix(interior,glass,.48+fresnel*.45);
  color+=vec3(.035,.035,.028)*exp(-pow((UV.x-UV.y*.55-.18)*15.0,2.0));
  roughness=.20;
  EMISSION=vec3(.22,.095,.028)*.045*(1.0-curtain*.5);
 } else if(kind==22.0) {
  color*=.90;
  roughness=.18;
  EMISSION=paint_color.rgb*.035;
 } else if(kind==20.0) {
  vec3 p=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
  float grain=texture(cliff_tex,vec2(p.x+p.z,p.y)*2.0).r;
  color*=.97+grain*.08;
  color*=mix(vec3(.77,.81,.89),vec3(1.02,.97,.87),smoothstep(.2,7.0,authored_height));
  height=grain*.003;
 } else if(kind==21.0) {
  vec3 p=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
  float grain=dot(texture(wood_tex,vec2(p.x+p.z,p.y)*.6).rgb,vec3(.3,.5,.2));
  color*=.75+grain*.45;
  height=grain*.003;
 } else if(kind==7.0) {
  color*=texture(linen_tex,UV).rgb;
  roughness=.83;
  BACKLIGHT=color*.12;
 } else if(kind==2.0) {
  vec3 texel=texture(roof_tex,UV).rgb;
  // The authored blue, rose and sage glazes carry the hue; the warm source
  // texture supplies tile variation without turning every roof beige.
  float tile_value=dot(texel,vec3(.3,.5,.2));
  color*=mix(vec3(1.0),mix(vec3(tile_value),texel,.15),.80);
  height=dot(texel,vec3(.3,.5,.2))*.018;
 } else if(kind==5.0 || kind==6.0) {
  vec3 p=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
  vec2 mapping=kind==6.0 ? vec2(p.x+p.z,p.y)*vec2(.4,.25) : p.xz*.3;
  color*=texture(wood_tex,mapping).rgb*vec3(.82,.73,.63);
 }
#endif
#ifdef SURFACE_VEHICLE
 else if(kind==5.0 || kind==6.0) {
  vec3 p=kind==6.0 ? local_position.xzy : local_position;
  vec3 n=kind==6.0 ? local_normal.xzy : local_normal;
  vec3 w=pow(abs(normalize(n)),vec3(6.0));
  w/=max(w.x+w.y+w.z,.001);
  vec3 grain=texture(wood_tex,vec2(p.y*.7,p.z*.18)).rgb*w.x+texture(wood_tex,vec2(p.x*.7,p.z*.18)).rgb*w.y+texture(wood_tex,p.xy*.35).rgb*w.z;
  float value=dot(grain,vec3(.2126,.7152,.0722));
  float fiber=sin(p.x*145.0+sin(p.z*2.0)*1.6+p.y*38.0);
  float filtered=1.0-smoothstep(.35,1.7,fwidth(p.x*145.0+p.y*38.0));
  color*=mix(vec3(value),grain,.65)*vec3(.82,.73,.63)*(.98+fiber*.025*filtered);
  roughness=.47+fiber*.035*filtered;
 } else if(kind==7.0) {
  color*=texture(linen_tex,UV*1.7).rgb;
  BACKLIGHT=color*.15;
 } else if(kind==8.0) {
  float a=atan(local_position.z,local_position.y);
  float tread=sin(a*42.0+abs(local_position.x)*22.0);
  float detail=1.0-smoothstep(.5,2.5,fwidth(a*42.0));
  color=mix(vec3(.018,.024,.024),vec3(.032,.039,.038),smoothstep(-.5,.5,tread)*detail);
  roughness=.82;
 }
#endif
#ifdef SURFACE_WORLD
 else if(kind==9.0 || kind==10.0) {
  vec3 texel=kind==9.0 ? texture(leaf_tex,UV*vec2(1.7,1.3)).rgb : texture(blossom_tex,UV*vec2(1.2,.9)).rgb;
  vec3 normal_world=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
  float crown=smoothstep(-.35,.85,normal_world.y);
  vec3 pigment=kind==9.0 ? mix(vec3(.10,.21,.10),vec3(.29,.40,.11),crown) : mix(vec3(.42,.18,.24),vec3(.83,.52,.48),crown);
  color*=mix(pigment,texel,.18);
  roughness=.9;
  BACKLIGHT=color*.28;
  height=dot(texel,vec3(.3,.5,.2))*.002;
 } else if(kind==13.0) {
  float grain=dot(texture(wood_tex,UV*vec2(.6,.25)).rgb,vec3(.3,.5,.2));
  float groove=sin(UV.x*69.115+sin(UV.y*1.3)*1.1);
  float filtered=1.0-smoothstep(.5,1.8,fwidth(UV.x*69.115));
  float bark=.86+.14*groove*filtered;
  color*=(.76+grain*.52)*bark;
  height=grain*.02+groove*.018*filtered;
 } else if(kind==18.0) {
  float rings=sin(UV.y*42.0+sin(UV.x*39.0)*2.0);
  float patches=smoothstep(.82,.97,rings)*smoothstep(.18,.36,sin(UV.x*93.0+UV.y*6.0));
  color*=mix(vec3(1.0),vec3(.33,.36,.32),patches*.7);
  height=patches*.004;
 } else if(kind==14.0) {
  float vein=1.0-smoothstep(.02,.07,abs(UV.x-.5));
  color*=.88+UV.y*.12+vein*.055;
  BACKLIGHT=color*.22;
 } else if(kind==15.0) {
  BACKLIGHT=color*.40;
  roughness=.92;
 } else if(kind==26.0) {
  vec3 p=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz-MODEL_MATRIX[3].xyz;
  float ripple=sin(length(p.xz)*28.0-ir_graphics_time()*3.5)*.5+.5;
  color*=.90+ripple*.10;
  roughness=.22;
  height=ripple*.008;
 }
#endif
 ALBEDO=color;
 ROUGHNESS=roughness;
 // Interpolation can put an integer family one ULP below its exact value.
 // fract() would then turn a matte petal or wall into a fully metallic triangle.
 METALLIC=clamp((material_data.x-kind)*10.0,0.0,1.0);
 SPECULAR=kind==8.0 ? .32 : (kind==5.0 || kind==6.0 ? .42 : .5);
#ifdef SURFACE_VEHICLE
 CLEARCOAT=kind==5.0 || kind==6.0 ? .26 : (kind==0.0 && roughness<.5 && METALLIC<.2 ? .4 : 0.0);
 CLEARCOAT_ROUGHNESS=kind==5.0 || kind==6.0 ? .32 : .22;
#endif
 if(kind==11.0) { EMISSION=paint_color.rgb*.55; }
#if defined(SURFACE_VEHICLE) || defined(SURFACE_RESIDENT)
 if(kind==30.0 || kind==43.0 || kind==44.0) { SPECULAR=.35; }
 if(kind==34.0) { SPECULAR=.08; }
 if(kind==31.0 || kind==32.0 || kind==42.0) { CLEARCOAT=.28; CLEARCOAT_ROUGHNESS=.16; }
 if(kind==50.0 || kind==54.0 || kind==55.0 || kind==57.0 || kind==58.0) { SPECULAR=.30; }
 if(kind==51.0 || kind==52.0 || kind==53.0) { SPECULAR=.44; CLEARCOAT=.22; CLEARCOAT_ROUGHNESS=.18; }
 if(ir_material_species>=0 && (kind==50.0 || kind==54.0 || kind==55.0 || kind==57.0 || kind==58.0 || kind==30.0)) { SPECULAR=.20; CLEARCOAT=0.0; }
 if(kind==65.0 || kind==66.0 || kind==67.0) { SPECULAR=.06; CLEARCOAT=0.0; }
 if(kind==69.0) { SPECULAR=.40; CLEARCOAT=.22; CLEARCOAT_ROUGHNESS=.18; }
 if(kind==70.0) { SPECULAR=.25; }
 if(kind==59.0) { SPECULAR=.10; }
#endif
 if(height>0.0) { NORMAL=mapped_normal(normalize(NORMAL),VERTEX,height); }
}
