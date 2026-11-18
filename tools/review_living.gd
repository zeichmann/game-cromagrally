extends SceneTree
## Actual driving-camera proof plus neighbourhood detail views, using the native renderer.
var captures: int=0
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/art-review")
	var race: IRRace=IRRace.new()
	root.add_child(race)
	for frame in range(5): await RenderingServer.frame_post_draw
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
	for index in [15,28,45,66,89,105,114,146,163,223,250,333]:
		hero.nearest=index
		hero.position=race.track.centers[index]+Vector3.UP*.03
		hero.rotation.y=atan2(-race.track.tangents[index].x,-race.track.tangents[index].z)
		race.preview_camera.position=hero.position-race.track.tangents[index]*8+Vector3.UP*4.4
		race.preview_camera.fov=58
		race.preview_camera.look_at(hero.position+race.track.tangents[index]*10+Vector3.UP*2)
		await capture("road_%03d"%index)
	hero.hide()
	for key in ["town_post","town_workshop","crystal_grotto","port_crane"]:
		var pose: Transform3D=world.global_transform*world.landmarks[key]
		var offset: Vector3=Vector3(12,8,20) if key!="crystal_grotto" else Vector3(0,3,-10)
		race.preview_camera.position=pose*offset
		race.preview_camera.look_at(pose.origin+Vector3.UP*(4 if key!="crystal_grotto" else 2))
		race.preview_camera.fov=48
		await capture(key)
	var plaza: Vector3=world.landmarks.fountain.origin
	race.preview_camera.position=plaza+Vector3(-10,6,8)
	race.preview_camera.look_at(plaza+Vector3.UP*1.4)
	await capture("village_square")
	print("LIVING_REVIEW %s: %d captures"%["PASS" if failures==0 else "FAIL",captures])
	quit(0 if failures==0 else 1)
func capture(key: String) -> void:
	for frame in range(9): await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://build/art-review/living_"+key+".png")!=OK: failures+=1
	captures+=1
	print("LIVING_REVIEW ",key)
