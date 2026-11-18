extends SceneTree
## Regression: the visible island must physically support cars outside the road.
const Contacts=preload("res://scripts/vehicle_contacts.gd")
var failures: int=0
var assertions: int=0
var race: IRRace
var cars: Array[IRVehicle]=[]
var touchdowns: Dictionary={}
var samples: Array[Dictionary]=[]
var edge_samples: Array[Dictionary]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value: failures+=1; push_error(message)
func advance(frames: int) -> void:
	for i in range(frames): await physics_frame
func collect_other_statics(node: Node,keep: StaticBody3D,excluded: Array[RID]) -> void:
	if node is StaticBody3D and node!=keep: excluded.append(node.get_rid())
	for child in node.get_children(): collect_other_statics(child,keep,excluded)
func run() -> void:
	race=IRRace.new()
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var scenery: IRSceneryArt=world.terrain
	var ground: MeshInstance3D=scenery.get_node("IslandGround")
	var body: StaticBody3D=ground.get_node("IslandGroundCollision")
	var shape: ConcavePolygonShape3D=body.get_child(0).shape
	check(shape.get_faces()==ground.mesh.get_faces(),"Collision triangles must exactly match the rendered island")
	check(body.collision_layer & 1 and body.collision_mask & 2,"The island collider must interact with racing cars")
	await advance(2)
	var exclude: Array[RID]=[]
	collect_other_statics(race.stage,body,exclude)
	var space: PhysicsDirectSpaceState3D=root.world_3d.direct_space_state
	var ray_count: int=0
	var missing: int=0
	var wrong_height: int=0
	for index in range(0,IRTrack.SAMPLES,4):
		for side in [-1.0,1.0]:
			for offset in [3.0,6.0,12.0]:
				var p: Vector3=race.track.centers[index]+race.track.right_at(index)*side*(race.track.half_width_at(index)+offset)
				var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(Vector3(p.x,80,p.z),Vector3(p.x,-40,p.z),1,exclude)
				var hit: Dictionary=space.intersect_ray(query)
				ray_count+=1
				if hit.is_empty() or hit.collider!=body:
					missing+=1
				elif absf(hit.position.y-scenery.surface_height(p))>.003 or hit.normal.y<=0:
					wrong_height+=1
	check(missing==0,"Island ground is missing outside the road: %d/%d rays"%[missing,ray_count])
	check(wrong_height==0,"Physical island heights/normals disagree with visible triangles: %d"%wrong_height)

	# Drop both chassis types beyond every road/sidewalk collider, with gravity.
	for index in [0,30,95,170,240,340]:
		for side in [-1.0,1.0]:
			var p: Vector3=race.track.centers[index]+race.track.right_at(index)*side*(race.track.half_width_at(index)+4)
			p.y=scenery.surface_height(p)+1.5
			var car: IRVehicle=IRVehicle.new()
			car.position=p
			car.variant=0 if side<0 else 1
			race.stage.add_child(car) # No track controller or recovery can hide a fall.
			cars.append(car)
	for frame in range(100):
		await advance(1)
		for car in cars:
			check(car.position.y>scenery.surface_height(car.position)-.35,"A chassis fell beneath the visible island")
			# A rock or foundation can support the car before it slides onto the
			# hillside. Require a real touchdown, not contact at one arbitrary tick.
			if car.grounded:
				for contact in car.get_colliding_bodies():
					if (contact.collision_layer & 5)!=0: touchdowns[car]=true
	for car in cars:
		var height: float=scenery.surface_height(car.position)
		var contacts: Array[String]=[]
		for contact in car.get_colliding_bodies(): contacts.append(str(contact.name))
		samples.append({"position":str(car.position),"ground_y":height,"grounded":car.grounded,"touchdown":touchdowns.has(car),"velocity":str(car.linear_velocity),"contacts":contacts})
		check(touchdowns.has(car),"An off-road chassis never landed on the island or its solid props")
	for car in cars: car.queue_free()
	cars.clear()
	await advance(2)

	# Drive physically from the asphalt across its edge; no teleport or respawn.
	for side in [-1.0,1.0]:
		# Find a genuinely open verge in the current authored layout. A rock
		# stopping the car on the asphalt is a valid collision, not a floor test.
		var index: int=-1
		var route: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
		var chassis: BoxShape3D=BoxShape3D.new()
		chassis.size=Contacts.CHASSIS_SIZE
		route.shape=chassis
		route.collision_mask=4
		for candidate in [80,90,180,285,305,360]:
			var outward: Vector3=race.track.right_at(candidate)*side
			var start: Vector3=race.track.centers[candidate]+Vector3.UP*.85
			route.transform=Transform3D(Basis(Vector3.UP,atan2(-outward.x,-outward.z)),start)
			route.motion=outward*(race.track.half_width_at(candidate)+10)
			var clearance: PackedFloat32Array=space.cast_motion(route)
			var verge: Vector3=race.track.centers[candidate]+outward*(race.track.half_width_at(candidate)+5)
			if clearance[0]>.99 and absf(scenery.surface_height(verge)-race.track.centers[candidate].y)<3:
				index=candidate
				break
		check(index>=0,"No unobstructed roadside corridor was available for a physical edge-crossing test")
		if index<0: continue
		var p: Vector3=race.track.centers[index]
		var car: IRVehicle=IRVehicle.new()
		car.position=p+Vector3.UP*.3
		car.linear_velocity=race.track.right_at(index)*side*14
		car.rotation.y=atan2(-car.linear_velocity.x,-car.linear_velocity.z)
		race.stage.add_child(car)
		var landed_offroad: bool=false
		for frame in range(120):
			await advance(1)
			check(car.position.y>scenery.surface_height(car.position)-.35,"A moving car fell under the island after crossing the road edge")
			if race.track.driving_margin(car.position,race.track.closest_index(car.position))>1.5 and car.grounded:
				for contact in car.get_colliding_bodies():
					if (contact.collision_layer & 5)!=0: landed_offroad=true
		check(race.track.driving_margin(car.position,race.track.closest_index(car.position))>1.5,"The edge-crossing sample did not actually leave the asphalt")
		check(landed_offroad,"The car did not land on the verge after leaving the road")
		var contacts: Array[String]=[]
		for contact in car.get_colliding_bodies(): contacts.append(str(contact.name))
		edge_samples.append({"side":side,"road_index":index,"position":str(car.position),"velocity":str(car.linear_velocity),"ground_y":scenery.surface_height(car.position),"contacts":contacts,"landed_offroad":landed_offroad})
		car.queue_free()
		await advance(2)

	var fallen: IRVehicle=IRVehicle.new()
	fallen.track=race.track
	fallen.human=true
	fallen.progress.next_gate=8
	fallen.position=Vector3(race.track.centers[0].x,-9,race.track.centers[0].z)
	race.stage.add_child(fallen)
	await advance(3)
	var recovery_index: int=posmod(race.track.gate_index(7)+2,IRTrack.SAMPLES)
	check(fallen.position.distance_to(race.track.centers[recovery_index])<4 and fallen.progress.next_gate==8,"A submerged car must recover immediately without awarding a checkpoint")
	fallen.queue_free()
	await advance(2)
	print("OFFROAD_PHYSICS_TEST %s: %d assertions, %d failures, %d roadside rays"%["PASS" if failures==0 else "FAIL",assertions,failures,ray_count])
	DirAccess.make_dir_recursive_absolute("res://build/collisions")
	var file: FileAccess=FileAccess.open("res://build/collisions/offroad_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"roadside_rays":ray_count,"missing_ground":missing,"wrong_heights":wrong_height,"settled_chassis":samples,"edge_crossings":edge_samples},"\t")+"\n")
	race.queue_free()
	await advance(2)
	quit(0 if failures==0 else 1)
