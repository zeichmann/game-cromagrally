extends SceneTree
## Measure control transitions on a physical floor without recovery or AI.
var assertions: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value: failures+=1; push_error(message)
func advance(frames: int) -> void:
	for i in range(frames): await physics_frame
func run() -> void:
	var course: IRTrack=IRTrack.new()
	course.build_centerline()
	var p: Vector3=course.centers[0]
	var floor_body: StaticBody3D=StaticBody3D.new()
	var shape: CollisionShape3D=CollisionShape3D.new()
	var box: BoxShape3D=BoxShape3D.new()
	box.size=Vector3(160,.5,160)
	shape.shape=box
	floor_body.add_child(shape)
	floor_body.position=p-Vector3.UP*.25
	floor_body.physics_material_override=IRTrack.driving_surface_material()
	root.add_child(floor_body)
	var car: IRVehicle=IRVehicle.new()
	car.track=course
	car.human=true
	car.set_physics_process(false) # Recovery and gate logic cannot hide a handling error.
	car.position=p+Vector3.UP*.35
	car.rotation.y=atan2(-course.tangents[0].x,-course.tangents[0].z)
	car.override_controls={"brake":1.0}
	root.add_child(car)
	await advance(30)
	car.drive_enabled=true
	car.override_controls={"throttle":1.0,"steer":1.0}
	await advance(2)
	check(car.steering_input>0 and car.steering_input<.3,"Keyboard steering must ramp rather than jump to full lock")
	await advance(15)
	check(car.steering_input>.8,"Steering must still reach full lock promptly")
	car.override_controls={"throttle":1.0,"steer":0.0}
	await advance(15)
	check(absf(car.steering_input)<.05,"Steering must center after release")
	await advance(35)
	var accelerated: float=car.speed
	check(accelerated>12,"Progressive acceleration must build useful driving speed")
	car.override_controls={"throttle":-1.0}
	await advance(2)
	check(car.speed>0,"Selecting reverse while moving must brake before reversing")
	await advance(70)
	check(car.speed< -1.0,"Holding reverse must eventually drive backwards")
	car.override_controls={"brake":1.0}
	await advance(40)
	check(car.linear_velocity.length()<.5,"Braking must stop a reversing car")
	car.queue_free()
	floor_body.queue_free()
	await advance(2)
	course.free()
	print("HANDLING_TEST %s: %d assertions, %d failures; acceleration %.2f m/s"%["PASS" if failures==0 else "FAIL",assertions,failures,accelerated])
	quit(0 if failures==0 else 1)
