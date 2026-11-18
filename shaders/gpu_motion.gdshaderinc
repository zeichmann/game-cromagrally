#include "gpu_clock.gdshaderinc"
instance uniform int ir_motion_slot=-1;
instance uniform int ir_motion_part=0;
instance uniform vec4 ir_root_row0=vec4(1,0,0,0);
instance uniform vec4 ir_root_row1=vec4(0,1,0,0);
instance uniform vec4 ir_root_row2=vec4(0,0,1,0);
instance uniform vec3 ir_inverse_x=vec3(1,0,0);
instance uniform vec3 ir_inverse_y=vec3(0,1,0);
instance uniform vec3 ir_inverse_z=vec3(0,0,1);

mat4 ir_matrix(int actor,int column) {
 vec4 a=texelFetch(ir_motion_atlas,ivec2(column,actor),0);
 vec4 b=texelFetch(ir_motion_atlas,ivec2(column+1,actor),0);
 vec4 c=texelFetch(ir_motion_atlas,ivec2(column+2,actor),0);
 return mat4(vec4(a.x,b.x,c.x,0),vec4(a.y,b.y,c.y,0),vec4(a.z,b.z,c.z,0),vec4(a.w,b.w,c.w,1));
}
mat4 ir_bone(int bone) { return ir_matrix(ir_motion_slot,bone*3); }
void ir_animate(inout vec3 vertex,inout vec3 normal) {
 if(!ir_motion_enabled) { return; }
 if(ir_motion_part==5) {
  mat3 turn=mat3(ir_matrix(7,0));
  vertex=turn*vertex; normal=turn*normal;
 } else if(ir_motion_slot>=0) {
  if(ir_motion_part>=1 && ir_motion_part<=3) {
   mat3 turn=mat3(ir_matrix(ir_motion_slot,20+ir_motion_part*3));
   vertex=turn*vertex; normal=turn*normal;
  }
  mat3 root=mat3(vec3(ir_root_row0.x,ir_root_row1.x,ir_root_row2.x),vec3(ir_root_row0.y,ir_root_row1.y,ir_root_row2.y),vec3(ir_root_row0.z,ir_root_row1.z,ir_root_row2.z));
  mat3 undo=mat3(ir_inverse_x,ir_inverse_y,ir_inverse_z);
  vec3 origin=vec3(ir_root_row0.w,ir_root_row1.w,ir_root_row2.w);
  mat4 body=ir_matrix(ir_motion_slot,20);
  vertex=undo*((body*vec4(root*vertex+origin,1.0)).xyz-origin);
  // Authored part bases have only rotation and uniform scale; no inverse per vertex.
  normal=normalize(undo*(mat3(body)*(root*normal)));
 }
}
