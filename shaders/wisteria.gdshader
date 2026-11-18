shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void vertex() {
 VERTEX.x+=sin(ir_graphics_time()*.85+MODEL_MATRIX[3].x*.17+UV.y*2.5)*UV.y*.10;
}
void fragment() {
 vec4 texel=texture(albedo_tex,UV);
 ALBEDO=texel.rgb;
 ALPHA=texel.a;
 ALPHA_SCISSOR_THRESHOLD=.48;
 ROUGHNESS=.86;
 BACKLIGHT=texel.rgb*.15;
}
