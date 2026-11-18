shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
#include "gpu_clock.gdshaderinc"
varying vec3 p;
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
void fragment() {
 float ripple=sin(p.x*5.2+p.z*3.1-ir_graphics_time()*2.7)*.5+.5;
 ALBEDO=mix(vec3(.18,.35,.32),vec3(.60,.72,.65),pow(ripple,12.0)*.25);
 ALPHA=.36;
 ROUGHNESS=.22;
 SPECULAR=.6;
 NORMAL_MAP=normalize(vec3(cos(p.x*5.2+p.z*3.1-ir_graphics_time()*2.7)*.09,0,1))*.5+.5;
}
