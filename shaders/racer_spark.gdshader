shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
varying vec4 shade;
void vertex() {
 float scale=length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale,INV_VIEW_MATRIX[1]*scale,INV_VIEW_MATRIX[2]*scale,MODEL_MATRIX[3]);
 shade=COLOR;
}
void fragment() {
 vec2 q=(UV-.5)*2.0;
 ALBEDO=shade.rgb;
 ALPHA=(1.0-smoothstep(.25,1.0,dot(q,q)))*shade.a;
}
