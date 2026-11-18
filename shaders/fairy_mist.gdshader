shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec4 shade;
void vertex() {
 float s=length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*s,INV_VIEW_MATRIX[1]*s,INV_VIEW_MATRIX[2]*s,MODEL_MATRIX[3]);
 shade=COLOR;
}
void fragment() {
 vec2 q=(UV-.5)*2.0;
 float mist=exp(-dot(q,q)*3.5)*(1.0-smoothstep(.4,1.0,length(q)));
 ALBEDO=vec3(.87,.96,.98);
 ALPHA=mist*.065*shade.a;
}
