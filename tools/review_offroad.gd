extends SceneTree
## Unmodified native captures of both production cars resting on the island.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute("res://build/collisions")
	var race: IRRace=IRRace.new()
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var evidence: Array[Dictionary]=[]
	for variant in range(2):
		race.vehicle_picker.selected=variant
		race.character_picker.selected=variant
		race._preview_selection(variant)
		race.ui.hide()
		var car: IRVehicle=race.vehicles[0]
		var index: int=0
		var outward: Vector3=-race.track.right_at(index)
		var p: Vector3=race.track.centers[index]+outward*(race.track.half_width_at(index)+4)
		p.y=world.terrain.surface_height(p)+1.5
		car.track=null # No recovery or controller can hide missing ground.
		car.process_mode=Node.PROCESS_MODE_INHERIT
		car.transform=Transform3D(Basis(Vector3.UP,atan2(-outward.x,-outward.z)+.25),p)
		for frame in range(120): await physics_frame
		if not car.grounded:
			push_error("Native car did not rest on physical off-road terrain")
			quit(1); return
		race.preview_camera.position=car.position+outward*6+Vector3.UP*5.0
		race.preview_camera.fov=48
		race.preview_camera.look_at(car.position+Vector3.UP*1.3)
		for frame in range(12): await RenderingServer.frame_post_draw
		var screenshot: String="offroad_"+["sail","flywheel"][variant]+".png"
		root.get_texture().get_image().save_png("res://build/collisions/"+screenshot)
		evidence.append({"variant":variant,"position":str(car.position),"visible_ground_y":world.terrain.surface_height(car.position),"grounded":car.grounded,"screenshot":screenshot})
	var file: FileAccess=FileAccess.open("res://build/collisions/native_review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t")+"\n")
	print("OFFROAD_NATIVE_REVIEW PASS: both chassis on physical island ground")
	root.disable_3d=true
	race.queue_free()
	for frame in range(3): await process_frame
	IRDriverArt.gpu_materials.clear()
	quit()
