shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
void vertex() {
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
 MODELVIEW_MATRIX=MODELVIEW_MATRIX*mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0),vec4(0,length(MODEL_MATRIX[1].xyz),0,0),vec4(0,0,1,0),vec4(0,0,0,1));
}
void fragment() {
 vec2 p=UV*2.0-1.0;
 float a=exp(-dot(p,p)*3.5)*smoothstep(1.0,.60,length(p));
 ALBEDO=vec3(.91,.89,.77);
 ALPHA=a*COLOR.a*.20;
}
