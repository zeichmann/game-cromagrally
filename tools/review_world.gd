extends SceneTree
## Actual game-viewport captures at each district, plus two landmark views. No generated mockups.

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	race.quality_picker.selected=0
	race._apply_quality()
	race.set_process(false)
	race.set_physics_process(false)
	race.stage.process_mode=Node.PROCESS_MODE_DISABLED
	race.menu.hide()
	race.showroom_fill.visible=false
	var car: IRVehicle=race.vehicles[0]
	for vehicle in race.vehicles:
		vehicle.visible=vehicle==car
	var folder: String="res://build/art-review"
	DirAccess.make_dir_recursive_absolute(folder)
	var views: Dictionary={"village":22,"grove":91,"waterfall_bridge":177,"castle":225,"gardens":273,"harbor":344}
	if OS.get_cmdline_user_args().has("--harbor-only"):
		views={"harbor":344}
	if OS.get_cmdline_user_args().has("--waterfall-only"):
		views={"waterfall_bridge":177}
	if OS.get_cmdline_user_args().has("--castle-only"):
		views={"castle":225}
	for name_key in views:
		var i: int=views[name_key]
		car.position=race.track.centers[i]+Vector3.UP*.03
		car.rotation.y=atan2(-race.track.tangents[i].x,-race.track.tangents[i].z)
		race.preview_camera.position=car.position-race.track.tangents[i]*8.0+Vector3.UP*4.4
		race.preview_camera.fov=58
		race.preview_camera.look_at(car.position+race.track.tangents[i]*10+Vector3.UP*2)
		for frame in range(7):
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/world_"+name_key+".png")
		print("WORLD_REVIEW ",name_key)
	car.hide()
	for name_key in ["castle_scenic","castle_facade","waterfall_scenic","spring_scenic","village_scenic","gardens_scenic","harbor_scenic","dock_detail"]:
		if OS.get_cmdline_user_args().has("--castle-only") and name_key not in ["castle_scenic","castle_facade"]:
			continue
		if OS.get_cmdline_user_args().has("--harbor-only") and name_key not in ["harbor_scenic","dock_detail"]:
			continue
		if OS.get_cmdline_user_args().has("--waterfall-only") and name_key not in ["waterfall_scenic","spring_scenic"]:
			continue
		var position: Vector3
		var target: Vector3
		match name_key:
			"castle_scenic":
				position=Vector3(-66,42,14)
				target=Vector3(-20,30,-35)
			"castle_facade":
				position=Vector3(-20,32,13)
				target=Vector3(-20,31,-35)
			"waterfall_scenic":
				position=Vector3(-116,16,24)
				target=Vector3(-61,10,7)
			"spring_scenic":
				position=Vector3(-65,39,39)
				target=Vector3(-39,27,-4)
			"harbor_scenic":
				position=race.track.centers[344]-race.track.right_at(344)*53+Vector3.UP*17
				target=race.track.centers[342]-race.track.right_at(342)*19
			"dock_detail":
				position=race.track.centers[344]-race.track.right_at(344)*40+race.track.tangents[344]*12
				position.y=3.2
				target=race.track.centers[344]-race.track.right_at(344)*22+race.track.tangents[344]*8
				target.y=-2.5
			"gardens_scenic":
				position=race.track.centers[289]+race.track.right_at(289)*45+race.track.tangents[289]*15+Vector3.UP*14
				target=race.track.centers[289]+race.track.right_at(289)*22+Vector3.UP*1.6
			_:
				position=race.track.centers[24]-race.track.right_at(24)*37+Vector3.UP*27
				target=race.track.centers[24]+Vector3.UP*2
		race.preview_camera.position=position
		race.preview_camera.fov=55
		race.preview_camera.look_at(target)
		for frame in range(7):
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/world_"+name_key+".png")
		print("WORLD_REVIEW ",name_key)
	var world: IRFairytaleWorld=race.track.get_child(-1).get_child(-1)
	print("WORLD_PLACEMENTS ",JSON.stringify(world.placements))
	race.queue_free()
	await process_frame
	quit()
