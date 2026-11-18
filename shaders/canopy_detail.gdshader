shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec4 variation;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(ir_graphics_time()*.8+p.x*.35+p.z*.18)*.055;
 variation=COLOR;
}
void fragment() {
 vec4 leaf=texture(albedo_tex,UV);
 ALBEDO=leaf.rgb*variation.rgb;
 ALPHA=leaf.a;
 ALPHA_SCISSOR_THRESHOLD=.50;
 ROUGHNESS=.88;
 BACKLIGHT=leaf.rgb*.20;
}
