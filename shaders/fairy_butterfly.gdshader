shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode unshaded, cull_disabled;
varying vec4 shade;
void vertex() {
 float phase=MODEL_MATRIX[3].x*2.7+MODEL_MATRIX[3].z*3.1;
 float flap=sin(ir_graphics_time()*9.5+phase)*.95;
 VERTEX.y+=abs(VERTEX.x)*sin(flap);
 VERTEX.x*=cos(flap);
 VERTEX.y+=sin(ir_graphics_time()*1.7+phase)*.28;
 VERTEX.z+=sin(ir_graphics_time()*.8+phase)*.4;
 shade=COLOR;
}
void fragment() {
 float edge=smoothstep(.68,.98,UV.x);
 float dotting=step(.89,sin(UV.y*38.0))*smoothstep(.58,.9,UV.x);
 ALBEDO=mix(shade.rgb,vec3(.34,.22,.25),edge*.42);
 ALBEDO=mix(ALBEDO,vec3(1.0,.92,.62),dotting*.8);
 ROUGHNESS=.8;
}
