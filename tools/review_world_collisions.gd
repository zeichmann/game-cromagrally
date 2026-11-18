extends "res://tests/test_world_collisions.gd"
## The same physical assertions, with native fullscreen evidence at each impact.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	print("WORLD_NATIVE_REVIEW START: ",DisplayServer.get_name())
	await super.run()
func snapshot(label: String,focus: Vector3,outward: Vector3) -> void:
	DirAccess.make_dir_recursive_absolute("res://build/scenery-contacts")
	race.ui.hide()
	race.preview_camera.make_current()
	var side: Vector3=outward.cross(Vector3.UP).normalized()
	race.preview_camera.position=focus+outward*8+side*2.8+Vector3.UP*4.0
	race.preview_camera.fov=48
	race.preview_camera.look_at(focus+Vector3.UP*.9)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/scenery-contacts/"+label+".png")
