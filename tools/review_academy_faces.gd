extends SceneTree
## Unretouched native renders: sculpture, closed lids and small GPU expressions.
var view: SubViewport
var camera: Camera3D
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for frame in range(8): await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://build/academy-review/"+name+".png")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	DirAccess.make_dir_recursive_absolute("res://build/academy-review")
	root.disable_3d=true
	view=SubViewport.new()
	view.own_world_3d=true
	view.size=Vector2i(1024,1024)
	view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var environment: WorldEnvironment=WorldEnvironment.new()
	var settings: Environment=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("ddd0bb")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("d7dfe1")
	settings.ambient_light_energy=.36
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	settings.ssao_enabled=true
	settings.ssao_radius=.22
	settings.ssao_intensity=.8
	environment.environment=settings
	view.add_child(environment)
	var key: DirectionalLight3D=DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-32,-32,0)
	key.light_color=Color("fff0da")
	key.light_energy=1.5
	key.shadow_enabled=true
	view.add_child(key)
	var fill: DirectionalLight3D=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-12,145,0)
	fill.light_color=Color("c9dce9")
	fill.light_energy=.34
	view.add_child(fill)
	camera=Camera3D.new()
	camera.fov=32
	view.add_child(camera)
	for identity in range(2):
		var driver: IRDriverArt=IRDriverArt.new(Color.WHITE,identity)
		view.add_child(driver)
		driver.skinned.set_instance_shader_parameter("ir_face_animation",false)
		var actor: String=["zabol","swinka"][identity]
		for i in range(4):
			camera.position=[Vector3(0,.88,-3.75),Vector3(1.75,1.03,-3.30),Vector3(3.75,.85,-.1),Vector3(.28,1.0,-1.90)][i]
			camera.look_at(Vector3(0,.66,0) if i<3 else Vector3(0,.86,-.10))
			await capture(actor+"_"+["front","threequarter","profile","face"][i])
		camera.position=Vector3(.28,1.0,-1.90)
		camera.look_at(Vector3(0,.86,-.10))
		driver.skinned.set_instance_shader_parameter("ir_face_animation",true)
		for state in [["calm",Vector4(0,0,0,0)],["joy",Vector4(1,0,0,0)],["blink",Vector4(.3,1,0,0)],["gaze",Vector4(.3,0,.014,.004)]]:
			driver.skinned.set_instance_shader_parameter("ir_face_state",state[1])
			await capture(actor+"_"+state[0])
		driver.free()
	view.size=Vector2i(1600,900)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.50
	camera.position=Vector3(0,.80,-3)
	camera.look_at(Vector3(0,.80,0))
	for identity in range(2):
		var driver: IRDriverArt=IRDriverArt.new(Color.WHITE,identity)
		driver.position.x=-.65 if identity==0 else .65
		driver.skinned.set_instance_shader_parameter("ir_face_state",Vector4(.4,0,0,0))
		view.add_child(driver)
	await capture("duo_faces")
	print("ACADEMY_REVIEW PASS: seventeen native sculpture and expression views")
	quit()
