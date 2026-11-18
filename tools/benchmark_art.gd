extends SceneTree
## Real renderer smoke test and repeatable frame-time capture; not a fixed-FPS simulation.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This benchmark needs a real rendering window")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var four: bool = args.has("--four")
	var high: bool = args.has("--high")
	var profile: int = 0 if high else (2 if args.has("--performance") else 1)
	var profile_name: String = ["high","balanced","performance"][profile]
	var showcase: bool = args.has("--showcase")
	var menu_view: bool=args.has("--menu")
	var circuit: bool=args.has("--circuit")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var race: IRRace = IRRace.new()
	root.add_child(race)
	if args.has("--heavy"):
		race.vehicle_picker.selected=1
		race._preview_selection(1)
	if args.has("--swinka"):
		race.character_picker.selected=1
		race._preview_selection(1)
	await process_frame
	var preparation_started: int=Time.get_ticks_msec()
	if not args.has("--cold"):
		await race.prepare_graphics()
	var preparation_ms: int=Time.get_ticks_msec()-preparation_started
	race.quality_picker.selected = profile
	if menu_view:
		race._apply_quality()
	else:
		race._start_race(4 if four else 1, true)
	var viewports: Array[Viewport] = [root]
	for camera in race.cameras:
		viewports.append(camera.get_viewport())
	for viewport in viewports:
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	if showcase:
		race.stage.process_mode = Node.PROCESS_MODE_DISABLED
		race.phase = IRRace.Phase.RESULTS
		var car: IRVehicle = race.vehicles[0]
		for other in race.vehicles:
			other.visible = other == car
		race._arrange_showroom()
		race.set_process(false)
		var camera: Camera3D = race.cameras[0]
		camera.fov=48
		camera.position = car.position+race.showroom_outward*5.2+Vector3.UP*2.3
		camera.look_at(car.position+Vector3.UP*1.45)
		race.huddles[0].visible = false
		race.center_text.visible = false
	var suffix: String = "menu" if menu_view else ("showcase" if showcase else ("four" if four else "single"))
	if args.has("--heavy"):
		suffix+="_flywheel"
	if args.has("--swinka"):
		suffix+="_swinka"
	suffix += "_"+RenderingServer.get_current_rendering_method()+"_"+profile_name
	if circuit:
		suffix+="_circuit"
	var folder: String = "res://build/art-review"
	DirAccess.make_dir_recursive_absolute(folder)
	var frames: Array[float] = []
	var gpu: Array[float] = []
	gpu.resize(viewports.size())
	gpu.fill(0)
	# Pipeline compilation can hold the very first rendered frame for many seconds.
	# Wait for it before starting the warmup and measuring steady frame times.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var layout_valid: bool=false
	for child in race.track.get_children():
		if child is MultiMeshInstance3D:
			var right: Vector3=race.track.right_at(0)
			var up: Vector3=right.cross(race.track.tangents[0]).normalized()
			var origin: Vector3=race.track.centers[0].lerp(race.track.centers[3],.5)-right*(IRTrack.HALF_WIDTH+.42)+up*.04
			var expected: Transform3D=race.track.global_transform*Transform3D(race.track.curb_basis(0),origin)
			var actual: Transform3D=child.global_transform*child.multimesh.get_instance_transform(0)
			layout_valid=(actual*Vector3(1,2,3)).distance_to(expected*Vector3(1,2,3))<.001
	if not layout_valid:
		push_error("ART_LAYOUT failed: rendered curb transform differs from source placement")
		quit(1)
		return
	var world_layout_valid: bool=_world_layout_valid(race)
	if not world_layout_valid:
		push_error("ART_LAYOUT failed: a quality bank moved environment instances")
		quit(1)
		return
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var pipeline_start: Dictionary=_pipeline_monitors()
	var captured: bool = false
	var adventure_observed: Dictionary={"collectibles":false,"boost":false,"jump":false,"splash":false,"leaf_wake":false}
	var duration: float=45.0 if circuit else 17.0
	var districts: Array[Array]=[[],[],[],[],[],[]]
	while Time.get_ticks_usec()-started < duration*1000000:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		var elapsed: float = float(now-started)/1000000.0
		for car in race.vehicles:
			adventure_observed.collectibles=adventure_observed.collectibles or car.seeds_collected>0
			adventure_observed.boost=adventure_observed.boost or car.boost_remaining>0
			adventure_observed.jump=adventure_observed.jump or car.jump_cooldown>0
			adventure_observed.splash=adventure_observed.splash or (car.splash!=null and car.splash.emitting)
			adventure_observed.leaf_wake=adventure_observed.leaf_wake or (car.leaf_wake!=null and car.leaf_wake.emitting)
		if elapsed > 5.0:
			var milliseconds: float=float(now-previous)/1000.0
			frames.append(milliseconds)
			if circuit:
				districts[clampi(race.vehicles[0].nearest/64,0,5)].append(milliseconds)
			for i in range(viewports.size()):
				gpu[i] += RenderingServer.viewport_get_measured_render_time_gpu(viewports[i].get_viewport_rid())
		if not captured and elapsed > 5.5:
			var screenshot: Image = root.get_texture().get_image()
			screenshot.save_png(folder+"/"+suffix+".png")
			captured = true
			# Disk IO and a screenshot readback are not part of ordinary play.
			previous = Time.get_ticks_usec()
			continue
		previous = now
	var sum_ms: float = 0
	var over_100: int=0
	var over_250: int=0
	for value in frames:
		sum_ms += value
		over_100+=1 if value>100 else 0
		over_250+=1 if value>250 else 0
	frames.sort()
	for i in range(gpu.size()):
		gpu[i] /= maxf(frames.size(),1)
	var textures: Dictionary = {}
	for kind in ["road","wood","linen"]:
		var image: Texture2D = IRArt.textured(kind).albedo_texture
		textures[kind] = {"width":image.get_width(),"height":image.get_height()}
	var resolutions: Array[Dictionary] = []
	for camera in race.cameras:
		var view: Viewport = camera.get_viewport()
		resolutions.append({"size":str(view.size),"render_scale":view.scaling_3d_scale,"msaa":view.msaa_3d,"screen_aa":view.screen_space_aa,"upscaler":view.scaling_3d_mode})
	var data: Dictionary = {
		"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"profile":profile_name,
		"views":1 if menu_view else race.cameras.size(),
		"viewport_size":str(root.size),
		"views_3d":resolutions,
		"samples":frames.size(),
		"mean_fps":1000.0*frames.size()/maxf(sum_ms,.001),
		"frame_ms_mean":sum_ms/maxf(frames.size(),1),
		"frame_ms_p50":frames[frames.size()/2] if not frames.is_empty() else 0,
		"frame_ms_p95":frames[mini(int(frames.size()*.95),frames.size()-1)] if not frames.is_empty() else 0,
		"frame_ms_p99":frames[mini(int(frames.size()*.99),frames.size()-1)] if not frames.is_empty() else 0,
		"frame_ms_max":frames[-1] if not frames.is_empty() else 0,
		"frames_over_100ms":over_100,
		"frames_over_250ms":over_250,
		"gpu_ms_by_viewport":gpu,
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"textures":textures,
		"skeleton_bones":IRDriverArt.BONE_COUNT,
		"gpu_pose_generation":race.gpu_motion.initialized,
		"root_camera_active":root.get_camera_3d()!=null,
		"driver_detail":(race.vehicles[0].visual as IRVehicleArt).driver.detail,
		"driver_vertices":_driver_vertices(race),
		"gpu_dust":race.vehicles[0].dust != null,
		"driving_audio":race.vehicles[0].driving_audio!=null,
		"obstacle_aware_camera":race.cameras[0] is IRChaseCamera if not menu_view else false,
		"instance_layout_valid":layout_valid,
		"world_instance_layout_valid":world_layout_valid,
		"screenshot":suffix+".png",
		"pipeline_compilations":_pipeline_delta(pipeline_start),
		"duration_seconds":duration,
		"startup_preparation_ms":preparation_ms,
		"graphics_prepared":race.graphics_prepared,
		"adventure_observed":adventure_observed,
		"completed_laps":race.vehicles[0].progress.completed_laps if not menu_view else 0,
	}
	if circuit:
		var section_data: Dictionary={}
		for i in range(districts.size()):
			var values: Array=districts[i]
			var total: float=0
			for value in values:
				total+=value
			values.sort()
			section_data[["village","grove","waterfall","castle","gardens","harbor"][i]]={"samples":values.size(),"mean_fps":1000*values.size()/maxf(total,.001),"p99_ms":values[mini(int(values.size()*.99),values.size()-1)] if not values.is_empty() else 0}
		data["districts"]=section_data
	var file: FileAccess = FileAccess.open(folder+"/"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	file.close()
	print("ART_REVIEW "+JSON.stringify(data))
	root.disable_3d=true
	race.queue_free()
	for frame in range(3): await process_frame
	IRDriverArt.gpu_materials.clear()
	quit(0)

func _pipeline_monitors() -> Dictionary:
	var result: Dictionary={}
	for key in ClassDB.class_get_integer_constant_list("Performance"):
		if str(key).begins_with("PIPELINE_COMPILATIONS_"):
			result[key]=Performance.get_monitor(ClassDB.class_get_integer_constant("Performance",key))
	return result

func _pipeline_delta(before: Dictionary) -> Dictionary:
	var after: Dictionary=_pipeline_monitors()
	for key in before:
		after[key]-=before[key]
	return after

func _world_layout_valid(race: IRRace) -> bool:
	for world in race.get_tree().get_nodes_in_group("fairytale_world"):
		for bank in world.life.banks:
			if bank.node.multimesh!=bank.variants[race.quality_picker.selected]: return false
			var positions: Dictionary={}
			for n in range(bank.variants[0].instance_count): positions[str(bank.variants[0].get_instance_transform(n))]=true
			for variant in bank.variants:
				for n in range(variant.instance_count):
					if not positions.has(str(variant.get_instance_transform(n))): return false
		for batch in world.quality_batches:
			if batch.node.multimesh!=batch.banks[race.quality_picker.selected]:
				return false
			var original: Dictionary={}
			var full: MultiMesh=batch.banks[0]
			for i in range(full.instance_count):
				var p: Vector3=full.get_instance_transform(i).origin
				original[Vector3i((p*1000).round())]=true
			for bank in batch.banks:
				for i in range(bank.instance_count):
					var p: Vector3=bank.get_instance_transform(i).origin
					if not original.has(Vector3i((p*1000).round())):
						return false
	return true

func _driver_vertices(race: IRRace) -> Array[int]:
	var counts: Array[int]=[]
	for car in race.vehicles:
		var mesh: ArrayMesh=(car.visual as IRVehicleArt).driver.skinned.mesh
		var count: int=0
		for surface in range(mesh.get_surface_count()):
			count+=mesh.surface_get_array_len(surface)
		counts.append(count)
	return counts
