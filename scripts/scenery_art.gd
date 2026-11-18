class_name IRSceneryArt
extends Node3D
## Sampled island terrain, grass and shoreline. Authored districts live in IRFairytaleWorld.

var track: IRTrack
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var terrain_heights: PackedFloat32Array=PackedFloat32Array()
var grass_groups: Array[Dictionary]=[]
const GRID_X: int=192
const GRID_Z: int=168
const CELL_SIZE: float=320.0/GRID_X

func _init(course: IRTrack) -> void:
	track = course
	rng.seed = 735104

func _ready() -> void:
	_landscape()
	_vegetation()
	_shore_rocks()
	add_child(IRFairytaleWorld.new(track,self))

func ground_height(p: Vector3, nearest: int = -1) -> float:
	var r: float = Vector2(p.x/155.0,p.z/136.0).length()
	var height: float = -.5 + sin(p.x*.046)*cos(p.z*.057)*2.8 + 6.0*exp(-r*r*7)
	height+=18.0*exp(-pow(Vector2(p.x+20,p.z+35).length()/25.0,2))
	height+=24.0*exp(-pow((p.x+48)/19.0,2)-pow((p.z-7)/23.0,2))
	height = lerpf(height,-14.0,smoothstep(.79,1.06,r))
	var i: int = track.closest_index(p) if nearest < 0 else nearest
	var d: float = Vector2(p.x-track.centers[i].x,p.z-track.centers[i].z).length()
	var village: bool=i<66
	var road_width: float=track.half_width_at(i)
	var blend: float = 1.0-smoothstep(22.0 if village else road_width,37.0 if village else road_width+18.0,d)
	height=lerpf(height,track.centers[i].y-.65,blend)
	if village:
		var verge: float=smoothstep(road_width+1.5,road_width+3.7,d)*(1-smoothstep(road_width+7.2,road_width+10.2,d))
		height+=verge*(.45+.30*sin(p.x*.17+p.z*.09))
	if i>=IRTrack.SHORTCUT_START-5 and i<=IRTrack.SHORTCUT_END+5 and not track.shortcut.is_empty():
		var n: int=track.shortcut_nearest(p)
		var path_distance: float=Vector2(p.x-track.shortcut[n].x,p.z-track.shortcut[n].z).length()
		height=lerpf(height,track.shortcut[n].y-.45,1-smoothstep(IRTrack.SHORTCUT_WIDTH,IRTrack.SHORTCUT_WIDTH+2,path_distance))
	var plaza: Vector3=track.centers[28]+track.right_at(28)*(track.half_width_at(28)+13.0)
	var plaza_distance: float=Vector2(p.x-plaza.x,(p.z-plaza.z)*1.05).length()
	height=lerpf(height,track.centers[28].y-.65,1.0-smoothstep(12.0,18.0,plaza_distance))
	var ravine: Vector3=p-track.centers[167]
	var ravine_distance: float=Vector2(ravine.dot(track.tangents[167])*1.8,ravine.dot(track.right_at(167))*.38).length()
	height=lerpf(height,track.centers[167].y-6.5,1-smoothstep(8,16,ravine_distance))
	# River crosses underneath the visual stone bridge; the driving surface stays intact.
	var river_z: float=7.0+sin((p.x+115)*.045)*3.0
	var river: float=(1.0-smoothstep(4.8,10.5,absf(p.z-river_z)))*(1.0-smoothstep(-74.0,-66.0,p.x))
	var pool: float=1.0-smoothstep(7.0,13.0,Vector2(p.x+76,(p.z-7)*.85).length())
	height=lerpf(height,-9.4,maxf(river,pool))
	height=IRWaterfallPath.adjust_ground(p,height)
	var harbor: Vector3=track.centers[344]-track.right_at(344)*35.0
	var delta: Vector3=(p-harbor)*Vector3(1,0,1)
	var cove_distance: float=Vector2(delta.dot(track.tangents[344])*.65,delta.dot(track.right_at(344))).length()
	height=lerpf(height,-9.6,1.0-smoothstep(14.0,27.0,cove_distance))
	return IRTeaBendLayout.adjust_ground(track,p,height)

func _landscape() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = GRID_X
	var nz: int = GRID_Z
	terrain_heights.clear()
	for z in range(nz+1):
		for x in range(nx+1):
			var p: Vector3 = Vector3(float(x)/nx*320-160,0,float(z)/nz*280-140)
			p.y = ground_height(p)
			terrain_heights.append(p.y)
	for z in range(nz+1):
		for x in range(nx+1):
			var p: Vector3=Vector3(x*CELL_SIZE-160,terrain_heights[z*(nx+1)+x],z*CELL_SIZE-140)
			st.set_uv(Vector2(p.x,p.z)*.05)
			st.set_normal(grid_normal(x,z))
			st.add_vertex(p)
	for z in range(nz):
		for x in range(nx):
			var a: int = z*(nx+1)+x
			for index in [a,a+1,a+nx+1,a+1,a+nx+2,a+nx+1]:
				st.add_index(index)
	var terrain_material: ShaderMaterial=IRArt.shader("island")
	terrain_material.set_shader_parameter("grass_tex",load("res://assets/textures/meadow_painted_v3.png"))
	terrain_material.set_shader_parameter("rock_tex",load("res://assets/textures/cliff_albedo_v2.png"))
	terrain_material.set_shader_parameter("sand_tex",load("res://assets/textures/shore_albedo_v2.png"))
	var ground: MeshInstance3D=IRArt.part(self,st.commit(),Vector3.ZERO,terrain_material)
	ground.name="IslandGround"
	# The road has its own collider, but leaving it must land on the island.
	# Use the exact rendered triangles, including hills, shore and creek cuts.
	ground.create_trimesh_collision()
	var ground_body: StaticBody3D=ground.get_child(0)
	ground_body.name="IslandGroundCollision"
	ground_body.collision_layer=1
	ground_body.collision_mask=2
	ground_body.physics_material_override=IRTrack.driving_surface_material()
	var occlusion: OccluderInstance3D=OccluderInstance3D.new()
	occlusion.name="ConservativeTerrainOccluder"
	occlusion.occluder=make_terrain_occluder()
	add_child(occlusion)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(1800,1800)
	plane.subdivide_width = 128
	plane.subdivide_depth = 128
	var water: MeshInstance3D = IRArt.part(self,plane,Vector3(0,-7.0,0),IRArt.shader("ocean"))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Distant islands give the ocean horizon depth without extra collision geometry.
	var far: Node3D = Node3D.new()
	add_child(far)
	var far_mesh: ArrayMesh = _rock_mesh()
	var island_material: ShaderMaterial=IRArt.shader("distant_island")
	island_material.set_shader_parameter("cliff_tex",load("res://assets/textures/cliff_albedo_v2.png"))
	island_material.set_shader_parameter("meadow_tex",load("res://assets/textures/meadow_painted_v3.png"))
	for n in range(9):
		var a: float = TAU*n/9.0+.31
		var p: Vector3 = Vector3(cos(a)*550,-22,sin(a)*550)
		var land: MeshInstance3D = IRArt.part(far,far_mesh,p,island_material)
		land.scale = Vector3(65+rng.randf()*40,25+rng.randf()*35,60)
		land.rotation.y=a+n*.4
	IRArt.bake(far)

func grid_normal(x: int, z: int) -> Vector3:
	# A broader central derivative removes alternating face directions introduced
	# by discrete road samples without changing the actual terrain or attachments.
	var x0: int=maxi(x-2,0)
	var x1: int=mini(x+2,GRID_X)
	var z0: int=maxi(z-2,0)
	var z1: int=mini(z+2,GRID_Z)
	var dx: float=0
	var dz: float=0
	for offset in range(-1,2):
		var weight: float=2 if offset==0 else 1
		var row: int=clampi(z+offset,0,GRID_Z)
		var column: int=clampi(x+offset,0,GRID_X)
		dx+=(terrain_heights[row*(GRID_X+1)+x1]-terrain_heights[row*(GRID_X+1)+x0])*weight
		dz+=(terrain_heights[z1*(GRID_X+1)+column]-terrain_heights[z0*(GRID_X+1)+column])*weight
	dx/=4*(x1-x0)*CELL_SIZE
	dz/=4*(z1-z0)*CELL_SIZE
	return Vector3(-dx,1,-dz).normalized()

func make_terrain_occluder() -> ArrayOccluder3D:
	# Every coarse vertex uses the minimum of its adjacent fine cells. The proxy
	# therefore remains below the visible terrain, including the narrow creek.
	var vertices: PackedVector3Array=PackedVector3Array()
	var indices: PackedInt32Array=PackedInt32Array()
	var step: int=4
	var width: int=GRID_X/step+1
	for z in range(0,GRID_Z+1,step):
		for x in range(0,GRID_X+1,step):
			var low: float=INF
			for row in range(maxi(0,z-step),mini(GRID_Z,z+step)+1):
				for column in range(maxi(0,x-step),mini(GRID_X,x+step)+1):
					low=minf(low,terrain_heights[row*(GRID_X+1)+column])
			vertices.append(Vector3(x*CELL_SIZE-160,low-.15,z*CELL_SIZE-140))
	for z in range(GRID_Z/step):
		for x in range(GRID_X/step):
			var a: int=z*width+x
			for index in [a,a+1,a+width,a+1,a+width+1,a+width]:
				indices.append(index)
	var occluder: ArrayOccluder3D=ArrayOccluder3D.new()
	occluder.set_arrays(vertices,indices)
	return occluder

func surface_height(p: Vector3) -> float:
	# Place small foliage on the exact rendered triangle, not an unsampled height field.
	if terrain_heights.is_empty():
		return ground_height(p)
	var grid: Vector2=Vector2((p.x+160)/CELL_SIZE,(p.z+140)/CELL_SIZE)
	grid.x=clampf(grid.x,0,GRID_X)
	grid.y=clampf(grid.y,0,GRID_Z)
	var x: int=mini(floori(grid.x),GRID_X-1)
	var z: int=mini(floori(grid.y),GRID_Z-1)
	var u: float=grid.x-x
	var v: float=grid.y-z
	var stride: int=GRID_X+1
	var a: int=z*stride+x
	if u+v<=1:
		return terrain_heights[a]+u*(terrain_heights[a+1]-terrain_heights[a])+v*(terrain_heights[a+stride]-terrain_heights[a])
	return terrain_heights[a+stride+1]+(1-u)*(terrain_heights[a+stride]-terrain_heights[a+stride+1])+(1-v)*(terrain_heights[a+1]-terrain_heights[a+stride+1])

func _fronds(grass: bool = false) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if grass:
		for n in range(7):
			var a: float = n*2.4
			var direction: Vector3 = Vector3(cos(a),0,sin(a))
			var side: Vector3 = direction.cross(Vector3.UP)
			var height: float = .38+.23*sin(n*3.1)*sin(n*3.1)
			for j in range(4):
				for off in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var t: float = float(j+off.x)/4
					var width: float = .05*(1.0-t)*(.7+.3*sin(t*PI))
					var p: Vector3 = direction*(.04+t*t*.22)+Vector3.UP*(t*height)
					st.set_uv(Vector2(off.y,t))
					st.set_color(Color.WHITE)
					st.set_normal((Vector3.UP*.65-direction*.3+side*.1).normalized())
					st.add_vertex(p+side*(off.y*2-1)*width)
	else:
		for n in range(11):
			var a: float = n*TAU/11+.07*sin(n*7)
			var direction: Vector3 = Vector3(cos(a),0,sin(a))
			var side: Vector3 = direction.cross(Vector3.UP)
			var length: float = 3.3+.55*sin(n*3.7)
			for j in range(17):
				var t: float = float(j+1)/18
				var p: Vector3 = direction*t*length
				p.y=sin(t*PI)*.85-t*t*1.25
				var span: float = .70*pow(sin(t*PI),.7)*(1.0-t*.30)
				for sign_side in [-1.0,1.0]:
					for step in range(3):
						for off in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
							var u: float = float(step+off.x)/3
							var point: Vector3 = p+side*sign_side*u*span-direction*u*.23
							point.y+=sin(u*PI)*.08-u*u*.13
							var width: float = .115*sin(u*PI)*.9+.014*(1-u)
							st.set_uv(Vector2(off.y,t))
							st.set_color(Color.WHITE)
							st.set_normal((Vector3.UP+side*sign_side*.22-direction*.1).normalized())
							st.add_vertex(point+direction*(off.y*2-1)*width)
			for j in range(12):
				for off in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var t: float=float(j+off.x)/12
					var center: Vector3=direction*t*length
					center.y=sin(t*PI)*.85-t*t*1.25
					var width: float=.18*pow(maxf(sin(t*PI),0.0),.7)
					st.set_uv(Vector2(off.y,t))
					st.set_color(Color.WHITE)
					st.set_normal(Vector3.UP)
					st.add_vertex(center+side*(off.y*2-1)*width)
	return st.commit()

func _vegetation() -> void:
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = .16
	trunk.bottom_radius = .28
	trunk.height = 1
	trunk.radial_segments = 16
	trunk.rings = 20
	var palm: ArrayMesh = _fronds()
	var grass_mesh: ArrayMesh = _fronds(true)
	var leaf_mat: ShaderMaterial = IRArt.shader("foliage")
	# Sector batches keep GPU instancing while allowing off-camera sectors to cull.
	for sector in range(8):
		var trunks: Array[Transform3D] = []
		var leaves: Array[Transform3D] = []
		var shades: Array[Color] = []
		var grasses: Array[Transform3D] = []
		var grass_colors: Array[Color] = []
		for n in range(2 if sector>=6 else 0):
			var i: int = sector*48+n*6
			var side: float = -1 if n%2 == 0 else 1
			var p: Vector3 = track.centers[i]+track.right_at(i)*side*rng.randf_range(15,27)
			p.y = surface_height(p)
			if p.y < -5.5:
				continue
			var height: float = rng.randf_range(6,10)
			var tilt: Basis = Basis.from_euler(Vector3(rng.randf_range(-.12,.12),rng.randf()*TAU,rng.randf_range(-.13,.13)))
			trunks.append(Transform3D(Basis(tilt.x,tilt.y*height,tilt.z),p+tilt.y*height*.5))
			leaves.append(Transform3D(tilt.scaled(Vector3.ONE*rng.randf_range(.8,1.2)),p+tilt.y*height+tilt.x*.25))
			shades.append(Color.WHITE.lerp(Color("c9db9b"),rng.randf()*.45))
		IRArt.scatter(self,trunk,IRArt.shader("palm_bark"),trunks,[],280)
		IRArt.scatter(self,palm,leaf_mat,leaves,shades,280)
		for n in range(250):
			var a: float = (sector+rng.randf())*TAU/8
			var radius: float = rng.randf_range(30,143)
			var p: Vector3 = Vector3(cos(a)*radius,0,sin(a)*radius*.88)
			var i: int = track.closest_index(p)
			var d: float = Vector2(p.x-track.centers[i].x,p.z-track.centers[i].z).length()
			if d < IRTrack.HALF_WIDTH+1.5:
				continue
			p.y = surface_height(p)
			if p.y < -4.5:
				continue
			grasses.append(Transform3D(Basis(Vector3.UP,a*5).scaled(Vector3.ONE*rng.randf_range(.7,1.7)),p))
			grass_colors.append(Color.WHITE.lerp(Color("dce6ac"),rng.randf()*.5))
		for n in range(200):
			var i: int = sector*48+rng.randi_range(0,47)
			var p: Vector3 = track.centers[i]+track.right_at(i)*rng.randf_range(8.3,14.0)*(-1 if n%2 else 1)
			p.y=surface_height(p)
			if p.y < -4.5:
				continue
			grasses.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.6,1.2)),p))
			grass_colors.append(Color.WHITE)
		IRArt.scatter(self,grass_mesh,leaf_mat,grasses,grass_colors,75,false)
		grass_groups.append({"node":get_child(-1),"transforms":grasses,"colors":grass_colors})

func trim_grass(world: IRFairytaleWorld) -> void:
	for group in grass_groups:
		var transforms: Array[Transform3D]=[]
		var colors: Array[Color]=[]
		var node: MultiMeshInstance3D=group.node
		for i in range(group.transforms.size()):
			var pose: Transform3D=group.transforms[i]
			if world.on_path(pose.origin,.35) or world.inside_building(pose.origin,.35):
				continue
			pose.origin-=node.position
			transforms.append(pose)
			colors.append(group.colors[i])
		var multi: MultiMesh=node.multimesh
		multi.instance_count=transforms.size()
		for i in range(transforms.size()):
			multi.set_instance_transform(i,transforms[i])
			multi.set_instance_color(i,colors[i])
	grass_groups.clear()

func _rock_mesh() -> ArrayMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 20
	sphere.rings = 12
	var arrays: Array = sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var p: Vector3 = vertices[index]
		var distortion: float = 1+sin(p.x*7+p.y*4)*cos(p.z*6)*.14
		st.set_color(Color.WHITE)
		st.add_vertex(p*distortion)
	st.index()
	st.generate_normals()
	return st.commit()

func _shore_rocks() -> void:
	var mesh: ArrayMesh = _rock_mesh()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color("a1a18b")
	mat.vertex_color_use_as_albedo = true
	mat.roughness = .9
	for sector in range(8):
		var rocks: Array[Transform3D] = []
		var colors: Array[Color] = []
		for n in range(24):
			var a: float = (sector+rng.randf())*TAU/8
			var r: float = rng.randf_range(.88,1.02)
			var p: Vector3 = Vector3(cos(a)*155*r,0,sin(a)*136*r)
			var i: int = track.closest_index(p)
			if Vector2(p.x-track.centers[i].x,p.z-track.centers[i].z).length() < 10:
				continue
			p.y = surface_height(p)+.2
			var size: Vector3 = Vector3(rng.randf_range(1.4,4.3),rng.randf_range(1.2,3.2),rng.randf_range(1.5,4))
			rocks.append(Transform3D(Basis(Vector3.UP,a).scaled(size),p))
			colors.append(Color.WHITE.lerp(Color("d4c49c"),rng.randf()*.6))
		IRArt.scatter(self,mesh,mat,rocks,colors,350)
