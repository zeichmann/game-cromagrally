shader_type spatial;
#include "gpu_clock.gdshaderinc"
varying vec3 paint;
void vertex() {
 float a=sin(ir_graphics_time()*.95+1.2)*.035;
 mat3 r=mat3(vec3(cos(a),sin(a),0.0),vec3(-sin(a),cos(a),0.0),vec3(0.0,0.0,1.0));
 VERTEX=r*VERTEX;
 NORMAL=r*NORMAL;
 paint=COLOR.rgb;
}
void fragment() { ALBEDO=paint; ROUGHNESS=.76; SPECULAR=.3; }
