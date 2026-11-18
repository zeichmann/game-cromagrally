extends RefCounted
## Authored cottage variations and small functional details, packed into shared surfaces.

var maker: RefCounted

func attach(root: Node3D, model: Node3D, position: Vector3, yaw: float = 0, size: float = 1.0) -> void:
	var merged: MeshInstance3D=IRArt.bake(model)
	var copy: MeshInstance3D=merged.duplicate()
	copy.transform=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),position)
	root.add_child(copy)
	model.free()

func gables(root: Node3D, half_width: float, depth: float, eaves: float, rise: float, roof_width: float, material: Material) -> void:
	for end in [-1.0,1.0]:
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0,1.0]:
			for j in range(8):
				var x: float=side*half_width*j/8.0
				var u: float=side*half_width*(j+1)/8.0
				var a: Vector3=Vector3(x,eaves-.1,end*depth*.5)
				var b: Vector3=Vector3(x,eaves+rise*pow(1-absf(x)/roof_width,1.3),end*depth*.5)
				var c: Vector3=Vector3(u,eaves-.1,end*depth*.5)
				var d: Vector3=Vector3(u,eaves+rise*pow(1-absf(u)/roof_width,1.3),end*depth*.5)
				if side*end>0:
					maker.quad(st,a,b,c,d)
				else:
					maker.quad(st,c,d,a,b)
		IRArt.part(root,st.commit(),Vector3.ZERO,material)

func wall_lantern(root: Node3D, p: Vector3) -> void:
	var iron: Material=maker.paint("iron","605b6c",.5,.5)
	IRArt.tube(root,p+Vector3(0,.16,-.30),p+Vector3(0,.16,0),.035,iron)
	var glass: StandardMaterial3D=StandardMaterial3D.new()
	glass.albedo_color=Color("ffe6b1")
	glass.emission_enabled=true
	glass.emission=Color("ffdc98")
	IRArt.block(root,Vector3(.24,.34,.24),p,glass)
	for x in [-.14,.14]:
		for z in [-.14,.14]:
			IRArt.tube(root,p+Vector3(x,-.2,z),p+Vector3(x,.2,z),.018,iron)
	var cap: Array[Vector2]=[Vector2(.22,.19),Vector2(.17,.29),Vector2(.02,.37)]
	maker.lathe(root,cap,p,iron,12)

func pot(root: Node3D, p: Vector3, kind: String, size: float = 1) -> void:
	var model: Node3D=Node3D.new()
	var clay: Material=maker.paint("garden_clay","c99882",.72)
	var profile: Array[Vector2]=[Vector2(.16,.02),Vector2(.21,.08),Vector2(.29,.37),Vector2(.25,.56),Vector2(.28,.59),Vector2(.27,.64),Vector2(.21,.64),Vector2(.20,.54),Vector2(.01,.52)]
	maker.lathe(model,profile,Vector3.ZERO,clay,20)
	var soil: CylinderMesh=CylinderMesh.new()
	soil.top_radius=.20
	soil.bottom_radius=.20
	soil.height=.025
	soil.radial_segments=12
	IRArt.part(model,soil,Vector3(0,.54,0),maker.paint("potting_soil","625644",.95))
	attach(model,maker.botanicals.flowers(kind),Vector3(0,.55,0),.2,.40)
	attach(root,model,p,0,size)

func shutters(root: Node3D, center: Vector3, color: Material) -> void:
	for side in [-1.0,1.0]:
		var p: Vector3=center+Vector3(side*.80,.78,.10)
		IRArt.block(root,Vector3(.35,1.53,.08),p,color)
		for j in range(8):
			IRArt.block(root,Vector3(.31,.075,.10),p+Vector3(0,-.63+j*.18,.045),maker.trim())
		for y in [-.53,.53]:
			IRArt.block(root,Vector3(.20,.045,.05),p+Vector3(-side*.12,y,.10),maker.paint("hinges","74686b",.55,.4))

func door_details(root: Node3D, variant: int) -> void:
	var color: Color=Color(["547b93","937290","9c715e"][variant])
	for i in range(7):
		var x: float=(i-3)*.185
		var top: float=2.62+sqrt(maxf(.49-x*x,0.0))
		IRArt.block(root,Vector3(.175,top-.46,.028),Vector3(x,(top+.46)*.5,3.14),IRArt.pbr(color.lightened(.035 if i%2 else 0),.58))
	for y in [1.0,2.20]:
		IRArt.block(root,Vector3(.33,.065,.045),Vector3(-.51,y,3.17),maker.paint("hinges","74686b",.55,.4))
	var ring: MeshInstance3D=IRArt.ring(root,.115,.018,Vector3(.05,2.04,3.23),maker.paint("brass","e2b96b",.3,.65))
	ring.rotation.x=PI*.5
	maker.ball(root,Vector3(.05,2.18,3.21),Vector3(.10,.10,.07),maker.paint("brass","e2b96b",.3,.65))
	IRArt.block(root,Vector3(1.25,.018,.50),Vector3(0,.385,3.40),maker.paint("door_mat","a6947c",.95))
	wall_lantern(root,Vector3(-1.20,2.55,3.35))
	pot(root,Vector3(-1.6,.02,3.75),"rose",.95)
	pot(root,Vector3(1.6,.02,3.75),"daisy",.95)

func dormer(root: Node3D, walls: Material, tiles: Material) -> void:
	var model: Node3D=Node3D.new()
	IRArt.block(model,Vector3(1.8,1.35,1.6),Vector3(0,.67,0),walls)
	gables(model,.9,1.6,1.35,.85,1.15,walls)
	maker.roof(model,1.15,2.05,1.35,.85,tiles)
	maker.window(model,Vector3(0,.20,.815),.85,1.15)
	attach(root,model,Vector3(1.8,5.65,-.65),PI*.5)

func balcony(root: Node3D, tiles: Material) -> void:
	maker.window(root,Vector3(0,4.27,3.025),1.4,2.25)
	IRArt.block(root,Vector3(2.6,.18,.95),Vector3(0,4.15,3.48),maker.stone())
	var metal: Material=maker.paint("balcony_iron","766471",.55,.3)
	for x in [-1.20,1.20]:
		IRArt.tube(root,Vector3(x,4.2,3.05),Vector3(x,4.2,3.95),.045,metal)
		IRArt.tube(root,Vector3(x,4.95,3.05),Vector3(x,4.95,3.95),.045,metal)
		IRArt.tube(root,Vector3(x,4.2,3.95),Vector3(x,4.95,3.95),.045,metal)
	for i in range(9):
		var x: float=-1.1+i*.275
		IRArt.tube(root,Vector3(x,4.2,3.95),Vector3(x,4.95,3.95),.025,metal)
	IRArt.tube(root,Vector3(-1.25,4.95,3.95),Vector3(1.25,4.95,3.95),.045,metal)
	for x in [-.80,.80]:
		IRArt.tube(root,Vector3(x,3.43,3.05),Vector3(x,4.07,3.87),.095,maker.trim())
	IRArt.block(root,Vector3(1.3,.23,.38),Vector3(0,4.88,4.02),weathered("ac91a6"))
	attach(root,maker.botanicals.flowers("rose"),Vector3(0,4.98,4.02),0,.55)

func porch(root: Node3D, tiles: Material) -> void:
	var model: Node3D=Node3D.new()
	for x in [-1.75,1.75]:
		IRArt.tube(model,Vector3(x,.1,.65),Vector3(x,2.8,.65),.095,maker.trim())
		maker.ball(model,Vector3(x,.14,.65),Vector3(.3,.2,.3),maker.stone())
	maker.roof(model,2.1,2.05,2.75,.65,tiles)
	attach(root,model,Vector3(0,0,4.0))

func cottage_details(root: Node3D, variant: int, author: RefCounted) -> void:
	maker=author
	var tiles: Material=maker.textured("roof%d"%variant,"fairy_roof",["829ec0","b585b9","df9d87"][variant],1.0)
	var walls: Material=maker.paint("wall%d"%variant,["eed0ad","e9b7ad","dfd8b8"][variant])
	for x in [-2.25,2.25]:
		shutters(root,Vector3(x,1.9,3.015),maker.paint("shutter%d"%variant,["7f9aaa","ae8eaa","a9ad8b"][variant],.7))
		attach(root,maker.botanicals.flowers("rose"),Vector3(x,1.91,3.28),.1,.48)
	door_details(root,variant)
	IRArt.tube(root,Vector3(0,4.65,3.08),Vector3(0,7.55,3.08),.06,maker.trim())
	for side in [-1.0,1.0]:
		IRArt.tube(root,Vector3(side*2.8,4.70,3.08),Vector3(side*.32,7.25,3.08),.05,maker.trim())
	for z in range(17):
		var cap: CylinderMesh=CylinderMesh.new()
		cap.radial_segments=8
		cap.rings=0
		cap.top_radius=.145
		cap.bottom_radius=.145
		cap.height=.39
		var part: MeshInstance3D=IRArt.part(root,cap,Vector3(0,7.90,-3.1+z*.39),tiles)
		part.rotation.x=PI*.5
	if variant==0:
		dormer(root,walls,tiles)
		for i in range(5):
			var x: float=-3.85-(i%2)*.17
			var y: float=.20+(i/2)*.19
			IRArt.tube(root,Vector3(x,y,-.2),Vector3(x,y,.65),.11,IRArt.timber())
	elif variant==1:
		balcony(root,tiles)
	else:
		porch(root,tiles)
		var wing: Node3D=Node3D.new()
		IRArt.block(wing,Vector3(2.8,3.5,4.6),Vector3(0,1.75,0),walls)
		IRArt.block(wing,Vector3(3.0,.55,4.8),Vector3(0,.25,0),maker.stone())
		gables(wing,1.4,4.6,3.5,1.6,1.75,walls)
		maker.roof(wing,1.75,5.3,3.5,1.6,tiles)
		maker.window(wing,Vector3(0,1.2,2.315),1.1,1.65)
		attach(root,wing,Vector3(-4.5,0,-.4))
	var back: Node3D=Node3D.new()
	for x in [-2.0,2.0]:
		maker.window(back,Vector3(x,1.9,3.015),1.0,1.55)
	attach(root,back,Vector3.ZERO,PI)
	if variant!=2:
		var side_window: Node3D=Node3D.new()
		maker.window(side_window,Vector3(0,1.9,0),1.0,1.55)
		attach(root,side_window,Vector3(-3.52,0,-.65),-PI*.5)
	for x in [1.86,2.34]:
		var pots: Array[Vector2]=[Vector2(.13,8.85),Vector2(.13,9.35),Vector2(.18,9.39),Vector2(.18,9.49),Vector2(.105,9.49),Vector2(.105,9.34)]
		maker.lathe(root,pots,Vector3(x,0,-1.3),maker.paint("chimney_clay","ab8c7c",.82),12)
	var dimensions: Vector3=[Vector3(1,1,1),Vector3(.84,1.10,.96),Vector3(1.12,.95,1.0)][variant]
	var shape: Transform3D=Transform3D(Basis.from_scale(dimensions),Vector3.ZERO)
	for child in root.get_children():
		if child is Node3D:
			child.transform=shape*child.transform
	maker=null

func clock(root: Node3D, p: Vector3) -> void:
	var ivory: Material=maker.trim()
	var gold: Material=maker.paint("clock_gold","d9b673",.34,.55)
	var face: CylinderMesh=CylinderMesh.new()
	face.top_radius=1.08
	face.bottom_radius=1.08
	face.height=.08
	face.radial_segments=48
	var disk: MeshInstance3D=IRArt.part(root,face,p,ivory)
	disk.rotation.x=PI*.5
	var rim: MeshInstance3D=IRArt.ring(root,1.13,.055,p+Vector3(0,0,.06),gold)
	rim.rotation.x=PI*.5
	var ink: Material=maker.paint("clock_ink","536777",.60)
	for i in range(12):
		var a: float=TAU*i/12
		var ray: Vector3=Vector3(sin(a),cos(a),0)
		IRArt.tube(root,p+ray*.84+Vector3(0,0,.06),p+ray*.97+Vector3(0,0,.06),.025,ink)
	IRArt.tube(root,p+Vector3(0,0,.09),p+Vector3(.42,.70,.09),.035,ink)
	IRArt.tube(root,p+Vector3(0,0,.10),p+Vector3(-.39,.28,.10),.045,ink)
	maker.ball(root,p+Vector3(0,0,.13),Vector3.ONE*.16,gold)

func keep_details(root: Node3D, author: RefCounted) -> void:
	maker=author
	var tiles: Material=maker.textured("keep_roof","fairy_roof","9b9bc7",1.4)
	# An integrated clock gable rises above the main roof and the entrance axis.
	IRArt.block(root,Vector3(4.3,5.5,3.9),Vector3(0,16.75,4.8),maker.stone())
	gables(root,2.15,3.9,19.5,3.4,2.65,maker.stone())
	# Gables above are authored at the origin, then translated to the clock tower.
	for child in root.get_children().slice(-2):
		child.position.z+=4.8
	var clock_roof: Node3D=Node3D.new()
	maker.roof(clock_roof,2.65,4.6,19.5,3.4,tiles)
	attach(root,clock_roof,Vector3(0,0,4.8))
	IRArt.block(root,Vector3(4.65,.20,4.2),Vector3(0,14.1,4.8),maker.trim())
	clock(root,Vector3(0,17.35,6.81))
	for x in [-1.77,1.77]:
		IRArt.block(root,Vector3(.24,5.3,.22),Vector3(x,16.8,6.83),maker.trim())
	# Gate has actual planks, straps, studs and a pair of ring handles.
	var timber: Material=maker.paint("gate_oak","776879",.66)
	var iron: Material=maker.paint("gate_iron","595568",.54,.35)
	for i in range(16):
		var x: float=(i-7.5)*.225
		var top: float=3.25+sqrt(maxf(1.82*1.82-x*x,0))
		IRArt.block(root,Vector3(.214,top-.25,.06),Vector3(x,(top+.25)*.5,5.65),timber)
	for side in [-1.0,1.0]:
		for y in [1.1,2.8]:
			IRArt.block(root,Vector3(1.5,.10,.07),Vector3(side*.93,y,5.72),iron)
			for x in [.32,.8,1.35]:
				maker.ball(root,Vector3(side*x,y,5.77),Vector3.ONE*.07,iron)
		var handle: MeshInstance3D=IRArt.ring(root,.17,.027,Vector3(side*.35,2.16,5.80),iron)
		handle.rotation.x=PI*.5
		wall_lantern(root,Vector3(side*3.0,4.4,5.94))
	for i in range(15):
		var a: float=PI*(i+.5)/15.0
		var block: MeshInstance3D=IRArt.block(root,Vector3(.44,.38,.35),Vector3(cos(a)*2.2,3.50+sin(a)*2.2,5.69),maker.trim())
		block.rotation.z=a-PI*.5
	# A stone balcony shades the gate and gives the facade real depth.
	IRArt.block(root,Vector3(6.3,.23,1.2),Vector3(0,6.6,6.0),maker.stone())
	IRArt.block(root,Vector3(6.3,.20,.30),Vector3(0,7.58,6.55),maker.trim())
	for i in range(13):
		IRArt.tube(root,Vector3((i-6)*.48,6.75,6.55),Vector3((i-6)*.48,7.5,6.55),.055,maker.trim())
	for x in [-2.5,0,2.5]:
		IRArt.tube(root,Vector3(x,5.7,5.55),Vector3(x,6.45,6.4),.15,maker.stone())
	# Recessed relief and a flower crest on the central banner.
	var crest: MeshInstance3D=IRArt.ring(root,.38,.035,Vector3(0,11.3,5.70),maker.trim())
	crest.rotation.x=PI*.5
	for i in range(6):
		var a: float=i*TAU/6
		maker.ball(root,Vector3(sin(a)*.19,11.3+cos(a)*.19,5.72),Vector3(.16,.23,.045),maker.trim())
	# Buttresses and a profiled base keep large walls from reading as a plain box.
	for x in [-7.8,-4.4,4.4,7.8]:
		IRArt.block(root,Vector3(.42,4.5,.5),Vector3(x,2.3,5.64),maker.stone())
	IRArt.block(root,Vector3(17.4,.30,11.35),Vector3(0,.75,0),maker.trim())
	maker=null

func turret_details(root: Node3D, author: RefCounted) -> void:
	maker=author
	for i in range(20):
		var a: float=TAU*i/20
		var ray: Vector3=Vector3(cos(a),0,sin(a))
		var corbel: MeshInstance3D=IRArt.block(root,Vector3(.24,.72,.45),ray*3.0+Vector3.UP*13.0,maker.trim())
		corbel.rotation.y=-a+PI*.5
	for y in [3.6,8.0]:
		var band: Array[Vector2]=[Vector2(2.85,y-.08),Vector2(2.93,y),Vector2(2.85,y+.13)]
		maker.lathe(root,band,Vector3.ZERO,maker.trim(),32)
	var fabric: StandardMaterial3D=maker.paint("tower_flag","de91ab",.82).duplicate()
	fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	fabric.set_meta("palette_kind",19)
	var flag: SurfaceTool=SurfaceTool.new()
	flag.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a: float=i/8.0
		var b: float=(i+1)/8.0
		maker.quad(flag,Vector3(a*1.8,24.1,0),Vector3(a*1.8,23.45+pow(a,4)*.24,0),Vector3(b*1.8,24.1,0),Vector3(b*1.8,23.45+pow(b,4)*.24,0),Vector2(1.0/8,1),Vector2(a,0))
	IRArt.part(root,flag.commit(),Vector3.ZERO,fabric)
	maker=null

func lighthouse_details(root: Node3D, author: RefCounted) -> void:
	maker=author
	var rail: Material=maker.paint("lighthouse_rail","726b79",.48,.4)
	IRArt.ring(root,2.35,.055,Vector3(0,21.30,0),rail)
	IRArt.ring(root,2.35,.035,Vector3(0,20.75,0),rail)
	for i in range(24):
		var a: float=i*TAU/24
		var p: Vector3=Vector3(cos(a)*2.35,20.4,sin(a)*2.35)
		IRArt.tube(root,p,p+Vector3.UP*.9,.035,rail)
	for level in [5.5,11.2,16.0]:
		var radius: float=3.1-level*.0575
		for i in range(4):
			var side: Node3D=Node3D.new()
			maker.window(side,Vector3(0,level,radius+.025),.65,1.50)
			attach(root,side,Vector3.ZERO,i*PI*.5)
	maker.panel(root,Vector3(0,.12,3.035),1.9,3.75,maker.trim())
	maker.panel(root,Vector3(0,.20,3.075),1.5,3.40,maker.paint("lighthouse_door","81748e",.65))
	wall_lantern(root,Vector3(-1.2,2.8,3.18))
	for i in range(3):
		IRArt.block(root,Vector3(2.5+i*.2,.18,.65),Vector3(0,.15-i*.10,3.45+i*.42),maker.stone())
	maker=null

func hull_point(t: float, angle: float) -> Vector3:
	var width: float=.035+1.15*pow(maxf(sin(t*PI),0),.62)
	return Vector3(sin(angle)*width,.76+.18*pow(absf(t*2-1),2)-cos(angle)*(.95-.2*absf(t*2-1)),lerpf(-2.8,2.8,t))

func boat_hull(root: Node3D, variant: int, author: RefCounted) -> void:
	maker=author
	var paint: StandardMaterial3D=maker.paint("boat_hull%d"%variant,["829fb8","c98f95","91aa9b"][variant],.43).duplicate()
	paint.cull_mode=BaseMaterial3D.CULL_DISABLED
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(28):
		for column in range(16):
			var t: float=row/28.0
			var u: float=(row+1)/28.0
			var a: float=lerpf(-PI*.5,PI*.5,column/16.0)
			var b: float=lerpf(-PI*.5,PI*.5,(column+1)/16.0)
			maker.quad(st,hull_point(t,a),hull_point(u,a),hull_point(t,b),hull_point(u,b))
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,paint)
	# Solid curved gunwales and a small planked cockpit, rather than a solid lozenge.
	for side in [-1.0,1.0]:
		var points: Array[Vector3]=[]
		var radii: Array[float]=[]
		for i in range(29):
			points.append(hull_point(i/28.0,side*PI*.5))
			radii.append(.055)
		maker.botanicals.path(root,points,radii,IRArt.timber(),Color.WHITE,8)
	for i in range(7):
		IRArt.block(root,Vector3(.18,.065,2.9),Vector3((i-3)*.18,.13,0),IRArt.timber())
	for z in [-1.12,.85]:
		IRArt.block(root,Vector3(1.85,.10,.32),Vector3(0,.58,z),IRArt.timber())
	IRArt.tube(root,Vector3(0,.4,-1.5),Vector3(0,.4,1.9),.032,maker.trim())
	IRArt.tube(root,Vector3(0,5.8,.02),Vector3(0,.77,2.3),.014,maker.trim())
	IRArt.tube(root,Vector3(0,5.8,.02),Vector3(0,.83,-2.4),.014,maker.trim())
	maker=null

func footbridge(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var timber: Material=weathered("b5ab9a")
	var rail: Material=maker.paint("garden_bridge","a99eae",.70)
	for i in range(25):
		var z: float=(i-12)*.36
		var y: float=.10+.65*(1-pow(z/4.5,2))
		var plank: MeshInstance3D=IRArt.block(root,Vector3(2.1,.13,.34),Vector3(0,y,z),timber)
		plank.rotation.x=atan(.65*2*z/(4.5*4.5))
	for side in [-1.0,1.0]:
		for i in range(10):
			var z: float=(i-4.5)*.94
			var y: float=.10+.65*(1-pow(z/4.5,2))
			IRArt.tube(root,Vector3(side*.99,y-.4,z),Vector3(side*.99,y+1.05,z),.06,rail)
			if i<9:
				var next_z: float=z+.94
				var next_y: float=.10+.65*(1-pow(next_z/4.5,2))
				for height in [.48,1.02]:
					IRArt.tube(root,Vector3(side*.99,y+height,z),Vector3(side*.99,next_y+height,next_z),.05,rail)
	maker=null
	return root

func weathered(color: String) -> Material:
	var material: StandardMaterial3D=maker.paint("weathered_"+color,color,.84).duplicate()
	material.set_meta("palette_kind",21)
	return material

func garden_fence(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var wood: Material=weathered("d8d0ba")
	for y in [.28,.69]:
		IRArt.block(root,Vector3(3.3,.095,.09),Vector3(0,y,-.04),wood)
	for i in range(12):
		var x: float=(i-5.5)*.275
		var height: float=.90+.09*cos(x*1.2)
		IRArt.block(root,Vector3(.125,height,.10),Vector3(x,height*.5,0),wood)
		var top: SurfaceTool=SurfaceTool.new()
		top.begin(Mesh.PRIMITIVE_TRIANGLES)
		for z in [-.051,.051]:
			for vertex in [Vector3(x-.0625,height,z),Vector3(x,height+.11,z),Vector3(x+.0625,height,z)]:
				top.set_normal(Vector3(0,0,signf(z)))
				top.add_vertex(vertex)
		IRArt.part(root,top.commit(),Vector3.ZERO,wood)
	for x in [-1.66,1.66]:
		IRArt.block(root,Vector3(.16,1.08,.16),Vector3(x,.52,0),wood)
		maker.ball(root,Vector3(x,1.08,0),Vector3(.23,.13,.23),maker.trim())
	maker=null
	return root

func mailbox(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var paint: Material=maker.paint("mailbox_blue","829bab",.60)
	IRArt.block(root,Vector3(.12,1.2,.12),Vector3(0,.6,0),weathered("c8bda7"))
	IRArt.block(root,Vector3(.50,.28,.56),Vector3(0,1.20,0),paint)
	var cap: SurfaceTool=SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(12):
		var a: float=PI*i/12
		var b: float=PI*(i+1)/12
		maker.quad(cap,Vector3(cos(b)*.25,1.34+sin(b)*.22,-.28),Vector3(cos(a)*.25,1.34+sin(a)*.22,-.28),Vector3(cos(b)*.25,1.34+sin(b)*.22,.28),Vector3(cos(a)*.25,1.34+sin(a)*.22,.28))
	IRArt.part(root,cap.commit(),Vector3.ZERO,paint)
	maker.panel(root,Vector3(0,1.07,.285),.45,.46,paint)
	IRArt.block(root,Vector3(.26,.035,.016),Vector3(0,1.31,.30),maker.paint("mail_slot","4c5962",.82))
	IRArt.block(root,Vector3(.035,.25,.035),Vector3(.30,1.39,0),maker.paint("mail_flag","cf8f9f",.75))
	IRArt.block(root,Vector3(.15,.11,.025),Vector3(.36,1.53,0),maker.paint("mail_flag","cf8f9f",.75))
	maker=null
	return root

func rose_arbor(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var frame: Material=weathered("d1c9b4")
	for z in [-.85,.85]:
		for side in [-1.0,1.0]:
			IRArt.tube(root,Vector3(side*1.3,-.08,z),Vector3(side*1.3,2.7,z),.065,frame)
		var points: Array[Vector3]=[]
		var radii: Array[float]=[]
		for i in range(25):
			var a: float=PI*i/24
			points.append(Vector3(cos(a)*1.3,2.7+sin(a)*1.3,z))
			radii.append(.065)
		maker.botanicals.path(root,points,radii,frame,Color.WHITE,8)
	for i in range(9):
		var a: float=PI*i/8
		IRArt.tube(root,Vector3(cos(a)*1.3,2.7+sin(a)*1.3,-.95),Vector3(cos(a)*1.3,2.7+sin(a)*1.3,.95),.045,frame)
	for side in [-1.0,1.0]:
		for i in range(6):
			IRArt.tube(root,Vector3(side*1.3,.25+i*.43,-.85),Vector3(side*1.3,.25+i*.43,.85),.025,frame)
	var petals: SurfaceTool=SurfaceTool.new()
	petals.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(52):
		var a: float=PI*(i%26)/25.0
		var p: Vector3=Vector3(cos(a)*1.35,2.7+sin(a)*1.35,-.92 if i<26 else .92)
		var normal: Vector3=Vector3(cos(a)*.4,.3,-1 if i<26 else 1).normalized()
		maker.botanicals.bloom(petals,p,.16,true,Color("edb0bd") if i%3 else Color("fff0db"),normal)
		maker.botanicals.leaf(leaves,p-Vector3.UP*.1,Basis.looking_at(-normal,Vector3.UP).rotated(normal,a),.31,.11,Color("79985c"))
	for side in [-1.0,1.0]:
		for i in range(8):
			var p: Vector3=Vector3(side*1.31,.4+i*.29,sin(i*1.4)*.8)
			maker.botanicals.bloom(petals,p,.13,true,Color("f0baca"),Vector3(side,.3,0).normalized())
	IRArt.part(root,petals.commit(),Vector3.ZERO,maker.botanicals.mat("petals",15,true))
	IRArt.part(root,leaves.commit(),Vector3.ZERO,maker.botanicals.mat("plant_leaves",14,true))
	maker=null
	return root

func pavilion_details(root: Node3D, author: RefCounted) -> void:
	maker=author
	var rail: Material=maker.paint("gazebo_rail","a6a8b7",.72)
	for i in range(8):
		if i in [1,5]:
			continue
		var a: Vector3=Vector3(cos(i*TAU/8)*3,0,sin(i*TAU/8)*3)
		var b: Vector3=Vector3(cos((i+1)*TAU/8)*3,0,sin((i+1)*TAU/8)*3)
		IRArt.tube(root,a+Vector3.UP*1.55,b+Vector3.UP*1.55,.065,rail)
		IRArt.tube(root,a+Vector3.UP*.65,b+Vector3.UP*.65,.045,rail)
		for j in range(5):
			var p: Vector3=a.lerp(b,(j+.5)/5.0)
			IRArt.tube(root,p+Vector3.UP*.65,p+Vector3.UP*1.55,.027,maker.trim())
	for i in range(8):
		var a: float=i*TAU/8
		var p: Vector3=Vector3(cos(a)*3,0,sin(a)*3)
		IRArt.block(root,Vector3(.38,.32,.38),p+Vector3.UP*.60,maker.stone())
		maker.ball(root,p+Vector3.UP*4.55,Vector3(.36,.32,.36),maker.trim())
	maker=null

func dock_supplies(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var wood: Material=weathered("b5a997")
	var iron: Material=maker.paint("barrel_hoops","6c6b72",.65,.35)
	for p in [Vector3(-.58,0,0),Vector3(.14,0,-.63)]:
		var body: Array[Vector2]=[Vector2(.35,.04),Vector2(.43,.20),Vector2(.48,.65),Vector2(.43,1.10),Vector2(.35,1.28)]
		maker.lathe(root,body,p,wood,24)
		for y in [.22,.65,1.08]:
			var r: float=.49 if y==.65 else .445
			var band: Array[Vector2]=[Vector2(r,y-.045),Vector2(r,y+.045)]
			maker.lathe(root,band,p,iron,24)
		var cap: CylinderMesh=CylinderMesh.new()
		cap.top_radius=.35
		cap.bottom_radius=.35
		cap.height=.035
		cap.radial_segments=24
		IRArt.part(root,cap,p+Vector3.UP*1.27,wood)
	var crate: Vector3=Vector3(.80,.48,.36)
	IRArt.block(root,Vector3(1.1,.90,1.0),crate,wood)
	for side in [-1.0,1.0]:
		for y in [-.35,0,.35]:
			IRArt.block(root,Vector3(1.12,.075,.045),crate+Vector3(0,y,side*.53),maker.trim())
		for x in [-.48,.48]:
			IRArt.block(root,Vector3(.075,.9,.07),crate+Vector3(x,0,side*.54),wood)
		var brace: MeshInstance3D=IRArt.block(root,Vector3(1.18,.075,.075),crate+Vector3(0,0,side*.56),wood)
		brace.rotation.z=side*.62
	var coil: Array[Vector3]=[]
	var radii: Array[float]=[]
	for i in range(130):
		var t: float=i/129.0
		var a: float=t*TAU*4
		coil.append(Vector3(cos(a)*lerpf(.16,.46,t)-.35,.055,sin(a)*lerpf(.16,.46,t)+.92))
		radii.append(.023)
	maker.botanicals.path(root,coil,radii,maker.paint("dock_rope","d9cbb1",.96),Color.WHITE,6)
	maker=null
	return root

func garden_planter(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	IRArt.block(root,Vector3(2.08,.08,1.42),Vector3(0,.15,0),maker.paint("garden_soil","71604a",.99))
	for side in [-1.0,1.0]:
		for i in range(8):
			IRArt.block(root,Vector3(.265,.25,.18),Vector3((i-3.5)*.275,.125,side*.78),maker.stone())
		for i in range(5):
			IRArt.block(root,Vector3(.18,.25,.265),Vector3(side*1.10,.125,(i-2)*.275),maker.stone())
	maker=null
	return root
