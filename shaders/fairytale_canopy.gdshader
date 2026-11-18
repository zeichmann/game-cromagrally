shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode diffuse_burley, specular_disabled;
uniform vec4 tint : source_color = vec4(.35,.56,.13,1.0);
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 local_position;
varying vec3 local_normal;
varying vec4 variation;
void vertex() {
 local_position=VERTEX;
 local_normal=NORMAL;
 variation=COLOR;
 vec3 origin=MODEL_MATRIX[3].xyz;
 float wind=sin(ir_graphics_time()*.72+origin.x*.07+origin.z*.11+VERTEX.y*.6);
 VERTEX.x+=wind*max(VERTEX.y-3.0,0.0)*.012;
}
void fragment() {
 float lobes=sin(local_position.x*5.7+sin(local_position.z*4.0))*sin(local_position.y*5.1+local_position.z*3.8)*.5+.5;
 float tips=smoothstep(3.4,8.4,local_position.y);
 vec3 leaf=mix(tint.rgb*.7,tint.rgb*1.16,lobes*.55+tips*.45);
 vec3 weights=pow(abs(normalize(local_normal)),vec3(4.0));
 weights/=max(weights.x+weights.y+weights.z,.001);
 vec4 x=texture(leaf_tex,local_position.zy*.48);
 vec4 y=texture(leaf_tex,local_position.xz*.48);
 vec4 z=texture(leaf_tex,local_position.xy*.48);
 float coverage=x.a*weights.x+y.a*weights.y+z.a*weights.z;
 vec3 detail=(x.rgb*x.a*weights.x+y.rgb*y.a*weights.y+z.rgb*z.a*weights.z)/max(coverage,.01);
 ALBEDO=mix(leaf,detail*.72+leaf*.28,coverage*.74)*variation.rgb;
 ROUGHNESS=.92;
 BACKLIGHT=tint.rgb*.12;
}
