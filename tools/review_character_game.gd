extends SceneTree
## Both drivers in real cockpit positions and the player's camera, with GPU animation active.
func _initialize() -> void: call_deferred("run")
func capture(key: String) -> void:
	for i in range(12): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/portrait-review/"+key+".png")
	print("CHARACTER_GAME ",key)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute("res://build/portrait-review")
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	race.vehicle_picker.selected=1
	race._preview_selection(1)
	for i in range(5): await RenderingServer.frame_post_draw
	race.set_process(false)
	race.set_physics_process(false)
	race.ui.hide()
	var center: Vector3=race.vehicles[0].position
	var outward: Vector3=race.showroom_outward
	var side: Vector3=Vector3.UP.cross(outward).normalized()
	var pose: Transform3D=race.vehicles[0].transform
	for i in range(2):
		var car: IRVehicle=race.vehicles[i]
		car.process_mode=Node.PROCESS_MODE_DISABLED
		car.visible=true
		car.transform=pose
		car.position=center+side*(-1.35+i*2.7)
	race.preview_camera.position=center+outward*4.8+Vector3.UP*2.4
	race.preview_camera.fov=46
	race.preview_camera.look_at(center+Vector3.UP*1.7)
	await capture("cockpit_pair")
	for i in range(2):
		var car: IRVehicle=race.vehicles[i]
		race.preview_camera.position=car.position+outward*2.5+side*.35+Vector3.UP*2.0
		race.preview_camera.fov=44
		race.preview_camera.look_at(car.position+Vector3.UP*1.94)
		await capture("cockpit_"+["zabol","swinka"][i])
	race.vehicle_picker.selected=0
	race._preview_selection(0)
	for i in range(5): await RenderingServer.frame_post_draw
	race.showroom_fill.hide()
	race.model_preview=false
	for i in range(race.vehicles.size()):
		var car: IRVehicle=race.vehicles[i]
		car.process_mode=Node.PROCESS_MODE_DISABLED
		car.visible=i==0
	var hero: IRVehicle=race.vehicles[0]
	hero.nearest=19
	hero.position=race.track.centers[19]+Vector3.UP*.03
	hero.rotation.y=atan2(-race.track.tangents[19].x,-race.track.tangents[19].z)
	race.preview_camera.position=hero.position-race.track.tangents[19]*8+Vector3.UP*4.4
	race.preview_camera.fov=58
	race.preview_camera.look_at(hero.position+race.track.tangents[19]*10+Vector3.UP*2)
	await capture("drive_visibility")
	hero.hide()
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var tea: Transform3D=world.landmarks.tea_hero
	race.preview_camera.position=tea*Vector3(0,5,22)
	race.preview_camera.fov=45
	race.preview_camera.look_at(tea.origin+Vector3.UP*4.8)
	await capture("villagers_in_game")
	print("CHARACTER_GAME_REVIEW PASS: five native in-game views")
	quit()
