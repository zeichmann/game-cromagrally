shader_type spatial;
uniform sampler2D grass_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 local_position;
void vertex() { local_position=VERTEX; }
void fragment() {
 vec3 grass=texture(grass_tex,local_position.xz*.12).rgb;
 float stream_z=-3.2+1.65*sin(local_position.x*.125)+.6*sin(local_position.x*.28+.3);
 float width=1.55+.20*sin(local_position.x*.17+.7)+.12*cos(local_position.x*.33);
 float distance=abs(local_position.z-stream_z)-width;
 float moss=smoothstep(.05,2.4,distance);
 vec3 earth=mix(vec3(.13,.17,.095),grass*vec3(.75,.80,.60),moss);
 ALBEDO=earth;
 ROUGHNESS=mix(.67,.92,moss);
 SPECULAR=.22;
}
