shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
#include "gpu_clock.gdshaderinc"
varying vec4 shade;
void vertex() {
 float scale=length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale,INV_VIEW_MATRIX[1]*scale,INV_VIEW_MATRIX[2]*scale,MODEL_MATRIX[3]);
 shade=COLOR;
}
void fragment() {
 vec2 q=(UV-.5)*2.0;
 ALBEDO=shade.rgb;
 ALPHA=exp(-dot(q,q)*4.0)*shade.a*.65;
}
