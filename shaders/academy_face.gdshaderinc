// Lid position deltas: UV.y / UV2.y. Closed normal XY: UV.x / COLOR.a.
// Static per-instance values only: production expression, gaze and blink stay on GPU.
instance uniform int ir_academy_species=0;
instance uniform vec4 ir_face_state=vec4(-1.0,-1.0,0.0,0.0);

vec4 ir_academy_controls() {
 if(ir_motion_enabled && ir_motion_slot>=0) {
  return texelFetch(ir_motion_atlas,ivec2(1+ir_motion_slot*2,6),0);
 }
 // Unbound model viewers use the shared clock; the race uses compute output.
 float t=ir_graphics_time();
 float phase=float(max(ir_motion_slot,0))*.71;
 float clock=mod(t+phase,5.4);
 float blink=smoothstep(4.94,5.04,clock)*(1.0-smoothstep(5.09,5.23,clock));
 float joy=.25+.18*pow(sin(t*.43+phase),2.0);
 float beat=t*.43+phase;
 float index=floor(beat);
 float transition=smoothstep(0.0,.065,fract(beat));
 vec2 previous=vec2(sin((index-1.0)*1.71),cos((index-1.0)*1.23));
 vec2 next=vec2(sin(index*1.71),cos(index*1.23));
 vec2 gaze=mix(previous,next,transition)*vec2(.006,.0035);
 return vec4(blink,joy,gaze);
}

float ir_academy_idle_tilt() {
 if(ir_motion_enabled && ir_motion_slot>=0) {
  return texelFetch(ir_motion_atlas,ivec2(2+ir_motion_slot*2,6),0).x;
 }
 return sin(ir_graphics_time()*.61+float(max(ir_motion_slot,0))*.4)*.009;
}

void ir_academy_face(inout vec3 position,inout vec3 normal,float family,vec2 uv,float delta_z,float packed_normal_y) {
 vec4 controls=ir_academy_controls();
 float blink=ir_face_state.y>=0.0 ? clamp(ir_face_state.y,0.0,1.0) : controls.x;
 float joy=ir_face_state.x>=0.0 ? clamp(ir_face_state.x,0.0,1.0) : controls.y;
 vec2 gaze=controls.zw+ir_face_state.zw;
 float t=ir_graphics_time();
 vec2 size=ir_academy_species==0 ? vec2(.103,.123) : vec2(.090,.108);
 vec2 center=vec2(sign(position.x)*ir_eye_center.x,ir_eye_center.y);
 float lid_close=max(blink,joy*.09);
 if(family==60.0 || family==69.0) {
  position+=vec3(0.0,uv.y,delta_z)*lid_close;
 } else if(family==54.0 || family==55.0) {
  position+=vec3(0.0,uv.y,delta_z)*lid_close;
  vec2 n=vec2(uv.x,packed_normal_y*2.0-1.0);
  vec3 closed=normalize(vec3(n,-sqrt(max(.0001,1.0-dot(n,n)))));
  normal=normalize(mix(normal,closed,lid_close));
 } else if(family==65.0 || family==66.0 || family==67.0) {
  vec2 iris_center=center+vec2(-sign(position.x)*.065,-.025)*size;
  vec2 radius=size*vec2(.72,.74);
  vec2 q=(position.xy-iris_center)/radius;
  vec2 moved=q+gaze/radius;
  // The scleral opening follows the iris while its outer rim stays under the lid.
  // A static opening would expose a crescent-shaped gap whenever the gaze moves.
  float follow=family==65.0 ? 1.0-smoothstep(0.0,.80,length(uv*2.0-1.0)) : 1.0;
  position.xy+=gaze*follow;
  position.z+=.007*(dot(q,q)-dot(moved,moved))*follow;
 } else if(family==52.0 || family==53.0) {
  vec2 q=(position.xy-center)/size;
  vec2 moved=q+gaze/size;
  position.xy+=gaze;
  position.z-=.060*(sqrt(max(0.0,1.0-dot(moved,moved)))-sqrt(max(0.0,1.0-dot(q,q))));
 } else if(family==56.0) {
  // Small unequal brow lift, without a permanently surprised expression.
  position.y+=joy*.004+sin(t*.67+sign(position.x)*.25)*.0015;
 } else if(family==58.0) {
  float free_tip=smoothstep(.35,.61,abs(position.x));
  position.y+=sin(t*1.2+sign(position.x)*.8)*free_tip*.005;
  position.z+=sin(t*1.2+sign(position.x)*.8)*free_tip*.008;
 }
 if(family==50.0 || family==57.0 || family==59.0) {
  float front=smoothstep(.08,.25,-position.z);
  float w=ir_academy_species==0 ? .33 : .214;
  float lower=1.0-smoothstep(.55,.70,position.y);
  float jaw=exp(-pow(position.x/(w+.025),4.0))*lower*front;
  position.y-=joy*.045*jaw;
  float corner=exp(-pow((abs(position.x)-w)/.075,2.0)-pow((position.y-.70)/.085,2.0))*front;
  position.y+=joy*.009*corner;
  position.z-=joy*.005*corner;
 }
}
