shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
#include "gpu_clock.gdshaderinc"
void fragment() {
 float rim=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
 float fade=sin(UV.y*3.14159);
 float dust=.83+.17*sin(UV.y*28.0-ir_graphics_time()*.12);
 ALBEDO=vec3(.96,.89,.65);
 ALPHA=.035*rim*fade*dust;
}
