class_name IRArt
extends RefCounted
## Shared materials and mesh construction for the original Windward art set.

static var materials: Dictionary = {}

static func pbr(color: Color, roughness: float = 0.65, metal: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s/%.2f/%.2f" % [color.to_html(), roughness, metal]
	if materials.has(key):
		return materials[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	if roughness < .5 and metal < .2:
		m.clearcoat_enabled = true
		m.clearcoat = .4
		m.clearcoat_roughness = .22
	materials[key] = m
	return m

static func textured(kind: String) -> StandardMaterial3D:
	if materials.has(kind):
		return materials[kind]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	var paths: Dictionary = {"road": "fairy_paving", "wood": "cedar_albedo", "linen": "sail_linen_albedo"}
	var path: String = "res://assets/textures/%s.png" % paths[kind]
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.albedo_color = Color.WHITE
	m.roughness = 0.92 if kind == "road" else (0.76 if kind == "linen" else 0.52)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Active surface shaders derive their normals on GPU; no unused CPU noise texture.
	if kind == "linen":
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[kind] = m
	return m

static func shader(path: String) -> ShaderMaterial:
	if materials.has(path):
		return materials[path]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://shaders/" + path + ".gdshader")
	materials[path] = m
	return m

static func timber(vertical: bool = false) -> ShaderMaterial:
	var key: String = "timber_vertical" if vertical else "timber_longitudinal"
	if materials.has(key):
		return materials[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://shaders/cedar_finish.gdshader")
	m.set_shader_parameter("albedo_tex",textured("wood").albedo_texture)
	m.set_shader_parameter("vertical_grain",vertical)
	materials[key] = m
	return m

static func road() -> ShaderMaterial:
	var m: ShaderMaterial = shader("racing_surface")
	m.set_shader_parameter("albedo_tex",load("res://assets/textures/fairy_paving.png"))
	m.set_shader_parameter("wood_tex",load("res://assets/textures/cedar_albedo.png"))
	m.set_shader_parameter("rock_tex",load("res://assets/textures/cliff_albedo_v2.png"))
	return m

static func part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

static func block(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return part(parent, mesh, pos, mat)

static func ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var node: MeshInstance3D = part(parent, mesh, pos, mat)
	node.scale = size
	return node

static func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 16
	mesh.rings = 1
	var node: MeshInstance3D = part(parent, mesh, (a + b) * 0.5, mat)
	var y: Vector3 = (b - a).normalized()
	var x: Vector3 = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	node.basis = Basis(x, y, x.cross(y))
	return node

static func ring(parent: Node3D, radius: float, thickness: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 16
	mesh.ring_segments = 32
	return part(parent, mesh, pos, mat)

static func loft(parent: Node3D, rings: Array[Vector3], y: float, mat: Material) -> MeshInstance3D:
	# Sample a continuous profile and supply analytic normals across every triangle.
	var profiles: Array[Vector3] = []
	for r in range(rings.size()-1):
		for step in range(8):
			var p: Vector3 = rings[r].cubic_interpolate(rings[r+1],rings[maxi(r-1,0)],rings[mini(r+2,rings.size()-1)],float(step)/8)
			p.x=maxf(p.x,.003)
			p.y=maxf(p.y,.003)
			profiles.append(p)
	profiles.append(rings[-1])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 48
	for r in range(profiles.size()):
		var profile: Vector3 = profiles[r]
		var slope: Vector3 = profiles[mini(r+1,profiles.size()-1)]-profiles[maxi(r-1,0)]
		for i in range(segments+1):
			var a: float = TAU*float(i)/segments
			var around: Vector3 = Vector3(-profile.x*sin(a),profile.y*cos(a),0)
			var along: Vector3 = Vector3(slope.x*cos(a),slope.y*sin(a),slope.z)
			st.set_normal(around.cross(along).normalized())
			st.set_uv(Vector2(float(i)/segments,profile.z*.5))
			st.add_vertex(Vector3(cos(a)*profile.x,y+sin(a)*profile.y,profile.z))
	for r in range(profiles.size()-1):
		for i in range(segments):
			var a: int = r*(segments+1)+i
			for index in [a,a+segments+1,a+1,a+1,a+segments+1,a+segments+2]:
				st.add_index(index)
	st.generate_tangents()
	return part(parent,st.commit(),Vector3.ZERO,mat)

static func bake(parent: Node3D, glazed: bool = false) -> MeshInstance3D:
	# Merge static model parts by shared material, preserving moving subassemblies.
	var groups: Dictionary = {}
	var mats: Dictionary = {}
	for node in parent.get_children():
		if not node is MeshInstance3D:
			continue
		for surface in range(node.mesh.get_surface_count()):
			var mat: Material=node.material_override if node.material_override!=null else node.mesh.surface_get_material(surface)
			assert(mat!=null,"A baked surface must have a material")
			var id: int=mat.get_instance_id()
			if not groups.has(id):
				var st: SurfaceTool=SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[id]=st
				mats[id]=mat
			# Mixing indexed primitives with unindexed custom faces silently drops the
			# latter at commit time. Give every source surface an index buffer first.
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
				var source: SurfaceTool=SurfaceTool.new()
				source.create_from(node.mesh,surface)
				source.index()
				groups[id].append_from(source.commit(),0,node.transform)
			else:
				groups[id].append_from(node.mesh,surface,node.transform)
		node.free()
	var mesh: ArrayMesh = ArrayMesh.new()
	for id in groups:
		groups[id].index()
		groups[id].set_material(mats[id])
		groups[id].commit(mesh)
	return part(parent,IRPaletteMesh.compact(mesh,false,glazed),Vector3.ZERO,null)

static func scatter(parent: Node3D, mesh: Mesh, mat: Material, transforms: Array[Transform3D], colors: Array[Color], distance: float = 240, shadows: bool = true) -> void:
	if transforms.is_empty():
		return
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	var center: Vector3=Vector3.ZERO
	for transform in transforms:
		center+=transform.origin
	center/=transforms.size()
	for i in range(transforms.size()):
		var local_transform: Transform3D=transforms[i]
		local_transform.origin-=center
		multi.set_instance_transform(i, local_transform)
		multi.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.position=center
	node.multimesh = multi
	node.material_override = mat
	node.visibility_range_end = distance
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
