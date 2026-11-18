shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_disable;
uniform float rotation = 0.35;
void sky() {
 vec3 direction=normalize(EYEDIR);
 vec2 uv=vec2(fract(atan(direction.x,direction.z)/6.283185307+.5+rotation/6.283185307),acos(clamp(direction.y,-1.0,1.0))/3.141592654);
 // Longitude wraps at the seam. An implicit mip derivative there spans the
 // whole panorama and creates a blue line, so sample the sky explicitly.
 vec3 color=textureLod(panorama,uv,0.0).rgb;
 float seam=1.0-smoothstep(0.0,.025,min(uv.x,1.0-uv.x));
 if(seam>0.0) {
  vec3 mirror=textureLod(panorama,vec2(1.0-uv.x,uv.y),0.0).rgb;
  color=mix(color,(color+mirror)*.5,seam);
 }
 if(direction.y<0.0) {
  color=mix(vec3(.035,.065,.045),color,exp(direction.y*13.0));
 }
 COLOR=color;
}
