class_name IRVehicleArt
extends Node3D
## Original ceramic-and-cedar wind racers. Static pieces are merged by material.

var wheels: Array[Node3D] = []
var steering: Array[Node3D] = []
var fan: Node3D
var driver: IRDriverArt
static var wheel_template: Mesh
static var fan_template: Mesh

func _init(variant: int = 0, color: Color = Color("ea7950"), number: int = 1,character: int=0) -> void:
	var body: Node3D = Node3D.new()
	add_child(body)
	var wood: Material = IRArt.timber()
	var paint: Material = IRArt.pbr(color, .31, .08)
	var cream: Material = IRArt.pbr(Color("eadab5"), .43)
	var brass: Material = IRArt.pbr(Color("bd8d4e"), .30, .72)
	var leather: Material = IRArt.pbr(Color("453b33"), .83)
	IRArt.loft(body, [Vector3(.03,.03,-1.65),Vector3(.67,.28,-1.35),Vector3(.87,.35,-.65),Vector3(.89,.32,.8),Vector3(.65,.22,1.42),Vector3(.03,.03,1.6)], .68, wood)
	IRArt.loft(body, [Vector3(.04,.03,-1.6),Vector3(.63,.18,-1.29),Vector3(.84,.24,-.76),Vector3(.83,.17,-.30),Vector3(.45,.10,-.21)], 1.02, paint)
	IRArt.loft(body, [Vector3(.6,.12,.65),Vector3(.86,.25,1.0),Vector3(.67,.22,1.4),Vector3(.03,.03,1.57)], .95, paint)
	IRArt.ellipsoid(body, Vector3(.95,.26,.80), Vector3(0,1.02,.14), leather)
	var seat: MeshInstance3D = IRArt.ellipsoid(body, Vector3(1.0,.79,.24), Vector3(0,1.33,.59), leather)
	seat.rotation.x = -.15
	for side in [-1.0,1.0]:
		IRArt.tube(body, Vector3(side*.91,.89,-1.1),Vector3(side*.91,.99,1.0),.055,brass)
		IRArt.tube(body, Vector3(side*.7,.49,-.9),Vector3(side*.9,.72,-.3),.055,brass)
		IRArt.ellipsoid(body,Vector3(.28,.17,2.3),Vector3(side*.86,.98,.08),cream)
		for z in [-1.0,-.6,-.2,.6,1.0]:
			IRArt.ellipsoid(body,Vector3(.055,.028,.055),Vector3(side*.86,1.07,z),brass)
		IRArt.ellipsoid(body,Vector3(.25,.17,.11),Vector3(side*.46,1.04,-1.38),brass)
		IRArt.ellipsoid(body,Vector3(.19,.11,.06),Vector3(side*.46,1.04,-1.44),IRArt.pbr(Color("fff2d0"),.13,.05))
		for z in [-.9,.95]:
			IRArt.tube(body,Vector3(side*.5,.65,z),Vector3(side*1.04,.44,z),.085,brass)
			var pivot: Node3D = Node3D.new()
			pivot.position = Vector3(side*1.0,.46,z)
			add_child(pivot)
			if z < 0:
				steering.append(pivot)
			var wheel: Node3D = Node3D.new()
			pivot.add_child(wheel)
			_wheel_model(wheel,wood,brass)
			wheels.append(wheel)
	IRArt.tube(body,Vector3(0,1.09,-.52),Vector3(0,1.47,-.40),.045,brass)
	var handle: MeshInstance3D = IRArt.ring(body,.23,.025,Vector3(0,1.49,-.41),leather)
	handle.rotation.x = .55
	IRArt.bake(body,true)
	fan = Node3D.new()
	fan.position = Vector3(0,1.34,1.56)
	add_child(fan)
	_fan_model(fan,brass)
	if variant == 0:
		_sail(wood,brass)
	else:
		var housing: Node3D = Node3D.new()
		add_child(housing)
		var cage: MeshInstance3D = IRArt.ring(housing,.65,.07,Vector3(0,1.34,1.52),cream)
		cage.rotation.x = PI/2
		IRArt.tube(housing,Vector3(-.66,.94,1.2),Vector3(-.66,1.6,1.52),.05,brass)
		IRArt.tube(housing,Vector3(.66,.94,1.2),Vector3(.66,1.6,1.52),.05,brass)
		IRArt.bake(housing,true)
	driver = IRDriverArt.new(color.lightened(.16),character)
	driver.position = Vector3(0,1.39,.05)
	driver.scale = Vector3.ONE*.85
	add_child(driver)
	var badge: Node3D=Node3D.new()
	add_child(badge)
	var text: TextMesh=TextMesh.new()
	text.font=preload("res://assets/fonts/Barlow-Medium.ttf")
	text.text="%02d" % number
	text.font_size=64
	text.pixel_size=.008
	text.depth=.001
	var tag: MeshInstance3D=IRArt.part(badge,text,Vector3.ZERO,IRArt.pbr(Color("fff1cf"),.6))
	tag.position = Vector3(0,1.267,-.88)
	tag.basis = Basis(Vector3.RIGHT,-PI/2)*Basis(Vector3.BACK,PI)
	IRArt.bake(badge,true)

func _ready() -> void:
	var actor: IRVehicle=get_parent() as IRVehicle
	if actor==null:
		return
	for item in find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D=item
		var pose: Transform3D=global_transform.affine_inverse()*mesh.global_transform
		mesh.set_instance_shader_parameter("ir_motion_slot",actor.slot)
		mesh.set_instance_shader_parameter("ir_root_row0",Vector4(pose.basis.x.x,pose.basis.y.x,pose.basis.z.x,pose.origin.x))
		mesh.set_instance_shader_parameter("ir_root_row1",Vector4(pose.basis.x.y,pose.basis.y.y,pose.basis.z.y,pose.origin.y))
		mesh.set_instance_shader_parameter("ir_root_row2",Vector4(pose.basis.x.z,pose.basis.y.z,pose.basis.z.z,pose.origin.z))
		var inverse: Basis=pose.basis.inverse()
		mesh.set_instance_shader_parameter("ir_inverse_x",inverse.x)
		mesh.set_instance_shader_parameter("ir_inverse_y",inverse.y)
		mesh.set_instance_shader_parameter("ir_inverse_z",inverse.z)
		var part: int=0
		if fan.is_ancestor_of(mesh):
			part=3
		for i in range(wheels.size()):
			if wheels[i].is_ancestor_of(mesh):
				part=1 if steering.has(wheels[i].get_parent()) else 2
		mesh.set_instance_shader_parameter("ir_motion_part",part)
		# Culling sees the complete range of GPU body, wheel and joint deformation.
		mesh.custom_aabb=mesh.mesh.get_aabb().grow(3.0)

func _wheel_model(wheel: Node3D, wood: Material, brass: Material) -> void:
	if wheel_template!=null:
		IRArt.part(wheel,wheel_template,Vector3.ZERO,null)
		return
	var tire: MeshInstance3D=IRArt.ring(wheel,.35,.12,Vector3.ZERO,IRArt.shader("rubber"))
	tire.rotation.z=PI/2
	var rim: MeshInstance3D=IRArt.ring(wheel,.245,.04,Vector3.ZERO,wood)
	rim.rotation.z=PI/2
	IRArt.tube(wheel,Vector3(-.16,0,0),Vector3(.16,0,0),.10,brass)
	for spoke in range(6):
		var a: float=spoke*TAU/6
		IRArt.tube(wheel,Vector3.ZERO,Vector3(0,sin(a)*.25,cos(a)*.25),.027,brass)
	wheel_template=IRArt.bake(wheel,true).mesh

func _fan_model(node: Node3D, brass: Material) -> void:
	if fan_template!=null:
		IRArt.part(node,fan_template,Vector3.ZERO,null)
		return
	for i in range(3):
		var a: float=i*TAU/3
		var blade: MeshInstance3D=IRArt.ellipsoid(node,Vector3(.16,.87,.08),Vector3(sin(a),cos(a),0)*.29,brass)
		blade.rotation.z=-a
	IRArt.ellipsoid(node,Vector3(.19,.19,.20),Vector3.ZERO,brass)
	fan_template=IRArt.bake(node,true).mesh

func _sail(wood: Material, brass: Material) -> void:
	var rig: Node3D=Node3D.new()
	rig.position=Vector3(1.08,-.15,0)
	add_child(rig)
	IRArt.tube(rig,Vector3(0,1.1,.98),Vector3(0,3.5,.98),.047,wood,.026)
	IRArt.tube(rig,Vector3(-.50,1.89,.98),Vector3(.50,1.89,.98),.027,brass)
	IRArt.tube(rig,Vector3(-.65,1.10,.98),Vector3(0,1.1,.98),.035,brass)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(14):
		for x in range(12):
			for offset in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var uv: Vector2 = Vector2(float(x+offset.x)/12,float(y+offset.y)/14)
				var half: float = lerpf(.52,.07,pow(uv.y,1.8))
				st.set_uv(uv)
				st.add_vertex(Vector3((uv.x-.5)*half*2,1.9+uv.y*1.52,.98+sin(uv.x*PI)*sin(uv.y*PI)*.24))
	st.generate_normals()
	var mat: ShaderMaterial = IRArt.shader("sail")
	mat.set_shader_parameter("albedo_tex",IRArt.textured("linen").albedo_texture)
	IRArt.part(rig,st.commit(),Vector3.ZERO,mat)
