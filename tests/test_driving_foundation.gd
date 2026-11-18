extends SceneTree
## Actual physics-space checks: camera clearance, traffic and occupied recoveries.
var assertions: int=0
var failures: int=0
var evidence: Dictionary={}
var race: IRRace
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value: failures+=1; push_error(message)
func advance(frames: int) -> void:
	for i in range(frames): await physics_frame
func snapshot(_label: String) -> void: pass
func finish_review() -> void: pass
func result_path() -> String: return "res://build/driving-review/headless_results.json"

func run() -> void:
	var preferences: IRRacePreferences=IRRacePreferences.new()
	preferences.rebind("throttle",KEY_A)
	check(preferences.bindings.throttle==KEY_A and preferences.bindings.left==KEY_W,"Remapping must swap duplicate keys rather than disable a second action")
	preferences.volume=.4
	preferences.sensitivity=1.4
	preferences.rides[2]=1
	check(preferences.save("user://test_driving_settings.json"),"Settings must save atomically")
	var restored: IRRacePreferences=IRRacePreferences.new()
	restored.read("user://test_driving_settings.json")
	check(restored.bindings==preferences.bindings and is_equal_approx(restored.volume,.4) and restored.rides[2]==1,"Settings must survive a fresh load")
	preferences.volume=.5
	check(preferences.save("user://test_driving_settings.json"),"Saving must replace an existing preferences file")
	DirAccess.remove_absolute("user://test_driving_settings.json")

	race=IRRace.new()
	root.add_child(race)
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var oak: ArrayMesh=world.meshes.tree_oak
	var source_indices: int=oak.surface_get_array_index_len(0)
	var low_oak: ArrayMesh=IRQualityMesh.performance(oak)
	check(low_oak.surface_get_array_index_len(0)<source_indices and oak.surface_get_array_index_len(0)==source_indices,"Performance LOD must reduce vegetation without mutating High or collision geometry")
	race.set_process(false)
	race.set_physics_process(false)
	race._start_race(2,true)
	race.phase=IRRace.Phase.RACING
	race.ui.hide()
	for car in race.vehicles: car.process_mode=Node.PROCESS_MODE_DISABLED
	var a: IRVehicle=race.vehicles[0]
	var b: IRVehicle=race.vehicles[1]
	var index: int=200
	var forward: Vector3=(race.track.tangents[index]*Vector3(1,0,1)).normalized()
	a.position=race.track.centers[index]+Vector3.UP*.15
	a.rotation.y=atan2(-forward.x,-forward.z)
	a.speed=20
	var camera: IRChaseCamera=race.cameras[0]
	camera.target=a
	camera.make_current()
	await advance(2)
	camera.update_follow(1.0/60)
	var open_length: float=camera.arm_length
	var focus: Vector3=a.position+Vector3.UP*1.25
	var blocker: StaticBody3D=StaticBody3D.new()
	blocker.collision_layer=4
	blocker.collision_mask=2
	blocker.position=focus+(camera.position-focus)*.43
	blocker.rotation.y=a.rotation.y
	var wall: CollisionShape3D=CollisionShape3D.new()
	var box: BoxShape3D=BoxShape3D.new()
	box.size=Vector3(12,10,.3)
	wall.shape=box
	blocker.add_child(wall)
	race.stage.add_child(blocker)
	await advance(2)
	camera.reset_follow()
	camera.update_follow(1.0/60)
	var blocked_length: float=camera.arm_length
	check(camera.obstruction and blocked_length<open_length*.6,"The camera must contract before a wall, including its near plane")
	var probe: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
	probe.shape=camera.sweep.shape
	probe.transform=Transform3D(Basis.IDENTITY,camera.global_position)
	probe.collision_mask=4
	check(root.world_3d.direct_space_state.intersect_shape(probe,1).is_empty(),"The contracted camera is inside solid scenery")
	await snapshot("camera_wall")
	blocker.queue_free()
	await advance(2)
	for i in range(90): camera.update_follow(1.0/60)
	check(camera.arm_length>open_length*.9,"The camera must release after the obstacle is gone")
	a.speed= -8
	for i in range(100): camera.update_follow(1.0/60)
	check((camera.position-a.position).dot(forward)>4,"Reverse driving must turn the camera toward the direction of travel")
	await snapshot("camera_reverse")
	a.position+=Vector3(30,0,0)
	camera.update_follow(1.0/60)
	check(camera.position.distance_to(a.position)<12,"Recovery must snap the camera instead of flying across the island")
	evidence["camera"]={"open_length":open_length,"blocked_length":blocked_length,"released_length":camera.arm_length}

	a.position=race.track.centers[index]+Vector3.UP*.15
	a.speed=18
	a.nearest=index
	a.linear_velocity=forward*18
	a.rotation.y=atan2(-forward.x,-forward.z)
	b.position=a.position+forward*9
	b.linear_velocity=forward*4
	b.process_mode=Node.PROCESS_MODE_INHERIT
	b.freeze=false
	b.gravity_scale=0
	a.traffic.timer=0
	a.traffic.update(a,root.world_3d.direct_space_state,.2)
	check(absf(a.traffic.lane_goal)>2.3 and a.traffic.decision=="pass","AI must choose a passing corridor around a slower lead car")
	evidence["passing_lane"]=a.traffic.lane_goal
	for n in [2,3]:
		var peer: IRVehicle=race.vehicles[n]
		peer.position=b.position+race.track.right_at(index)*(-2.6 if n==2 else 2.6)
		peer.linear_velocity=forward*4
		peer.process_mode=Node.PROCESS_MODE_INHERIT
		peer.gravity_scale=0
		peer.freeze=false
	a.traffic.timer=0
	a.traffic.update(a,root.world_3d.direct_space_state,.2)
	check(a.traffic.speed_limit<12,"AI must brake when all passing corridors are occupied")
	evidence["blocked_traffic_speed_limit"]=a.traffic.speed_limit
	for car in race.vehicles: car.freeze=true
	var obstacle: StaticBody3D=StaticBody3D.new()
	obstacle.collision_layer=4
	obstacle.collision_mask=2
	obstacle.position=race.track.centers[index+4]+Vector3.UP*1.5
	obstacle.rotation.y=a.rotation.y
	var obstacle_shape: CollisionShape3D=CollisionShape3D.new()
	var obstacle_box: BoxShape3D=BoxShape3D.new()
	obstacle_box.size=Vector3(14,4,2)
	obstacle_shape.shape=obstacle_box
	obstacle.add_child(obstacle_shape)
	race.stage.add_child(obstacle)
	await advance(2)
	a.traffic.timer=0
	a.traffic.update(a,root.world_3d.direct_space_state,.2)
	check(a.traffic.speed_limit==0 and a.traffic.decision=="blocked","AI must brake for a solid obstacle blocking every lane")
	obstacle.queue_free()
	await advance(2)
	a.process_mode=Node.PROCESS_MODE_INHERIT
	a.freeze=true

	a.progress.next_gate=8
	var recovery_index: int=race.track.gate_index(7)+2
	b.position=race.track.centers[recovery_index]-race.track.right_at(recovery_index)*1.8+Vector3.UP*.5
	b.linear_velocity=Vector3.ZERO
	b.rotation.y=atan2(-race.track.tangents[recovery_index].x,-race.track.tangents[recovery_index].z)
	await advance(2)
	probe.shape=b.get_node("ChassisCollision").shape
	probe.transform=b.global_transform*Transform3D(Basis.IDENTITY,Vector3.UP*.55)
	probe.collision_mask=2
	probe.exclude=[a.get_rid()]
	check(not root.world_3d.direct_space_state.intersect_shape(probe,1).is_empty(),"Recovery fixture must be a real occupied physics position")
	a.position=Vector3(0,-9,0)
	a.respawn()
	await advance(2)
	check(a.progress.next_gate==8 and not a.recovery_pending,"Recovery must preserve the next checkpoint and find free space")
	check(a.position.distance_to(b.position)>2.3,"Recovery placed the chassis inside another driver")
	probe.shape=a.get_node("ChassisCollision").shape
	probe.transform=a.global_transform*Transform3D(Basis.IDENTITY,Vector3.UP*.55)
	probe.collision_mask=6
	probe.exclude=[a.get_rid()]
	check(root.world_3d.direct_space_state.intersect_shape(probe,1).is_empty(),"The recovered chassis overlaps another car or scenery")
	var recovered: Vector3=a.position
	a.respawn()
	check(a.position.is_equal_approx(recovered),"Repeated recovery must respect its cooldown")
	evidence["recovery"]={"position":str(a.position),"blocker":str(b.position)}

	check(race.track.surface_at(race.track.centers[230],230)=="paving","The paved road must use road handling")
	check(race.track.surface_at(race.track.centers[185],185)=="wood","The timber bridge must use wooden-surface handling")
	var grass: Vector3=race.track.centers[200]+race.track.right_at(200)*20
	check(race.track.surface_at(grass,200)=="grass","Leaving the road must select the actual off-road handling")
	check(race.track.surface_at(race.track.centers[148],148)=="water","The ford must select wet handling")
	check(float(IRTrack.SURFACES.grass.drive)<float(IRTrack.SURFACES.paving.drive),"Grass must penalize acceleration")
	check(float(IRTrack.SURFACES.water.grip)<float(IRTrack.SURFACES.paving.grip),"Water must have lower tire grip")
	race.preferences.rides[1]=1
	race.preferences.characters[1]=1
	race.vehicle_picker.selected=0
	race.character_picker.selected=0
	race._create_field(2,false)
	check(race.vehicles[0].variant==0 and race.vehicles[1].variant==1,"Local players must keep separate vehicle choices")
	check(race.vehicles[0].character==0 and race.vehicles[1].character==1,"Local players must keep separate character choices")
	await finish_review()
	DirAccess.make_dir_recursive_absolute("res://build/driving-review")
	var file: FileAccess=FileAccess.open(result_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"evidence":evidence},"\t")+"\n")
	print("DRIVING_FOUNDATION_TEST %s: %d assertions, %d failures"%["PASS" if failures==0 else "FAIL",assertions,failures])
	root.disable_3d=true
	race.queue_free()
	for i in range(3): await process_frame
	IRDriverArt.gpu_materials.clear()
	quit(0 if failures==0 else 1)
