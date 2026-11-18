shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode cull_disabled, shadows_disabled, specular_disabled;
varying vec3 leaf_color;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float sway=sin(ir_graphics_time()*1.25+p.x*.20+p.z*.16);
 VERTEX.x += sway*.16*UV.y*UV.y;
 VERTEX.z += cos(ir_graphics_time()*.9+p.x*.13)*.08*UV.y;
 leaf_color=COLOR.rgb;
}
void fragment() {
 float midrib=1.0-smoothstep(.015,.075,abs(UV.x-.5));
 ALBEDO=leaf_color*mix(vec3(.055,.13,.035),vec3(.14,.29,.065),UV.y);
 ALBEDO=mix(ALBEDO,ALBEDO*1.25,midrib*.3);
 ROUGHNESS=.84;
 BACKLIGHT=ALBEDO*.38;
}
