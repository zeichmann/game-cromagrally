extends RefCounted
## Reproducible, offline model authoring. Runtime loads compressed meshes with baked LODs.

var mats: Dictionary = {}
var report: Dictionary = {}
var botanicals: RefCounted=preload("res://tools/botanical_builder.gd").new()
var architecture: RefCounted=preload("res://tools/architecture_builder.gd").new()
var sky_art: RefCounted=preload("res://tools/sky_asset_builder.gd").new()
var enchanted: RefCounted=preload("res://tools/enchanted_builder.gd").new()
var living: RefCounted=preload("res://tools/living_asset_builder.gd").new()
var residents: RefCounted=preload("res://tools/portrait_resident_builder.gd").new()

func paint(name: String, color: String, roughness: float = .78, metal: float = 0.0) -> Material:
	if not mats.has(name):
		mats[name] = IRArt.pbr(Color(color),roughness,metal)
		if name=="glass":
			mats[name].set_meta("palette_kind",4)
		elif name.begins_with("wall"):
			mats[name].set_meta("palette_kind",20)
		elif name=="fountain_water":
			mats[name].set_meta("palette_kind",26)
		elif name.begins_with("planter"):
			mats[name].set_meta("palette_kind",21)
	return mats[name]

func textured(name: String, file: String, color: String, scale_uv: float = 1.0) -> Material:
	if not mats.has(name):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader=load("res://shaders/storybook_surface.gdshader")
		mat.set_shader_parameter("albedo_tex",load("res://assets/textures/"+file+".png"))
		mat.set_shader_parameter("tint",Color(color))
		mat.set_shader_parameter("texture_scale",scale_uv)
		mats[name]=mat
	return mats[name]

func stone() -> Material:
	return textured("limestone","fairy_masonry","fff6df",2.0)

func trim() -> Material:
	return paint("ivory","fff1d2",.67)

func foliage(kind: String) -> Material:
	if not mats.has(kind):
		var mat: ShaderMaterial=ShaderMaterial.new()
		mat.shader=load("res://shaders/fairytale_canopy.gdshader")
		var colors: Dictionary={"oak":"608d32","willow":"719844","blossom":"ed94af","hedge":"487d38"}
		mat.set_shader_parameter("tint",Color(colors[kind]))
		mat.set_shader_parameter("leaf_tex",load("res://assets/textures/storybook_"+("blossom" if kind=="blossom" else "oak")+"_spray.png"))
		mats[kind]=mat
	return mats[kind]

func ball(root: Node3D, pos: Vector3, size: Vector3, material: Material, seed_value: float = 0.0) -> void:
	var sphere: SphereMesh=SphereMesh.new()
	sphere.radius=.5
	sphere.height=1.0
	sphere.radial_segments=18
	sphere.rings=10
	var arrays: Array=sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var p: Vector3=vertices[i]
		vertices[i]=p*(1.0+sin(p.x*19.0+seed_value)*sin(p.y*17.0+p.z*13.0)*.065)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh: ArrayMesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var part: MeshInstance3D=IRArt.part(root,mesh,pos,material)
	part.scale=size

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_scale: Vector2 = Vector2.ONE, uv_offset: Vector2 = Vector2.ZERO, swap_uv: bool = false) -> void:
	var points: Array[Vector3]=[a,b,c,d]
	var uvs: Array[Vector2]=[Vector2.ZERO,Vector2(0,uv_scale.y),Vector2(uv_scale.x,0),uv_scale]
	var normal: Vector3=(c-a).cross(b-a).normalized()
	for i in [0,1,2,2,1,3]:
		st.set_normal(normal)
		var uv: Vector2=uvs[i]+uv_offset
		st.set_uv(Vector2(uv.y,uv.x) if swap_uv else uv)
		st.add_vertex(points[i])

func panel(root: Node3D, center: Vector3, width: float, height: float, material: Material) -> void:
	# Clockwise arched silhouette in its front (+Z) plane.
	var points: Array[Vector3]=[Vector3(-width*.5,0,0)]
	var radius: float=width*.5
	for i in range(17):
		var a: float=PI-PI*i/16.0
		points.append(Vector3(cos(a)*radius,height-radius+sin(a)*radius,0))
	points.append(Vector3(width*.5,0,0))
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		for p in [Vector3(0,height*.45,0),points[i],points[(i+1)%points.size()]]:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(p.x/width+.5,1.0-p.y/height))
			st.add_vertex(p)
	IRArt.part(root,st.commit(),center,material)

func window(root: Node3D, center: Vector3, width: float = 1.1, height: float = 1.65) -> void:
	panel(root,center,width+.24,height+.18,trim())
	panel(root,center+Vector3(.0,.10,.025),width,height-.10,paint("glass","557d93",.26))
	IRArt.block(root,Vector3(.075,height-.10,.075),center+Vector3(0,height*.48,.07),trim())
	IRArt.block(root,Vector3(width,.065,.075),center+Vector3(0,height*.56,.07),trim())
	IRArt.block(root,Vector3(width+.45,.15,.32),center+Vector3(0,.02,.10),stone())

func lathe(root: Node3D, profile: Array[Vector2], position: Vector3, material: Material, segments: int = 32) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(profile.size()-1):
		for i in range(segments):
			var a: float=TAU*i/segments
			var b: float=TAU*(i+1)/segments
			var p: Vector2=profile[j]
			var q: Vector2=profile[j+1]
			quad(st,Vector3(cos(a)*p.x,p.y,sin(a)*p.x),Vector3(cos(b)*p.x,p.y,sin(b)*p.x),Vector3(cos(a)*q.x,q.y,sin(a)*q.x),Vector3(cos(b)*q.x,q.y,sin(b)*q.x),Vector2((q.y-p.y)*.4,1.0/segments*5.0),Vector2(p.y*.4,i/float(segments)*5.0),true)
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),position,material)

func roof(root: Node3D, half_width: float, depth: float, eaves: float, rise: float, material: Material) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for j in range(14):
			var t: float=j/14.0
			var u: float=(j+1)/14.0
			var a: Vector3=Vector3(side*half_width*t,eaves+rise*pow(1-t,1.3),-depth*.5)
			var b: Vector3=Vector3(side*half_width*u,eaves+rise*pow(1-u,1.3),-depth*.5)
			var c: Vector3=a+Vector3(0,0,depth)
			var d: Vector3=b+Vector3(0,0,depth)
			if side>0:
				quad(st,a,b,c,d,Vector2(depth*.55,1.0/14*2.5),Vector2(0,t*2.5))
			else:
				quad(st,c,d,a,b,Vector2(depth*.55,1.0/14*2.5),Vector2(0,t*2.5))
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,material)
	for side in [-1.0,1.0]:
		IRArt.tube(root,Vector3(side*half_width,eaves,-depth*.5),Vector3(side*half_width,eaves,depth*.5),.12,trim())
		for end in [-1.0,1.0]:
			for j in range(7):
				var t: float=j/7.0
				var u: float=(j+1)/7.0
				IRArt.tube(root,Vector3(side*half_width*t,eaves+rise*pow(1-t,1.3),end*depth*.5),Vector3(side*half_width*u,eaves+rise*pow(1-u,1.3),end*depth*.5),.09,trim())
	IRArt.tube(root,Vector3(0,eaves+rise,-depth*.5-.1),Vector3(0,eaves+rise,depth*.5+.1),.14,material)

func cottage(variant: int) -> Node3D:
	var root: Node3D=Node3D.new()
	var walls: Material=paint("wall%d"%variant,["eed0ad","e9b7ad","dfd8b8"][variant])
	var tiles: Material=textured("roof%d"%variant,"fairy_roof",["829ec0","b585b9","df9d87"][variant],1.0)
	enchanted.rounded_box(root,Vector3(7,4.65,6),Vector3(0,2.3,0),walls,.18)
	IRArt.block(root,Vector3(7.35,.65,6.35),Vector3(0,.30,0),stone())
	# Gables follow the curved roof, rather than leaving a triangular hole under it.
	for end in [-1.0,1.0]:
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0,1.0]:
			for j in range(14):
				var t: float=j/14.0
				var u: float=(j+1)/14.0
				var a: Vector3=Vector3(side*3.5*t,4.5,end*3.0)
				var b: Vector3=Vector3(side*3.5*t,4.65+3.25*pow(1-t*.875,1.3),end*3.0)
				var c: Vector3=Vector3(side*3.5*u,4.5,end*3.0)
				var d: Vector3=Vector3(side*3.5*u,4.65+3.25*pow(1-u*.875,1.3),end*3.0)
				if side*end>0:
					quad(st,a,b,c,d)
				else:
					quad(st,c,d,a,b)
		IRArt.part(root,st.commit(),Vector3.ZERO,walls)
	roof(root,4.0,7.25,4.65,3.25,tiles)
	IRArt.block(root,Vector3(1,3.0,1),Vector3(2.1,7.2,-1.3),stone())
	IRArt.block(root,Vector3(1.3,.28,1.3),Vector3(2.1,8.75,-1.3),trim())
	for x in [-2.25,2.25]:
		window(root,Vector3(x,1.9,3.015))
		IRArt.block(root,Vector3(1.6,.35,.58),Vector3(x,1.75,3.22),paint("planter%d"%variant,["829bab","a687a3","b78f7e"][variant],.80))
	panel(root,Vector3(0,.4,3.02),1.75,3.10,trim())
	panel(root,Vector3(0,.42,3.06),1.40,2.90,paint("door%d"%variant,["547b93","937290","9c715e"][variant],.54))
	IRArt.block(root,Vector3(.045,2.7,.04),Vector3(0,1.8,3.10),trim())
	ball(root,Vector3(.43,1.67,3.16),Vector3.ONE*.14,paint("brass","e2b96b",.3,.65))
	for j in range(3):
		IRArt.block(root,Vector3(2.3+j*.25,.23,1.0),Vector3(0,.26-j*.10,3.4+j*.42),stone())
	if variant!=1:
		window(root,Vector3(0,5.20,3.025),1.05,1.45)
	# Side extension: a separate little gable and a bay window break the box silhouette.
	var bay: Node3D=Node3D.new()
	IRArt.block(bay,Vector3(2.4,2.6,2.2),Vector3(0,1.9,0),walls)
	architecture.maker=self
	architecture.gables(bay,1.2,2.2,3.2,1.15,1.55,walls)
	architecture.maker=null
	roof(bay,1.55,2.7,3.2,1.15,tiles)
	window(bay,Vector3(0,1.5,1.12),1.25,1.4)
	var baked: MeshInstance3D=IRArt.bake(bay)
	baked.transform=Transform3D(Basis(Vector3.UP,PI*.5),Vector3(3.4,0,-.8))
	root.add_child(baked.duplicate())
	bay.free()
	architecture.cottage_details(root,variant,self)
	return root

func tree(kind: String) -> Node3D:
	return botanicals.tree(kind)

func flowers(kind: String) -> Node3D:
	return botanicals.flowers(kind)

func mushroom() -> Node3D:
	var root: Node3D=Node3D.new()
	IRArt.tube(root,Vector3.ZERO,Vector3(.08,1.7,0),.22,trim(),.32)
	lathe(root,[Vector2(.02,1.68),Vector2(.8,1.65),Vector2(1.02,1.85),Vector2(.94,2.1),Vector2(.65,2.45),Vector2(.05,2.58)],Vector3.ZERO,paint("mushroom","d66e7a",.62))
	for i in range(9):
		var a: float=i*2.4
		var r: float=.45+(i%2)*.22
		ball(root,Vector3(cos(a)*r,2.40-r*.35,sin(a)*r),Vector3(.19,.07,.19),trim())
	return root

func arch() -> Node3D:
	var root: Node3D=Node3D.new()
	for x in [-8.2,8.2]:
		IRArt.block(root,Vector3(1.5,5.9,1.8),Vector3(x,2.9,0),stone())
		IRArt.block(root,Vector3(2.05,.4,2.25),Vector3(x,.2,0),trim())
		IRArt.block(root,Vector3(2.05,.3,2.25),Vector3(x,5.85,0),trim())
		ball(root,Vector3(x,6.3,0),Vector3(.7,.9,.7),paint("brass","e2b96b",.3,.65))
	# 32 voussoirs form an actual open arch over the track.
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a: float=PI*i/32
		var b: float=PI*(i+1)/32
		for z in [-.8,.8]:
			var p: Vector3=Vector3(cos(a)*8.2,5.8+sin(a)*3.4,z)
			var q: Vector3=Vector3(cos(b)*8.2,5.8+sin(b)*3.4,z)
			var r: Vector3=Vector3(cos(a)*8.2,6.7+sin(a)*3.4,z)
			var s: Vector3=Vector3(cos(b)*8.2,6.7+sin(b)*3.4,z)
			if z>0:
				quad(st,q,s,p,r)
			else:
				quad(st,p,r,q,s)
		var p: Vector3=Vector3(cos(a)*8.2,5.8+sin(a)*3.4,-.8)
		var q: Vector3=Vector3(cos(b)*8.2,5.8+sin(b)*3.4,-.8)
		quad(st,q,p,q+Vector3(0,0,1.6),p+Vector3(0,0,1.6))
		quad(st,p+Vector3.UP*.9,q+Vector3.UP*.9,p+Vector3(0,.9,1.6),q+Vector3(0,.9,1.6))
	IRArt.part(root,st.commit(),Vector3.ZERO,stone())
	return root

func turret() -> Node3D:
	var root: Node3D=Node3D.new()
	lathe(root,[Vector2(3.15,0),Vector2(3.15,.55),Vector2(2.8,.8),Vector2(2.8,12.8),Vector2(3.2,13.1),Vector2(3.2,14.1),Vector2(3.6,14.35)],Vector3.ZERO,stone())
	var tiles: Material=textured("castle_roof","fairy_roof","8f93c7",1.3)
	lathe(root,[Vector2(3.9,14.3),Vector2(3.6,14.8),Vector2(2.5,16.0),Vector2(1.55,18.3),Vector2(.65,20.7),Vector2(.12,22.1),Vector2(.02,22.3)],Vector3.ZERO,tiles)
	for i in range(4):
		var side: Node3D=Node3D.new()
		window(side,Vector3(0,8.9,2.81),.90,2.55)
		window(side,Vector3(0,4.1,2.81),.70,1.9)
		var part: MeshInstance3D=IRArt.bake(side)
		part.rotation.y=i*PI*.5
		root.add_child(part.duplicate())
		side.free()
	ball(root,Vector3(0,22.45,0),Vector3(.4,.55,.4),paint("brass","e2b96b",.3,.65))
	IRArt.tube(root,Vector3(0,22.4,0),Vector3(0,24.3,0),.045,trim())
	architecture.turret_details(root,self)
	return root

func keep() -> Node3D:
	var root: Node3D=Node3D.new()
	IRArt.block(root,Vector3(17,14.0,11),Vector3(0,7,0),stone())
	IRArt.block(root,Vector3(17.5,.6,11.5),Vector3(0,3.5,0),trim())
	IRArt.block(root,Vector3(17.8,.55,11.8),Vector3(0,13.8,0),trim())
	roof(root,9.4,12.6,14.0,5.5,textured("keep_roof","fairy_roof","9b9bc7",1.4))
	for end in [-1.0,1.0]:
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0,1.0]:
			for j in range(14):
				var x: float=side*8.5*j/14.0
				var u: float=side*8.5*(j+1)/14.0
				var a: Vector3=Vector3(x,13.9,end*5.5)
				var b: Vector3=Vector3(x,14+5.5*pow(1-absf(x)/9.4,1.3),end*5.5)
				var c: Vector3=Vector3(u,13.9,end*5.5)
				var d: Vector3=Vector3(u,14+5.5*pow(1-absf(u)/9.4,1.3),end*5.5)
				if side*end>0:
					quad(st,a,b,c,d)
				else:
					quad(st,c,d,a,b)
		IRArt.part(root,st.commit(),Vector3.ZERO,stone())
	for x in [-5.8,-2.9,2.9,5.8]:
		for y in [5.2,9.7]:
			window(root,Vector3(x,y,5.53),1.1,2.8)
	panel(root,Vector3(0,.1,5.53),4.6,5.8,trim())
	panel(root,Vector3(0,.15,5.57),3.8,5.2,paint("castle_gate","6e6682"))
	IRArt.block(root,Vector3(1.1,5.5,.05),Vector3(0,10.5,5.62),paint("rose_banner","d96c8c"))
	architecture.keep_details(root,self)
	return root

func lantern() -> Node3D:
	var root: Node3D=Node3D.new()
	var metal: Material=paint("iron","605b6c",.5,.5)
	IRArt.tube(root,Vector3.ZERO,Vector3(0,3.7,0),.085,metal,.06)
	IRArt.block(root,Vector3(.45,.17,.45),Vector3(0,.08,0),stone())
	var light_material: StandardMaterial3D=StandardMaterial3D.new()
	light_material.albedo_color=Color("ffe5ae")
	light_material.emission_enabled=true
	light_material.emission=Color("ffc87e")
	light_material.emission_energy_multiplier=.45
	IRArt.block(root,Vector3(.48,.70,.48),Vector3(0,3.9,0),light_material)
	for x in [-.27,.27]:
		for z in [-.27,.27]:
			IRArt.tube(root,Vector3(x,3.5,z),Vector3(x,4.3,z),.035,metal)
	lathe(root,[Vector2(.44,4.28),Vector2(.35,4.45),Vector2(.04,4.67)],Vector3.ZERO,metal,12)
	return root

func rail() -> Node3D:
	var root: Node3D=Node3D.new()
	for x in [-1.6,1.6]:
		IRArt.block(root,Vector3(.45,1.55,.45),Vector3(x,.75,0),stone())
		ball(root,Vector3(x,1.65,0),Vector3(.60,.35,.60),trim())
	IRArt.block(root,Vector3(3.3,.25,.45),Vector3(0,1.35,0),trim())
	IRArt.block(root,Vector3(3.3,.30,.45),Vector3(0,.15,0),stone())
	for x in [-.9,-.3,.3,.9]:
		lathe(root,[Vector2(.13,.3),Vector2(.08,.65),Vector2(.15,.85),Vector2(.08,1.2)],Vector3(x,0,0),stone(),10)
	return root

func fountain() -> Node3D:
	var root: Node3D=Node3D.new()
	lathe(root,[Vector2(.01,0),Vector2(3.0,0),Vector2(3,.35),Vector2(2.75,.5),Vector2(2.75,.9),Vector2(2.35,.9),Vector2(2.35,.45),Vector2(.02,.45)],Vector3.ZERO,stone(),40)
	lathe(root,[Vector2(.60,.4),Vector2(.40,1.8),Vector2(1.35,2.0),Vector2(1.45,2.3),Vector2(1.15,2.5),Vector2(.3,2.5),Vector2(.18,3.6),Vector2(.04,3.9)],Vector3.ZERO,trim(),32)
	var water: CylinderMesh=CylinderMesh.new()
	water.top_radius=2.33
	water.bottom_radius=2.33
	water.height=.025
	water.radial_segments=40
	IRArt.part(root,water,Vector3(0,.56,0),paint("fountain_water","83b8ca",.22))
	return root

func bench() -> Node3D:
	var root: Node3D=Node3D.new()
	var metal: Material=paint("iron","605b6c",.5,.5)
	for x in [-1.05,1.05]:
		IRArt.tube(root,Vector3(x,0,-.33),Vector3(x,.8,-.28),.08,metal)
		IRArt.tube(root,Vector3(x,0,.40),Vector3(x,1.65,.32),.08,metal)
	for z in [-.2,.08,.36]:
		IRArt.block(root,Vector3(2.65,.12,.23),Vector3(0,.80,z),trim())
	for y in [1.08,1.36,1.64]:
		IRArt.block(root,Vector3(2.65,.22,.10),Vector3(0,y,.40),paint("bench_blue","a3b8c8"))
	return root

func windmill() -> Node3D:
	var root: Node3D=Node3D.new()
	lathe(root,[Vector2(3.1,0),Vector2(2.95,1),Vector2(2.1,11.8),Vector2(2.5,12.0)],Vector3.ZERO,stone(),32)
	lathe(root,[Vector2(3.2,11.9),Vector2(2.6,12.5),Vector2(1.7,14.0),Vector2(.15,15.7)],Vector3.ZERO,textured("mill_roof","fairy_roof","99abc5"),32)
	window(root,Vector3(0,5.0,2.5),.85,1.6)
	panel(root,Vector3(0,.2,3.02),1.4,2.9,paint("castle_gate","6e6682"))
	return root

func windmill_rotor() -> Node3D:
	var root: Node3D=Node3D.new()
	for i in range(4):
		var a: float=i*PI*.5
		var direction: Vector3=Vector3(sin(a),cos(a),0)
		var side: Vector3=Vector3(cos(a),-sin(a),0)
		IRArt.tube(root,direction*.2,direction*6.8,.075,trim())
		for j in range(8):
			var center: Vector3=direction*(2.0+j*.62)+side*.5
			IRArt.tube(root,center-side*.58,center+side*.58,.035,trim())
		for k in [-.02,.50,1.02]:
			IRArt.tube(root,direction*1.8+side*k,direction*6.7+side*k,.035,trim())
	ball(root,Vector3.ZERO,Vector3(.7,.7,.5),paint("brass","e2b96b",.3,.65))
	return root

func stall() -> Node3D:
	var root: Node3D=Node3D.new()
	var canvas: Material=paint("market_red","ce8293")
	var red_fabric: StandardMaterial3D=canvas.duplicate()
	var cream_fabric: StandardMaterial3D=trim().duplicate()
	red_fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	cream_fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	for x in [-1.7,1.7]:
		for z in [-1.1,1.1]:
			IRArt.tube(root,Vector3(x,0,z),Vector3(x,3.2,z),.07,trim())
	for i in range(10):
		var x: float=(i-4.5)*.38
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(6):
			var t: float=j/6.0
			var u: float=(j+1)/6.0
			quad(st,Vector3(x+.19,3.7-t*t*.7,-1.5+t*3.1),Vector3(x+.19,3.7-u*u*.7,-1.5+u*3.1),Vector3(x-.19,3.7-t*t*.7,-1.5+t*3.1),Vector3(x-.19,3.7-u*u*.7,-1.5+u*3.1))
		IRArt.part(root,st.commit(),Vector3.ZERO,cream_fabric if i%2 else red_fabric)
	IRArt.block(root,Vector3(3.7,1.0,1.1),Vector3(0,.55,.6),paint("wall0","eed0ad"))
	IRArt.block(root,Vector3(3.9,.15,1.3),Vector3(0,1.1,.6),trim())
	for i in range(9):
		ball(root,Vector3((i-4)*.35,1.29,.7),Vector3(.3,.3,.3),paint("fruit%d"%(i%2),"e4b15e" if i%2 else "db8392"))
	return root

func pavilion() -> Node3D:
	var root: Node3D=Node3D.new()
	lathe(root,[Vector2(3.9,0),Vector2(3.9,.25),Vector2(3.5,.5)],Vector3.ZERO,stone(),8)
	for i in range(8):
		var a: float=i*TAU/8
		var p: Vector3=Vector3(cos(a)*3,0,sin(a)*3)
		IRArt.tube(root,p+Vector3.UP*.5,p+Vector3.UP*4.8,.13,trim())
	lathe(root,[Vector2(4.4,4.7),Vector2(3.9,5.1),Vector2(2.3,5.6),Vector2(1.3,6.9),Vector2(.15,8.0)],Vector3.ZERO,textured("gazebo_roof","fairy_roof","a1b8ca"),32)
	ball(root,Vector3(0,8.2,0),Vector3(.3,.5,.3),paint("brass","e2b96b",.3,.65))
	architecture.pavilion_details(root,self)
	return root

func boat(variant: int = 0) -> Node3D:
	var root: Node3D=Node3D.new()
	architecture.boat_hull(root,variant,self)
	IRArt.tube(root,Vector3(0,.8,0),Vector3(0,6,0),.065,paint("bark","8a7051"))
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(16):
		for column in range(10):
			var corners: Array[Vector2]=[Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]
			if row==15:
				corners.resize(3)
			for offset in corners:
				var t: float=(row+offset.x)/16.0
				var u: float=(column+offset.y)/10.0
				st.set_uv(Vector2(u,t))
				st.set_color(Color(["e8b6a4","b3c6d4","d4bdcc"][variant]) if column in [1,2] else Color("f5e6c9"))
				st.add_vertex(Vector3(.04+sin(t*PI)*sin(u*PI)*.28,lerpf(1.6,5.8,t),.05+u*2.55*(1-t)))
	st.index()
	st.generate_normals()
	var linen: StandardMaterial3D=IRArt.textured("linen").duplicate()
	linen.vertex_color_use_as_albedo=true
	linen.vertex_color_is_srgb=true
	linen.cull_mode=BaseMaterial3D.CULL_DISABLED
	IRArt.part(root,st.commit(),Vector3.ZERO,linen)
	return root

func lighthouse() -> Node3D:
	var root: Node3D=Node3D.new()
	for j in range(5):
		lathe(root,[Vector2(3.1-j*.23,j*4.0),Vector2(2.87-j*.23,j*4.0+4.0)],Vector3.ZERO,stone() if j%2==0 else paint("lighthouse_blue","98adc5"))
	lathe(root,[Vector2(2.5,20),Vector2(2.5,20.4),Vector2(2.1,20.6)],Vector3.ZERO,trim())
	var glass: Material=paint("lighthouse_glass","a9c7d5",.26)
	glass.set_meta("palette_kind",22)
	lathe(root,[Vector2(1.65,20.5),Vector2(1.65,23.0)],Vector3.ZERO,glass,8)
	for i in range(8):
		var a: float=i*TAU/8
		var p: Vector3=Vector3(cos(a)*1.7,20.5,sin(a)*1.7)
		IRArt.tube(root,p,p+Vector3.UP*2.5,.07,trim())
	lathe(root,[Vector2(2.2,23),Vector2(1.8,23.5),Vector2(.15,25.2)],Vector3.ZERO,textured("lighthouse_roof","fairy_roof","b789a1"))
	panel(root,Vector3(0,.2,3.02),1.55,3.4,paint("castle_gate","6e6682"))
	architecture.lighthouse_details(root,self)
	return root

func save_asset(name: String, root: Node3D) -> void:
	var baked: MeshInstance3D=IRArt.bake(root)
	var authored: ArrayMesh=baked.mesh
	if name.begins_with("cottage"):
		authored=enchanted.sculpt_cottage(authored,["cottage_blue","cottage_rose","cottage_peach"].find(name))
	var importer: ImporterMesh=ImporterMesh.from_mesh(IRPaletteMesh.compact(authored,name=="boat" or name.begins_with("boat_"),false,name.begins_with("balloon")))
	importer.generate_lods(60.0,25.0,[])
	var mesh: ArrayMesh=importer.get_mesh()
	var triangles: int=0
	var lod_count: int=0
	for i in range(mesh.get_surface_count()):
		var arrays: Array=mesh.surface_get_arrays(i)
		triangles+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
		lod_count+=importer.get_surface_lod_count(i)
	var result: Error=ResourceSaver.save(mesh,"res://assets/fairytale/"+name+".res",ResourceSaver.FLAG_COMPRESS)
	assert(result==OK,"Cannot save "+name)
	report[name]={"surfaces":mesh.get_surface_count(),"triangles":triangles,"lod_levels_total":lod_count}
	root.free()

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/fairytale")
	for i in range(3):
		save_asset("cottage_"+["blue","rose","peach"][i],cottage(i))
		save_asset("town_"+["post","workshop","tea"][i],living.townhouse(self,i))
	save_asset("port_crane",living.crane(self))
	save_asset("crystal_grotto",living.grotto(self))
	save_asset("giant_fern",living.forest_fern(self))
	save_asset("moss_boulder",living.boulder(self))
	save_asset("lantern_mushroom",living.lantern_mushroom(self))
	save_asset("resident_rabbit",residents.resident(self,0))
	save_asset("resident_mouse",residents.resident(self,1))
	save_asset("resident_cat",residents.cat(self))
	save_asset("resident_gull",residents.bird(self))
	save_asset("resident_duck",residents.bird(self,true))
	save_asset("elder_gate",enchanted.elder_gate(self))
	save_asset("bakery",enchanted.bakery(self))
	save_asset("castle_crag",enchanted.castle_crag(self))
	save_asset("boathouse",enchanted.boathouse(self))
	for kind in ["oak","blossom","willow","birch","cypress"]:
		save_asset("tree_"+kind,tree(kind))
	save_asset("flowering_bush",botanicals.flowering_bush())
	save_asset("hanging_ivy",botanicals.hanging_ivy())
	save_asset("water_lily",botanicals.water_lily())
	save_asset("footbridge",architecture.footbridge(self))
	save_asset("garden_fence",architecture.garden_fence(self))
	save_asset("mailbox",architecture.mailbox(self))
	save_asset("rose_arbor",architecture.rose_arbor(self))
	save_asset("dock_supplies",architecture.dock_supplies(self))
	save_asset("garden_planter",architecture.garden_planter(self))
	save_asset("balloon_coral",sky_art.balloon(0,self))
	save_asset("balloon_blue",sky_art.balloon(1,self))
	for kind in ["daisy","rose","lavender"]:
		save_asset("flowers_"+kind,flowers(kind))
	save_asset("fern",botanicals.fern())
	save_asset("mushroom",mushroom())
	save_asset("arch",arch())
	save_asset("turret",turret())
	save_asset("castle_keep",keep())
	save_asset("lantern",lantern())
	save_asset("stone_rail",rail())
	save_asset("pavilion",pavilion())
	save_asset("boat",boat())
	save_asset("boat_coral",boat(1))
	save_asset("boat_sage",boat(2))
	save_asset("lighthouse",lighthouse())
	save_asset("fountain",fountain())
	save_asset("bench",bench())
	save_asset("windmill",windmill())
	save_asset("windmill_rotor",windmill_rotor())
	save_asset("market_stall",stall())
	var hedge: Node3D=Node3D.new()
	ball(hedge,Vector3(0,.7,0),Vector3(3.0,1.6,1.4),foliage("hedge"))
	save_asset("hedge",hedge)
	var manifest: FileAccess=FileAccess.open("res://assets/fairytale/mesh_manifest.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(report,"\t")+"\n")
	print("FAIRY_ASSETS: ",report.size()," compressed meshes with generated distance LODs")
