shader_type spatial;
render_mode blend_premul_alpha,depth_draw_never,cull_back,shadows_disabled,fog_disabled;
#include "gpu_motion.gdshaderinc"
#include "driver_deformation.gdshaderinc"
uniform float cornea_gain=.75;

void vertex() {
 ir_driver_deform(VERTEX,NORMAL,BONE_INDICES,BONE_WEIGHTS,UV,UV2,COLOR.a);
 ir_animate(VERTEX,NORMAL);
}

void fragment() {
 // A clear optical surface. Lighting supplies the reflection; no painted glints.
 ALBEDO=vec3(0.0);
 ROUGHNESS=.16;
 METALLIC=0.0;
 SPECULAR=.50;
 ALPHA=.012*min(cornea_gain/.75,1.0);
 PREMUL_ALPHA_FACTOR=cornea_gain;
}
