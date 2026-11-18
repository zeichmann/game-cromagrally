extends SceneTree
## Controlled A/B diagnostics: fixed geometry, cameras and pixel sizes, no racing simulation.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var four: bool=OS.get_cmdline_user_args().has("--four")
	if OS.get_cmdline_user_args().has("--coarse"):
		IRFairytaleWorld.batch_cell_size=0
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	race.quality_picker.selected=1
	race._start_race(4 if four else 1,true)
	race.set_process(false)
	race.set_physics_process(false)
	race.stage.process_mode=Node.PROCESS_MODE_DISABLED
	race.phase=IRRace.Phase.RESULTS
	if OS.get_cmdline_user_args().has("--no-occlusion"):
		root.use_occlusion_culling=false
		for camera in race.cameras:
			camera.get_viewport().use_occlusion_culling=false
	race.center_text.hide()
	for hud in race.huddles:
		hud.hide()
	for slot in range(race.vehicles.size()):
		var car: IRVehicle=race.vehicles[slot]
		var index: int=(195 if OS.get_cmdline_user_args().has("--landmark") else 22)-slot*2
		car.position=race.track.centers[index]+race.track.right_at(index)*(-2.0 if slot%2 else 2.0)+Vector3.UP*.03
		car.rotation.y=atan2(-race.track.tangents[index].x,-race.track.tangents[index].z)
	for index in range(race.cameras.size()):
		var camera: Camera3D=race.cameras[index]
		var car: IRVehicle=race.vehicles[index]
		var i: int=race.track.closest_index(car.position)
		camera.position=car.position-race.track.tangents[i]*8.5+Vector3.UP*3.2
		camera.look_at(car.position+race.track.tangents[i]*10+Vector3.UP*.8)
	var worlds: Array[Node]=get_nodes_in_group("fairytale_world")
	var modes: Array[Dictionary]=[
		{"name":"baseline_4096","shadow":4096},
		{"name":"shadow_2048","shadow":2048},
		{"name":"shadow_1024","shadow":1024},
		{"name":"shadow_off","shadow":1024,"no_shadow":true},
		{"name":"no_small_2048","shadow":2048,"no_small":true},
		{"name":"world_off_2048","shadow":2048,"no_world":true},
		{"name":"native_2048","shadow":2048,"native":true},
	]
	var viewports: Array[Viewport]=[]
	if OS.get_cmdline_user_args().has("--quick"):
		modes=[modes[0],modes[1],modes[-1]]
	if OS.get_cmdline_user_args().has("--culling"):
		modes=[{"name":"culling_2048","shadow":2048,"native":true}]
	for camera in race.cameras:
		viewports.append(camera.get_viewport())
		RenderingServer.viewport_set_measure_render_time(camera.get_viewport().get_viewport_rid(),true)
	var results: Array[Dictionary]=[]
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for mode in modes:
		RenderingServer.directional_shadow_atlas_set_size(mode.shadow,true)
		race.sun.shadow_enabled=not mode.get("no_shadow",false)
		for world in worlds:
			world.show()
			world.apply_quality(1)
			for batch in world.quality_batches:
				if mode.get("no_small",false) and batch.small:
					batch.node.hide()
			if mode.get("no_world",false):
				world.hide()
		for view in viewports:
			view.scaling_3d_scale=(.75 if four else 1.0)*(1280.0/1440.0 if mode.get("native",false) else 1.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var started: int=Time.get_ticks_usec()
		var previous: int=started
		var samples: Array[float]=[]
		var gpu_sum: float=0
		while Time.get_ticks_usec()-started<3500000:
			await RenderingServer.frame_post_draw
			var now: int=Time.get_ticks_usec()
			if now-started>1000000:
				samples.append((now-previous)/1000.0)
				for viewport in viewports:
					gpu_sum+=RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
			previous=now
		var total: float=0
		for sample in samples:
			total+=sample
		var result: Dictionary={"mode":mode.name,"views":viewports.size(),"fps":1000*samples.size()/maxf(total,.001),"gpu_ms_sum":gpu_sum/maxi(samples.size(),1),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
		results.append(result)
		print("WORLD_PROFILE ",JSON.stringify(result))
	var folder: String="res://build/art-review"
	DirAccess.make_dir_recursive_absolute(folder)
	var label: String=("four" if four else "single")+("_coarse" if OS.get_cmdline_user_args().has("--coarse") else "_fine")+("_no_occ" if OS.get_cmdline_user_args().has("--no-occlusion") else "_occ")
	label+="_landmark" if OS.get_cmdline_user_args().has("--landmark") else "_village"
	var file: FileAccess=FileAccess.open(folder+"/fixed_profile_"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")+"\n")
	race.queue_free()
	await process_frame
	quit()
