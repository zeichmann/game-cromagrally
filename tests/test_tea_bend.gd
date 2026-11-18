extends SceneTree
## Driving clearance, real stream/terrain integration and focal-asset integrity.
var assertions: int=0
var failures: int=0
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var bend: IRTeaBend=world.tea_bend
	var frame: Transform3D=bend.frame
	check(bend!=null and bend.house_node.mesh!=null and bend.tree_node.mesh!=null,"Focal district did not initialise")
	for key in ["teahouse","ancient_oak","tea_garden","teapot_sign"]:
		var mesh: ArrayMesh=load("res://assets/tea_bend/"+key+".res")
		var valid: bool=mesh!=null and mesh.get_surface_count()>0
		if mesh==null: check(false,"Missing asset "+key); continue
		for surface in range(mesh.get_surface_count()):
			var arrays: Array=mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			valid=valid and vertices.size()>0 and normals.size()==vertices.size()
			for i in range(vertices.size()): valid=valid and vertices[i].is_finite() and normals[i].is_finite() and absf(normals[i].length()-1)<.025
		check(valid,"Invalid focal mesh "+key)
	var roof_up: float=0
	var roof_count: int=0
	for surface in range(bend.house_node.mesh.get_surface_count()):
		var arrays: Array=bend.house_node.mesh.surface_get_arrays(surface)
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			if arrays[Mesh.ARRAY_VERTEX][i].y>7.0 and is_equal_approx(roundf(arrays[Mesh.ARRAY_TEX_UV2][i].x),40):
				roof_up+=arrays[Mesh.ARRAY_NORMAL][i].y
				roof_count+=1
	check(roof_count>500 and roof_up/maxi(roof_count,1)>.15,"Curved roof tiles face away from the sky")
	var submerged: bool=true
	var min_depth: float=INF
	for x in [-29.0,-24.0,-17.0,-11.0,0.0,10.0,19.0,27.0]:
		var p: Vector3=frame*Vector3(x,IRTeaBendLayout.water_y(x),IRTeaBendLayout.stream_z(x))
		var depth: float=p.y-world.terrain.surface_height(p)
		min_depth=minf(min_depth,depth)
		submerged=submerged and depth>.12
	check(submerged,"Terrain protrudes through the stream; minimum depth %.3f"%min_depth)
	var grade: bool=true
	var road_normals: bool=true
	for i in range(12,42):
		var delta: Vector3=race.track.centers[i+1]-race.track.centers[i]
		grade=grade and absf(delta.y)/Vector2(delta.x,delta.z).length()<.35
		road_normals=road_normals and race.track.half_width_at(i)>=4.34
	check(grade and road_normals,"Bridge approach is too steep or too narrow")
	var geometry_bounds: AABB=(bend.static_root.get_child(0) as MeshInstance3D).mesh.get_aabb()
	check(geometry_bounds.end.y<4.5 and geometry_bounds.position.z>-22 and geometry_bounds.end.z<20,"A bridge or garden piece is displaced outside the district")
	var open: bool=true
	for node in [bend.house_node,bend.tree_node]:
		for surface in range(node.mesh.get_surface_count()):
			for p in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var position: Vector3=node.global_transform*p
				var i: int=race.track.closest_index(position)
				if i<8 or i>45: continue
				if position.y<race.track.centers[i].y+3.2 and position.y>race.track.centers[i].y-.2:
					open=open and race.track.driving_margin(position,i)>.65
	check(open,"House or oak blocks the driving corridor")
	var residents_dry: bool=true
	for spot in world.life.spots:
		if spot.asset in ["resident_gull","resident_duck"]: continue
		var p: Vector3=frame.affine_inverse()*spot.pose.origin
		if absf(p.x)>34: continue
		residents_dry=residents_dry and absf(p.z-IRTeaBendLayout.stream_z(p.x))>IRTeaBendLayout.stream_half_width(p.x)+.25
	check(residents_dry,"A pedestrian stands in the new stream")
	check(not bend.is_processing() and not bend.is_physics_processing(),"District unexpectedly updates visual transforms on CPU")
	print("TEA_BEND_TEST %s: %d assertions, %d failures; minimum stream depth %.3fm"%["PASS" if failures==0 else "FAIL",assertions,failures,min_depth])
	quit(0 if failures==0 else 1)
