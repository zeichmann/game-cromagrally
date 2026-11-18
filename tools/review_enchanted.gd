extends SceneTree
## Driving-camera review is the main art acceptance view, followed by authored close views.
var failures: int=0
var captures: int=0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/art-review")
	var race: IRRace=IRRace.new()
	root.add_child(race)
	for frame in range(5):
		await RenderingServer.frame_post_draw
	race.set_process(false)
	race.set_physics_process(false)
	race.ui.hide()
	race.showroom_fill.hide()
	race.model_preview=false
	for car in race.vehicles:
		car.process_mode=Node.PROCESS_MODE_DISABLED
		car.visible=car==race.vehicles[0]
	var hero: IRVehicle=race.vehicles[0]
	hero.visual.transform=Transform3D.IDENTITY
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	for index in [22,37,49,55,59,91,177,225,344]:
		hero.nearest=index
		hero.position=race.track.centers[index]+Vector3.UP*.03
		hero.rotation.y=atan2(-race.track.tangents[index].x,-race.track.tangents[index].z)
		race.preview_camera.position=hero.position-race.track.tangents[index]*8+Vector3.UP*4.4
		race.preview_camera.fov=58
		race.preview_camera.look_at(hero.position+race.track.tangents[index]*10+Vector3.UP*2)
		await capture("road_%03d"%index)
	hero.hide()
	for key in ["bakery","elder_gate","cottage_blue","boathouse"]:
		var pose: Transform3D=world.global_transform*world.landmarks[key]
		var offset: Vector3=Vector3(12,8,20) if key!="elder_gate" else Vector3(18,16,38)
		var target: Vector3=Vector3.UP*(4 if key!="elder_gate" else 12)
		race.preview_camera.position=pose*offset
		race.preview_camera.look_at(pose.origin+target)
		race.preview_camera.fov=52
		await capture(key)
	race.queue_free()
	await process_frame
	print("ENCHANTED_REVIEW %s: %d captures"%["PASS" if failures==0 else "FAIL",captures])
	quit(0 if failures==0 else 1)
func capture(name_key: String) -> void:
	for frame in range(9):
		await RenderingServer.frame_post_draw
	var saved: Error=root.get_texture().get_image().save_png("res://build/art-review/enchanted_"+name_key+".png")
	if saved!=OK:
		failures+=1
		push_error("Cannot save enchanted review: "+name_key)
	captures+=1
	print("ENCHANTED_REVIEW ",name_key)
