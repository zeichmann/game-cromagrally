shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode cull_disabled, depth_prepass_alpha;
varying vec3 world_position;
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.z+=sin(UV.y*31.0-ir_graphics_time()*4.0+UV.x*5.0)*.10;
}
void fragment() {
 float threads=sin(UV.x*140.0+sin(UV.y*23.0-ir_graphics_time()*3.0))*0.5+0.5;
 float flow=sin(UV.y*65.0-ir_graphics_time()*9.0+UV.x*31.0)*.5+.5;
 float turbulence=sin(UV.y*28.0-ir_graphics_time()*5.0+sin(UV.x*19.0))*sin(UV.x*42.0+UV.y*11.0-ir_graphics_time()*3.0)*.5+.5;
 float foam=smoothstep(.76,1.0,UV.y)+smoothstep(.90,1.0,threads)*flow*.6;
 ALBEDO=mix(vec3(.43,.71,.78),vec3(.91,.97,.98),clamp(foam+threads*.35+turbulence*.20,0.0,1.0));
 ROUGHNESS=.25;
 SPECULAR=.5;
 float edges=smoothstep(0.0,.07,UV.x)*(1.0-smoothstep(.93,1.0,UV.x));
 ALPHA=(.82+foam*.15)*edges;
}
