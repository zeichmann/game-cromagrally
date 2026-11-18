extends RefCounted
## Original curved architecture, individual roof tiles and a branching leafy elder.
var maker: RefCounted=preload("res://tools/fairy_asset_builder.gd").new()
var report: Dictionary={}
var random: RandomNumberGenerator=RandomNumberGenerator.new()

func paint(key: String,hex: String,kind: int=0,roughness: float=.85) -> Material:
	var material: Material=maker.paint("tea_"+key,hex,roughness)
	material.set_meta("palette_kind",kind)
	return material

func box(root: Node3D,size: Vector3,p: Vector3,material: Material,radius: float=.08) -> MeshInstance3D:
	return IRTeaGeometry.rounded_box(root,size,p,material,radius)

func lathe(root: Node3D,profile: Array[Vector2],p: Vector3,material: Material,segments: int=24) -> void:
	maker.lathe(root,profile,p,material,segments)

func branch(root: Node3D,controls: Array[Vector3],radii: Array[float],material: Material,radial: int=12) -> void:
	var points: Array[Vector3]=[]
	var sizes: Array[float]=[]
	for i in range(controls.size()-1):
		for step in range(7):
			var t: float=step/7.0
			points.append(controls[i].cubic_interpolate(controls[i+1],controls[maxi(i-1,0)],controls[mini(i+2,controls.size()-1)],t))
			sizes.append(lerpf(radii[i],radii[i+1],t))
	points.append(controls[-1])
	sizes.append(radii[-1])
	maker.botanicals.path(root,points,sizes,material,Color.WHITE,radial,true)

func face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color=Color.WHITE) -> void:
	var points: Array[Vector3]=[a,b,c,d]
	var uv: Array[Vector2]=[Vector2.ZERO,Vector2(0,1),Vector2(1,0),Vector2.ONE]
	var normal: Vector3=(c-a).cross(b-a).normalized()
	for k in [0,1,2,2,1,3]:
		st.set_normal(normal)
		st.set_color(color)
		st.set_uv(uv[k])
		st.add_vertex(points[k])

func roof_y(x: float,z: float) -> float:
	var u: float=absf((x-.22)/4.55)
	return 9.7-3.55*pow(u,.79)+.65*pow(u,5)+.22*sin(z*.52)+.08*x

func roof(root: Node3D) -> void:
	var underlay: SurfaceTool=SurfaceTool.new()
	underlay.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(64):
		var x0: float=-4.37+n*9.21/64
		var x1: float=-4.37+(n+1)*9.21/64
		for m in range(20):
			var z0: float=-3.85+m*8.0/20
			var z1: float=-3.85+(m+1)*8.0/20
			face(underlay,Vector3(x0,roof_y(x0,z0)-.06,z0),Vector3(x1,roof_y(x1,z0)-.06,z0),Vector3(x0,roof_y(x0,z1)-.06,z1),Vector3(x1,roof_y(x1,z1)-.06,z1))
	var soffit: StandardMaterial3D=paint("roof_underlay","454d48",40)
	soffit.cull_mode=BaseMaterial3D.CULL_DISABLED
	IRArt.part(root,underlay.commit(),Vector3.ZERO,soffit)
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors: Array[Color]=[Color("596d76"),Color("647b80"),Color("70858a"),Color("536772"),Color("7a8c86")]
	for side in [-1.0,1.0]:
		for row in range(14):
			var x0: float=.22+side*(row/14.0)*4.55
			var x1: float=.22+side*((row+1.15)/14.0)*4.55
			for column in range(17):
				var z0: float=-3.8+column*.46+(row%2)*.23
				var z1: float=minf(z0+.445,4.05)
				if z0>3.9: continue
				var color: Color=colors[(column*7+row*3)%colors.size()]
				for step in range(3):
					var a: float=lerpf(x0,x1,step/3.0)
					var b: float=lerpf(x0,x1,(step+1)/3.0)
					var za: float=z0+(.055 if step==2 else 0)
					var zb: float=z1-(.055 if step==2 else 0)
					var p: Vector3=Vector3(a,roof_y(a,z0)+.04,z0)
					var q: Vector3=Vector3(b,roof_y(b,z0)+.04,za)
					var r: Vector3=Vector3(a,roof_y(a,z1)+.04,z1)
					var s: Vector3=Vector3(b,roof_y(b,z1)+.04,zb)
					if side>0: face(st,p,q,r,s,color)
					else: face(st,q,p,s,r,color)
					if step==2:
						if side>0: face(st,q,q-Vector3.UP*.085,s,s-Vector3.UP*.085,color*.82)
						else: face(st,s,s-Vector3.UP*.085,q,q-Vector3.UP*.085,color*.82)
	var tiles: Material=paint("slate","ffffff",40)
	tiles.vertex_color_use_as_albedo=true
	tiles.vertex_color_is_srgb=true
	IRArt.part(root,st.commit(),Vector3.ZERO,tiles)
	for z in [-3.86,4.10]:
		var controls: Array[Vector3]=[]
		var radii: Array[float]=[]
		for n in range(19):
			var x: float=-4.37+n*9.1/18
			controls.append(Vector3(x,roof_y(x,z)-.08,z))
			radii.append(.11)
		branch(root,controls,radii,paint("fascia","c0a276",21),8)
	branch(root,[Vector3(.22,9.8,-3.9),Vector3(.25,9.95,0),Vector3(.18,9.9,4.25)],[.16,.14,.10],paint("ridge","a0a596",21),10)

func window(root: Node3D,p: Vector3,width: float,height: float,round_top: bool=true) -> void:
	var wood: Material=paint("window_wood","546a65",21)
	if round_top:
		maker.panel(root,p,width+.28,height+.20,paint("window_stone","e5d0a0",1))
		maker.panel(root,p+Vector3(0,.10,.035),width,height-.03,wood)
		maker.panel(root,p+Vector3(0,.19,.055),width-.17,height-.23,paint("window_glass","d6b775",4,.25))
	else:
		box(root,Vector3(width+.20,height+.20,.14),p+Vector3.UP*height*.5,wood,.05)
		box(root,Vector3(width-.09,height-.09,.045),p+Vector3(0,height*.5,.095),paint("window_glass","c5b289",4,.25),.025)
	for n in range(3):
		box(root,Vector3(.045,height-.16,.075),p+Vector3((n-1)*width*.29,height*.5,.13),wood,.012)
	box(root,Vector3(width,.055,.075),p+Vector3(0,height*.48,.14),wood,.012)
	box(root,Vector3(width+.38,.14,.38),p+Vector3(0,.01,.13),paint("sill","b8aa86",1),.05)

func house() -> Node3D:
	var root: Node3D=Node3D.new()
	var plaster: Material=paint("plaster","dfc995",20)
	var wood: Material=paint("beams","725943",21)
	var trim: Material=paint("trim","d8b77e",21)
	var stone: Material=paint("foundation","a49d85",1)
	box(root,Vector3(7.8,.7,5.9),Vector3(0,.28,0),stone,.20)
	box(root,Vector3(7.15,3.0,5.35),Vector3(0,2.05,0),plaster,.23)
	box(root,Vector3(7.65,3.12,5.7),Vector3(.16,5.02,0),plaster,.18)
	box(root,Vector3(7.9,.25,5.98),Vector3(.13,3.58,0),wood,.07)
	# A genuine curved gable closes both roof ends; no rectangular wall behind it.
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-2.87,2.88]:
		for n in range(28):
			var x0: float=-3.66+n*7.66/28
			var x1: float=-3.66+(n+1)*7.66/28
			var a: Vector3=Vector3(x0,6.55,z)
			var b: Vector3=Vector3(x0,roof_y(x0,z)-.12,z)
			var c: Vector3=Vector3(x1,6.55,z)
			var d: Vector3=Vector3(x1,roof_y(x1,z)-.12,z)
			if z>0: face(st,a,b,c,d)
			else: face(st,c,d,a,b)
	IRArt.part(root,st.commit(),Vector3.ZERO,plaster)
	# Close the attic along both eaves as well as the front and rear gables.
	var infill: SurfaceTool=SurfaceTool.new()
	infill.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-3.66,3.985]:
		for n in range(20):
			var z0: float=-2.85+n*5.7/20
			var z1: float=-2.85+(n+1)*5.7/20
			var a: Vector3=Vector3(x,6.5,z0)
			var b: Vector3=Vector3(x,roof_y(x,z0)-.06,z0)
			var c: Vector3=Vector3(x,6.5,z1)
			var d: Vector3=Vector3(x,roof_y(x,z1)-.06,z1)
			if x<0: face(infill,a,b,c,d)
			else: face(infill,c,d,a,b)
	IRArt.part(root,infill.commit(),Vector3.ZERO,plaster)
	roof(root)
	for x in [-3.42,-.10,3.60]:
		branch(root,[Vector3(x,.65,2.78),Vector3(x+.10,3.6,2.94),Vector3(x-.06,6.60,2.96)],[.095,.10,.08],wood,8)
	for z in [-2.72,2.72]:
		for side in [-1.0,1.0]:
			branch(root,[Vector3(side*3.55,.6,z),Vector3(side*3.76,3.6,z),Vector3(side*3.80,6.6,z)],[.095,.105,.08],wood,8)
	for side in [-1.0,1.0]:
		var facade: Node3D=Node3D.new()
		window(facade,Vector3(-1.15,4.10,0),.92,1.7)
		window(facade,Vector3(1.15,4.10,0),.92,1.7)
		window(facade,Vector3(-.55,1.0,-.01),1.50,1.78)
		box(facade,Vector3(1.90,.24,.52),Vector3(-.55,.93,.17),wood,.06)
		for n in range(3): maker.architecture.pot(facade,Vector3(-1.15+n*.60,1.07,.17),"rose",.52)
		maker.architecture.attach(root,facade,Vector3(.16+side*3.85,0,0),side*PI*.5)
		IRArt.tube(root,Vector3(side*3.88,3.69,-2.5),Vector3(side*3.88,4.70,-1.4),.07,wood)
		IRArt.tube(root,Vector3(side*3.88,3.69,2.5),Vector3(side*3.88,4.70,1.4),.07,wood)
	# Door, glazing recess, individual planks, hinges, latch and arched masonry.
	maker.panel(root,Vector3(-1.9,.55,2.74),1.75,2.75,paint("door_recess","574b3c"))
	maker.panel(root,Vector3(-1.9,.66,2.79),1.43,2.49,paint("door","5b7564",21))
	for n in range(7):
		var x: float=-1.9+(n-3)*.184
		box(root,Vector3(.018,1.75,.035),Vector3(x,1.56,2.83),wood,.006)
	for y in [1.02,2.10]: box(root,Vector3(.54,.085,.055),Vector3(-2.3,y,2.86),paint("iron","655b4d",3,.60),.02)
	maker.ball(root,Vector3(-1.40,1.76,2.91),Vector3(.12,.12,.10),paint("brass","c2a35d",3,.36))
	for n in range(15):
		var a: float=PI*n/14
		var piece: MeshInstance3D=box(root,Vector3(.24,.25,.27),Vector3(-1.9+cos(a)*.88,2.45+sin(a)*.88,2.84),stone,.045)
		piece.rotation.z=a-PI*.5
	# Deep, three-facet shop bay with an overhanging copper hood.
	box(root,Vector3(3.40,.25,1.45),Vector3(1.35,1.12,3.12),wood,.12)
	for n in range(3):
		var facet: Node3D=Node3D.new()
		window(facet,Vector3.ZERO,1.05,1.92,false)
		var yaw: float=(n-1)*.53
		maker.architecture.attach(root,facet,Vector3(1.35+(n-1)*1.08,1.25,3.42-(.29 if n!=1 else 0)),yaw)
	box(root,Vector3(3.65,.24,1.7),Vector3(1.35,3.28,3.12),trim,.13)
	for side in [-1.0,1.0]:
		window(root,Vector3(side*1.80+.15,4.22,2.94),1.20,1.72)
		for shutter in [-1.0,1.0]:
			var x: float=side*1.8+.15+shutter*.91
			box(root,Vector3(.43,1.59,.10),Vector3(x,5.03,2.99),paint("shutter","6f8270",21),.035)
			for y in range(7): box(root,Vector3(.36,.045,.13),Vector3(x,4.40+y*.19,3.03),trim,.012)
		box(root,Vector3(1.8,.24,.54),Vector3(side*1.8+.15,4.14,3.12),wood,.065)
		for n in range(3): maker.architecture.pot(root,Vector3(side*1.8-.45+n*.60,4.28,3.19),"rose",.53)
	window(root,Vector3(.25,7.02,2.95),.92,1.25)
	for side in [-1.0,1.0]: IRArt.tube(root,Vector3(side*2.85,6.48,3.0),Vector3(side*1.13,8.28,3.0),.065,wood)
	# Proportioned porch roof and carved supports around the entrance.
	var awning: MeshInstance3D=box(root,Vector3(2.65,.18,1.85),Vector3(-1.85,3.65,3.45),paint("porch_roof","657b77",40),.08)
	awning.rotation.x=-.16
	for x in [-3.0,-.70]:
		branch(root,[Vector3(x,.5,4.1),Vector3(x,2.7,4.05),Vector3(x,3.5,4.0)],[.095,.08,.10],wood,10)
		branch(root,[Vector3(x,2.7,4.0),Vector3(x,3.18,3.78),Vector3(x,3.5,3.30)],[.075,.05,.035],wood,8)
	for n in range(3): box(root,Vector3(2.65,.15,.40),Vector3(-1.85,.20+n*.13,4.36-n*.36),stone,.055)
	# Tall crooked chimney and a copper rain gutter with a real downpipe.
	branch(root,[Vector3(-2.3,6.1,-1.3),Vector3(-2.4,9.6,-1.35),Vector3(-2.0,11.3,-1.3)],[.46,.42,.35],stone,4)
	box(root,Vector3(1.05,.24,.98),Vector3(-2.0,11.30,-1.3),trim,.06)
	for x in [-4.37,4.75]:
		branch(root,[Vector3(x,roof_y(x,-3.7)-.05,-3.75),Vector3(x,roof_y(x,0)-.05,0),Vector3(x,roof_y(x,4)-.05,4.0)],[.075,.075,.075],paint("copper","8d8d69",3,.67),8)
	branch(root,[Vector3(3.95,6.35,2.6),Vector3(4.02,3.2,2.6),Vector3(3.98,.60,2.9)],[.055,.055,.055],paint("copper","8d8d69",3,.67),8)
	var plaque: Node3D=Node3D.new()
	box(plaque,Vector3(3.65,.48,.13),Vector3.ZERO,paint("plaque","526b5c",21),.13)
	maker.living.maker=maker
	maker.living.label(plaque,"HERBACIARNIA",Vector3(0,0,.084),3.20)
	maker.living.maker=null
	maker.architecture.attach(root,plaque,Vector3(.10,3.75,2.99),0)
	maker.architecture.wall_lantern(root,Vector3(-3.34,2.72,2.96))
	var sign_iron: Material=paint("sign_iron","564d3d",3,.70)
	IRArt.tube(root,Vector3(3.25,5.1,2.97),Vector3(3.25,5.1,4.66),.035,sign_iron)
	IRArt.tube(root,Vector3(3.25,4.5,2.97),Vector3(3.25,5.1,4.35),.028,sign_iron)
	IRArt.tube(root,Vector3(2.7,5.1,4.6),Vector3(3.82,5.1,4.6),.035,sign_iron)
	return root

func teapot(root: Node3D,p: Vector3,size: float,material: Material) -> void:
	var profile: Array[Vector2]=[Vector2(.03,0),Vector2(.25,.03),Vector2(.36,.22),Vector2(.34,.40),Vector2(.24,.47)]
	var pot: Node3D=Node3D.new()
	lathe(pot,profile,Vector3.ZERO,material,24)
	lathe(pot,[Vector2(.29,.47),Vector2(.24,.53),Vector2(.04,.58)],Vector3.ZERO,material,24)
	maker.ball(pot,Vector3(0,.60,0),Vector3(.10,.08,.10),paint("brass","c2a35d",3,.36))
	branch(pot,[Vector3(.24,.20,0),Vector3(.45,.29,0),Vector3(.55,.51,0)],[.12,.085,.05],material,10)
	var ring: MeshInstance3D=IRArt.ring(pot,.23,.04,Vector3(-.35,.29,0),material)
	ring.rotation.x=PI*.5
	for child in pot.get_children():
		pot.remove_child(child)
		child.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),p)*child.transform
		root.add_child(child)
	pot.free()

func signboard() -> Node3D:
	var root: Node3D=Node3D.new()
	var metal: Material=paint("sign_iron","564d3d",3,.70)
	for x in [-.48,.48]:
		for n in range(5):
			var ring: MeshInstance3D=IRArt.ring(root,.045,.012,Vector3(x,-.05-n*.065,0),metal)
			if n%2: ring.rotation.x=PI*.5
	box(root,Vector3(1.66,1.08,.15),Vector3(0,-.94,0),paint("sign_base","465f4e",21),.20)
	teapot(root,Vector3(-.05,-1.20,.16),1.0,paint("sign_pot","d7b879",3,.55))
	for side in [-1.0,1.0]:
		branch(root,[Vector3(side*.68,-1.30,.12),Vector3(side*.73,-.95,.12),Vector3(side*.58,-.55,.12)],[.025,.018,.008],paint("sign_trim","d5b77a",3,.6),7)
	return root

func oak_leaf(st: SurfaceTool,p: Vector3,orientation: Basis,length: float,width: float,color: Color) -> void:
	for row in range(6):
		var points: Array[Vector3]=[]
		var uv: Array[Vector2]=[]
		for t in [row/6.0,(row+1)/6.0]:
			for side in [-1.0,0.0,1.0]:
				var span: float=sin(t*PI)*width*(.88+.12*cos(t*PI*7))
				points.append(Vector3(side*span,t*length,sin(t*PI)*(1-absf(side))*.11*length+t*t*.11*length))
				uv.append(Vector2((side+1)*.5,t))
		for side in range(2):
			for k in [side,side+3,side+1,side+1,side+3,side+4]:
				st.set_color(color)
				st.set_uv(uv[k])
				st.set_normal((orientation*Vector3(-(uv[k].x-.5)*.45,-uv[k].y*.15,1)).normalized())
				st.add_vertex(p+orientation*points[k])

func tree() -> Node3D:
	var root: Node3D=Node3D.new()
	var bark: Material=paint("ancient_bark","c9bc9c",36)
	branch(root,[Vector3(0,-.55,0),Vector3(.6,2.9,.4),Vector3(-.7,6.5,.2),Vector3(-1.8,10.3,-.9),Vector3(-.3,14.6,-.8)],[1.95,1.50,1.15,.68,.06],bark,28)
	for i in range(9):
		var a: float=TAU*i/9+.21
		var ray: Vector3=Vector3(cos(a),0,sin(a))
		branch(root,[ray*.65+Vector3.UP*1.1,ray*2.5+Vector3.UP*.1,ray*(4.2+(i%3)*.55)-Vector3.UP*.25],[.70,.44,.025],bark,12)
	var crowns: Array[Vector3]=[
		Vector3(-6.6,11.5,-3.3),Vector3(-3.9,14.2,-3.1),Vector3(.2,15.5,-2),Vector3(3.7,14.4,-2.8),Vector3(7.6,11.9,-2.2),
		Vector3(-8.4,9.7,.2),Vector3(-4.3,11.8,.8),Vector3(-.1,13.4,1.2),Vector3(4.3,12.3,1.6),Vector3(8.3,10.7,.8),
		Vector3(-6.5,10.4,4.7),Vector3(-2.6,12.2,4.4),Vector3(1.6,13.0,4.8),Vector3(5.7,10.6,4.3),
		Vector3(-5.4,12.9,-6.7),Vector3(-.8,14.3,-6.5),Vector3(3.7,12.5,-6.7),Vector3(6.7,10.0,-5.6)]
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	random.seed=184026
	for i in range(crowns.size()):
		var end: Vector3=crowns[i]
		var start: Vector3=Vector3(-.4,6.9+(i%4)*.65,.1)
		var middle: Vector3=start.lerp(end,.55)+Vector3.UP*1.0
		branch(root,[start,middle,end-Vector3.UP*.25],[.48 if i%3==0 else .34,.22,.035],bark,12)
		for twig in range(5):
			var a: float=twig*TAU/5+i*.7
			var tip: Vector3=end+Vector3(cos(a)*2.4,.45+sin(a*2)*.35,sin(a)*1.8)
			branch(root,[middle.lerp(end,.8),end,tip],[.10,.06,.007],bark,7)
		for n in range(260):
			var a: float=random.randf()*TAU
			var r: float=sqrt(random.randf())
			var p: Vector3=end+Vector3(cos(a)*3.0*r,random.randf_range(-.55,.75)+.5*(1-r*r),sin(a)*2.5*r)
			var normal: Vector3=Vector3(cos(a)*.25,random.randf_range(.55,1.0),sin(a)*.25).normalized()
			var orientation: Basis=Basis.looking_at(-normal).rotated(normal,random.randf()*TAU)
			var shade: float=clampf((p.y-9)/8.0+random.randf_range(-.25,.22),0,1)
			var color: Color=Color("3c6450").lerp(Color("9aaa66"),shade)
			oak_leaf(leaves,p,orientation,random.randf_range(.72,1.18),random.randf_range(.26,.42),color)
	IRArt.part(root,leaves.commit(),Vector3.ZERO,maker.botanicals.mat("tea_leaves",37,true))
	# Small hanging lanterns and mushrooms reward a closer look at the roots.
	for i in range(5):
		var p: Vector3=Vector3(-4.5+i*2.2,7.6+sin(i*.9)*.6,3.8)
		IRArt.tube(root,p+Vector3.UP*1.4,p,.018,paint("lantern_wire","79705a"))
		maker.architecture.wall_lantern(root,p)
	return root

func garden() -> Node3D:
	var root: Node3D=Node3D.new()
	var wood: Material=paint("garden_wood","8e7858",21)
	var stone: Material=paint("garden_stone","b9ad8c",1)
	# Terrace, edging, slatted tables and individual chairs with curved backs.
	box(root,Vector3(8.5,.32,5.6),Vector3(0,-.10,0),stone,.18)
	for x in [-2.5,1.8]:
		lathe(root,[Vector2(.68,.80),Vector2(.76,.84),Vector2(.76,.92),Vector2(.68,.95)],Vector3(x,0,.2),wood,28)
		IRArt.tube(root,Vector3(x,.05,.2),Vector3(x,.84,.2),.08,wood)
		for n in range(3):
			var a: float=n*TAU/3+.3
			var p: Vector3=Vector3(x+cos(a)*1.20,0,.2+sin(a)*1.2)
			var chair: Node3D=Node3D.new()
			box(chair,Vector3(.50,.10,.46),Vector3(0,.48,0),wood,.06)
			for side in [-1.0,1.0]:
				for z in [-.15,.15]: IRArt.tube(chair,Vector3(side*.18,0,z),Vector3(side*.18,.48,z),.028,wood)
				branch(chair,[Vector3(side*.20,.35,-.17),Vector3(side*.22,.85,-.22),Vector3(side*.18,1.02,-.20)],[.035,.035,.035],wood,7)
			branch(chair,[Vector3(-.18,1.02,-.20),Vector3(0,1.06,-.21),Vector3(.18,1.02,-.20)],[.04,.04,.04],wood,7)
			maker.architecture.attach(root,chair,p,-a-PI*.5)
		teapot(root,Vector3(x,.96,.15),.60,paint("ceramic","d6c6a6",0,.40))
		for n in range(2):
			lathe(root,[Vector2(.10,.0),Vector2(.12,.14),Vector2(.13,.15)],Vector3(x+(n*2-1)*.35,.96,.46),paint("ceramic","d6c6a6",0,.40),16)
			IRArt.ring(root,.15,.02,Vector3(x+(n*2-1)*.35,.965,.46),paint("ceramic","d6c6a6",0,.40))
	for side in [-1.0,1.0]:
		for n in range(8):
			var x: float=-4.0+n*1.14
			if side>0 and n in [3,4]: continue
			IRArt.tube(root,Vector3(x,0,side*2.65),Vector3(x,1.05,side*2.65),.04,wood)
		branch(root,[Vector3(-4.1,.90,side*2.65),Vector3(0,.83,side*2.65),Vector3(4.1,.90,side*2.65)],[.055,.055,.055],wood,8)
	for x in [-3.9,3.9]: maker.architecture.pot(root,Vector3(x,.10,-1.8),"rose",1.15)
	return root

func save(key: String,root: Node3D) -> void:
	var baked: MeshInstance3D=IRArt.bake(root)
	var importer: ImporterMesh=ImporterMesh.from_mesh(baked.mesh)
	importer.generate_lods(60.0,25.0,[])
	var mesh: ArrayMesh=importer.get_mesh()
	var vertices: int=0
	var triangles: int=0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array=mesh.surface_get_arrays(surface)
		vertices+=arrays[Mesh.ARRAY_VERTEX].size()
		triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
	assert(ResourceSaver.save(mesh,"res://assets/tea_bend/"+key+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	report[key]={"surfaces":mesh.get_surface_count(),"vertices":vertices,"triangles":triangles}
	root.free()

func build() -> void:
	maker.enchanted.maker=maker
	maker.architecture.maker=maker
	DirAccess.make_dir_recursive_absolute("res://assets/tea_bend")
	save("teahouse",house())
	save("ancient_oak",tree())
	save("tea_garden",garden())
	save("teapot_sign",signboard())
	var file: FileAccess=FileAccess.open("res://assets/tea_bend/mesh_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	maker.enchanted.maker=null
	maker.architecture.maker=null
	print("TEA_ASSETS ",JSON.stringify(report))
