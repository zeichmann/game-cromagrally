extends SceneTree
## Actual Jolt simulation of production chassis, with no artificial separation.
const Contacts=preload("res://scripts/vehicle_contacts.gd")
var assertions: int=0
var failures: int=0
var objects: Array[Node]=[]
var evidence: Dictionary={}

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value: failures+=1; push_error(message)
func advance(frames: int) -> void:
	for i in range(frames): await physics_frame
func clear_scene() -> void:
	for item in objects: item.queue_free()
	objects.clear()
	await advance(2)
func car(where: Vector3,motion: Vector3,kind: int=0) -> IRVehicle:
	var body: IRVehicle=IRVehicle.new()
	body.variant=kind
	body.position=where
	body.gravity_scale=0
	body.linear_velocity=motion
	root.add_child(body)
	objects.append(body)
	return body
func wall(where: Vector3,size: Vector3) -> StaticBody3D:
	var body: StaticBody3D=StaticBody3D.new()
	body.position=where
	var collider: CollisionShape3D=CollisionShape3D.new()
	var shape: BoxShape3D=BoxShape3D.new()
	shape.size=size
	collider.shape=shape
	body.add_child(collider)
	root.add_child(body)
	objects.append(body)
	return body
func momentum(cars: Array[IRVehicle]) -> Vector3:
	var total: Vector3=Vector3.ZERO
	for body in cars: total+=body.linear_velocity*body.mass
	return total
func energy(cars: Array[IRVehicle]) -> float:
	var total: float=0
	for body in cars:
		var inertia_y: float=body.mass*(pow(Contacts.CHASSIS_SIZE.x,2)+pow(Contacts.CHASSIS_SIZE.z,2))/12.0
		total+=.5*body.mass*body.linear_velocity.length_squared()+.5*inertia_y*pow(body.angular_velocity.y,2)
	return total
func record(label: String,cars: Array[IRVehicle],before: Vector3,initial_energy: float) -> void:
	var samples: Array[Dictionary]=[]
	for body in cars:
		samples.append({"position":str(body.position),"velocity":str(body.linear_velocity),"spin":str(body.angular_velocity),"mass":body.mass})
	evidence[label]={"cars":samples,"momentum_error":momentum(cars).distance_to(before),"energy_before":initial_energy,"energy_after":energy(cars)}
	print("VEHICLE_PHYSICS ",label," ",evidence[label])

func run() -> void:
	check(ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics","The production physics engine must be Jolt")
	var a: IRVehicle=car(Vector3(-3,0,0),Vector3(12,0,0))
	var b: IRVehicle=car(Vector3(3,0,0),Vector3(-12,0,0))
	var pair: Array[IRVehicle]=[a,b]
	check(a is RigidBody3D and a.collision_mask & 2 and a.continuous_cd,"Cars must be dynamic bodies with mutual collisions and CCD")
	check(a.axis_lock_angular_x and a.axis_lock_angular_z and not a.axis_lock_angular_y,"Only roll and pitch may be locked")
	var before: Vector3=momentum(pair)
	var initial_energy: float=energy(pair)
	await advance(40)
	record("head_on",pair,before,initial_energy)
	check(a.linear_velocity.x<-.05 and b.linear_velocity.x>.05,"A head-on collision must stop the approach and produce a small rebound")
	check(momentum(pair).length()<1,"A symmetric crash must conserve linear momentum")
	check(energy(pair)<initial_energy*.2,"Inelastic bumper collisions must dissipate kinetic energy")
	check(absf(a.position.y)<.05 and absf(b.position.y)<.05,"A horizontal crash must not launch cars vertically")
	await clear_scene()

	var target_speeds: Array[float]=[]
	for incoming in range(2):
		a=car(Vector3(0,0,3.5),Vector3(0,0,-16),incoming)
		b=car(Vector3(0,0,-1),Vector3.ZERO,1-incoming)
		pair=[a,b]
		before=momentum(pair); initial_energy=energy(pair)
		await advance(24)
		record("rear_end_"+str(incoming),pair,before,initial_energy)
		target_speeds.append(-b.linear_velocity.z)
		check(b.linear_velocity.z<-3,"A rear-end impact must accelerate the other car")
		check(momentum(pair).distance_to(before)<before.length()*.002,"Unequal masses must conserve linear momentum")
		check(energy(pair)<=initial_energy*1.01,"A collision must not create energy")
		await clear_scene()
	check(target_speeds[1]>target_speeds[0]+1,"The heavier chassis must transfer more motion to the lighter car")

	a=car(Vector3(-4,0,.9),Vector3(20,0,0))
	b=car(Vector3.ZERO,Vector3.ZERO,1)
	pair=[a,b]; before=momentum(pair); initial_energy=energy(pair)
	await advance(24)
	record("corner",pair,before,initial_energy)
	check(absf(a.angular_velocity.y)+absf(b.angular_velocity.y)>.25,"An offset impact must generate yaw torque")
	check(a.angular_velocity.x==0 and a.angular_velocity.z==0 and b.angular_velocity.x==0 and b.angular_velocity.z==0,"A side impact must preserve the arcade roll/pitch locks")
	check(momentum(pair).distance_to(before)<before.length()*.002,"An offset impact must conserve linear momentum")
	check(energy(pair)<initial_energy*1.01,"Angular impact energy must be included in the energy budget")
	await clear_scene()

	a=car(Vector3(-3,0,0),Vector3(16,0,3))
	b=car(Vector3(0,0,0),Vector3.ZERO,1)
	pair=[a,b]; before=momentum(pair); initial_energy=energy(pair)
	await advance(15)
	record("glancing",pair,before,initial_energy)
	check(b.linear_velocity.z>.02,"Friction at a glancing contact must transfer tangential motion")
	check(energy(pair)<=initial_energy*1.01,"Friction must not increase total kinetic energy")
	await clear_scene()

	a=car(Vector3(-3,0,0),Vector3(12,0,0))
	b=car(Vector3(3,2,0),Vector3(-12,0,0))
	await advance(35)
	check(a.position.x>b.position.x and a.linear_velocity.x>11.9 and b.linear_velocity.x< -11.9,"Cars at different heights must not collide as flat footprints")
	await clear_scene()

	a=car(Vector3(-1.11,0,0),Vector3(0,0,-12))
	b=car(Vector3(1.11,0,0),Vector3(0,0,-12))
	await advance(35)
	check(a.linear_velocity.distance_to(b.linear_velocity)<.001 and a.linear_velocity.z< -11.9,"Parallel cars must not receive false contact impulses")
	await clear_scene()

	var pile: Array[IRVehicle]=[]
	for i in range(6): pile.append(car(Vector3(i*2.3,0,0),Vector3(28,0,0) if i==0 else Vector3.ZERO,i%2))
	before=momentum(pile); initial_energy=energy(pile)
	await advance(75)
	record("six_car_pile",pile,before,initial_energy)
	check(momentum(pile).distance_to(before)<before.length()*.004,"The six-car contact chain must conserve momentum")
	check(energy(pile)<initial_energy*1.01,"A multi-car pile must remain energetically stable")
	var stable: bool=true
	var clear: bool=true
	for i in range(pile.size()):
		stable=stable and pile[i].position.is_finite() and pile[i].linear_velocity.is_finite() and absf(pile[i].position.y)<.1
		for j in range(i+1,pile.size()): clear=clear and Contacts.separation(pile[i].transform,pile[j].transform).length()<.06
	check(stable,"A six-car pile must not produce NaNs or vertical popping")
	check(clear,"The solver must remove persistent chassis interpenetration")
	await clear_scene()

	wall(Vector3(0,2,0),Vector3(.08,8,30))
	a=car(Vector3(-8,0,0),Vector3(800,0,0))
	await advance(3)
	evidence["ccd_wall"]={"position":str(a.position),"velocity":str(a.linear_velocity)}
	check(a.position.x< -1.0,"CCD must stop a car from tunneling through a thin wall")
	await clear_scene()
	# Check different collision times at the actual boosted race speed. Two
	# opposing 500 m/s bodies exceed this integration's reliable CCD envelope;
	# the separate exploratory result records that limit rather than hiding it.
	for start in [4.2,6.0,6.35]:
		a=car(Vector3(-start,0,0),Vector3(39*1.28,0,0))
		b=car(Vector3(start,0,0),Vector3(-39*1.28,0,0))
		await advance(12)
		evidence["ccd_pair_"+str(start)]={"a":str(a.position),"b":str(b.position),"a_velocity":str(a.linear_velocity),"b_velocity":str(b.linear_velocity)}
		check(a.position.x<b.position.x and a.linear_velocity.x<0 and b.linear_velocity.x>0,"Boosted racing cars must collide and rebound without swapping sides")
		await clear_scene()

	wall(Vector3(0,-.25,0),Vector3(100,.5,100))
	wall(Vector3(3,2,0),Vector3(.1,4,20))
	a=car(Vector3(0,.4,0),Vector3.ZERO)
	a.gravity_scale=1
	await advance(45)
	check(a.is_on_floor() and absf(a.position.y)<.06,"A rigid chassis must settle on the actual road surface")
	a.apply_central_impulse(Vector3(20*a.mass,0,0))
	await advance(35)
	check(a.position.x<1.95 and a.position.y<.25,"A road-level wall collision must stop the chassis without a rooftop jump")
	await clear_scene()

	# Exercise the production force callback as well as the unconstrained
	# chassis above: tire control must preserve an external collision impulse.
	var course: IRTrack=IRTrack.new()
	course.build_centerline()
	var start: Vector3=course.centers[0]
	wall(start-Vector3.UP*.25,Vector3(80,.5,80))
	a=car(start+Vector3.UP*.4,Vector3.ZERO)
	a.track=course
	a.human=true
	a.gravity_scale=1
	a.rotation.y=atan2(-course.tangents[0].x,-course.tangents[0].z)
	a.override_controls={"throttle":0.0,"brake":1.0}
	await advance(30)
	a.drive_enabled=true
	a.override_controls={"throttle":1.0}
	await advance(40)
	var driven_speed: float=a.linear_velocity.length()
	check(driven_speed>7 and a.grounded,"The production controller must accelerate a grounded rigid chassis")
	a.apply_impulse(a.global_basis.x*a.mass*8,-a.global_basis.z*1.2+Vector3.UP*.55)
	await advance(3)
	var impact_spin: float=absf(a.angular_velocity.y)
	check(impact_spin>.4,"Tire steering must not erase an off-center impact on the next tick")
	a.override_controls={"brake":1.0}
	await advance(45)
	evidence["controller"]={"driven_speed":driven_speed,"impact_spin":impact_spin,"braked_speed":a.linear_velocity.length(),"grounded":a.grounded}
	check(a.linear_velocity.length()<1,"The production brakes must still stop the dynamic chassis after a collision")
	await clear_scene()
	course.free()

	DirAccess.make_dir_recursive_absolute("res://build/collisions")
	var file: FileAccess=FileAccess.open("res://build/collisions/physics_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":str(Engine.get_version_info().string),"backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":Engine.physics_ticks_per_second,"assertions":assertions,"failures":failures,"scenarios":evidence},"\t")+"\n")
	print("VEHICLE_PHYSICS_TEST %s: %d assertions, %d failures"%["PASS" if failures==0 else "FAIL",assertions,failures])
	quit(0 if failures==0 else 1)
