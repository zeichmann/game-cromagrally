shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode cull_disabled, depth_prepass_alpha;
varying vec3 world_position;
varying float steepness;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 steepness=1.0-abs(NORMAL.y);
 VERTEX+=NORMAL*sin(UV.y*80.0-ir_graphics_time()*5.0+UV.x*11.0)*(.015+steepness*.025);
}
void fragment() {
 if(!FRONT_FACING) { NORMAL=-NORMAL; }
 vec2 flow_uv=vec2(UV.x*18.0+sin(UV.y*19.0-ir_graphics_time()*.8)*.7,UV.y*90.0-ir_graphics_time()*(3.0+steepness*15.0));
 float threads=noise(flow_uv*vec2(1.4,.12));
 float flow=noise(flow_uv*vec2(.7,.65)+vec2(7,11));
 float turbulence=noise(flow_uv*2.3);
 float rim=pow(abs(UV.x-.5)*2.0,7.0);
 float foam=clamp(rim*.65+turbulence*.26+steepness*(.27+threads*.34)+flow*threads*.32,0.0,1.0);
 ALBEDO=mix(vec3(.07,.31,.34),vec3(.86,.95,.95),foam);
 ROUGHNESS=mix(.18,.55,foam);
 SPECULAR=.5;
 float edge=smoothstep(0.0,.05,UV.x)*(1.0-smoothstep(.95,1.0,UV.x));
 ALPHA=mix(.71,.95,steepness)*edge;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX),n=normalize(NORMAL);
 vec3 r1=cross(sy,n),r2=cross(n,sx);
 float determinant=dot(sx,r1);
 float height=(flow*.008+threads*.006)*(1.0-foam*.45);
 NORMAL=normalize(abs(determinant)*n-sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2));
}
