extends SceneTree
## Real level bodies and live race cars, including the actual controller callback.
var assertions: int=0
var failures: int=0
var race: IRRace
var evidence: Dictionary={}
const BUILDINGS: Array[String]=["cottage_blue","cottage_rose","cottage_peach","bakery","town_post","town_workshop","town_tea","boathouse","lighthouse","castle_keep","teahouse"]
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value: failures+=1; push_error(message)
func advance(frames: int) -> void:
	for i in range(frames): await physics_frame
func snapshot(_label: String,_focus: Vector3,_outward: Vector3) -> void:
	pass # Native review overrides this; the headless test does no rendering.
func run() -> void:
	race=IRRace.new()
	root.add_child(race)
	race.ui.hide()
	race.set_process(false)
	race.set_physics_process(false)
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var solid: IRWorldCollisions=world.collisions
	check(solid!=null and not solid.bodies.is_empty(),"The rendered world has no static scenery colliders")
	for asset in BUILDINGS:
		if world.placements.has(asset): check(int(solid.counts.get(asset,0))==int(world.placements[asset]),"Missing building colliders: "+asset)
	check(solid.counts.get("teahouse",0)==1,"The hero teahouse must have a physical body")
	check(solid.counts.get("ancient_oak",0)==1,"The hero tree trunk must be physical")
	check(solid.bodies.size()>solid.shapes.size(),"Instances should reuse collision geometry")
	var valid_layers: bool=true
	for body in solid.bodies: valid_layers=valid_layers and body.collision_layer==4 and body.collision_mask==2
	check(valid_layers,"Solid scenery must use its own layer and interact with cars")
	await advance(2)
	var space: PhysicsDirectSpaceState3D=root.world_3d.direct_space_state
	var all_rids: Array[RID]=[]
	for body in solid.bodies: all_rids.append(body.get_rid())
	var ray_count: int=0
	var walls_hit: int=0
	for body in solid.bodies:
		if body.get_meta("asset") not in BUILDINGS: continue
		var mesh: Mesh=body.get_meta("source_mesh")
		var bounds: AABB=mesh.get_aabb()
		var center: Vector3=bounds.get_center()
		var excluded: Array[RID]=all_rids.duplicate()
		excluded.erase(body.get_rid())
		var hits: int=0
		# A boathouse is on stilts: its open lower level is not a missing wall.
		for height in [bounds.position.y+1.2,bounds.get_center().y]:
			center.y=height
			for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
				var start: Vector3=center+axis*(bounds.size.length()+3)
				var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(body.global_transform*start,body.global_transform*center,4,excluded)
				var result: Dictionary=space.intersect_ray(query)
				ray_count+=1
				if not result.is_empty() and result.collider==body and absf(result.normal.y)<.55: hits+=1
		walls_hit+=hits
		check(hits>=2,"Missing physical walls around "+str(body.name))
	evidence["scenery"]={"instances":solid.bodies.size(),"shared_shapes":solid.shapes.size(),"counts":solid.counts,"building_rays":ray_count,"walls_hit":walls_hit}
	print("WORLD_COLLISION_COUNTS ",evidence["scenery"])

	var box: BoxShape3D=BoxShape3D.new()
	box.size=Vector3(2.2,.65,3.3)
	var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
	query.shape=box
	query.collision_mask=4
	var blocked: Array[String]=[]
	for i in range(0,IRTrack.SAMPLES,2):
		for offset in [-1.6,0.0,1.6]:
			var direction: Vector3=race.track.tangents[i]*Vector3(1,0,1)
			var p: Vector3=race.track.centers[i]+race.track.right_at(i)*offset+Vector3.UP*.80
			query.transform=Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),p)
			var hits: Array[Dictionary]=space.intersect_shape(query,8)
			if not hits.is_empty() and blocked.size()<30: blocked.append("road %d offset %.1f: %s"%[i,offset,hits[0].collider.get_meta("asset")])
	for i in range(race.track.shortcut.size()-1):
		var direction: Vector3=(race.track.shortcut[i+1]-race.track.shortcut[i])*Vector3(1,0,1)
		query.transform=Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),race.track.shortcut[i]+Vector3.UP*.80)
		var hits: Array[Dictionary]=space.intersect_shape(query,8)
		if not hits.is_empty() and blocked.size()<30: blocked.append("shortcut %d: %s"%[i,hits[0].collider.get_meta("asset")])
	evidence["blocked_driving_lanes"]=blocked
	check(blocked.is_empty(),"Solid scenery blocks driving lanes: "+str(blocked))
	var body_count: int=solid.bodies.size()
	for quality in range(3):
		world.apply_quality(quality)
		check(solid.bodies.size()==body_count and solid.bodies[0].collision_layer==4,"Changing graphics quality removed collision geometry")

	# Start the real four-view race, then stage a controlled frontal impact.
	# Both cars retain their production tire/steering callback and road contacts.
	race._start_race(4,true)
	race.phase=IRRace.Phase.RACING
	race.set_physics_process(false)
	for car in race.vehicles: car.process_mode=Node.PROCESS_MODE_DISABLED
	var a: IRVehicle=race.vehicles[0]
	var b: IRVehicle=race.vehicles[1]
	var index: int=200
	var direction: Vector3=(race.track.tangents[index]*Vector3(1,0,1)).normalized()
	for data in [[a,-1.0],[b,1.0]]:
		var car: IRVehicle=data[0]
		var sign_value: float=data[1]
		car.human=true
		car.demo_control=false
		car.override_controls={"throttle":0.0,"brake":1.0}
		car.process_mode=Node.PROCESS_MODE_INHERIT
		car.position=race.track.centers[index]+race.track.tangents[index]*sign_value*4.5+Vector3.UP*.18
		var forward: Vector3=direction*-sign_value
		car.rotation.y=atan2(-forward.x,-forward.z)
		car.drive_enabled=true
	await advance(25)
	check(not a.freeze and not b.freeze and a.collision_mask==7 and b.collision_mask==7,"Live racing cars must collide with each other and scenery")
	a.override_controls={"throttle":0.0,"brake":0.0}
	b.override_controls={"throttle":0.0,"brake":0.0}
	a.linear_velocity=direction*12
	b.linear_velocity=-direction*12
	await snapshot("cars_before",(a.position+b.position)*.5,race.track.right_at(index))
	var touched: bool=false
	var smallest: float=INF
	var max_outward_speed: float=0
	for frame in range(60):
		await advance(1)
		var contact_now: bool=a.get_colliding_bodies().has(b) or b.get_colliding_bodies().has(a)
		if contact_now and not touched:
			await snapshot("cars_contact",(a.position+b.position)*.5,race.track.right_at(index))
		touched=touched or contact_now
		smallest=minf(smallest,(b.position-a.position).dot(direction))
		if touched: max_outward_speed=maxf(max_outward_speed,(b.linear_velocity-a.linear_velocity).dot(direction))
	check(touched,"Production cars never generated a mutual contact in the running race")
	check(smallest>2.9,"Production cars passed through one another")
	check(max_outward_speed>.3,"The actual controller erased the car-to-car rebound")
	evidence["live_race_impact"]={"contact":touched,"minimum_separation":smallest,"outward_speed":max_outward_speed,"a_position":str(a.position),"b_position":str(b.position),"a_velocity":str(a.linear_velocity),"b_velocity":str(b.linear_velocity)}
	for camera in race.cameras: check(camera.get_world_3d()==race.stage.get_world_3d(),"A race camera has a separate physics world")
	print("LIVE_RACE_CONTACT ",evidence["live_race_impact"])
	await snapshot("cars_after",(a.position+b.position)*.5,race.track.right_at(index))

	# Hit a real building wall with the real chassis. Pick a clear approach
	# rather than an arbitrary box which would miss placement or layer bugs.
	b.process_mode=Node.PROCESS_MODE_DISABLED
	b.hide()
	a.track=null
	a.gravity_scale=0
	var house: StaticBody3D
	for candidate in solid.bodies:
		if candidate.get_meta("asset")=="teahouse": house=candidate; break
	var house_mesh: Mesh=house.get_meta("source_mesh")
	var house_bounds: AABB=house_mesh.get_aabb()
	var house_center: Vector3=house_bounds.get_center()
	house_center.y=house_bounds.position.y+1.2
	var exclude: Array[RID]=all_rids.duplicate()
	exclude.erase(house.get_rid())
	var house_contact: bool=false
	var closest_wall: float=INF
	for axis in [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.LEFT]:
		var ray: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(house.global_transform*(house_center+axis*(house_bounds.size.length()+3)),house.global_transform*house_center,4,exclude)
		var hit: Dictionary=space.intersect_ray(ray)
		if hit.is_empty() or absf(hit.normal.y)>.3: continue
		var normal: Vector3=(hit.normal*Vector3(1,0,1)).normalized()
		var start: Vector3=hit.position+normal*4-Vector3.UP*.55
		var pose: Transform3D=Transform3D(Basis(Vector3.UP,atan2(normal.x,normal.z)),start)
		var probe: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
		probe.shape=a.get_node("ChassisCollision").shape
		probe.transform=pose*Transform3D(Basis.IDENTITY,Vector3.UP*.55)
		probe.collision_mask=4
		probe.exclude=[house.get_rid()]
		if not space.intersect_shape(probe,1).is_empty(): continue
		a.global_transform=pose
		closest_wall=INF
		a.linear_velocity=-normal*18
		a.angular_velocity=Vector3.ZERO
		await snapshot("building_before",hit.position,normal)
		for frame in range(35):
			await advance(1)
			house_contact=house_contact or a.get_colliding_bodies().has(house)
			closest_wall=minf(closest_wall,(a.position+Vector3.UP*.55-hit.position).dot(normal))
		if house_contact:
			evidence["building_impact"]={"asset":"teahouse","contact":true,"minimum_wall_distance":closest_wall,"position":str(a.position),"velocity":str(a.linear_velocity)}
			await snapshot("building_contact",hit.position,normal)
			break
	check(house_contact,"A production chassis passed through the real teahouse wall")
	check(house_contact and closest_wall>.8,"The chassis center penetrated the building wall")
	print("BUILDING_CONTACT ",evidence.get("building_impact",{}))
	DirAccess.make_dir_recursive_absolute("res://build/scenery-contacts")
	var file: FileAccess=FileAccess.open("res://build/scenery-contacts/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"evidence":evidence},"\t")+"\n")
	print("WORLD_COLLISION_TEST %s: %d assertions, %d failures"%["PASS" if failures==0 else "FAIL",assertions,failures])
	root.disable_3d=true
	race.queue_free()
	for frame in range(3): await process_frame
	IRDriverArt.gpu_materials.clear()
	quit(0 if failures==0 else 1)
