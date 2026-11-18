shader_type sky;
void sky() {
 float h=max(EYEDIR.y,0.0);
 vec3 blue=mix(vec3(.15,.37,.48),vec3(.025,.16,.39),pow(h,.48));
 vec2 p=EYEDIR.xz/(h+.28);
 float cloud=0.0;
 for(int i=0;i<8;i++) {
  float a=float(i)*2.40+.35;
  vec2 center=vec2(cos(a),sin(a))*(.85+mod(float(i),3.0)*.67);
  vec2 q=(p-center)*vec2(1.0,.82);
  vec2 b=q-vec2(.30,.05);
  vec2 c=q+vec2(.24,.10);
  vec2 d=q-vec2(.12,.20);
  vec2 e=q+vec2(.12,-.18);
  cloud+=exp(-dot(q,q)*10.0)+exp(-dot(b,b)*15.0)*.72+exp(-dot(c,c)*18.0)*.58;
  cloud+=exp(-dot(d,d)*32.0)*.30+exp(-dot(e,e)*28.0)*.28;
 }
 float bank=smoothstep(.14,1.15,cloud)*smoothstep(.025,.12,h)*(1.0-smoothstep(.85,.98,h));
 vec3 white=mix(vec3(.65,.73,.82),vec3(1.40,1.37,1.29),smoothstep(.18,1.3,cloud));
 COLOR=mix(blue,white,bank*.92);
 if(LIGHT0_ENABLED) {
  float sun=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
  COLOR+=vec3(1.0,.72,.35)*(pow(sun,96.0)*.18+smoothstep(.9994,.9997,sun)*1.5);
 }
 if(EYEDIR.y<0.0) { COLOR=mix(vec3(.035,.075,.065),vec3(.15,.37,.48),pow(1.0+EYEDIR.y,8.0)); }
}
