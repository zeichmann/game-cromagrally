shader_type spatial;
varying vec3 bark_position;
void vertex() {
 float t=VERTEX.y+.5;
 VERTEX.x+=t*t*.25;
 bark_position=VERTEX;
}
void fragment() {
 float rings=sin((bark_position.y+.5)*170.0+sin(bark_position.x*9.0)*.35);
 float ridges=smoothstep(.50,.90,rings);
 ALBEDO=mix(vec3(.16,.115,.073),vec3(.28,.225,.15),ridges*.55+.25);
 ROUGHNESS=.88;
 NORMAL_MAP=vec3(.5,.5+ridges*.025,1.0);
}
