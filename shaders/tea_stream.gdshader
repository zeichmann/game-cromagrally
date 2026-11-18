shader_type spatial;
render_mode cull_disabled;
#include "gpu_clock.gdshaderinc"
varying vec3 stream_position;
void vertex() {
 stream_position=VERTEX;
 float t=ir_graphics_time();
 VERTEX.y+=sin(VERTEX.x*3.2+t*1.2)*.012+sin(VERTEX.z*5.0+VERTEX.x*1.3+t*1.7)*.008;
 NORMAL=normalize(NORMAL+vec3(-cos(VERTEX.x*3.2+t*1.2)*.038,0.0,-cos(VERTEX.z*5.0+VERTEX.x*1.3+t*1.7)*.04));
}
void fragment() {
 float t=ir_graphics_time();
 vec2 p=UV;
 float edge=smoothstep(.63,.99,abs(p.y));
 float ribbons=sin(p.x*5.7+t*1.5+sin(p.y*12.0+p.x*1.2)*1.8);
 float fine=sin(p.x*15.0+t*3.3+sin(p.y*27.0-p.x*3.0)*2.0);
 float ripple=smoothstep(.91,.995,ribbons*.75+fine*.25)*.24;
 vec3 deep=vec3(.075,.205,.18);
 vec3 shallow=vec3(.30,.42,.28);
 ALBEDO=mix(deep,shallow,edge*.75)+vec3(.46,.55,.39)*ripple;
 float froth=smoothstep(.85,.99,abs(p.y))*smoothstep(.25,.85,sin(p.x*7.3+t*1.3+p.y*4.0)*.5+.5);
 ALBEDO=mix(ALBEDO,vec3(.64,.70,.54),froth*.60);
 ROUGHNESS=.25+edge*.12;
 SPECULAR=.65;
 METALLIC=.08;
}
