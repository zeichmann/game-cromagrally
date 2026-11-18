extends SceneTree
## Native image comparisons: resident joints/patrols, facial blink and shared-clock pause.
var assertions: int=0
var failures: int=0
var viewport: SubViewport
var race: IRRace
var records: PackedFloat32Array=PackedFloat32Array()
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func snapshot() -> Image:
	for frame in range(5): await RenderingServer.frame_post_draw
	var img: Image=viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
func changed(a: Image,b: Image) -> int:
	var x: PackedByteArray=a.get_data()
	var y: PackedByteArray=b.get_data()
	var count: int=0
	for i in range(a.get_width()*a.get_height()):
		var delta: int=0
		for c in range(3): delta=maxi(delta,absi(x[i*4+c]-y[i*4+c]))
		if delta>5: count+=1
	return count
func advance(dt: float) -> void:
	race.gpu_motion.dispatch_for_test(records,dt)
	await race.gpu_motion.snapshot_for_test()
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("GPU life image test requires the native renderer")
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	race=IRRace.new()
	root.add_child(race)
	for frame in range(8): await RenderingServer.frame_post_draw
	# Inspect actual renderer instance transforms; the headless dummy does not
	# retain MultiMesh buffers and cannot validate these rendered placements.
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var props_clear: bool=true
	for bank in world.quality_batches:
		if bank.node.multimesh.mesh not in [world.meshes.mushroom,world.meshes.lantern_mushroom]: continue
		for n in range(bank.banks[0].instance_count):
			var p: Vector3=bank.node.transform*bank.banks[0].get_instance_transform(n).origin
			var k: int=race.track.shortcut_nearest(p)
			props_clear=props_clear and Vector2(p.x-race.track.shortcut[k].x,p.z-race.track.shortcut[k].z).length()>IRTrack.SHORTCUT_WIDTH+.6
	check(props_clear,"Rendered mushrooms occupy the grotto driving corridor")
	var soundscape: Node3D=get_first_node_in_group("soundscape")
	var audio_valid: bool=soundscape.sources.size()==7
	for source in soundscape.sources:
		audio_valid=audio_valid and source.playing and is_equal_approx(source.stream.get_length(),8) and source.stream.loop_end==352800 and source.max_distance>0 and source.max_distance<=65
	check(audio_valid,"Positional ambient sources failed to initialise or loop")
	race._start_race(4,true)
	var listeners_valid: bool=not root.audio_listener_enable_3d
	for i in range(4): listeners_valid=listeners_valid and race.cameras[i].get_viewport().audio_listener_enable_3d==(i==0)
	check(listeners_valid,"Split screen must have one positional listener")
	race.set_process(false)
	race.set_physics_process(false)
	race.stage.process_mode=Node.PROCESS_MODE_DISABLED
	race.gpu_motion.set_process(false)
	root.disable_3d=true
	viewport=SubViewport.new()
	viewport.size=Vector2i(400,400)
	viewport.own_world_3d=true
	viewport.audio_listener_enable_3d=false
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment: WorldEnvironment=WorldEnvironment.new()
	var settings: Environment=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("c7c0b2")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=.6
	environment.environment=settings
	viewport.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-35,-30,0)
	viewport.add_child(sun)
	var camera: Camera3D=Camera3D.new()
	camera.fov=36
	viewport.add_child(camera)
	for actor in range(6): records.append_array(PackedFloat32Array([0,0,0,501]))
	for specimen in [["rabbit",1],["mouse",2],["cat",6],["gull",4],["duck",5]]:
		var multi: MultiMesh=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.use_custom_data=true
		multi.mesh=load("res://assets/fairytale/resident_"+specimen[0]+".res")
		multi.instance_count=1
		multi.set_instance_transform(0,Transform3D.IDENTITY)
		multi.set_instance_custom_data(0,Color(0,specimen[1],.7,0))
		var node: MultiMeshInstance3D=MultiMeshInstance3D.new()
		node.multimesh=multi
		node.material_override=IRPaletteMesh.material(false).duplicate()
		node.material_override.shader=load("res://shaders/palette_resident.gdshader")
		node.extra_cull_margin=3
		viewport.add_child(node)
		var large: bool=specimen[1]<3
		var center: Vector3=Vector3(0,1.15,0) if large else Vector3(0,.35,0)
		camera.position=center+Vector3(.8,.22,1).normalized()*(4 if large else 2.8)
		camera.look_at(center)
		var a: Image=await snapshot()
		await advance(.85)
		var b: Image=await snapshot()
		var count: int=changed(a,b)
		check(count>20,"No visible GPU motion for "+specimen[0]+": "+str(count))
		print("GPU_LIFE ",specimen[0]," changed_pixels=",count)
		b.save_png("res://build/art-review/living_gpu_"+specimen[0]+".png")
		node.free()
	var driver: IRDriverArt=IRDriverArt.new(Color.WHITE,1)
	viewport.add_child(driver)
	camera.position=Vector3(0,.91,-1.85)
	camera.look_at(Vector3(0,.9,0))
	var data: PackedFloat32Array=await race.gpu_motion.snapshot_for_test()
	await advance(fposmod(4.6-data[6*32*4],5.4))
	var open: Image=await snapshot()
	await advance(.46)
	var closed: Image=await snapshot()
	check(changed(open,closed)>100,"New GPU facial blink does not change the eyes")
	open.save_png("res://build/art-review/living_blink_open.png")
	closed.save_png("res://build/art-review/living_blink_closed.png")
	# Exercise the production pause path, which submits dt=0 to the same atlas.
	race.gpu_motion.set_process(true)
	race._pause()
	var frozen: Image=await snapshot()
	var paused_again: Image=await snapshot()
	check(frozen.get_data()==paused_again.get_data(),"Shared GPU clock did not freeze resident / facial animation")
	race._resume()
	for frame in range(10): await RenderingServer.frame_post_draw
	var resumed: Image=await snapshot()
	check(changed(frozen,resumed)>20,"GPU facial animation did not resume")
	# Stop every consumer before releasing the shared storage atlas. Keep the
	# hidden root inactive rather than rendering a fresh world during shutdown.
	race.gpu_motion.set_process(false)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	await process_frame
	viewport.free()
	race.queue_free()
	for frame in range(3): await process_frame
	IRDriverArt.gpu_materials.clear()
	print("GPU_LIFE_TEST %s: %d assertions, %d failures"%["PASS" if failures==0 else "FAIL",assertions,failures])
	quit(0 if failures==0 else 1)
