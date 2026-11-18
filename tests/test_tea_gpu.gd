extends SceneTree
## Visible native-image changes, production pause and GPUParticles pause/resume.
var race: IRRace
var viewport: SubViewport
var camera: Camera3D
var records: PackedFloat32Array=PackedFloat32Array()
var assertions: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value:
		failures+=1
		push_error(message)
func changed(a: Image,b: Image) -> int:
	var x: PackedByteArray=a.get_data()
	var y: PackedByteArray=b.get_data()
	var count: int=0
	for i in range(a.get_width()*a.get_height()):
		var difference: int=0
		for c in range(3): difference=maxi(difference,absi(x[i*4+c]-y[i*4+c]))
		if difference>5: count+=1
	return count
func snapshot() -> Image:
	for i in range(8): await RenderingServer.frame_post_draw
	var img: Image=viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
func advance(dt: float) -> void:
	race.gpu_motion.dispatch_for_test(records,dt)
	await race.gpu_motion.snapshot_for_test()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute("res://build/tea-review")
	race=IRRace.new()
	root.add_child(race)
	for i in range(8): await RenderingServer.frame_post_draw
	race._start_race(1,true)
	race.set_process(false)
	race.set_physics_process(false)
	race.gpu_motion.set_process(false)
	race.stage.process_mode=Node.PROCESS_MODE_DISABLED
	root.disable_3d=true
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.size=Vector2i(400,400)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment: WorldEnvironment=WorldEnvironment.new()
	var settings: Environment=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("bcb6a6")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=.7
	environment.environment=settings
	viewport.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	viewport.add_child(sun)
	camera=Camera3D.new()
	camera.fov=45
	viewport.add_child(camera)
	for i in range(6): records.append_array(PackedFloat32Array([0,0,0,703]))
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var bend: IRTeaBend=world.tea_bend
	for key in ["leaves","sign","water"]:
		var node: MeshInstance3D=MeshInstance3D.new()
		if key=="leaves":
			node.mesh=bend.tree_node.mesh
			camera.position=Vector3(7,14,19)
			viewport.add_child(node)
			camera.look_at(Vector3(0,11,0))
		elif key=="sign":
			node.mesh=bend.sign_node.mesh
			node.material_override=bend.sign_node.material_override
			viewport.add_child(node)
			camera.position=Vector3(0,-.7,3.4)
			camera.look_at(Vector3(0,-.7,0))
		else:
			node.mesh=bend.stream_node.mesh
			node.material_override=bend.stream_node.material_override
			viewport.add_child(node)
			camera.position=Vector3(-15,3,3)
			camera.look_at(Vector3(-15,-1.9,-3.5))
		await advance(.25)
		var a: Image=await snapshot()
		await advance(1.35)
		var b: Image=await snapshot()
		var pixels: int=changed(a,b)
		check(pixels>35,"No visible GPU movement for "+key+": "+str(pixels))
		print("TEA_GPU ",key," changed_pixels=",pixels)
		b.save_png("res://build/tea-review/gpu_"+key+".png")
		await advance(0)
		var frozen: Image=await snapshot()
		var frozen_again: Image=await snapshot()
		check(frozen.get_data()==frozen_again.get_data(),"GPU clock animation does not freeze: "+key)
		node.free()
	# Duplicate one production emitter into the isolated viewport; no CPU trajectory.
	var steam: GPUParticles3D=bend.effects[1].duplicate()
	steam.position=Vector3.ZERO
	steam.process_mode=Node.PROCESS_MODE_INHERIT
	viewport.add_child(steam)
	camera.position=Vector3(0,.8,3)
	camera.look_at(Vector3(0,.8,0))
	var a: Image=await snapshot()
	for i in range(24): await RenderingServer.frame_post_draw
	var b: Image=await snapshot()
	check(changed(a,b)>30,"Steam particles did not move on GPU")
	race.gpu_motion.set_process(true)
	race._pause()
	var paused: Image=await snapshot()
	var paused_again: Image=await snapshot()
	check(paused.get_data()==paused_again.get_data(),"Steam continues simulating while game is paused")
	race._resume()
	for i in range(20): await RenderingServer.frame_post_draw
	var resumed: Image=await snapshot()
	check(changed(paused,resumed)>30,"Steam particles did not resume")
	print("TEA_GPU_TEST %s: %d assertions, %d failures"%["PASS" if failures==0 else "FAIL",assertions,failures])
	quit(0 if failures==0 else 1)
