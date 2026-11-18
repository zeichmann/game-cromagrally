shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec2 road_data;
float band(float x,float a,float b) { return smoothstep(a,a+5.0,x)*(1.0-smoothstep(b-5.0,b,x)); }
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; road_data=UV2; }
void fragment() {
 vec3 source=texture(albedo_tex,UV).rgb;
 float grain=dot(source,vec3(.25,.6,.15));
 float broad=sin(world_position.x*.075+sin(world_position.z*.047))*sin(world_position.z*.083)*.5+.5;
 vec3 clay=source*mix(vec3(.83,.88,.91),vec3(1.0,.97,.91),broad);
 float lateral=UV.x*3.0;
 float rut=exp(-pow((abs(lateral)-1.05)*5.0,2.0))+exp(-pow((abs(lateral)-3.05)*5.0,2.0));
 float index=mod(road_data.x,384.0);
 float forest=band(index,70.0,174.0);
 float timber=max(band(index,158.0,177.0),band(index,177.0,202.0));
 float castle=band(index,205.0,261.0);
 float gardens=band(index,264.0,324.0);
 float harbor=band(index,326.0,380.0);
 float tea=band(index,10.0,42.0);
 vec3 color=clay*vec3(.92,.91,.86)*(.84+grain*.05);
 float edge=smoothstep(.65,1.0,abs(road_data.y));
 float surface_height=grain*.035;
 if(tea>.001) {
  // Large, quiet limestone setts replace the visually noisy golden texture here.
  vec2 q=vec2(UV.x*3.0,UV.y*3.0)*vec2(1.85,2.25);
  q.x+=mod(floor(q.y),2.0)*.5;
  q+=vec2(sin(q.y*2.7+floor(q.x)*1.3),sin(q.x*3.1+floor(q.y)*.7))*.035;
  vec2 cell=fract(q);
  float joint=min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y));
  float bevel=smoothstep(.012,.07+fwidth(joint),joint);
  float seed=fract(sin(dot(floor(q),vec2(12.9898,78.233)))*43758.5453);
  vec3 limestone=mix(vec3(.31,.32,.26),vec3(.46,.44,.34),seed);
  limestone=mix(vec3(.23,.255,.19),limestone,bevel);
  limestone*=.97+grain*.07;
  color=mix(color,limestone,tea);
  surface_height=mix(surface_height,bevel*.016,tea);
 }
 if(forest>.001) {
  vec3 earth=texture(rock_tex,UV*.33).rgb;
  float flecks=smoothstep(.63,.77,grain);
  vec3 loam=mix(vec3(.21,.145,.075),vec3(.34,.29,.14),broad)+earth*.065+flecks*.025;
  loam=mix(loam,vec3(.14,.23,.065),edge*.55);
  color=mix(color,loam,forest);
 }
 if(timber>.001) {
  vec3 wood=texture(wood_tex,UV*vec2(.3,.8)).rgb;
  float wood_value=clamp(dot(wood,vec3(.3,.5,.2))*1.5,0.0,1.0);
  float seam=1.0-smoothstep(.015,.05,abs(fract(UV.y*6.0)-.5));
  vec3 planks=mix(vec3(.19,.115,.055),vec3(.43,.31,.18),wood_value)*(1.0-seam*.30);
  color=mix(color,planks,timber);
  surface_height=mix(surface_height,wood_value*.018-seam*.008,timber);
 }
 if(castle>.001) {
  vec3 slab=texture(rock_tex,UV*.65).rgb;
  color=mix(color,slab*vec3(.66,.70,.72),castle);
 }
 color=mix(color,clay*vec3(.91,.73,.72),gardens);
 color=mix(color,clay*vec3(.62,.74,.82),harbor);
 ALBEDO=color*(1.0-rut*.035);
 ROUGHNESS=.88-rut*.04;
 SPECULAR=.25;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX);
 vec3 n=normalize(NORMAL);
 vec3 r1=cross(sy,n),r2=cross(n,sx);
 float det=dot(sx,r1);
 float h=surface_height;
 if(abs(det)>1e-12) { NORMAL=normalize(abs(det)*n-sign(det)*(dFdx(h)*r1+dFdy(h)*r2)); }
}
