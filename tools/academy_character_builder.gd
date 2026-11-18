extends "res://tools/portrait_character_builder.gd"
## Fourth-generation driver silhouettes, with separately sculpted facial anatomy.

func _initialize() -> void:
	portrait=preload("res://tools/academy_face_geometry.gd").new()
	call_deferred("build")

func bow(root: Node3D) -> void:
	var first: int=root.get_child_count()
	super.bow(root)
	# The canonical bow is on the character's left, not on the viewer's left.
	for i in range(first,root.get_child_count()):
		var node: Node3D=root.get_child(i)
		node.scale.x*=-1
		node.position.x*=-1
		node.position.y+=.025

func ear_surface(side: float,u: float,a: float) -> Vector3:
	var width: float=.130*pow(maxf(sin(PI*pow(u,.78)),0),.75)+.016*(1-u)
	var middle: Vector3=Vector3(side*(.33+.31*u),1.015+.080*sin(u*PI)-.095*u,.018-.055*sin(u*PI)+.020*u)
	return middle+Vector3(0,cos(a)*width,sin(a)*(.022+.020*sin(u*PI))+pow(cos(a),2)*.048*sin(u*PI))

func ears(root: Node3D) -> void:
	if identity==0: return
	var material: StandardMaterial3D=material("v4_ear","ffffff",.50,58)
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	var count: int=[48,36,24][detail]
	var rows: int=[24,18,12][detail]
	for side in [-1.0,1.0]:
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(rows+1):
			for n in range(count+1):
				var u: float=row/float(rows)
				var a: float=TAU*n/count
				var p: Vector3=ear_surface(side,u,a)
				var du: Vector3=ear_surface(side,u+.0005,a)-ear_surface(side,u-.0005,a)
				var da: Vector3=ear_surface(side,u,a+.0005)-ear_surface(side,u,a-.0005)
				st.set_normal(da.cross(du).normalized()*side)
				var inside: float=smoothstep(.1,.8,-sin(a))*sin(u*PI)
				st.set_color(Color("f0ad98").lerp(Color("e6827e"),inside*.74))
				st.set_uv(Vector2(u,n/float(count)))
				st.add_vertex(p)
		for row in range(rows):
			for n in range(count):
				var k: int=row*(count+1)+n
				for index in ([k,k+count+1,k+1,k+1,k+count+1,k+count+2] if side>0 else [k,k+1,k+count+1,k+1,k+count+2,k+count+1]): st.add_index(index)
		IRArt.part(root,st.commit(),Vector3.ZERO,material).set_meta("driver_bone",1)

func clothing(root: Node3D) -> void:
	super.clothing(root)
	# Broader shoulders support the head; the hands remain on the original wheel.
	for child in root.get_children():
		if not child is MeshInstance3D: continue
		var bone: int=int(child.get_meta("driver_bone",1))
		if child.get_meta("blend_neck",false):
			child.position.y+=.025
			child.scale.y*=1.15
		if bone not in [0,2,3]: continue
		var mesh: ArrayMesh=ArrayMesh.new()
		for surface in range(child.mesh.get_surface_count()):
			var arrays: Array=child.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for i in range(vertices.size()):
				var p: Vector3=child.transform*vertices[i]
				var factor: float=smoothstep(.09,.32,p.y)
				p.x*=1+factor*.09
				p.y+=factor*.014
				vertices[i]=child.transform.affine_inverse()*p
			arrays[Mesh.ARRAY_VERTEX]=vertices
			arrays[Mesh.ARRAY_NORMAL]=normals
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh.surface_set_material(surface,child.mesh.surface_get_material(surface))
		child.mesh=mesh

func pack_lid_targets(source: ArrayMesh) -> ArrayMesh:
	var mesh: ArrayMesh=ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays: Array=source.surface_get_arrays(surface)
		var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var data: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for i in range(positions.size()):
			var family: int=roundi(data[i].x)
			if family not in [54,55,60]: continue
			var side: float=-1 if positions[i].x<0 else 1
			if family==60:
				var lash_delta: Vector3=portrait.lid_point(side,true,uv[i].x,0,1)-portrait.lid_point(side,true,uv[i].x,0,0)
				uv[i]=Vector2(0,lash_delta.y)
				data[i].y=lash_delta.z
				continue
			var closed: Vector3=portrait.lid_point(side,family==54,uv[i].x,uv[i].y,1)
			var delta: Vector3=closed-positions[i]
			var du: Vector3=portrait.lid_point(side,family==54,uv[i].x+.0005,uv[i].y,1)-portrait.lid_point(side,family==54,uv[i].x-.0005,uv[i].y,1)
			var dv: Vector3=portrait.lid_point(side,family==54,uv[i].x,uv[i].y+.0005,1)-portrait.lid_point(side,family==54,uv[i].x,uv[i].y-.0005,1)
			var closed_normal: Vector3=du.cross(dv).normalized()*(-1 if family==54 else 1)
			# Eyelid X stays fixed. Its spare UV component and color alpha store
			# the closed normal, so GPU morphing also preserves soft shading.
			uv[i]=Vector2(closed_normal.x,delta.y)
			colors[i].a=closed_normal.y*.5+.5
			data[i].y=delta.z
		arrays[Mesh.ARRAY_TEX_UV]=uv
		arrays[Mesh.ARRAY_TEX_UV2]=data
		arrays[Mesh.ARRAY_COLOR]=colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(surface,source.surface_get_material(surface))
	return mesh

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/characters/academy_v4")
	# Share the fitted costume construction, with the canonical deeper pigments.
	mats["v3_coat0"]=material("v4_coat0","185260",.80,35)
	mats["v3_coat1"]=material("v4_coat1","9a303b",.80,35)
	mats["v3_bow"]=material("v4_bow","d7527e",.69,35)
	mats["v3_felt"]=material("v4_felt","211c19",.92,34)
	for character in range(2):
		identity=character
		portrait.species=identity
		for profile in range(3):
			detail=profile
			portrait.detail=detail
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
			var key: String=("zabol" if identity==0 else "swinka")+"_driver"+["","_balanced","_performance"][detail]
			if ResourceSaver.save(mesh,"res://assets/characters/academy_v4/"+key+".res",ResourceSaver.FLAG_COMPRESS)!=OK:
				push_error("Failed to save the authored driver: "+key)
				quit(1)
				return
			var count: int=0
			for s in range(mesh.get_surface_count()): count+=mesh.surface_get_array_len(s)
			report[key]={"vertices":count,"surfaces":mesh.get_surface_count(),"eye_center":str(portrait.eye_center()),"closed_lid_targets":true,"head_width":portrait.width()*2}
			print("ACADEMY_DRIVER ",key," ",report[key])
			model.free()
	var file: FileAccess=FileAccess.open("res://assets/characters/academy_v4/mesh_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("ACADEMY_DRIVERS PASS: six sculpted drivers with GPU eyelid targets")
	quit()
