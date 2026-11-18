// Analytic joint animation, patrols and flight entirely in the vertex stage.
void resident_rotate(inout vec3 p,inout vec3 n,vec3 pivot,float angle,int axis) {
 p-=pivot;
 float c=cos(angle),s=sin(angle);
 mat3 r=axis==0 ? mat3(vec3(1,0,0),vec3(0,c,s),vec3(0,-s,c)) : (axis==1 ? mat3(vec3(c,0,-s),vec3(0,1,0),vec3(s,0,c)) : mat3(vec3(c,s,0),vec3(-s,c,0),vec3(0,0,1)));
 p=r*p+pivot;
 n=r*n;
}
void resident_animate(inout vec3 p,inout vec3 n,int joint,vec4 custom) {
 float time=ir_graphics_time();
 float t=time+custom.x;
 int role=int(custom.y+.5);
 float stride=sin(t*3.1);
 if(role==4) {
  if(joint==2 || joint==3) { resident_rotate(p,n,vec3(0,.18,0),sin(t*5.0)*.6*(joint==2?1.0:-1.0),2); }
  p+=vec3(sin(t*.18)*custom.z,sin(t*.35)*.5,cos(t*.18)*custom.z*.6);
 } else if(role==5) {
  p.y+=sin(t*1.2)*.055;
  p.x+=sin(t*.18)*custom.z;
  p.z+=cos(t*.18)*custom.z*.35;
 } else if(role==6) {
  if(joint==1) { resident_rotate(p,n,vec3(0,.58,.34),sin(t*.7)*.13,1); }
  if(joint==3) { resident_rotate(p,n,vec3(0,.4,-.35),sin(t*1.2)*.18,2); }
 } else {
  if(joint==1) { resident_rotate(p,n,vec3(0,1.55,0),sin(t*.8)*.11,1); }
  if(joint==2 || joint==3) {
   float side=joint==2?-1.0:1.0;
   float angle=role==1 && joint==3 ? -1.8+sin(t*3.5)*.38 : (role==2 ? stride*side*.35 : sin(t*1.3+side)*.07);
   resident_rotate(p,n,vec3(side*.31,1.25,0),angle,2);
  }
  if(role==2) {
   if(joint==4 || joint==5) { resident_rotate(p,n,vec3(joint==4?-.19:.19,.73,0),stride*(joint==4?1.0:-1.0)*.35,0); }
   resident_rotate(p,n,vec3(0),3.14159*(1.0-smoothstep(-.07,.07,cos(t*.32))),1);
   p.z+=sin(t*.32)*custom.z;
   p.y+=abs(stride)*.025;
  } else { p.y+=sin(t*1.5)*.012; }
 }
}
