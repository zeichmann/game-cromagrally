#[compute]
#version 450
// One invocation owns one actor row. No pose or animation state returns to the CPU.
layout(local_size_x=1, local_size_y=1, local_size_z=1) in;
layout(set=0,binding=0,std430) readonly buffer Controls { vec4 actor[6]; } controls;
layout(rgba32f,set=0,binding=1) uniform image2D poses;
layout(push_constant,std430) uniform Parameters { vec4 step; } params;

mat4 translation(vec3 p) { mat4 m=mat4(1.0); m[3].xyz=p; return m; }
mat4 euler_yxz(vec3 a) {
 vec3 c=cos(a),s=sin(a);
 mat4 x=mat4(1,0,0,0, 0,c.x,s.x,0, 0,-s.x,c.x,0, 0,0,0,1);
 mat4 y=mat4(c.y,0,-s.y,0, 0,1,0,0, s.y,0,c.y,0, 0,0,0,1);
 mat4 z=mat4(c.z,s.z,0,0, -s.z,c.z,0,0, 0,0,1,0, 0,0,0,1);
 return y*x*z;
}
void write_matrix(int actor,int column,mat4 m) {
 for(int row=0;row<3;row++) {
  imageStore(poses,ivec2(column+row,actor),vec4(m[0][row],m[1][row],m[2][row],m[3][row]));
 }
}
void write_bone(int actor,int bone,mat4 m) { write_matrix(actor,bone*3,m); }
void main() {
 int actor=int(gl_GlobalInvocationID.x);
 float dt=params.step.x;
 if(actor==6) {
  vec4 clock=imageLoad(poses,ivec2(0,6));
  if(dt<=0 && clock.w>0) { return; }
  imageStore(poses,ivec2(0,6),vec4(clock.x+dt,dt,0,1));
  write_matrix(7,0,euler_yxz(vec3(0,0,(clock.x+dt)*.42)));
  return;
 }
 if(actor>5) { return; }
 vec4 input_state=controls.actor[actor];
 float steer=clamp(input_state.x,-1,1),speed=input_state.y;
 vec4 state=imageLoad(poses,ivec2(18,actor));
 vec4 chassis=imageLoad(poses,ivec2(19,actor));
 bool reset=state.w!=input_state.w;
 if(dt<=0 && !reset) { return; }
 if(reset) { state=vec4(0,0,0,input_state.w); chassis=vec4(0); }
 state.x=mod(state.x-speed*dt/.45,6.28318530718);
 state.y=mod(state.y+(2.5+abs(speed)*.3)*dt,6.28318530718);
 state.z+=dt;
 // Facial controls are shared by every vertex and viewport. Each actor owns
 // two spare texels in row 6; invocation 6 only owns the global clock at x=0.
 float face_t=state.z,face_phase=float(actor)*.71;
 float blink_clock=mod(face_t+face_phase,5.4);
 float blink=smoothstep(4.94,5.04,blink_clock)*(1-smoothstep(5.09,5.23,blink_clock));
 float joy=.25+.18*pow(sin(face_t*.43+face_phase),2)+.18*abs(steer);
 float beat=face_t*.43+face_phase,index=floor(beat);
 float transition=smoothstep(0,.065,fract(beat));
 vec2 previous=vec2(sin((index-1)*1.71),cos((index-1)*1.23));
 vec2 next=vec2(sin(index*1.71),cos(index*1.23));
 vec2 gaze=mix(previous,next,transition)*vec2(.006,.0035)+vec2(steer*.010,0);
 imageStore(poses,ivec2(1+actor*2,6),vec4(blink,joy,gaze));
 imageStore(poses,ivec2(2+actor*2,6),vec4(sin(face_t*.61+float(actor)*.4)*.009,0,0,1));
 float pitch=asin(clamp(input_state.z,-1,1));
 chassis.x=mix(chassis.x,-steer*speed*.003,1-exp(-7*dt));
 chassis.y=mix(chassis.y,pitch,1-exp(-9*dt));
 chassis.z=mix(chassis.z,-abs(sin(pitch))*1.1,1-exp(-9*dt));
 chassis.w=steer;
 imageStore(poses,ivec2(18,actor),state);
 imageStore(poses,ivec2(19,actor),chassis);
 write_matrix(actor,20,translation(vec3(0,chassis.z,0))*euler_yxz(vec3(chassis.y,0,chassis.x)));
 write_matrix(actor,23,euler_yxz(vec3(state.x,-steer*.38,0)));
 write_matrix(actor,26,euler_yxz(vec3(state.x,0,0)));
 write_matrix(actor,29,euler_yxz(vec3(0,0,state.y)));
 float t=state.z,wind=clamp(abs(speed)/25,0,1);
 mat4 torso=translation(vec3(0,sin(t*1.8)*.002,0))*euler_yxz(vec3(sin(t*5)*min(abs(speed)*.0006,.018),0,steer*.055));
 write_bone(actor,0,torso);
 vec3 head=vec3(0,.44,0),left=vec3(-.28,.30,0),right=vec3(.28,.30,0),scarf=vec3(0,.39,.04),tip=vec3(0,0,.30);
 write_bone(actor,1,torso*translation(head)*euler_yxz(vec3(sin(t*.8)*.009,-steer*.16+sin(t*.6)*.022,-steer*.035))*translation(-head));
 write_bone(actor,2,torso*translation(left)*euler_yxz(vec3(.15,steer*.12,.13+steer*.07))*translation(-left));
 write_bone(actor,3,torso*translation(right)*euler_yxz(vec3(.15,steer*.12,-.13+steer*.07))*translation(-right));
 mat4 scarf_pose=torso*translation(scarf)*euler_yxz(vec3(sin(t*5)*(.025+.09*wind),sin(t*3)*.08*wind,0));
 write_bone(actor,4,scarf_pose*translation(-scarf));
 write_bone(actor,5,scarf_pose*translation(tip)*euler_yxz(vec3(sin(t*5-.7)*(.035+.16*wind),sin(t*3-1)*.10*wind,0))*translation(-scarf-tip));
}
