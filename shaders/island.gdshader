shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p) { vec3 q=fract(vec3(p.x,p.y,p.x)*.1031); q+=dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=MODEL_NORMAL_MATRIX*NORMAL; }
void fragment() {
 float broad=noise(world_position.xz*0.065);
 vec3 turf=texture(grass_tex,world_position.xz*.115).rgb;
 vec3 grass=mix(vec3(.16,.245,.075),turf,.55)*mix(vec3(.76,.91,.84),vec3(1.05,1.02,.87),broad);
 vec3 sand=texture(sand_tex,world_position.xz*.13).rgb*mix(vec3(.83,.88,.90),vec3(.96,.97,.94),broad);
 float shore=1.0-smoothstep(-5.4,-1.8,world_position.y);
 vec3 base=mix(grass,sand,shore);
 float stone=1.0-smoothstep(.45,.80,normalize(world_normal).y);
 vec3 w=abs(normalize(world_normal));
 vec2 blend=pow(w.xz,vec2(4.0));
 blend/=max(blend.x+blend.y,.0001);
 vec3 rock=texture(rock_tex,world_position.zy*.10).rgb*blend.x+texture(rock_tex,world_position.xy*.10).rgb*blend.y;
 ALBEDO=mix(base,rock*vec3(.80,.85,.77),stone*.87);
 ROUGHNESS=.92;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX),n=normalize(NORMAL);
 vec3 r1=cross(sy,n),r2=cross(n,sx);
 float determinant=dot(sx,r1);
 float height=dot(rock,vec3(.3,.5,.2))*.018*stone;
 if(abs(determinant)>1e-12) { NORMAL=normalize(abs(determinant)*n-sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2)); }
}
