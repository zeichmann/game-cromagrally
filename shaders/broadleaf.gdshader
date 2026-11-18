shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode cull_disabled, depth_prepass_alpha, shadows_disabled, specular_disabled;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying float leaf_height;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float weight=1.0-UV.y;
 VERTEX.x+=sin(ir_graphics_time()*1.15+p.x*.25+p.z*.19)*.075*weight;
 VERTEX.z+=cos(ir_graphics_time()*.85+p.x*.16)*.045*weight;
 leaf_height=weight;
}
void fragment() {
 vec4 leaf=texture(leaf_texture,UV);
 ALBEDO=leaf.rgb*mix(vec3(.72,.80,.69),vec3(.94,1.0,.83),leaf_height);
 ALPHA=leaf.a;
 ALPHA_SCISSOR_THRESHOLD=.43;
 ROUGHNESS=.72;
 SPECULAR=.30;
 BACKLIGHT=ALBEDO*.35;
 if(!FRONT_FACING) { NORMAL=-NORMAL; }
}
