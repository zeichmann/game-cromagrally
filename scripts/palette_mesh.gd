class_name IRPaletteMesh
extends RefCounted
## Offline packing: preserve geometry/skinning while reducing colored parts to shared surfaces.

static var shared: Dictionary={}

static func material(double_sided: bool, boat: bool = false, glazed: bool = false, floating: bool = false) -> ShaderMaterial:
	var key: String=("double" if double_sided else "solid")+("_boat" if boat else "")+("_glazed" if glazed else "")
	key+="_floating" if floating else ""
	if shared.has(key):
		return shared[key]
	var mat: ShaderMaterial=ShaderMaterial.new()
	var file: String=("palette_vehicle_double" if double_sided else "palette_vehicle") if glazed or boat else ("palette_double" if double_sided else "palette_surface")
	mat.shader=load("res://shaders/"+file+".gdshader")
	var textures: Dictionary={"stone_tex":"fairy_masonry","roof_tex":"fairy_roof","wood_tex":"cedar_albedo","linen_tex":"sail_linen_albedo","leaf_tex":"leaf_canopy_albedo_v2","blossom_tex":"blossom_canopy_albedo_v2","cliff_tex":"cliff_albedo_v2"}
	for param in textures:
		var path: String="res://assets/textures/"+textures[param]+".png"
		if ResourceLoader.exists(path):
			mat.set_shader_parameter(param,load(path))
	if ResourceLoader.exists("res://assets/textures/tea_ancient_bark_v1.png"):
		mat.set_shader_parameter("tea_bark_tex",load("res://assets/textures/tea_ancient_bark_v1.png"))
	mat.set_shader_parameter("boat_motion",boat)
	mat.set_shader_parameter("floating_motion",floating)
	shared[key]=mat
	return mat

static func descriptor(mat: Material) -> Dictionary:
	if mat is StandardMaterial3D:
		if mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
			return {}
		var kind: int=3 if mat.metallic>.2 else (11 if mat.emission_enabled else 0)
		if mat.has_meta("palette_kind"):
			kind=int(mat.get_meta("palette_kind"))
		if mat.albedo_texture!=null:
			if "linen" in mat.albedo_texture.resource_path:
				kind=7
			else:
				return {}
		return {"kind":kind+mat.metallic*.1,"roughness":mat.roughness,"color":mat.albedo_color,"vertex_color":mat.vertex_color_use_as_albedo,"srgb":mat.vertex_color_is_srgb,"double":mat.cull_mode==BaseMaterial3D.CULL_DISABLED,"uv_scale":1.0}
	if mat is ShaderMaterial:
		var path: String=mat.shader.resource_path.get_file()
		if path=="storybook_surface.gdshader":
			var texture: Texture2D=mat.get_shader_parameter("albedo_tex")
			if texture==null:
				return {}
			var kind: int=12 if "cliff" in texture.resource_path else (2 if "roof" in texture.resource_path else 1)
			var color: Color=mat.get_shader_parameter("tint") if mat.get_shader_parameter("tint")!=null else Color.WHITE
			var roughness: float=mat.get_shader_parameter("roughness") if mat.get_shader_parameter("roughness")!=null else .78
			var scale_uv: float=mat.get_shader_parameter("texture_scale") if mat.get_shader_parameter("texture_scale")!=null else 1.0
			return {"kind":kind,"roughness":roughness,"color":color,"vertex_color":false,"srgb":false,"double":false,"uv_scale":scale_uv}
		if path=="cedar_finish.gdshader":
			return {"kind":6 if mat.get_shader_parameter("vertical_grain") else 5,"roughness":.55,"color":Color.WHITE,"vertex_color":false,"srgb":false,"double":false,"uv_scale":1.0}
		if path=="rubber.gdshader":
			return {"kind":8,"roughness":.9,"color":Color("202b2d"),"vertex_color":false,"srgb":false,"double":false,"uv_scale":1.0}
		if path=="fairytale_canopy.gdshader":
			var tex: Texture2D=mat.get_shader_parameter("leaf_tex")
			return {"kind":10 if tex!=null and "blossom" in tex.resource_path else 9,"roughness":.9,"color":Color.WHITE,"vertex_color":true,"srgb":false,"double":false,"uv_scale":1.0}
	return {}

static func compact(mesh: Mesh, boat: bool = false, glazed: bool = false, floating: bool = false) -> ArrayMesh:
	var result: ArrayMesh=ArrayMesh.new()
	var groups: Dictionary={}
	for surface in range(mesh.get_surface_count()):
		var mat: Material=mesh.surface_get_material(surface)
		var arrays: Array=mesh.surface_get_arrays(surface)
		var properties: Dictionary=descriptor(mat)
		var packed: bool=mat is ShaderMaterial and mat.shader.resource_path.get_file().begins_with("palette_")
		if properties.is_empty() and not packed:
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			result.surface_set_material(result.get_surface_count()-1,mat)
			continue
		var double_sided: bool="_double" in mat.shader.resource_path.get_file() if packed else properties.double
		var count: int=arrays[Mesh.ARRAY_VERTEX].size()
		if not packed:
			var old_colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			var colors: PackedColorArray=PackedColorArray()
			var data: PackedVector2Array=PackedVector2Array()
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
			colors.resize(count)
			data.resize(count)
			uv.resize(count)
			var base_color: Color=properties.color.srgb_to_linear()
			colors.fill(base_color)
			data.fill(Vector2(properties.kind,properties.roughness))
			if properties.vertex_color and not old_colors.is_empty():
				for i in range(count):
					colors[i]=base_color*(old_colors[i].srgb_to_linear() if properties.srgb else old_colors[i])
			if not is_equal_approx(properties.uv_scale,1.0):
				for i in range(count):
					uv[i]*=properties.uv_scale
			arrays[Mesh.ARRAY_COLOR]=colors
			arrays[Mesh.ARRAY_TEX_UV2]=data
			arrays[Mesh.ARRAY_TEX_UV]=uv
		if not groups.has(double_sided):
			groups[double_sided]=[]
		groups[double_sided].append(arrays)
	for key in groups:
		var vertices: PackedVector3Array=PackedVector3Array()
		var normals: PackedVector3Array=PackedVector3Array()
		var colors: PackedColorArray=PackedColorArray()
		var uv: PackedVector2Array=PackedVector2Array()
		var data: PackedVector2Array=PackedVector2Array()
		var bones: PackedInt32Array=PackedInt32Array()
		var weights: PackedFloat32Array=PackedFloat32Array()
		var indices: PackedInt32Array=PackedInt32Array()
		for source in groups[key]:
			var offset: int=vertices.size()
			vertices.append_array(source[Mesh.ARRAY_VERTEX])
			normals.append_array(source[Mesh.ARRAY_NORMAL])
			colors.append_array(source[Mesh.ARRAY_COLOR])
			uv.append_array(source[Mesh.ARRAY_TEX_UV])
			data.append_array(source[Mesh.ARRAY_TEX_UV2])
			if source[Mesh.ARRAY_BONES]!=null:
				bones.append_array(source[Mesh.ARRAY_BONES])
				weights.append_array(source[Mesh.ARRAY_WEIGHTS])
			if source[Mesh.ARRAY_INDEX]!=null and not source[Mesh.ARRAY_INDEX].is_empty():
				for i in source[Mesh.ARRAY_INDEX]:
					indices.append(offset+i)
			else:
				for i in range(source[Mesh.ARRAY_VERTEX].size()):
					indices.append(offset+i)
		var arrays: Array=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_TEX_UV]=uv
		arrays[Mesh.ARRAY_TEX_UV2]=data
		arrays[Mesh.ARRAY_INDEX]=indices
		if not bones.is_empty():
			arrays[Mesh.ARRAY_BONES]=bones
			arrays[Mesh.ARRAY_WEIGHTS]=weights
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(result.get_surface_count()-1,material(key,boat,glazed,floating))
	return result
