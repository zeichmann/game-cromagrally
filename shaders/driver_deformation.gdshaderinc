// Shared by the opaque driver and its optically separate cornea.
// gpu_motion.gdshaderinc must be included first.
instance uniform bool ir_face_animation=true;
instance uniform vec2 ir_eye_center=vec2(.226,.972);
#include "academy_face.gdshaderinc"

void ir_driver_deform(inout vec3 p,inout vec3 n,uvec4 bones,vec4 weights,vec2 uv,vec2 data,float alpha) {
 if(ir_face_animation) {
  float family=floor(data.x+.5);
  if(family>=50.0 && family<=71.0) {
   ir_academy_face(p,n,family,uv,data.y,alpha);
  } else {
   float clock=mod(ir_graphics_time()+float(max(ir_motion_slot,0))*.71,5.4);
   float blink=smoothstep(4.94,5.04,clock)*(1.0-smoothstep(5.09,5.23,clock));
   if(family==31.0 || family==32.0 || family==42.0) {
    p.y=ir_eye_center.y+(p.y-ir_eye_center.y)*mix(1.0,.035,blink);
    n=normalize(n*vec3(1.0,mix(1.0,28.57,blink),1.0));
   } else if(family==33.0) {
    p.y=ir_eye_center.y+(p.y-ir_eye_center.y)*(1.0-1.8*blink);
   } else if(family==43.0) {
    p.y=ir_eye_center.y+(p.y-ir_eye_center.y)*(1.0-blink);
   }
  }
  if(int(bones.x)==1) {
   float tilt=((ir_academy_species==0 ? -.035 : .055)+ir_academy_idle_tilt())*weights.x;
   mat2 turn=mat2(vec2(cos(tilt),sin(tilt)),vec2(-sin(tilt),cos(tilt)));
   p.xy=turn*(p.xy-vec2(0.0,.44))+vec2(0.0,.44);
   n.xy=turn*n.xy;
  }
 }
 if(ir_motion_slot>=0 && ir_motion_enabled) {
  mat4 skin=mat4(vec4(0),vec4(0),vec4(0),vec4(0));
  for(int i=0;i<4;i++) {
   if(weights[i]>0.0) { skin+=ir_bone(int(bones[i]))*weights[i]; }
  }
  p=(skin*vec4(p,1.0)).xyz;
  n=normalize(mat3(skin)*n);
 }
}
