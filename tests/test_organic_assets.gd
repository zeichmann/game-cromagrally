extends SceneTree
## Check that material packing preserves the optical surface and authored textures.
var assertions: int=0
var failures: int=0
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for identity in range(2):
		for profile in range(3):
			var driver: IRDriverArt=IRDriverArt.new(Color.WHITE,identity)
			driver.set_detail(profile)
			var corneas: int=0
			var opaque_valid: bool=true
			var families: Dictionary={}
			for s in range(driver.skinned.mesh.get_surface_count()):
				var material: ShaderMaterial=driver.skinned.get_surface_override_material(s)
				if material.shader.resource_path.ends_with("academy_cornea.gdshader"):
					corneas+=1
				else:
					opaque_valid=opaque_valid and int(material.get_shader_parameter("ir_material_species"))==identity
					for name in ["organic_frog_tex","organic_pig_tex","organic_iris_tex"]:
						var texture: Texture2D=material.get_shader_parameter(name)
						opaque_valid=opaque_valid and texture!=null and texture.get_width()==1254 and texture.get_height()==1254
				var data: PackedVector2Array=driver.skinned.mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV2]
				for p in data: families[roundi(p.x)]=true
			check(driver.skinned.mesh.get_surface_count()==3 and corneas==1,"Cornea was merged into an opaque palette or duplicated")
			check(opaque_valid,"Organic texture bindings or species were lost during GPU material remapping")
			check(families.has(65) and families.has(66) and families.has(67) and families.has(68) and families.has(69),"A layer of the eye was lost")
			check(not families.has(53) and not families.has(32),"Painted spherical catchlights remain in the eye")
			driver.free()
	print("ORGANIC_ASSET_TEST %s: %d assertions, %d failures"%["PASS" if failures==0 else "FAIL",assertions,failures])
	quit(0 if failures==0 else 1)
