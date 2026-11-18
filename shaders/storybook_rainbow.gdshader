shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
varying vec4 shade;
void vertex() { shade=COLOR; }
void fragment() {
 ALBEDO=shade.rgb;
 float fringe=smoothstep(0.0,.15,UV.y)*(1.0-smoothstep(.85,1.0,UV.y));
 ALPHA=.075*fringe*sin(UV.x*3.14159)*(1.0-smoothstep(65.0,120.0,length(VERTEX)));
}
