shader_type spatial;
render_mode diffuse_burley,cull_disabled;
void fragment() {
 if(abs(UV.x-.5)>sin(UV.y*3.14159)*.44) { discard; }
 ALBEDO=mix(vec3(.17,.27,.065),vec3(.43,.49,.16),UV.y);
 ROUGHNESS=.9;
 BACKLIGHT=ALBEDO*.3;
}
