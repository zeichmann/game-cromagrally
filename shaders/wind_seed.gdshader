shader_type spatial;
render_mode diffuse_burley;
#include "gpu_clock.gdshaderinc"
varying vec4 shade;
void vertex() {
 float t=ir_graphics_time()+INSTANCE_CUSTOM.x;
 float c=cos(t*.9),s=sin(t*.9);
 mat3 spin=mat3(vec3(c,0,-s),vec3(0,1,0),vec3(s,0,c));
 VERTEX=spin*VERTEX;
 NORMAL=spin*NORMAL;
 VERTEX.y+=sin(t*1.7)*.15;
 if(INSTANCE_CUSTOM.z<.5) { VERTEX=vec3(0); }
 shade=COLOR;
}
void fragment() {
 vec3 gold=vec3(.48,.23,.045);
 ALBEDO=gold*mix(vec3(.85),shade.rgb,.2);
 ROUGHNESS=.28;
 METALLIC=.55;
 EMISSION=gold*.06;
}
