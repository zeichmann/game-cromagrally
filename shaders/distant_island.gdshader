shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D cliff_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D meadow_tex : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment() {
 vec3 n=normalize(world_normal);
 vec2 blend=pow(abs(n.xz),vec2(4.0));
 blend/=max(blend.x+blend.y,.0001);
 vec3 stone=texture(cliff_tex,world_position.zy*.035).rgb*blend.x+texture(cliff_tex,world_position.xy*.035).rgb*blend.y;
 vec3 meadow=texture(meadow_tex,world_position.xz*.04).rgb;
 float green=smoothstep(-4.0,6.0,world_position.y)*smoothstep(.30,.75,n.y);
 ALBEDO=mix(stone*vec3(.42,.51,.45),meadow*vec3(.60,.69,.52),green);
 ROUGHNESS=1.0;
}
