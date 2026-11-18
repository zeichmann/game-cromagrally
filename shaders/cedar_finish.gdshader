shader_type spatial;
#include "gpu_motion.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool vertical_grain=false;
varying vec3 wood_position;
varying vec3 wood_normal;
void vertex() {
 wood_position=vertical_grain?VERTEX.xzy:VERTEX;
 wood_normal=vertical_grain?NORMAL.xzy:NORMAL;
 ir_animate(VERTEX,NORMAL);
}
void fragment() {
 vec3 p=wood_position;
 vec3 w=pow(abs(normalize(wood_normal)),vec3(6.0));
 w/=max(w.x+w.y+w.z,.001);
 vec3 along_x=texture(albedo_tex,vec2(p.y*.7,p.z*.18)).rgb;
 vec3 along_y=texture(albedo_tex,vec2(p.x*.7,p.z*.18)).rgb;
 vec3 end=texture(albedo_tex,p.xy*.35).rgb;
 vec3 grain=along_x*w.x+along_y*w.y+end*w.z;
 float fiber=sin(p.x*145.0+sin(p.z*2.0)*1.6+p.y*38.0);
 float filtered=1.0-smoothstep(.35,1.7,fwidth(p.x*145.0+p.y*38.0));
 float value=dot(grain,vec3(.2126,.7152,.0722));
 ALBEDO=mix(vec3(value),grain,.65)*vec3(.82,.73,.63)*(.98+fiber*.025*filtered);
 ROUGHNESS=.47+fiber*.035*filtered;
 SPECULAR=.42;
 CLEARCOAT=.26;
}
