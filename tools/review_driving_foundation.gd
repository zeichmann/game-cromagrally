extends "res://tests/test_driving_foundation.gd"
## Fullscreen QA with the production HUD, spatial voices and pause/settings UI.
func result_path() -> String: return "res://build/driving-review/native_results.json"
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	await super.run()

func snapshot(label: String) -> void:
	var camera: Camera3D=race.cameras[0]
	race.preview_camera.global_transform=camera.global_transform
	race.preview_camera.fov=camera.fov
	race.preview_camera.make_current()
	for i in range(3): await RenderingServer.frame_post_draw
	save_frame(label)

func save_frame(label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://build/driving-review")
	root.get_texture().get_image().save_png("res://build/driving-review/"+RenderingServer.get_current_rendering_method()+"_"+label+".png")

func driving_frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		for camera in race.cameras:
			if camera is IRChaseCamera: camera.update_follow(1.0/60)

func finish_review() -> void:
	evidence["native_renderer"]=RenderingServer.get_current_rendering_method()
	race.quality_picker.selected=1
	race._start_race(1,true)
	race.phase=IRRace.Phase.RACING
	for car in race.vehicles: car.process_mode=Node.PROCESS_MODE_DISABLED
	var car: IRVehicle=race.vehicles[0]
	car.human=true
	car.demo_control=false
	car.process_mode=Node.PROCESS_MODE_INHERIT
	car.drive_enabled=true
	car.position=race.track.centers[200]+Vector3.UP*.35
	var forward: Vector3=(race.track.tangents[200]*Vector3(1,0,1)).normalized()
	car.rotation.y=atan2(-forward.x,-forward.z)
	car.override_controls={"throttle":0.0,"brake":1.0}
	race.ui.show()
	race.preview_camera.clear_current(false)
	await driving_frames(25)
	var idle_pitch: float=car.driving_audio.engine.pitch_scale
	car.override_controls={"throttle":1.0,"brake":0.0}
	await driving_frames(65)
	var driving_speed: float=car.speed
	var acceleration_pitch: float=car.driving_audio.engine.pitch_scale
	check(driving_speed>10 and acceleration_pitch>idle_pitch+.15,"Native engine pitch must react to real acceleration")
	check(car.driving_audio.engine.playing and car.driving_audio.rolling.playing,"Native driving loops must be playing")
	await RenderingServer.frame_post_draw
	save_frame("driving_hud")
	car.boost_charge=3
	check(car.try_boost(),"Native boost input must activate a charged vehicle")
	await driving_frames(8)
	check(car.driving_audio.event_counts.boost==1,"A boost must trigger exactly one spatial sound")
	car.position=race.track.centers[200]+Vector3.UP*.1
	car.rotation.y=atan2(-forward.x,-forward.z)
	car.override_controls={"throttle":0.0,"brake":0.0}
	car.linear_velocity=forward*14
	car.angular_velocity=Vector3.ZERO
	car.boost_remaining=0
	var wall: StaticBody3D=StaticBody3D.new()
	wall.name="ImpactTestFixture"
	wall.collision_layer=4
	wall.collision_mask=2
	wall.position=car.position+forward*5+Vector3.UP*1.8
	wall.rotation.y=car.rotation.y
	var collider: CollisionShape3D=CollisionShape3D.new()
	var shape: BoxShape3D=BoxShape3D.new()
	shape.size=Vector3(10,4,.3)
	collider.shape=shape
	wall.add_child(collider)
	IRArt.block(wall,shape.size,Vector3.ZERO,IRArt.pbr(Color("ab7754")))
	race.stage.add_child(wall)
	await driving_frames(35)
	check(car.impact_events>0 and car.driving_audio.event_counts.impact>0,"Real wall contact must reach the native impact audio voice")
	await RenderingServer.frame_post_draw
	save_frame("impact_hud")
	evidence["native_audio"]={"idle_pitch":idle_pitch,"driving_pitch":acceleration_pitch,"impact_pitch":car.driving_audio.engine.pitch_scale,"driving_speed":driving_speed,"impact_events":car.impact_events,"audio_events":car.driving_audio.event_counts.duplicate()}
	race._pause()
	var paused_at: Vector3=car.position
	for i in range(8): await RenderingServer.frame_post_draw
	check(car.position.is_equal_approx(paused_at),"The improved driving rig must remain frozen during pause")
	race._open_settings()
	await process_frame
	var panel: IRSettingsPanel=race.overlay.get_child(-1)
	panel.capture("brake")
	var key: InputEventKey=InputEventKey.new()
	key.physical_keycode=KEY_F
	key.pressed=true
	panel._input(key)
	check(race.preferences.bindings.brake==KEY_F and panel.capture_action=="","The visible settings panel must rebind a physical key")
	for i in range(3): await RenderingServer.frame_post_draw
	check(panel.get_global_rect().end.y<race.ui.size.y,"The settings panel must fit the fullscreen viewport")
	save_frame("settings_panel")
	panel.close_panel()
	race._resume()
	wall.queue_free()
	race._start_race(4,true)
	race.phase=IRRace.Phase.RACING
	for runner in race.vehicles: runner.drive_enabled=true
	await driving_frames(35)
	await RenderingServer.frame_post_draw
	save_frame("four_views")
	check(race.cameras.size()==4 and race.cameras[3] is IRChaseCamera,"Every local player must use the obstacle-aware camera")
	race._show_menu()
	race.set_process(true)
	for i in range(4): await RenderingServer.frame_post_draw
	check(race.menu.visible and race.controls_hint.get_global_rect().end.y<=race.ui.size.y,"The menu and remapped control hint must fit the fullscreen viewport")
	save_frame("main_menu")
	print("DRIVING_NATIVE_REVIEW PASS: live acceleration, wall impact audio, pause, remapping and four views")
