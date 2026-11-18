class_name IRWorldCollisions
extends Node3D
## Static level geometry, independent of render distance and visual quality banks.
const SCENERY_LAYER: int=4
const VEHICLE_LAYER: int=2
const SOFT_FAMILIES: Array[int]=[7,9,10,11,14,15,16,19,22,24,26,37]
const SOLID_ASSETS: Array[String]=[
	"cottage_blue","cottage_rose","cottage_peach","bakery",
	"town_post","town_workshop","town_tea","boathouse","lighthouse",
	"castle_keep","turret","windmill","port_crane","crystal_grotto",
	"arch","elder_gate","footbridge","stone_rail","garden_fence",
	"garden_planter","mailbox","lantern","rose_arbor","dock_supplies","pavilion",
	"fountain","bench","market_stall","moss_boulder",
	"tree_oak","tree_blossom","tree_willow","tree_birch","tree_cypress"
]
var shapes: Dictionary={}
var bodies: Array[StaticBody3D]=[]
var counts: Dictionary={}

func solid_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	if shapes.has(mesh): return shapes[mesh]
	var faces: PackedVector3Array=PackedVector3Array()
	for s in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(s)!=Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays: Array=mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var families: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
		var count: int=indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0,count-2,3):
			var a: int=indices[i] if not indices.is_empty() else i
			var b: int=indices[i+1] if not indices.is_empty() else i+1
			var c: int=indices[i+2] if not indices.is_empty() else i+2
			if not families.is_empty() and roundi(families[a].x) in SOFT_FAMILIES: continue
			if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared()<1e-10: continue
			faces.append(vertices[a]); faces.append(vertices[b]); faces.append(vertices[c])
	var shape: ConcavePolygonShape3D
	if not faces.is_empty():
		shape=ConcavePolygonShape3D.new()
		shape.backface_collision=true
		shape.set_faces(faces)
	shapes[mesh]=shape
	return shape

func add_mesh(asset: String,mesh: Mesh,pose: Transform3D,driving_surface: bool=false) -> StaticBody3D:
	var shape: ConcavePolygonShape3D=solid_shape(mesh)
	if shape==null: return null
	var body: StaticBody3D=StaticBody3D.new()
	body.name="Solid_%04d_%s"%[bodies.size(),asset]
	body.transform=pose
	body.collision_layer=SCENERY_LAYER
	body.collision_mask=VEHICLE_LAYER
	body.set_meta("asset",asset)
	body.set_meta("source_mesh",mesh)
	body.set_meta("source_transform",pose)
	if driving_surface: body.physics_material_override=IRTrack.driving_surface_material()
	var collider: CollisionShape3D=CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	add_child(body)
	body.add_to_group("solid_scenery")
	bodies.append(body)
	counts[asset]=int(counts.get(asset,0))+1
	return body

func add_visual(asset: String,node: MeshInstance3D,driving_surface: bool=false) -> StaticBody3D:
	return add_mesh(asset,node.mesh,global_transform.affine_inverse()*node.global_transform,driving_surface)
