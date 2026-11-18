shader_type spatial;
varying vec3 tire_position;
void vertex() { tire_position=VERTEX; }
void fragment() {
 float a=atan(tire_position.z,tire_position.y);
 float tread=sin(a*42.0+abs(tire_position.x)*22.0);
 float detail=1.0-smoothstep(.5,2.5,fwidth(a*42.0));
 ALBEDO=mix(vec3(.018,.024,.024),vec3(.032,.039,.038),smoothstep(-.5,.5,tread)*detail);
 ROUGHNESS=.82;
 SPECULAR=.32;
}
