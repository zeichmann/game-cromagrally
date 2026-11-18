shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float texture_strength = 0.78;
uniform float texture_scale = 1.0;
uniform float roughness = 0.78;
uniform bool world_mapping = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment() {
 vec3 texel=texture(albedo_tex,UV*texture_scale).rgb;
 if(world_mapping) {
  vec3 weight=pow(abs(world_normal),vec3(4.0));
  weight/=max(weight.x+weight.y+weight.z,.001);
  texel=texture(albedo_tex,world_position.zy*.18).rgb*weight.x+texture(albedo_tex,world_position.xz*.18).rgb*weight.y+texture(albedo_tex,world_position.xy*.18).rgb*weight.z;
 }
 ALBEDO=mix(vec3(1.0),texel,texture_strength)*tint.rgb;
 ROUGHNESS=roughness;
 SPECULAR=0.32;
 float grain=dot(texel,vec3(.3,.5,.2));
 NORMAL_MAP=normalize(vec3(-vec2(dFdx(grain),dFdy(grain))*1.4,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.17;
}
