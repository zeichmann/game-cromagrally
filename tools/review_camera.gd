extends SceneTree
## Compare two actual follow-camera framings in the game world.

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	race._apply_quality()
	race.set_process(false)
	race.set_physics_process(false)
	race.stage.process_mode=Node.PROCESS_MODE_DISABLED
	race.menu.hide()
	race.showroom_fill.hide()
	var car: IRVehicle=race.vehicles[0]
	for other in race.vehicles:
		other.visible=other==car
	for index in [22,91,177]:
		car.position=race.track.centers[index]+Vector3.UP*.03
		car.rotation.y=atan2(-race.track.tangents[index].x,-race.track.tangents[index].z)
		for variant in ["old","new"]:
			var height: float=3.5 if variant=="old" else 4.4
			var ahead: float=3.8 if variant=="old" else 6.5
			race.preview_camera.position=car.position+car.basis.z*8.0+Vector3.UP*height
			race.preview_camera.fov=64
			race.preview_camera.look_at(car.position-car.basis.z*ahead+Vector3.UP*1.2)
			for frame in range(8):
				await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/art-review/camera_%d_%s.png"%[index,variant])
			print("CAMERA_REVIEW ",index," ",variant)
	race.queue_free()
	await process_frame
	quit()
