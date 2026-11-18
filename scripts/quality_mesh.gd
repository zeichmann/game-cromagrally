class_name IRQualityMesh
extends RefCounted
## Select authored index LODs for instanced vegetation; never mutate source meshes.
static var cache: Dictionary={}
static func performance(source: ArrayMesh) -> ArrayMesh:
	if cache.has(source): return cache[source]
	var importer: ImporterMesh=ImporterMesh.from_mesh(source)
	var result: ArrayMesh=ArrayMesh.new()
	for s in range(importer.get_surface_count()):
		var arrays: Array=importer.get_surface_arrays(s)
		var base: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var chosen: PackedInt32Array=base
		var material: Material=importer.get_surface_material(s)
		var foliage_cards: bool=material is ShaderMaterial and material.shader.resource_path.ends_with("palette_double.gdshader")
		for lod in range(importer.get_surface_lod_count(s)):
			var indices: PackedInt32Array=importer.get_surface_lod_indices(s,lod)
			if indices.size()>base.size()*.5: continue
			if indices.size()<base.size()*(.015 if foliage_cards else .18): break
			chosen=indices
			if indices.size()<=base.size()*.45: break
		arrays[Mesh.ARRAY_INDEX]=chosen
		result.add_surface_from_arrays(importer.get_surface_primitive_type(s),arrays)
		result.surface_set_material(s,material)
	cache[source]=result
	return result
