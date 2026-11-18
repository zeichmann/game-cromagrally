extends "res://tools/academy_character_builder.gd"
## Organic material edition, retaining the complete six-joint GPU rig.
var skin_averages: Dictionary={}

func _initialize() -> void:
	portrait=preload("res://tools/organic_face_geometry.gd").new()
	call_deferred("build")

func pack_lid_targets(source: ArrayMesh) -> ArrayMesh:
	var mesh: ArrayMesh=super.pack_lid_targets(source)
	var result: ArrayMesh=ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		var arrays: Array=mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_TEX_UV2]!=null:
			var data: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):
				if roundi(data[i].x)!=69: continue
				var side: float=-1 if vertices[i].x<0 else 1
				var delta: Vector3=portrait.lid_point(side,false,uv[i].x,0,1)-portrait.lid_point(side,false,uv[i].x,0,0)
				uv[i]=Vector2(0,delta.y)
				data[i].y=delta.z
			arrays[Mesh.ARRAY_TEX_UV]=uv
			arrays[Mesh.ARRAY_TEX_UV2]=data
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(s,mesh.surface_get_material(s))
	return result

func skin_average(character: int) -> Vector3:
	if not skin_averages.has(character):
		var texture: Texture2D=load("res://assets/textures/academy_"+["frog","pig"][character]+"_skin_v5.png")
		var image: Image=texture.get_image()
		if image.is_compressed(): image.decompress()
		var total: Vector3=Vector3.ZERO
		var count: int=0
		for y in range(0,image.get_height(),47):
			for x in range(0,image.get_width(),47):
				var c: Color=image.get_pixel(x,y).srgb_to_linear()
				total+=Vector3(c.r,c.g,c.b)
				count+=1
		skin_averages[character]=total/count
	return skin_averages[character]

func surface_materials(mesh: ArrayMesh) -> void:
	for s in range(mesh.get_surface_count()):
		var source: ShaderMaterial=mesh.surface_get_material(s)
		if source.shader.resource_path.ends_with("academy_cornea.gdshader"): continue
		var material: ShaderMaterial=source.duplicate()
		material.set_shader_parameter("ir_material_species",identity)
		material.set_shader_parameter("ir_skin_average",skin_average(identity))
		material.set_shader_parameter("organic_frog_tex",load("res://assets/textures/academy_frog_skin_v5.png"))
		material.set_shader_parameter("organic_pig_tex",load("res://assets/textures/academy_pig_skin_v5.png"))
		material.set_shader_parameter("organic_iris_tex",load("res://assets/textures/academy_iris_v5.png"))
		mesh.surface_set_material(s,material)

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/characters/academy_v5")
	mats["v3_coat0"]=material("v5_coat0","185260",.80,35)
	mats["v3_coat1"]=material("v5_coat1","9a303b",.80,35)
	mats["v3_bow"]=material("v5_bow","d7527e",.69,35)
	mats["v3_felt"]=material("v5_felt","211c19",.92,34)
	mats["v3_hands0"]=material("v5_hands0","89aa38",.65,30)
	mats["v3_hands1"]=material("v5_hands1","eeac98",.69,30)
	for character in range(2):
		identity=character
		portrait.species=identity
		for profile in range(3):
			detail=profile
			portrait.detail=profile
			var model: Node3D=Node3D.new()
			portrait.head(model)
			portrait.eyes(model)
			ears(model)
			hat(model)
			clothing(model)
			weight_parts(model)
			var baked: MeshInstance3D=IRArt.bake(model,true)
			var importer: ImporterMesh=ImporterMesh.from_mesh(pack_lid_targets(baked.mesh))
			importer.generate_lods(60.0,25.0,[])
			var mesh: ArrayMesh=importer.get_mesh()
			surface_materials(mesh)
			var key: String=["zabol","swinka"][identity]+"_driver"+["","_balanced","_performance"][profile]
			if ResourceSaver.save(mesh,"res://assets/characters/academy_v5/"+key+".res",ResourceSaver.FLAG_COMPRESS)!=OK:
				push_error("Failed to save organic driver "+key)
				quit(1)
				return
			var count: int=0
			for s in range(mesh.get_surface_count()): count+=mesh.surface_get_array_len(s)
			report[key]={"vertices":count,"surfaces":mesh.get_surface_count(),"separate_cornea":true,"skin_average_linear":str(skin_average(identity))}
			print("ORGANIC_DRIVER ",key," ",report[key])
			model.free()
	var file: FileAccess=FileAccess.open("res://assets/characters/academy_v5/mesh_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("ORGANIC_DRIVERS PASS: six layered-eye models and authored skin materials")
	quit()
