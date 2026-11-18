shader_type spatial;
#include "gpu_clock.gdshaderinc"
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 boat_shadow_center = vec2(100000.0);
// World x/z and the precomputed cosine/sine of each static mooring angle.
uniform vec4 boat_shadows[5];
varying vec3 world_position;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(p.x*.055+ir_graphics_time()*.7)*.16+cos(p.z*.08-ir_graphics_time()*.55)*.10;
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 float raw_depth=texture(scene_depth,SCREEN_UV).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(SCREEN_UV,raw_depth)*2.0-1.0;
 #else
 vec3 ndc=vec3(SCREEN_UV*2.0-1.0,raw_depth);
 #endif
 vec4 ground=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
 float thickness=max(-ground.z/max(ground.w,.0001)+VERTEX.z,0.0);
 vec2 p=world_position.xz;
 float flow=sin(p.x*.039+p.y*.047+ir_graphics_time()*.14)*1.6;
 vec2 ripple=vec2(cos(p.x*.41+p.y*.27+flow+ir_graphics_time()*.8),sin(p.y*.37-p.x*.15-ir_graphics_time()*.6))*.04;
 ripple+=vec2(sin(p.x*.21-p.y*.25+ir_graphics_time()*.4),cos(p.x*.16+p.y*.21+ir_graphics_time()*.32))*.02;
 float distance_fade=1.0-smoothstep(80.0,260.0,length(VERTEX));
 NORMAL_MAP=normalize(vec3(ripple*distance_fade,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.8;
 float shallows=exp(-thickness*.24);
 float wave=sin(p.x*.8+p.y*.51+ir_graphics_time()*1.3+flow)*.5+.5;
 float foam=(1.0-smoothstep(.10,.9,thickness))*(.25+smoothstep(.45,.85,wave)*.65);
 ALBEDO=mix(vec3(.025,.13,.23),vec3(.08,.41,.36),shallows);
 float contact=0.0;
 vec2 harbor_delta=p-boat_shadow_center;
 if(dot(harbor_delta,harbor_delta)<550.0) {
  for(int i=0;i<5;i++) {
   vec4 boat=boat_shadows[i];
   vec2 delta=(p-boat.xy)/.85;
   if(dot(delta,delta)<64.0) {
    vec2 local=mat2(vec2(boat.z,boat.w),vec2(-boat.w,boat.z))*delta;
    contact=max(contact,exp(-dot(local/vec2(1.25,2.6),local/vec2(1.25,2.6))*2.0));
   }
  }
 }
 ALBEDO*=1.0-contact*.16;
 if(shallows>.08) {
  float caustic=pow(max(sin(p.x*.63+sin(p.y*.37)+ir_graphics_time()*.5)*sin(p.y*.55+sin(p.x*.41)-ir_graphics_time()*.4),0.0),9.0);
  ALBEDO+=vec3(.045,.060,.035)*caustic*shallows;
 }
 ALBEDO=mix(ALBEDO,vec3(.76,.83,.75),foam*.75);
 ROUGHNESS=mix(.28,.75,foam);
 METALLIC=0.0;
 SPECULAR=.4;
 ALPHA=clamp(mix(.995,.94,shallows)+foam*.06,0.0,1.0);
}
