class_name IRTeaBend
extends Node3D
## Authored focal district. Startup geometry only; all visual motion is on the GPU.
var world: IRFairytaleWorld
var frame: Transform3D
var static_root: Node3D
var effects: Array[GPUParticles3D]=[]
var tree_node: MeshInstance3D
var house_node: MeshInstance3D
var stream_node: MeshInstance3D
var sign_node: MeshInstance3D
var random: RandomNumberGenerator=RandomNumberGenerator.new()

func _init(island: IRFairytaleWorld) -> void:
	world=island

func _ready() -> void:
	name="TeahouseBend"
	add_to_group("tea_bend")
	frame=IRTeaBendLayout.pose(world.track)
	transform=frame
	random.seed=100424
	static_root=Node3D.new()
	add_child(static_root)
	house_node=asset("teahouse",IRTeaBendLayout.HOUSE,PI*.5)
	house_node.name="Teahouse"
	tree_node=asset("ancient_oak",IRTeaBendLayout.TREE,-.18)
	tree_node.name="AncientOak"
	tree_node.extra_cull_margin=.35
	asset("tea_garden",Vector3(-12.2,-.45,10.1),PI*.5)
	sign_node=asset("teapot_sign",IRTeaBendLayout.HOUSE+Vector3(4.6,5.1,-3.25),PI*.5)
	sign_node.name="SwingingTeapot"
	sign_node.material_override=IRArt.shader("tea_sign")
	sign_node.extra_cull_margin=.10
	world.landmarks["tea_hero"]=frame*house_node.transform
	world.landmarks["tea_oak"]=frame*tree_node.transform
	world.building_footprints.append({"inverse":(frame*house_node.transform).affine_inverse(),"min":Vector2(-4.4,-3.9),"max":Vector2(4.7,4.9)})
	for local in [IRTeaBendLayout.TREE,Vector3(-12.2,0,10.1)]:
		var p: Vector3=frame*local
		world.prop_clearances.append({"center":Vector2(p.x,p.z),"radius":5.8})
	_stream()
	_bridge()
	_retaining_wall()
	_gardens()
	var solid_garden: MeshInstance3D=IRArt.bake(static_root)
	world.collisions.add_visual("tea_bridge_banks_garden",solid_garden,true)
	_effects()
	set_meta("gpu_visual_motion",true)

func asset(key: String,p: Vector3,yaw: float=0) -> MeshInstance3D:
	var mesh: ArrayMesh=load("res://assets/tea_bend/"+key+".res")
	var node: MeshInstance3D=IRArt.part(self,mesh,p,null)
	node.rotation.y=yaw
	node.visibility_range_end=175
	node.visibility_range_end_margin=15
	if key in ["teahouse","ancient_oak","tea_garden"]:
		world.collisions.add_visual(key,node)
	return node

func material(hex: String,kind: int=0) -> StandardMaterial3D:
	var result: StandardMaterial3D=StandardMaterial3D.new()
	result.albedo_color=Color(hex)
	result.roughness=.90
	result.set_meta("palette_kind",kind)
	return result

func block(size: Vector3,p: Vector3,mat: Material,yaw: float=0,bevel: float=.07) -> MeshInstance3D:
	var node: MeshInstance3D=IRTeaGeometry.rounded_box(static_root,size,p,mat,bevel)
	node.rotation.y=yaw
	return node

func stream_point(x: float,lateral: float) -> Vector3:
	return Vector3(x,IRTeaBendLayout.water_y(x),IRTeaBendLayout.stream_z(x)+lateral*IRTeaBendLayout.stream_half_width(x))

func bank_height(x: float,distance: float,side: float) -> float:
	var half_width: float=IRTeaBendLayout.stream_half_width(x)
	var edge: Vector3=frame*Vector3(x,0,IRTeaBendLayout.stream_z(x)+side*(half_width+4.4))
	var height: float=world.terrain.surface_height(edge)-frame.origin.y+.025
	var t: float=smoothstep(half_width,half_width+4.4,distance)
	var analytic: float=lerpf(IRTeaBendLayout.water_y(x)-.06,height,t)
	var actual: Vector3=frame*Vector3(x,0,IRTeaBendLayout.stream_z(x)+side*distance)
	return maxf(analytic,world.terrain.surface_height(actual)-frame.origin.y+.04)

func _stream() -> void:
	var water: SurfaceTool=SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank: SurfaceTool=SurfaceTool.new()
	bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(152):
		var x0: float=-36+n*.48
		var x1: float=x0+.48
		for side in range(6):
			var a: float=-1+side/3.0
			var b: float=-1+(side+1)/3.0
			var points: Array[Vector3]=[stream_point(x0,a),stream_point(x0,b),stream_point(x1,a),stream_point(x1,b)]
			var uv: Array[Vector2]=[Vector2(x0,a),Vector2(x0,b),Vector2(x1,a),Vector2(x1,b)]
			for k in [0,2,1,1,2,3]:
				water.set_uv(uv[k])
				var slope: float=(IRTeaBendLayout.water_y(points[k].x+.01)-IRTeaBendLayout.water_y(points[k].x-.01))/.02
				water.set_normal(Vector3(-slope,1,0).normalized())
				water.add_vertex(points[k])
		for side in [-1.0,1.0]:
			for strip in range(9):
				var points: Array[Vector3]=[]
				for x in [x0,x1]:
					for ring in [strip,strip+1]:
						var distance: float=IRTeaBendLayout.stream_half_width(x)+ring*(4.4/9.0)
						var p: Vector3=Vector3(x,0,IRTeaBendLayout.stream_z(x)+side*distance)
						p.y=bank_height(x,distance,side)
						points.append(p)
				for k in ([0,2,1,1,2,3] if side>0 else [0,1,2,2,1,3]):
					bank.set_uv(Vector2(points[k].x*.3,points[k].z*.3))
					bank.add_vertex(points[k])
	water.index()
	stream_node=IRArt.part(self,water.commit(),Vector3.ZERO,IRArt.shader("tea_stream"))
	stream_node.name="LivingStream"
	stream_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stream_node.visibility_range_end=140
	stream_node.extra_cull_margin=.04
	bank.index()
	bank.generate_normals()
	var bank_material: ShaderMaterial=IRArt.shader("tea_bank")
	bank_material.set_shader_parameter("grass_tex",load("res://assets/textures/meadow_painted_v3.png"))
	IRArt.part(static_root,bank.commit(),Vector3.ZERO,bank_material)
	# Exclude all ordinary flowers, trees and walking paths from the watercourse.
	for n in range(37):
		var x0: float=-36+n*2.0
		var a: Vector3=frame*stream_point(x0,0)
		var b: Vector3=frame*stream_point(x0+2,0)
		world.path_corridors.append({"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"radius":IRTeaBendLayout.stream_half_width(x0)+3.8})

func _bridge() -> void:
	var stone: Material=material("bcb398",1)
	var cap: Material=material("d4c8a7",1)
	var inverse: Transform3D=frame.affine_inverse()
	for i in range(21,32):
		var j: int=i+1
		var f: Vector3=(world.track.centers[j]-world.track.centers[i]).normalized()
		var yaw: float=atan2(-f.x,-f.z)-frame.basis.get_euler().y
		var length: float=world.track.centers[i].distance_to(world.track.centers[j])
		for side in [-1.0,1.0]:
			var a: Vector3=world.track.centers[i]+world.track.right_at(i)*side*(world.track.half_width_at(i)+.72)
			var b: Vector3=world.track.centers[j]+world.track.right_at(j)*side*(world.track.half_width_at(j)+.72)
			var p: Vector3=inverse*((a+b)*.5)
			var h: float=.60+.12*sin((i-21)/11.0*PI)
			block(Vector3(.54,h,length+.035),p+Vector3.UP*(h*.5-.04),stone,yaw,.09)
			block(Vector3(.76,.18,length+.10),p+Vector3.UP*(h+.04),cap,yaw,.075)
			# A shaded side wall follows the arched opening above the stream.
			var distance: float=absf(p.z-IRTeaBendLayout.stream_z(p.x))
			var arch: float=sqrt(maxf(0,1-pow(distance/4.65,2)))
			var bottom: float=IRTeaBendLayout.water_y(p.x)-.35+1.6*arch
			var top: float=p.y-.05
			if top>bottom:
				block(Vector3(.65,top-bottom,length+.03),Vector3(p.x,(top+bottom)*.5,p.z),stone,yaw,.06)
			var arch_position: Vector3=Vector3(p.x,bottom,p.z)
			var voussoir: MeshInstance3D=block(Vector3(.80,.24,length*.95),arch_position,cap,yaw,.065)
			voussoir.rotation.x=clampf(signf(p.z-IRTeaBendLayout.stream_z(p.x))*distance*.085,-.45,.45)
	# Post caps and curved newel finials make the bridge legible while driving.
	for i in [21,32]:
		for side in [-1.0,1.0]:
			var p: Vector3=inverse*(world.track.centers[i]+world.track.right_at(i)*side*(world.track.half_width_at(i)+.72))
			block(Vector3(.85,1.05,.85),p+Vector3.UP*.45,stone,0,.13)
			block(Vector3(1.01,.18,1.01),p+Vector3.UP*1.05,cap,0,.09)
			var ball: MeshInstance3D=IRArt.ellipsoid(static_root,Vector3(.30,.40,.30),p+Vector3.UP*1.32,cap)
			ball.rotation.y=.3

func _retaining_wall() -> void:
	var stone: Material=material("a49b7c",1)
	var cap: Material=material("c6bb97",1)
	for n in range(14):
		var x: float=-21.0+n*.85
		var z: float=IRTeaBendLayout.stream_z(x)+3.0
		for row in range(3):
			block(Vector3(.81,.37,.50),Vector3(x+(row%2)*.20,-1.35+row*.35,z),stone,.03*sin(n),.09)
		block(Vector3(.90,.17,.67),Vector3(x,-.34,z),cap,0,.06)
	# An intimate pedestrian crossing links the terrace to the old oak.
	var wood: Material=material("85765a",21)
	var p: Vector3=Vector3(-20.5,-.38,IRTeaBendLayout.stream_z(-20.5))
	for n in range(17):
		block(Vector3(2.1,.13,.26),p+Vector3(0,.20*sin(n*PI/16),-2.15+n*.27),wood,.025*sin(n),.04)
	for side in [-1.0,1.0]:
		var last: Vector3=Vector3.ZERO
		for n in range(9):
			var foot: Vector3=p+Vector3(side*1.1,.20*sin(n*PI/8),-2.2+n*.55)
			var top: Vector3=foot+Vector3.UP*.88
			IRArt.tube(static_root,foot,top,.035,wood)
			if n>0: IRArt.tube(static_root,last,top,.05,wood)
			last=top

func _gardens() -> void:
	var stone: Material=material("b8b08c",1)
	# Hand-placed stepping stones lead through the garden with an open walking corridor.
	for n in range(15):
		var t: float=n/14.0
		var p: Vector3=Vector3(lerpf(-7.2,-21.0,t),0,lerpf(10.5,1.8,t)+sin(t*PI)*2)
		p.y=world.terrain.surface_height(frame*p)-frame.origin.y+.08
		block(Vector3(.68,.13,.54),p,stone,sin(n*1.6)*.30,.12)
	# Patches have varied sizes and species, clustered at walls and bank turns.
	var flower_groups: Dictionary={}
	for n in range(88):
		var x: float=random.randf_range(-30,16)
		var side: float=-1 if n%2 else 1
		var z: float=IRTeaBendLayout.stream_z(x)+side*(IRTeaBendLayout.stream_half_width(x)+random.randf_range(1.4,3.3))
		var p: Vector3=frame*Vector3(x,0,z)
		if not world.clear_of_road(p,1.8) or world.inside_building(p,.7) or world.near_prop(p,.5): continue
		var species: String=["flowers_lavender","flowers_daisy","flowers_rose","fern","giant_fern"][n%5]
		if not flower_groups.has(species): flower_groups[species]=[]
		var local: Vector3=frame.affine_inverse()*p
		local.y=bank_height(local.x,absf(local.z-IRTeaBendLayout.stream_z(local.x)),side)+.015
		flower_groups[species].append(Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*random.randf_range(.65,1.05)),local))
	for species in flower_groups:
		var poses: Array[Transform3D]=[]
		poses.assign(flower_groups[species])
		IRArt.scatter(self,world.meshes[species],null,poses,[],75,false)
	for n in range(24):
		var x: float=-29+n*2.2
		var p: Vector3=stream_point(x,-1 if n%2 else 1)
		p.z+=(-1 if n%2 else 1)*.45
		if world.clear_of_road(frame*p,1.9):
			block(Vector3(.65+random.randf()*.60,.4+random.randf()*.3,.55+random.randf()*.45),p,stone,random.randf()*TAU,.18)
	for n in range(6):
		var x: float=-29+n*3
		var p: Vector3=stream_point(x,random.randf_range(-.65,.65))
		world.place("water_lily",frame*(p+Vector3.UP*.035),n*.9,.65,Color.WHITE,false)
	world.place("moss_boulder",frame*(stream_point(36,0)+Vector3.UP*.85),.4,1.85,Color.WHITE,false)
	# A small square around the roots is visible between the teahouse and water.
	for n in range(6):
		var a: float=.20+n*TAU/6
		var p: Vector3=IRTeaBendLayout.TREE+Vector3(cos(a)*3.8,.13,sin(a)*3.8)
		var base: Vector3=frame*p
		if world.clear_of_road(base,3.0): world.place("lantern_mushroom",base,n,.45,Color.WHITE,false)
	# Conservative occlusion remains fully inside the new house walls.
	world._box_occluder(frame*(IRTeaBendLayout.HOUSE+Vector3(0,3.2,0)),frame.basis.get_euler().y+PI*.5,Vector3(5.9,5.3,3.8))

func particles(p: Vector3,amount: int,life: float,box_size: Vector3,velocity: Vector2,scale: Vector2,shader: String,quad_size: Vector2,gravity: Vector3) -> GPUParticles3D:
	var node: GPUParticles3D=GPUParticles3D.new()
	node.position=p
	node.amount=amount
	node.lifetime=life
	node.preprocess=minf(life,3.0)
	node.visibility_aabb=AABB(-box_size-Vector3(2,1,2),box_size*2+Vector3(4,8,4))
	node.visibility_range_end=65
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=box_size
	process.direction=Vector3.UP
	process.spread=30
	process.gravity=gravity
	process.initial_velocity_min=velocity.x
	process.initial_velocity_max=velocity.y
	process.scale_min=scale.x
	process.scale_max=scale.y
	process.angular_velocity_min=-25
	process.angular_velocity_max=25
	var fade: Gradient=Gradient.new()
	fade.offsets=PackedFloat32Array([0,.15,.70,1])
	fade.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.65),Color(1,1,1,.3),Color(1,1,1,0)])
	var ramp: GradientTexture1D=GradientTexture1D.new()
	ramp.gradient=fade
	process.color_ramp=ramp
	node.process_material=process
	var quad: QuadMesh=QuadMesh.new()
	quad.size=quad_size
	quad.material=IRArt.shader(shader)
	node.draw_pass_1=quad
	add_child(node)
	effects.append(node)
	return node

func _effects() -> void:
	if DisplayServer.get_name()=="headless": return
	particles(Vector3(-12.05,.90,8.3),12,2.6,Vector3(.06,.015,.06),Vector2(.28,.38),Vector2(.35,.65),"tea_steam",Vector2(.33,.33),Vector3(.04,.12,0))
	particles(IRTeaBendLayout.HOUSE+Vector3(-1.3,11.5,2.0),18,4.8,Vector3(.13,.05,.13),Vector2(.35,.55),Vector2(.7,1.6),"tea_steam",Vector2(.60,.60),Vector3(.06,.06,.02))
	particles(IRTeaBendLayout.TREE+Vector3(1,5,1),24,8.5,Vector3(5,1.1,4),Vector2(.04,.12),Vector2(.35,.7),"leaf_wake",Vector2(.13,.23),Vector3(.04,-.045,.02))
	particles(IRTeaBendLayout.TREE+Vector3(2,1.7,1),18,6.0,Vector3(5,.7,4),Vector2(.04,.13),Vector2(.55,1.1),"forest_mote",Vector2(.08,.08),Vector3.ZERO)

func apply_quality(profile: int) -> void:
	profile=clampi(profile,0,2)
	house_node.lod_bias=[1.25,.85,.55][profile]
	tree_node.lod_bias=[1.05,.65,.35][profile]
	for i in range(effects.size()):
		var amount: int=[12,18,24,18][i]
		effects[i].amount=maxi(5,roundi(amount*[1.0,.75,.45][profile]))
		effects[i].visibility_range_end=[65,55,42][profile]
