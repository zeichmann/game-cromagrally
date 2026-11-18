extends SceneTree
## Asset integrity and placement geometry checks independent of native screenshot review.

var assertions: int=0
var failures: int=0

func check(condition: bool, message: String) -> void:
	assertions+=1
	if not condition:
		failures+=1
		push_error(message)

func _initialize() -> void:
	var unique: Dictionary={}
	for asset in IRFairytaleWorld.ASSET_NAMES:
		check(not unique.has(asset),"Duplicate environment asset: "+asset)
		unique[asset]=true
		var mesh: ArrayMesh=load("res://assets/fairytale/"+asset+".res")
		check(mesh!=null and mesh.get_surface_count()>0,"Missing mesh: "+asset)
		if mesh==null:
			continue
		check(mesh.get_aabb().size.is_finite(),"Invalid bounds: "+asset)
		for surface in range(mesh.get_surface_count()):
			var arrays: Array=mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var valid: bool=not vertices.is_empty() and normals.size()==vertices.size() and indices.size()%3==0
			for i in range(vertices.size()):
				valid=valid and vertices[i].is_finite() and normals[i].is_finite() and absf(normals[i].length()-1)<.03
			for index in indices:
				valid=valid and index>=0 and index<vertices.size()
			check(valid,"Invalid positions, normals or indices: %s surface %d"%[asset,surface])
			if asset=="boat" or asset.begins_with("boat_"):
				check("palette_vehicle" in mesh.surface_get_material(surface).shader.resource_path,"Boat lost its moving material: "+asset)
			if asset=="boathouse":
				check(not mesh.surface_get_material(surface).get_shader_parameter("boat_motion"),"Stilt house must remain fixed to the pier")
	var elder: ArrayMesh=load("res://assets/fairytale/elder_gate.res")
	var clearance: bool=true
	var overhead: int=0
	for surface in range(elder.get_surface_count()):
		var points: PackedVector3Array=elder.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for p in points:
			if absf(p.x)<7.7 and absf(p.z)<4.0:
				overhead+=1
				clearance=clearance and p.y>6.0
	check(overhead>100 and clearance,"Elder tree blocks the full driving corridor or has lost its arch")
	var crag: ArrayMesh=load("res://assets/fairytale/castle_crag.res")
	var cap_vertices: int=0
	for surface in range(crag.get_surface_count()):
		var arrays: Array=crag.surface_get_arrays(surface)
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			if arrays[Mesh.ARRAY_VERTEX][i].y>.999 and arrays[Mesh.ARRAY_NORMAL][i].y>.98:
				cap_vertices+=1
	check(cap_vertices>=80,"Castle crag has no upward-facing closed terrace")
	var track: IRTrack=IRTrack.new()
	track.build_centerline()
	var terrain: IRSceneryArt=IRSceneryArt.new(track)
	var world: IRFairytaleWorld=IRFairytaleWorld.new(track,terrain)
	world.path_corridors=[{"a":Vector2(0,0),"b":Vector2(10,10),"radius":1.0}]
	check(world.on_path(Vector3(5,99,5)),"Path query must ignore elevation")
	check(world.on_path(Vector3(10.5,0,10.5)),"Path endpoint cap is open")
	check(not world.on_path(Vector3(5,0,8)),"Path exclusion extends too far")
	check(world.on_path(Vector3(5,0,8),1.2),"Plant radius is omitted from path clearance")
	var pose: Transform3D=Transform3D(Basis(Vector3.UP,.7).scaled(Vector3.ONE*1.3),Vector3(20,4,30))
	world.building_footprints=[{"inverse":pose.affine_inverse(),"min":Vector2(-3,-2),"max":Vector2(3,4)}]
	check(world.inside_building(pose*Vector3(2,0,3)),"Rotated building footprint missed its interior")
	check(not world.inside_building(pose*Vector3(4,0,3)),"Rotated building footprint rejected a clear point")
	check(world.inside_building(pose*Vector3(4,0,3),1.1),"Crown radius omitted from building clearance")
	var spring: Vector3=Vector3(-44.5,IRWaterfallPath.creek_height(-44.5),IRWaterfallPath.creek_z(-44.5))
	check(spring.y>21.5 and spring.y<21.7,"Creek does not meet the source pond")
	var lip: Vector3=Vector3(-61.6,IRWaterfallPath.creek_height(-61.6),IRWaterfallPath.creek_z(-61.6))
	check(lip.distance_to(IRWaterfallPath.FLOW[0])<.15,"Creek does not meet the upper cascade")
	var clear_lip: bool=true
	for step in range(51):
		var cliff: Vector3=IRWaterfallPath.cliff_point(IRWaterfallPath.PROFILE[10],10,4.5+step*.1)
		# The water shader moves up to .04 m along its normal. Leave clearance.
		clear_lip=clear_lip and cliff.x>IRWaterfallPath.FLOW[0].x+.08
	check(clear_lip,"Rock protrudes through the moving water at the upper lip")
	world.prop_clearances=[{"center":Vector2(10,4),"radius":1.7}]
	check(world.near_prop(Vector3(11,30,4)),"Bench clearance must ignore elevation")
	check(not world.near_prop(Vector3(13,0,4)),"Bench clearance extends too far")
	for z in range(IRSceneryArt.GRID_Z+1):
		for x in range(IRSceneryArt.GRID_X+1):
			terrain.terrain_heights.append(sin(x*.31)*cos(z*.27)*4-8*exp(-pow((x-72)/7.0,2)-pow((z-65)/11.0,2)))
	var proxy: ArrayOccluder3D=terrain.make_terrain_occluder()
	check(proxy.has_method("get_vertices"),"Occluder vertices cannot be inspected")
	if proxy.has_method("get_vertices"):
		var vertices: PackedVector3Array=proxy.call("get_vertices")
		var conservative: bool=not vertices.is_empty()
		for z in range(IRSceneryArt.GRID_Z/4):
			for x in range(IRSceneryArt.GRID_X/4):
				var a: int=z*(IRSceneryArt.GRID_X/4+1)+x
				var high: float=maxf(maxf(vertices[a].y,vertices[a+1].y),maxf(vertices[a+IRSceneryArt.GRID_X/4+1].y,vertices[a+IRSceneryArt.GRID_X/4+2].y))
				for row in range(z*4,z*4+5):
					for column in range(x*4,x*4+5):
						conservative=conservative and high<terrain.terrain_heights[row*(IRSceneryArt.GRID_X+1)+column]
		check(conservative,"Occlusion proxy rises above the terrain at a ridge or narrow creek")
	print("ENVIRONMENT_TEST %s: %d assertions, %d failures, %d meshes"%["PASS" if failures==0 else "FAIL",assertions,failures,unique.size()])
	world.free()
	terrain.free()
	track.free()
	quit(0 if failures==0 else 1)
