shader_type spatial;
render_mode cull_disabled;
#include "gpu_motion.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(.93,.81,.59,1.0);
void vertex() {
 VERTEX.z += sin(ir_graphics_time()*2.0+VERTEX.y*2.0)*.045*UV.y;
 ir_animate(VERTEX,NORMAL);
}
void fragment() {
 vec3 cloth=texture(albedo_tex,UV*2.0).rgb;
 float stripe=smoothstep(.29,.30,UV.x)-smoothstep(.38,.39,UV.x);
 ALBEDO=cloth*mix(tint.rgb,vec3(.08,.31,.34),stripe*.8);
 ROUGHNESS=.87;
 BACKLIGHT=ALBEDO*.18;
}
