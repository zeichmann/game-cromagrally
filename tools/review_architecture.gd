extends SceneTree
## Native game captures of the actual cottage instances, not isolated concept renders.

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
	race.showroom_fill.hide()
	for vehicle in race.vehicles:
		vehicle.hide()
	for frame in range(3):
		await RenderingServer.frame_post_draw
	var world: IRFairytaleWorld=race.track.get_child(-1).get_child(-1)
	for style in ["blue","rose","peach"]:
		for batch in world.quality_batches:
			var node: MultiMeshInstance3D=batch.node
			if not str(node.name).begins_with("0_cottage_"+style):
				continue
			var pose: Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
			race.preview_camera.position=pose.origin+pose.basis.z.normalized()*15+pose.basis.x.normalized()*6+Vector3.UP*6.4
			race.preview_camera.fov=52
			race.preview_camera.look_at(pose.origin+Vector3.UP*3.7)
			for frame in range(8):
				await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/art-review/cottage_"+style+".png")
			print("COTTAGE_REVIEW ",style," ",pose.origin)
			break
	race.queue_free()
	await process_frame
	quit()
