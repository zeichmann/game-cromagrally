extends SceneTree
## Pixel comparison of the new GPU pose + skin against the original Skeleton3D path.
const Reference=preload("res://tests/driver_pose_reference.gd")
var failures: int=0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Skin comparison requires the native renderer")
		quit(1)
		return
	root.disable_3d=true
	# test_gpu_motion records actual GPU results only after its assertions pass.
	# Re-upload those values as a sampled texture here. Keeping storage-image
	# ownership out of the Skeleton3D comparison avoids Iris Xe teardown stalls.
	var captured: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://build/validated_skin_poses.json"))
	if not captured is Dictionary or captured.get("shader_sha256","")!=FileAccess.get_sha256("res://shaders/gpu_motion.glsl") or captured.get("samples",[]).size()!=3:
		push_error("Run tests/test_gpu_motion.gd first to capture current, validated GPU poses")
		quit(1)
		return
	var blank: Image=Image.create(32,8,false,Image.FORMAT_RGBAF)
	var atlas: ImageTexture=ImageTexture.create_from_image(blank)
	RenderingServer.global_shader_parameter_set("ir_motion_atlas",atlas)
	RenderingServer.global_shader_parameter_set("ir_motion_enabled",true)
	var viewport: SubViewport=SubViewport.new()
	viewport.size=Vector2i(512,512)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment: WorldEnvironment=WorldEnvironment.new()
	var settings: Environment=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("334146")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=.6
	environment.environment=settings
	viewport.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-38,-28,0)
	sun.light_energy=1.2
	viewport.add_child(sun)
	var camera: Camera3D=Camera3D.new()
	camera.fov=38
	viewport.add_child(camera)
	var maximum_error: float=0
	for identity in range(2):
		for detail in range(3):
			var sample: Dictionary=captured.samples[detail]
			var data: PackedFloat32Array=PackedFloat32Array(sample.data)
			var steer: float=sample.steer
			atlas.update(Image.create_from_data(32,8,false,Image.FORMAT_RGBAF,data.to_byte_array()))
			var gpu: IRDriverArt=IRDriverArt.new(Color.WHITE,identity)
			gpu.set_detail(detail)
			var cockpit: Transform3D=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.85),Vector3(0,1.39,.05))
			gpu.transform=cockpit
			viewport.add_child(gpu)
			# Compare the six-joint pose independently from the additional GPU blink.
			gpu.skinned.set_instance_shader_parameter("ir_face_animation",false)
			gpu.skinned.set_instance_shader_parameter("ir_motion_slot",0)
			gpu.skinned.set_instance_shader_parameter("ir_root_row0",Vector4(.85,0,0,0))
			gpu.skinned.set_instance_shader_parameter("ir_root_row1",Vector4(0,.85,0,1.39))
			gpu.skinned.set_instance_shader_parameter("ir_root_row2",Vector4(0,0,.85,.05))
			gpu.skinned.set_instance_shader_parameter("ir_inverse_x",cockpit.basis.inverse().x)
			gpu.skinned.set_instance_shader_parameter("ir_inverse_y",cockpit.basis.inverse().y)
			gpu.skinned.set_instance_shader_parameter("ir_inverse_z",cockpit.basis.inverse().z)
			var bounds: AABB=gpu.skinned.mesh.get_aabb()
			var center: Vector3=cockpit*bounds.get_center()
			camera.position=center+Vector3(.8,.22,-1).normalized()*bounds.size.length()*1.55*.85
			camera.look_at(center)
			for frame in range(4):
				await RenderingServer.frame_post_draw
			var gpu_image: Image=viewport.get_texture().get_image()
			gpu_image.save_png("res://build/art-review/gpu_skin_%d_%d.png"%[identity,detail])
			gpu.hide()
			var reference: Node3D=Node3D.new()
			var base: int=19*4
			reference.transform=Transform3D(Basis.from_euler(Vector3(data[base+1],0,data[base])),Vector3(0,data[base+2],0))*cockpit
			viewport.add_child(reference)
			var skeleton: Skeleton3D=Reference.pose(sample.time,steer,sample.speed)
			reference.add_child(skeleton)
			var mesh: MeshInstance3D=MeshInstance3D.new()
			mesh.mesh=gpu.skinned.mesh
			mesh.skeleton=NodePath("../PilotSkeleton")
			mesh.skin=skeleton.create_skin_from_rest_transforms()
			reference.add_child(mesh)
			mesh.set_instance_shader_parameter("ir_face_animation",false)
			for frame in range(4):
				await RenderingServer.frame_post_draw
			var cpu_image: Image=viewport.get_texture().get_image()
			cpu_image.save_png("res://build/art-review/reference_skin_%d_%d.png"%[identity,detail])
			gpu_image.convert(Image.FORMAT_RGBA8)
			cpu_image.convert(Image.FORMAT_RGBA8)
			var actual: PackedByteArray=gpu_image.get_data()
			var expected: PackedByteArray=cpu_image.get_data()
			var difference: float=0
			var changed: int=0
			for pixel in range(512*512):
				var largest: int=0
				for channel in range(3):
					var delta: int=absi(actual[pixel*4+channel]-expected[pixel*4+channel])
					difference+=delta
					largest=maxi(largest,delta)
				changed+=1 if largest>32 else 0
			var mean: float=difference/(512*512*3*255.0)
			maximum_error=maxf(maximum_error,mean)
			var valid: bool=mean<.003 and changed<512*512*.01
			print("GPU_SKIN_COMPARE identity=%d detail=%d mean=%.7f changed=%d %s"%[identity,detail,mean,changed,"PASS" if valid else "FAIL"])
			if not valid:
				failures+=1
			gpu.free()
			reference.free()
			await process_frame
	print("GPU_SKIN_TEST %s: six meshes; maximum image error %.7f"%["PASS" if failures==0 else "FAIL",maximum_error])
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	await process_frame
	RenderingServer.global_shader_parameter_set("ir_motion_enabled",false)
	RenderingServer.global_shader_parameter_set("ir_motion_atlas",null)
	await process_frame
	viewport.free()
	IRDriverArt.gpu_materials.clear()
	atlas=null
	for frame in range(3): await process_frame
	quit(0 if failures==0 else 1)
