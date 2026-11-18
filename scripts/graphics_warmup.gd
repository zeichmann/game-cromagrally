extends RefCounted
## Render the actual mesh/profile combinations behind a loading screen before play.
const MenuArt=preload("res://scripts/menu_art.gd")

func run(race: IRRace) -> void:
	var started: int=Time.get_ticks_msec()
	var original_quality: int=race.quality_picker.selected
	var original_humans: int=race.human_count
	var original_process: bool=race.is_processing()
	var original_physics: bool=race.is_physics_processing()
	var original_input: bool=race.is_processing_unhandled_input()
	var layer: CanvasLayer=CanvasLayer.new()
	layer.layer=100
	race.add_child(layer)
	var paper: ColorRect=ColorRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.color=MenuArt.PAPER
	layer.add_child(paper)
	var label: Label=Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.position=Vector2(-240,-45)
	label.size=Vector2(480,70)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",MenuArt.BODY)
	label.add_theme_font_size_override("font_size",24)
	label.add_theme_color_override("font_color",MenuArt.INK)
	label.text="Preparing Windward Island…"
	paper.add_child(label)
	var progress: ProgressBar=ProgressBar.new()
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	progress.position=Vector2(-160,38)
	progress.size=Vector2(320,5)
	progress.max_value=15
	progress.show_percentage=false
	progress.add_theme_stylebox_override("background",MenuArt.flat(Color("e2dbcd")))
	progress.add_theme_stylebox_override("fill",MenuArt.flat(MenuArt.RED))
	paper.add_child(progress)
	race.get_viewport().gui_release_focus()
	race.set_process(false)
	race.set_physics_process(false)
	race.set_process_unhandled_input(false)
	race.ui.hide()
	await RenderingServer.frame_post_draw
	race._start_race(4,true)
	for car in race.vehicles:
		car.process_mode=Node.PROCESS_MODE_DISABLED
		if car.dust!=null:
			car.dust.emitting=true
		for effect in [car.splash,car.boost_trail,car.leaf_wake]:
			if effect!=null: effect.emitting=true
	for camera in race.cameras:
		var viewport: SubViewport=camera.get_viewport()
		(viewport.get_parent() as SubViewportContainer).stretch=false
		viewport.size=Vector2i(320,200)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var shots: Array[Dictionary]=[]
	for i in [22,91,177,225,273,344]:
		shots.append({"position":race.track.centers[i]-race.track.tangents[i]*8+Vector3.UP*4.4,"target":race.track.centers[i]+race.track.tangents[i]*10+Vector3.UP*2})
	var world: IRFairytaleWorld=race.get_tree().get_first_node_in_group("fairytale_world")
	var quay: Vector3=race.track.centers[344]-race.track.right_at(344)*22
	var sea: Vector3=race.track.centers[344]-race.track.right_at(344)*62+race.track.tangents[344]*15
	sea.y=16
	quay.y=3
	shots.append({"position":sea,"target":quay})
	var plaza: Vector3=world.global_transform*world.landmarks.fountain.origin
	shots.append({"position":plaza+Vector3(-9,6,7),"target":plaza+Vector3.UP*1.5})
	for key in ["bakery","elder_gate","boathouse"]:
		var pose: Transform3D=world.global_transform*world.landmarks[key]
		shots.append({"position":pose*Vector3(12,8,20),"target":pose.origin+Vector3.UP*4})
	shots.append({"position":race.track.centers[49]-race.track.tangents[49]*8+Vector3.UP*4.4,"target":race.track.centers[57]+Vector3.UP*4})
	for index in [105,146,163]:
		shots.append({"position":race.track.centers[index]-race.track.tangents[index]*8+Vector3.UP*4.4,"target":race.track.centers[index]+race.track.tangents[index]*10+Vector3.UP*2})
	var cave: Transform3D=world.landmarks.crystal_grotto
	shots.append({"position":cave*Vector3(3,3,-12),"target":cave.origin+Vector3.UP*2})
	var tea: Transform3D=world.landmarks.tea_hero
	var bend: Transform3D=IRTeaBendLayout.pose(race.track)
	shots.append({"position":tea*Vector3(13,7,22),"target":tea.origin+Vector3.UP*5})
	shots.append({"position":bend*Vector3(-4,2.7,-14),"target":bend*Vector3(-15,.8,-3)})
	shots.append({"position":bend*Vector3(-11,3,14),"target":bend*Vector3(-15,1,4)})
	shots.append({"position":bend*Vector3(-10,7,-22),"target":bend*Vector3(-17,8,-8)})
	for profile in range(3):
		race.quality_picker.selected=profile
		race._apply_quality()
		for batch in range(5):
			for slot in range(4):
				var camera: Camera3D=race.cameras[slot]
				var shot: Dictionary=shots[batch*4+slot]
				camera.position=shot.position
				camera.look_at(shot.target)
			for slot in range(race.vehicles.size()):
				var index: int=22-slot*2
				var car: IRVehicle=race.vehicles[slot]
				car.position=race.track.centers[index]+race.track.right_at(index)*(-2 if slot%2 else 2)+Vector3.UP*.05
				car.rotation.y=atan2(-race.track.tangents[index].x,-race.track.tangents[index].z)
			for frame in range(3):
				await RenderingServer.frame_post_draw
			progress.value=profile*5+batch+1
	for car in race.vehicles:
		if car.dust!=null:
			car.dust.emitting=false
			car.dust.hide()
		for effect in [car.splash,car.boost_trail,car.leaf_wake]:
			if effect!=null:
				effect.emitting=false
				effect.hide()
	for camera in race.cameras:
		var viewport: SubViewport=camera.get_viewport()
		viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		(viewport.get_parent() as SubViewportContainer).stretch=true
	for child in race.panes.get_children():
		child.queue_free()
	race.cameras.clear()
	race.camera_targets.clear()
	race.huddles.clear()
	race.human_count=original_humans
	race.quality_picker.selected=original_quality
	race.ui.show()
	race._show_menu()
	race.set_process(original_process)
	race.set_physics_process(original_physics)
	race.set_process_unhandled_input(original_input)
	layer.queue_free()
	await race.get_tree().process_frame
	print("GRAPHICS_PREPARED ",Time.get_ticks_msec()-started," ms; 3 profiles, 20 views")
