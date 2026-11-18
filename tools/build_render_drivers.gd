extends SceneTree
## Rendering-only packing of the rejected prototypes; canonical geometry and identity are unchanged.

var report: Array[Dictionary]=[]

func _initialize() -> void:
	build()
	quit(0 if report.size()==6 else 1)

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/characters/render_optimized")
	for identity in ["zabol","swinka"]:
		for suffix in ["","_balanced","_performance"]:
			var name_key: String=identity+"_driver"+suffix
			var path: String="res://assets/characters/"+name_key+".res"
			var original: ArrayMesh=load(path)
			var packed: ArrayMesh=IRPaletteMesh.compact(original,false,true)
			assert(packed.get_surface_count()==2,"Expected opaque and double-sided palette surfaces")
			var expected: int=0
			var faces: int=0
			var max_delta: float=0.0
			for output in range(packed.get_surface_count()):
				var arrays: Array=packed.surface_get_arrays(output)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var double_sided: bool="_double" in packed.surface_get_material(output).shader.resource_path.get_file()
				var offset: int=0
				var source_faces: int=0
				for surface in range(original.get_surface_count()):
					if IRPaletteMesh.descriptor(original.surface_get_material(surface)).double!=double_sided:
						continue
					var source: Array=original.surface_get_arrays(surface)
					var positions: PackedVector3Array=source[Mesh.ARRAY_VERTEX]
					for i in range(positions.size()):
						assert(offset+i<vertices.size(),"Packed skin lost vertices")
						max_delta=maxf(max_delta,positions[i].distance_to(vertices[offset+i]))
						for j in range(4):
							var weight: float=source[Mesh.ARRAY_WEIGHTS][i*4+j]
							if weight<=0:
								continue
							var bone: int=source[Mesh.ARRAY_BONES][i*4+j]
							var expected_weight: float=0.0
							for k in range(4):
								if source[Mesh.ARRAY_BONES][i*4+k]==bone:
									expected_weight+=source[Mesh.ARRAY_WEIGHTS][i*4+k]
							var actual: float=0.0
							for k in range(4):
								if arrays[Mesh.ARRAY_BONES][(offset+i)*4+k]==bone:
									actual+=arrays[Mesh.ARRAY_WEIGHTS][(offset+i)*4+k]
							if absf(actual-expected_weight)>.000061:
								print("SKIN_PACK_MISMATCH ",surface," vertex=",i," bone=",bone," source=",expected_weight," packed=",actual," position_delta=",max_delta)
							assert(absf(actual-expected_weight)<.000061,"Packing changed a skin influence")
					offset+=positions.size()
					source_faces+=source[Mesh.ARRAY_INDEX].size()/3
				assert(offset==vertices.size() and max_delta<.00001,"Packing changed source geometry")
				assert(source_faces==arrays[Mesh.ARRAY_INDEX].size()/3,"Packing changed triangles")
				expected+=vertices.size()
				faces+=source_faces
			var importer: ImporterMesh=ImporterMesh.from_mesh(packed)
			importer.generate_lods(60.0,25.0,[])
			var mesh: ArrayMesh=importer.get_mesh()
			mesh.custom_aabb=original.get_aabb()
			mesh.resource_name=original.resource_name+"Palette"
			mesh.set_meta("source_mesh",path)
			mesh.set_meta("geometry_max_delta",max_delta)
			mesh.set_meta("visual_review","rejected_prototype_render_optimization_only")
			var destination: String="res://assets/characters/render_optimized/"+name_key+".res"
			assert(ResourceSaver.save(mesh,destination,ResourceSaver.FLAG_COMPRESS)==OK)
			report.append({"source":path,"source_sha256":FileAccess.get_sha256(path),"path":destination,"vertices":expected,"triangles":faces,"surfaces_before":original.get_surface_count(),"surfaces_after":mesh.get_surface_count(),"geometry_max_delta":max_delta,"lods":importer.get_surface_lod_count(0)})
			print("DRIVER_RENDER_PACK ",name_key," ",expected," vertices; ",original.get_surface_count()," -> ",mesh.get_surface_count()," surfaces")
	var file: FileAccess=FileAccess.open("res://assets/characters/render_optimized/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Render packing only; character likeness remains rejected","meshes":report},"\t")+"\n")
