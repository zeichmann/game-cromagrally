shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Low-cost contact shadow for the performance profile; follows the rigid chassis.
void fragment() {
	float radius=length(UV*2.0-1.0);
	ALBEDO=vec3(.045,.035,.025);
	ALPHA=(1.0-smoothstep(.12,1.0,radius))*.32;
}
