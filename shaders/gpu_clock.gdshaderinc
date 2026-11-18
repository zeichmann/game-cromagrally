global uniform sampler2D ir_motion_atlas;
global uniform bool ir_motion_enabled;
float ir_graphics_time() { return ir_motion_enabled ? texelFetch(ir_motion_atlas,ivec2(0,6),0).x : 0.0; }
