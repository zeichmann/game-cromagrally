extends SceneTree
## Fixed native camera measurements isolate the cost of the new district.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute("res://build/tea-review")
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	await race.prepare_graphics()
	race.set_process(false)
	race.set_physics_process(false)
	race.ui.hide()
	race.showroom_fill.hide()
	race.model_preview=false
	for car in race.vehicles:
		car.process_mode=Node.PROCESS_MODE_DISABLED
		car.hide()
	var hero: IRVehicle=race.vehicles[0]
	hero.position=race.track.centers[19]+Vector3.UP*.03
	hero.rotation.y=atan2(-race.track.tangents[19].x,-race.track.tangents[19].z)
	hero.visual.transform=Transform3D.IDENTITY
	var bend: Transform3D=IRTeaBendLayout.pose(race.track)
	var scenes: Array[Dictionary]=[
		{"name":"drive","position":hero.position-race.track.tangents[19]*8+Vector3.UP*4.4,"target":hero.position+race.track.tangents[19]*10+Vector3.UP*2,"fov":58},
		{"name":"stream","position":bend*Vector3(-4,2.7,-14),"target":bend*Vector3(-15,.8,-3),"fov":55}]
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var results: Array[Dictionary]=[]
	for scene in scenes:
		hero.visible=scene.name=="drive"
		race.preview_camera.position=scene.position
		race.preview_camera.fov=scene.fov
		race.preview_camera.look_at(scene.target)
		for profile in range(3):
			race.quality_picker.selected=profile
			race._apply_quality()
			for i in range(2): await RenderingServer.frame_post_draw
			var warmup: int=Time.get_ticks_usec()
			while Time.get_ticks_usec()-warmup<2000000: await RenderingServer.frame_post_draw
			var frames: Array[float]=[]
			var gpu: float=0
			var started: int=Time.get_ticks_usec()
			var previous: int=started
			while Time.get_ticks_usec()-started<4000000:
				await RenderingServer.frame_post_draw
				var now: int=Time.get_ticks_usec()
				frames.append((now-previous)/1000.0)
				gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
				previous=now
			var total: float=0
			for value in frames: total+=value
			frames.sort()
			var name: String="fixed_"+scene.name+"_"+["high","balanced","performance"][profile]
			var result: Dictionary={"camera":scene.name,"profile":["high","balanced","performance"][profile],"samples":frames.size(),"mean_fps":1000*frames.size()/total,"frame_ms_p99":frames[mini(int(frames.size()*.99),frames.size()-1)],"frame_ms_max":frames[-1],"gpu_ms":gpu/frames.size(),"render_scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"viewport_size":str(root.size),"screenshot":name+".png"}
			root.get_texture().get_image().save_png("res://build/tea-review/"+name+".png")
			results.append(result)
			print("TEA_FIXED ",JSON.stringify(result))
	var file: FileAccess=FileAccess.open("res://build/tea-review/fixed_camera_benchmarks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":"Fixed camera, one stationary visible vehicle in drive view; no AI or vehicle physics. Not a racing FPS measurement.","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"warmup_seconds":2,"measured_seconds_per_case":4,"gpu_motion_initialized":race.gpu_motion.initialized,"results":results},"\t")+"\n")
	print("TEA_FIXED PASS: ",results.size()," measured cases")
	quit(0)
