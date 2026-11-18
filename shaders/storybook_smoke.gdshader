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
 float cloud=exp(-dot(q,q)*2.5)*(1.0-smoothstep(.45,1.0,length(q)));
 ALBEDO=shade.rgb;
 ALPHA=cloud*shade.a*.65;
}
