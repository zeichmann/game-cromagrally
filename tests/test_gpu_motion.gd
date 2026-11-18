extends SceneTree
const Reference=preload("res://tests/driver_pose_reference.gd")
var failures: int=0
var assertions: int=0

func check(condition: bool,message: String) -> void:
	assertions+=1
	if not condition:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func matrix(data: PackedFloat32Array,actor: int,column: int) -> Transform3D:
	var base: int=(actor*32+column)*4
	return Transform3D(Basis(Vector3(data[base],data[base+4],data[base+8]),Vector3(data[base+1],data[base+5],data[base+9]),Vector3(data[base+2],data[base+6],data[base+10])),Vector3(data[base+3],data[base+7],data[base+11]))

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("GPU tests require the native Forward+ renderer")
		quit(1)
		return
	var race: IRRace=IRRace.new()
	root.add_child(race)
	for frame in range(8):
		await RenderingServer.frame_post_draw
	check(race.gpu_motion.initialized,"GPU motion texture was not initialized")
	race.set_process(false)
	race.set_physics_process(false)
	race.gpu_motion.set_process(false)
	var maximum: float=0
	var skin_samples: Array[Dictionary]=[]
	for sample in [Vector3(0,0,.2),Vector3(.8,25,.7),Vector3(-.75,-20,.3)]:
		var records: PackedFloat32Array=PackedFloat32Array()
		for actor in range(6):
			records.append_array(PackedFloat32Array([sample.x,sample.y,.15,100+assertions]))
		race.gpu_motion.dispatch_for_test(records,sample.z)
		var data: PackedFloat32Array=await race.gpu_motion.snapshot_for_test()
		skin_samples.append({"time":sample.z,"steer":sample.x,"speed":sample.y,"data":Array(data)})
		var reference: Skeleton3D=Reference.pose(sample.z,sample.x,sample.y)
		root.add_child(reference)
		for actor in range(6):
			var face: int=(6*32+1+actor*2)*4
			check(data[face]>=0 and data[face]<=1 and data[face+1]>=.25 and data[face+1]<.9 and absf(data[face+2])<.017 and absf(data[face+3])<.004 and data[face+7]==1,"Compute facial controls are missing or out of bounds")
			for joint in range(6):
				var expected: Transform3D=reference.get_bone_global_pose(joint)*reference.get_bone_global_rest(joint).affine_inverse()
				var actual: Transform3D=matrix(data,actor,joint*3)
				var error: float=maxf(actual.origin.distance_to(expected.origin),maxf(actual.basis.x.distance_to(expected.basis.x),maxf(actual.basis.y.distance_to(expected.basis.y),actual.basis.z.distance_to(expected.basis.z))))
				maximum=maxf(maximum,error)
				# GPU float transcendental instructions and CPU quaternions round differently.
				check(error<.0001,"GPU bone differs from reference: actor %d joint %d error %f"%[actor,joint,error])
		check(absf(data[18*4]-fposmod(-sample.y*sample.z/.45,TAU))<.00003,"GPU wheel integration is incorrect")
		var wheel: Basis=Basis(Vector3.UP,-sample.x*.38)*Basis(Vector3.RIGHT,data[18*4])
		check(matrix(data,0,23).basis.x.distance_to(wheel.x)<.0001 and matrix(data,0,23).basis.y.distance_to(wheel.y)<.0001,"GPU front wheel matrix is incorrect")
		var fan: Basis=Basis(Vector3.BACK,data[18*4+1])
		check(matrix(data,0,29).basis.x.distance_to(fan.x)<.0001,"GPU fan matrix is incorrect")
		var before: PackedFloat32Array=data
		race.gpu_motion.dispatch_for_test(records,0)
		data=await race.gpu_motion.snapshot_for_test()
		check(data==before,"Paused GPU animation changed its pose or clock")
		reference.free()
	race._start_race(4,true)
	race.gpu_motion.set_process(true)
	for frame in range(8):
		await RenderingServer.frame_post_draw
	check(root.get_camera_3d()==null,"Split screen must not render a second world behind the UI")
	check(race.vehicles[0].fan.rotation.is_zero_approx(),"CPU changed the fan node instead of leaving its animation to GPU")
	race._pause()
	var paused_state: PackedFloat32Array=await race.gpu_motion.snapshot_for_test()
	for frame in range(5):
		await RenderingServer.frame_post_draw
	check(paused_state==await race.gpu_motion.snapshot_for_test(),"The real pause action did not freeze GPU animation")
	race._resume()
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var resumed: PackedFloat32Array=await race.gpu_motion.snapshot_for_test()
	check(resumed[6*32*4]>paused_state[6*32*4],"GPU clock did not resume")
	race._show_menu()
	if failures==0:
		DirAccess.make_dir_recursive_absolute("res://build")
		var capture: FileAccess=FileAccess.open("res://build/validated_skin_poses.json",FileAccess.WRITE)
		capture.store_string(JSON.stringify({"shader_sha256":FileAccess.get_sha256("res://shaders/gpu_motion.glsl"),"samples":skin_samples}))
		capture.close()
	print("GPU_MOTION_TEST %s: %d assertions, maximum bone error %.9f"%["PASS" if failures==0 else "FAIL",assertions,maximum])
	race.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
