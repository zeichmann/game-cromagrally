extends SceneTree
const VehicleContacts=preload("res://scripts/vehicle_contacts.gd")
## Checks every skinned surface, blended cloth, foliage alpha and exact terrain attachment.

func _initialize() -> void:
	call_deferred("run")

func verify_driver(identity: int,detail: int) -> bool:
	var driver: IRDriverArt=IRDriverArt.new(Color.WHITE,identity)
	root.add_child(driver)
	driver.set_detail(detail)
	var valid: bool=driver.skinned.skin==null and driver.skinned.skeleton.is_empty() and driver.find_children("*","Skeleton3D",true,false).is_empty()
	var blended: bool=false
	valid=valid and driver.identity==identity and driver.skinned.mesh.get_surface_count()<=8
	for surface in range(driver.skinned.mesh.get_surface_count()):
		var shader_path: String=driver.skinned.get_surface_override_material(surface).shader.resource_path
		valid=valid and ("palette_driver" in shader_path or shader_path.ends_with("academy_cornea.gdshader"))
		var arrays: Array=driver.skinned.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		valid=valid and bones.size()==vertices.size()*4 and weights.size()==bones.size() and normals.size()==vertices.size()
		if valid:
			for i in range(vertices.size()):
				var sum: float=0
				for j in range(4):
					var k: int=i*4+j
					valid=valid and bones[k]>=0 and bones[k]<IRDriverArt.BONE_COUNT
					sum+=weights[k]
					blended=blended or (weights[k]>.01 and weights[k]<.99)
				# Mesh storage quantizes skin weights to UNORM16.
				valid=valid and absf(sum-1.0)<.000031 and vertices[i].is_finite() and normals[i].is_finite() and absf(normals[i].length()-1)<.01
	valid=valid and blended
	driver.free()
	if not valid:
		push_error("Invalid character skin: "+IRDriverArt.CHARACTER_NAMES[identity]+" profile "+str(detail))
	return valid

func run() -> void:
	var valid: bool=true
	for identity in range(2):
		for detail in range(3):
			valid=verify_driver(identity,detail) and valid
	valid=valid and IRDriverArt.MESHES[0]!=IRDriverArt.MESHES[1]
	for kind in ["road","wood","linen"]:
		var material: StandardMaterial3D=IRArt.textured(kind)
		valid=valid and material.albedo_texture!=null
	var foliage: Image=(load("res://assets/textures/seagrape_sprig.png") as Texture2D).get_image()
	for texture_file in DirAccess.get_files_at("res://assets/textures"):
		if texture_file.ends_with(".png"):
			var texture: Texture2D=load("res://assets/textures/"+texture_file)
			var image: Image=texture.get_image()
			valid=valid and image!=null and image.has_mipmaps()
	valid=valid and foliage!=null and foliage.get_pixel(0,0).a<.01
	if foliage!=null:
		print("FOLIAGE_TEXTURE %dx%d alpha=%s" % [foliage.get_width(),foliage.get_height(),foliage.detect_alpha()])
	var track: IRTrack=IRTrack.new()
	track.build_centerline()
	track._build_road()
	for i in range(0,IRTrack.SAMPLES,3):
		var basis: Basis=track.curb_basis(i)
		valid=valid and is_equal_approx(basis.x.length(),1.0) and is_equal_approx(basis.y.length(),1.0)
		valid=valid and absf(basis.x.dot(basis.z))<.001 and absf(basis.y.dot(basis.z))<.001
	var scenery: IRSceneryArt=IRSceneryArt.new(track)
	var car: IRVehicle=IRVehicle.new()
	car.track=track
	car.drive_enabled=true
	car.demo_control=true
	car.nearest=31
	valid=valid and car._needs_gate_recovery()
	car.progress.next_gate=2
	valid=valid and not car._needs_gate_recovery()
	car.free()
	for z in range(IRSceneryArt.GRID_Z+1):
		for x in range(IRSceneryArt.GRID_X+1):
			scenery.terrain_heights.append(x*.2+z*.3)
	for grid in [Vector2(20.2,30.3),Vector2(20.8,30.7),Vector2(IRSceneryArt.GRID_X,IRSceneryArt.GRID_Z)]:
		var p: Vector3=Vector3(grid.x*IRSceneryArt.CELL_SIZE-160,0,grid.y*IRSceneryArt.CELL_SIZE-140)
		valid=valid and absf(scenery.surface_height(p)-(grid.x*.2+grid.y*.3))<.0001
	for grid in [Vector2i(20,30),Vector2i(0,0),Vector2i(IRSceneryArt.GRID_X,IRSceneryArt.GRID_Z)]:
		valid=valid and scenery.grid_normal(grid.x,grid.y).distance_to(Vector3(-.2/IRSceneryArt.CELL_SIZE,1,-.3/IRSceneryArt.CELL_SIZE).normalized())<.0001
	var cell: int=30*(IRSceneryArt.GRID_X+1)+20
	scenery.terrain_heights[cell]=0
	scenery.terrain_heights[cell+1]=2
	scenery.terrain_heights[cell+IRSceneryArt.GRID_X+1]=4
	scenery.terrain_heights[cell+IRSceneryArt.GRID_X+2]=9
	# This saddle distinguishes exact triangle interpolation from bilinear sampling.
	for sample in [Vector3(20.2,1.6,30.3),Vector3(20.8,5.9,30.7)]:
		var point: Vector3=Vector3(sample.x*IRSceneryArt.CELL_SIZE-160,0,sample.z*IRSceneryArt.CELL_SIZE-140)
		valid=valid and absf(scenery.surface_height(point)-sample.y)<.0001
	var parent: Node3D=Node3D.new()
	# A mixed indexed/unindexed material group used to lose custom faces (stone arches).
	var mixed: Node3D=Node3D.new()
	var shared: Material=IRArt.pbr(Color("b5aa93"))
	IRArt.block(mixed,Vector3.ONE,Vector3.ZERO,shared)
	var triangle: SurfaceTool=SurfaceTool.new()
	triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(-1,3,0),Vector3(0,4,0),Vector3(1,3,0)]:
		triangle.set_normal(Vector3.BACK)
		triangle.add_vertex(vertex)
	IRArt.part(mixed,triangle.commit(),Vector3.ZERO,shared)
	var merged: MeshInstance3D=IRArt.bake(mixed)
	valid=valid and merged.mesh.get_faces().size()==39 and merged.mesh.get_aabb().end.y>3.99
	mixed.free()
	var pose_a: Transform3D=Transform3D.IDENTITY
	var pose_b: Transform3D=Transform3D(Basis.IDENTITY,Vector3(1.6,0,0))
	var contact: Vector3=VehicleContacts.separation(pose_a,pose_b)
	valid=valid and contact.length()>.5 and absf(contact.y)<.00001
	pose_a.origin+=contact*.5
	pose_b.origin-=contact*.5
	valid=valid and VehicleContacts.separation(pose_a,pose_b).is_zero_approx()
	pose_b.origin=Vector3(0,3,0)
	valid=valid and VehicleContacts.separation(Transform3D.IDENTITY,pose_b).is_zero_approx()
	pose_b=Transform3D(Basis(Vector3.UP,.6),Vector3(2,0,0))
	contact=VehicleContacts.separation(Transform3D.IDENTITY,pose_b)
	valid=valid and contact.length()>.1 and absf(contact.y)<.00001
	var transforms: Array[Transform3D]=[Transform3D(Basis(Vector3.UP,.6),Vector3(15,2,50)),Transform3D(Basis(Vector3.UP,-.3),Vector3(35,4,70))]
	IRArt.scatter(parent,BoxMesh.new(),IRArt.pbr(Color.WHITE),transforms,[])
	var batch: MultiMeshInstance3D=parent.get_child(0)
	valid=valid and batch.position.is_equal_approx(Vector3(25,3,60))
	# Renderer Dummy does not retain MultiMesh instance buffers; the windowed
	# benchmark verifies their actual roundtrip through the rendering server.
	if DisplayServer.get_name()!="headless":
		for i in range(2):
			var point: Vector3=Vector3(1,2,3)
			valid=valid and (batch.transform*(batch.multimesh.get_instance_transform(i)*point)).distance_to(transforms[i]*point)<.0001
	print("ART_TEST %s: skin surfaces, blended scarf, foliage alpha, terrain heights, instance transforms, curbs, planar contacts, AI gate recovery" % ("PASS" if valid else "FAIL"))
	scenery.free()
	track.free()
	parent.free()
	quit(0 if valid else 1)
