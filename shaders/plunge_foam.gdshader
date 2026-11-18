shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode unshaded, cull_disabled, depth_draw_never;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(p.x*.055+ir_graphics_time()*.7)*.16+cos(p.z*.08-ir_graphics_time()*.55)*.10;
}
void fragment() {
 float radius=length((UV-.5)*2.0);
 float phase=fract(radius*3.0-ir_graphics_time()*.32);
 float ring=pow(max(1.0-abs(phase-.5)*2.0,0.0),5.0);
 float fade=(1.0-smoothstep(.45,1.0,radius))*smoothstep(.02,.16,radius);
 ALBEDO=vec3(.87,.96,.95);
 ALPHA=ring*fade*.30;
}
