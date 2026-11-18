extends SceneTree
## Actual GPU driver materials and geometric front/profile views, without reference billboards.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	DirAccess.make_dir_recursive_absolute("res://build/portrait-review")
	root.disable_3d=true
	var view: SubViewport=SubViewport.new()
	view.own_world_3d=true
	view.size=Vector2i(1024,1024)
	view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var environment: WorldEnvironment=WorldEnvironment.new()
	var settings: Environment=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("d9cdbb")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("e5e6df")
	settings.ambient_light_energy=.45
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	settings.ssao_enabled=true
	settings.ssao_radius=.3
	settings.ssao_intensity=1.0
	environment.environment=settings
	view.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-30,-28,0)
	sun.light_color=Color("fff0dc")
	sun.light_energy=1.40
	sun.shadow_enabled=true
	view.add_child(sun)
	var fill: DirectionalLight3D=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-10,145,0)
	fill.light_color=Color("d4e2e9")
	fill.light_energy=.5
	view.add_child(fill)
	var camera: Camera3D=Camera3D.new()
	camera.fov=32
	view.add_child(camera)
	for identity in range(2):
		var driver: IRDriverArt=IRDriverArt.new(Color.WHITE,identity)
		view.add_child(driver)
		driver.skinned.set_instance_shader_parameter("ir_face_animation",false)
		for i in range(4):
			camera.position=[Vector3(0,.83,-3.75),Vector3(2.65,1.0,-2.65),Vector3(3.75,.83,-.1),Vector3(.7,1.0,-1.9)][i]
			camera.look_at(Vector3(0,.63,0) if i<3 else Vector3(0,.88,-.1))
			for frame in range(10): await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("res://build/portrait-review/"+["zabol","swinka"][identity]+"_"+["front","threequarter","profile","face"][i]+".png")
		driver.free()
	for species in ["rabbit","mouse"]:
		var resident: MeshInstance3D=MeshInstance3D.new()
		resident.mesh=load("res://assets/fairytale/resident_"+species+".res")
		var material: ShaderMaterial=IRPaletteMesh.material(false).duplicate()
		material.shader=load("res://shaders/palette_resident.gdshader")
		resident.material_override=material
		view.add_child(resident)
		for i in range(2):
			camera.position=Vector3(2.5,1.85,3.7) if i==0 else Vector3(.7,1.9,1.8)
			camera.look_at(Vector3(0,1.25,0) if i==0 else Vector3(0,1.82,0))
			for frame in range(10): await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("res://build/portrait-review/"+species+"_"+["threequarter","face"][i]+".png")
		resident.free()
	print("PORTRAIT_REVIEW PASS: twelve native geometry views")
	quit()
