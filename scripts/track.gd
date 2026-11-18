class_name IRTrack
extends Node3D
## Analytic circuit, terrain and props authored for this prototype.

const SAMPLES: int = 384
const HALF_WIDTH: float = 6.8
const GATE_COUNT: int = 16
var centers: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector3Array = PackedVector3Array()
var length_m: float = 0.0
var half_widths: PackedFloat32Array=PackedFloat32Array()
var shortcut: PackedVector3Array=PackedVector3Array()
const SHORTCUT_START: int=99
const SHORTCUT_END: int=117
const SHORTCUT_WIDTH: float=2.3
const SURFACES: Dictionary={
	"paving":{"grip":9.0,"drag":1.0,"drive":1.0},
	"dirt":{"grip":7.4,"drag":1.7,"drive":.94},
	"wood":{"grip":8.2,"drag":1.2,"drive":1.0},
	"water":{"grip":5.4,"drag":2.4,"drive":.88},
	"grass":{"grip":5.0,"drag":7.0,"drive":.62},
	"sand":{"grip":4.2,"drag":9.0,"drive":.52}
}

func surface_at(p: Vector3,i: int) -> String:
	if driving_margin(p,i)>1.0:
		return "sand" if Vector2(p.x/155.0,p.z/136.0).length()>.86 else "grass"
	if i>=145 and i<=152: return "water"
	if i>=160 and i<=202: return "wood"
	if i>=73 and i<170: return "dirt"
	return "paving"

func _ready() -> void:
	build_centerline()
	_build_road()
	_build_shortcut()
	add_child(IRSceneryArt.new(self))
	add_child(load("res://scripts/race_signs.gd").new(self))

func build_centerline() -> void:
	centers.clear()
	tangents.clear()
	length_m = 0.0
	half_widths.clear()
	for i in range(SAMPLES):
		var a: float = TAU * float(i) / SAMPLES
		var radius: float = 99.0 + 13.0 * sin(3.0 * a + 0.4) + 8.0 * cos(5.0 * a)
		centers.append(Vector3(cos(a) * radius, 5.0 + 3.8 * sin(2.0 * a) + 1.8 * sin(5.0 * a), sin(a) * radius * 0.8))
	var original: PackedVector3Array=centers.duplicate()
	for i in range(SAMPLES):
		var direction: Vector3=(original[(i+1)%SAMPLES]-original[posmod(i-1,SAMPLES)]).normalized()
		var right: Vector3=direction.cross(Vector3.UP).normalized()
		var village: float=clampf((i-10)/55.0,0,1)
		var forest: float=clampf((i-76)/76.0,0,1)
		var detour: float=clampf((i-97)/22.0,0,1)
		centers[i]+=right*(2.2*sin(village*TAU)*pow(sin(village*PI),2)+1.8*sin(forest*PI*3)*pow(sin(forest*PI),2))
		centers[i]-=right*8.0*pow(sin(detour*PI),2)
		centers[i].y+=.65*pow(sin(forest*PI),2)
		centers[i].y+=.65*_zone(i,247,254,2)
		centers[i].y+=.35*_zone(i,21,33,4)
		half_widths.append(_width_profile(i))
	for i in range(SAMPLES):
		tangents.append((centers[(i + 1) % SAMPLES] - centers[posmod(i - 1, SAMPLES)]).normalized())
		length_m += centers[i].distance_to(centers[(i + 1) % SAMPLES])
	shortcut.clear()
	for n in range(33):
		var t: float=n/32.0
		var p: Vector3=centers[SHORTCUT_START].lerp(centers[SHORTCUT_END],t)
		p+=right_at((SHORTCUT_START+SHORTCUT_END)/2)*sin(t*PI)*4.8
		shortcut.append(p)

static func _zone(i: float,a: float,b: float,fade: float=7) -> float:
	return smoothstep(a,a+fade,i)*(1.0-smoothstep(b-fade,b,i))

static func _width_profile(i: int) -> float:
	var width: float=HALF_WIDTH
	width=lerpf(width,5.1,_zone(i,5,23,5))
	width=lerpf(width,7.5,_zone(i,21,39,5))
	width=lerpf(width,4.9,_zone(i,39,73))
	width=lerpf(width,4.7,_zone(i,71,169,10))
	width=lerpf(width,3.5,_zone(i,99,118,4))
	width=lerpf(width,5.6,_zone(i,207,261))
	width=lerpf(width,5.2,_zone(i,263,324))
	width=lerpf(width,4.35,_zone(i,12,46,12))
	return width

func half_width_at(i: int) -> float:
	return half_widths[posmod(i,SAMPLES)] if not half_widths.is_empty() else HALF_WIDTH

func edge_offset(i: int,authored: float) -> float:
	return signf(authored)*half_width_at(i)+authored-signf(authored)*HALF_WIDTH

func shortcut_nearest(p: Vector3) -> int:
	var result: int=0
	var distance: float=INF
	for n in range(shortcut.size()):
		var d: float=Vector2(p.x-shortcut[n].x,p.z-shortcut[n].z).length_squared()
		if d<distance:
			distance=d
			result=n
	return result

func driving_margin(p: Vector3,i: int) -> float:
	var margin: float=absf((p-centers[i]).dot(right_at(i)))-half_width_at(i)
	if i>=SHORTCUT_START-5 and i<=SHORTCUT_END+5 and not shortcut.is_empty():
		var n: int=shortcut_nearest(p)
		margin=minf(margin,Vector2(p.x-shortcut[n].x,p.z-shortcut[n].z).length()-SHORTCUT_WIDTH)
	return margin

func ai_target(i: int,ahead: int,slot: int) -> Vector3:
	var target: int=posmod(i+ahead,SAMPLES)
	return centers[target]+right_at(target)*sin(slot*3.1)*minf(1.6,half_width_at(target)*.25)

func main_road_speed_limit(i: int,yaw_rate: float) -> float:
	# A long look-ahead chord cuts across the grotto's solid outer wall.
	# The detour must respect the chassis turning rate, just like the shortcut.
	var limit: float=30.0
	for offset in range(-1,17):
		var k: int=posmod(i+offset,SAMPLES)
		var before: Vector3=(centers[k]-centers[posmod(k-1,SAMPLES)])*Vector3(1,0,1)
		var after: Vector3=(centers[(k+1)%SAMPLES]-centers[k])*Vector3(1,0,1)
		var curvature: float=before.angle_to(after)/maxf((before.length()+after.length())*.5,.01)
		if curvature>.001: limit=minf(limit,yaw_rate*.68/curvature)
	return maxf(limit,2.5)

func shortcut_target(p: Vector3,ahead: int) -> Vector3:
	# Follow actual shortcut waypoints, not the projected main-road index.
	# Stay on this route until its end, then aim through the exit checkpoint.
	var n: int=shortcut_nearest(p)
	if n>=shortcut.size()-3:
		return centers[gate_index(5)+2]
	return shortcut[mini(n+ahead,shortcut.size()-1)]

func shortcut_speed_limit(p: Vector3,yaw_rate: float) -> float:
	var n: int=shortcut_nearest(p)
	var limit: float=8.0
	for k in range(maxi(1,n-1),mini(shortcut.size()-1,n+12)):
		var before: Vector3=(shortcut[k]-shortcut[k-1])*Vector3(1,0,1)
		var after: Vector3=(shortcut[k+1]-shortcut[k])*Vector3(1,0,1)
		var curvature: float=before.angle_to(after)/maxf((before.length()+after.length())*.5,.01)
		if curvature>.001: limit=minf(limit,yaw_rate*.72/curvature)
	return maxf(limit,2.5)

static func driving_surface_material() -> PhysicsMaterial:
	# Rolling resistance belongs to the tire controller. A sliding-box ground
	# material would also resist yaw and prevent the steering motor from turning.
	var surface: PhysicsMaterial=PhysicsMaterial.new()
	surface.friction=.02
	return surface

func closest_index(p: Vector3) -> int:
	var best: int = 0
	var best_distance: float = INF
	for i in range(centers.size()):
		var d: float = Vector2(p.x - centers[i].x, p.z - centers[i].z).length_squared()
		if d < best_distance:
			best_distance = d
			best = i
	return best

func right_at(i: int) -> Vector3:
	return tangents[posmod(i, SAMPLES)].cross(Vector3.UP).normalized()

func gate_index(gate: int) -> int:
	return posmod(gate, GATE_COUNT) * (SAMPLES / GATE_COUNT)

func spawn_transform(slot: int, gate: int = 0) -> Transform3D:
	var i: int = posmod(gate_index(gate) - 5 - (slot / 2) * 5, SAMPLES)
	var p: Vector3 = centers[i] + right_at(i) * (-2.5 if slot % 2 == 0 else 2.5) + Vector3.UP * 1.2
	var yaw: float = atan2(-tangents[i].x, -tangents[i].z)
	return Transform3D(Basis(Vector3.UP, yaw), p)

func crossed_gate(previous: Vector3, current: Vector3, gate: int) -> bool:
	var i: int = gate_index(gate)
	var direction: Vector3 = Vector3(tangents[i].x, 0, tangents[i].z).normalized()
	var before: float = (previous - centers[i]).dot(direction)
	var after: float = (current - centers[i]).dot(direction)
	if before >= 0.0 or after < 0.0:
		return false
	var crossing: Vector3 = previous.lerp(current, -before / maxf(after - before, 0.0001))
	return absf((crossing - centers[i]).dot(right_at(i))) < half_width_at(i) + 1.4 and absf(crossing.y - centers[i].y) < 4.0

static func material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _strip(left: float, right: float, height: float, color: Color, collision: bool = false, mat: Material = null,first: int=0,last: int=SAMPLES) -> MeshInstance3D:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance: float = 0
	for i in range(first,last):
		var j: int = (i + 1) % SAMPLES
		var left_i: float=edge_offset(i,left)
		var right_i: float=edge_offset(i,right)
		var left_j: float=edge_offset(j,left)
		var right_j: float=edge_offset(j,right)
		var a: Vector3 = centers[i] + right_at(i) * left_i + Vector3.UP * height
		var b: Vector3 = centers[i] + right_at(i) * right_i + Vector3.UP * height
		var c: Vector3 = centers[j] + right_at(j) * left_j + Vector3.UP * height
		var d: Vector3 = centers[j] + right_at(j) * right_j + Vector3.UP * height
		# Godot treats clockwise triangles as front faces; the road faces up.
		var step: float = centers[i].distance_to(centers[j])
		var vertices: Array[Vector3] = [a,b,c,d]
		var uv: Array[Vector2] = [Vector2(left_i/3,distance/3),Vector2(right_i/3,distance/3),Vector2(left_j/3,(distance+step)/3),Vector2(right_j/3,(distance+step)/3)]
		var data: Array[Vector2]=[Vector2(i,left_i/half_width_at(i)),Vector2(i,right_i/half_width_at(i)),Vector2(i+1,left_j/half_width_at(j)),Vector2(i+1,right_j/half_width_at(j))]
		for k in [0,2,1,1,2,3]:
			surface.set_uv(uv[k])
			surface.set_uv2(data[k])
			surface.add_vertex(vertices[k])
		distance += step
	surface.generate_normals()
	surface.generate_tangents()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = mat if mat != null else material(color)
	add_child(instance)
	if collision:
		instance.create_trimesh_collision()
		var body: StaticBody3D=instance.get_child(0)
		body.physics_material_override=driving_surface_material()
	return instance

func curb_basis(i: int) -> Basis:
	var right: Vector3=right_at(i)
	var up: Vector3=right.cross(tangents[i]).normalized()
	return Basis(right,up,-tangents[i]*centers[i].distance_to(centers[(i+3)%SAMPLES]))

func _build_road() -> void:
	_strip(-HALF_WIDTH, HALF_WIDTH, 0.0, Color.WHITE, true, IRArt.road())
	_strip(-HALF_WIDTH-1.0,-HALF_WIDTH,-.02,Color.WHITE,true,IRArt.road())
	_strip(HALF_WIDTH,HALF_WIDTH+1.0,-.02,Color.WHITE,true,IRArt.road())
	for section in [Vector2i(5,21),Vector2i(33,72)]:
		_strip(-HALF_WIDTH-2.35,-HALF_WIDTH-1.02,.08,Color("c7c1b1"),true,null,section.x,section.y)
		_strip(HALF_WIDTH+1.02,HALF_WIDTH+2.35,.08,Color("c7c1b1"),true,null,section.x,section.y)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var curb_mesh: BoxMesh = BoxMesh.new()
	curb_mesh.size = Vector3(.58,.15,1.0)
	var curb_mat: StandardMaterial3D = StandardMaterial3D.new()
	curb_mat.vertex_color_use_as_albedo = true
	curb_mat.roughness = .72
	for i in range(0,SAMPLES,3):
		if i>3 and i<170:
			continue
		var j: int = (i+3)%SAMPLES
		var r: Vector3 = right_at(i)
		var up: Vector3 = r.cross(tangents[i]).normalized()
		var basis: Basis = curb_basis(i)
		for side in [-1.0,1.0]:
			transforms.append(Transform3D(basis,centers[i].lerp(centers[j],.5)+r*side*((half_width_at(i)+half_width_at(j))*.5+.42)+up*.04))
			colors.append(Color("ded2b7") if (i/3)%2 == 0 else Color("c9bba6"))
	IRArt.scatter(self,curb_mesh,curb_mat,transforms,colors,300)
	var grid: Node3D = Node3D.new()
	add_child(grid)
	grid.transform = Transform3D(Basis(Vector3.UP,atan2(-tangents[0].x,-tangents[0].z)),centers[0])
	for x in range(14):
		for z in range(2):
			IRArt.block(grid,Vector3(.92,.025,.85),Vector3(x-6.5,.028,(z-.5)*.9),IRArt.pbr(Color("f3e4c0") if (x+z)%2 == 0 else Color("234f54"),.7))
	IRArt.bake(grid)

func _build_shortcut() -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance: float=0
	for n in range(shortcut.size()-1):
		var forward: Vector3=(shortcut[n+1]-shortcut[n]).normalized()
		var right: Vector3=forward.cross(Vector3.UP).normalized()
		var step: float=shortcut[n].distance_to(shortcut[n+1])
		var points: Array[Vector3]=[shortcut[n]-right*SHORTCUT_WIDTH,shortcut[n]+right*SHORTCUT_WIDTH,shortcut[n+1]-right*SHORTCUT_WIDTH,shortcut[n+1]+right*SHORTCUT_WIDTH]
		for k in [0,2,1,1,2,3]:
			st.set_uv(Vector2((-SHORTCUT_WIDTH if k%2==0 else SHORTCUT_WIDTH)/3,(distance+(step if k>1 else 0))/3))
			st.set_uv2(Vector2(105,(-1 if k%2==0 else 1)))
			st.add_vertex(points[k]+Vector3.UP*.035)
		distance+=step
	st.generate_normals()
	var road: MeshInstance3D=IRArt.part(self,st.commit(),Vector3.ZERO,IRArt.road())
	road.name="GrottoShortcut"
	road.create_trimesh_collision()
	var body: StaticBody3D=road.get_child(0)
	body.physics_material_override=driving_surface_material()
