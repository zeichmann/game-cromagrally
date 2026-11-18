extends SceneTree
## Real geometry, with front / three-quarter / profile views; no reference image billboards.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	for frame in range(5): await RenderingServer.frame_post_draw
	race.set_process(false)
	race.set_physics_process(false)
	root.disable_3d=true
	var viewport: SubViewport=SubViewport.new()
	viewport.size=Vector2i(1024,1024)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment: WorldEnvironment=WorldEnvironment.new()
	var settings: Environment=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("d9cbb8")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("e4e9eb")
	settings.ambient_light_energy=.45
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	settings.ssao_enabled=true
	settings.ssao_radius=.5
	environment.environment=settings
	viewport.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-35,-30,0)
	sun.light_color=Color("fff0d6")
	sun.light_energy=1.35
	sun.shadow_enabled=true
	viewport.add_child(sun)
	var fill: DirectionalLight3D=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-18,135,0)
	fill.light_color=Color("c4d8e5")
	fill.light_energy=.48
	viewport.add_child(fill)
	var camera: Camera3D=Camera3D.new()
	camera.fov=32
	viewport.add_child(camera)
	for identity in ["zabol","swinka"]:
		var mesh: MeshInstance3D=MeshInstance3D.new()
		mesh.mesh=load("res://assets/characters/storybook_v2/"+identity+"_driver.res")
		viewport.add_child(mesh)
		for i in range(3):
			camera.position=Vector3(0,.85,-3.75) if i==0 else (Vector3(2.65,1.05,-2.65) if i==1 else Vector3(3.75,.87,-.1))
			camera.look_at(Vector3(0,.64,0))
			for frame in range(6): await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://build/art-review/driver_v2_"+identity+"_"+["front","threequarter","profile"][i]+".png")
		mesh.free()
	viewport.queue_free()
	await process_frame
	root.disable_3d=false
	print("STORYBOOK_DRIVER_REVIEW PASS: six views")
	quit()
