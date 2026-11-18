extends RefCounted
## Original modular streets, grotto and woodland. Authored once; loaded as LOD meshes.
var maker: RefCounted

func begin(author: RefCounted) -> Node3D:
	maker=author
	maker.enchanted.maker=author
	maker.architecture.maker=author
	return Node3D.new()

func finish(root: Node3D) -> Node3D:
	maker.enchanted.maker=null
	maker.architecture.maker=null
	maker=null
	return root

func box(root: Node3D,size: Vector3,p: Vector3,material: Material,radius: float=.12) -> void:
	maker.enchanted.rounded_box(root,size,p,material,radius)

func label(root: Node3D,text_value: String,p: Vector3,width: float,color: String="f7e5b8") -> void:
	var text: TextMesh=TextMesh.new()
	text.font=preload("res://assets/fonts/Barlow-Medium.ttf")
	text.text=text_value
	text.font_size=64
	text.pixel_size=width/maxf(text_value.length()*35.0,1)
	text.depth=.014
	text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	IRArt.part(root,text,p,maker.paint("letters_"+color,color,.8))

func townhouse(author: RefCounted,variant: int) -> Node3D:
	var root: Node3D=begin(author)
	var height: float=[7.5,8.6,7.9][variant]
	var plaster: Material=maker.paint("wall_town_%d"%variant,["c7a38b","a3b9b1","d8bb87"][variant],.89)
	var timber: Material=maker.paint("town_timber","786555",.86)
	var door: Material=maker.paint("town_door_%d"%variant,["658e89","8d6672","667c91"][variant],.8)
	var tiles: Material=maker.textured("town_roof%d"%variant,"fairy_roof",["5b7f9f","a46e83","667f62"][variant],.85)
	box(root,Vector3(5.4,.6,4.9),Vector3(0,.2,0),maker.stone(),.16)
	box(root,Vector3(5.05,3.1,4.45),Vector3(0,1.9,0),plaster,.22)
	box(root,Vector3(5.65,height-3.35,4.8),Vector3(.16,(height+3.35)*.5,0),plaster,.22)
	box(root,Vector3(5.85,.24,5.0),Vector3(.16,3.45,0),timber,.07)
	maker.architecture.gables(root,2.8,4.8,height,2.8,3.2,plaster)
	maker.roof(root,3.2,5.7,height,2.8,tiles)
	for x in [-2.48,0,2.48]:
		box(root,Vector3(.14,height-3.2,.16),Vector3(x,3.3+(height-3.2)*.5,2.47),timber,.04)
	for side in [-1.0,1.0]:
		var facade: Node3D=Node3D.new()
		for z in [-1.35,1.15]:
			maker.window(facade,Vector3(z,4.18,0),.85,1.6)
			maker.window(facade,Vector3(z,height-1.25,0),.65,1.0)
			box(facade,Vector3(.11,height-3.3,.12),Vector3(z+( .60 if z<0 else -.60),(height+3.3)*.5,.02),timber,.025)
		maker.architecture.attach(root,facade,Vector3(.16+side*2.84,0,0),side*PI*.5)
		for z in [-2.23,2.23]:
			box(root,Vector3(.14,height-3.3,.15),Vector3(.16+side*2.90,(height+3.3)*.5,z),timber,.035)
		IRArt.tube(root,Vector3(.16+side*2.91,3.53,-2.15),Vector3(.16+side*2.91,4.20,-1.40),.055,timber)
		IRArt.tube(root,Vector3(.16+side*2.91,3.53,2.15),Vector3(.16+side*2.91,4.20,1.40),.055,timber)
	for side in [-1.0,1.0]:
		maker.window(root,Vector3(side*1.34,4.15,2.48),1.2,1.75)
		maker.architecture.shutters(root,Vector3(side*1.34,4.15,2.46),door)
		maker.window(root,Vector3(side*1.34,height-1.4,2.48),.8,1.15)
		IRArt.tube(root,Vector3(side*2.0,2.95,2.10),Vector3(side*2.0,3.32,2.50),.11,timber)
	maker.panel(root,Vector3(-1.30,.45,2.28),1.22,2.4,maker.trim())
	maker.panel(root,Vector3(-1.30,.51,2.32),.98,2.2,door)
	maker.window(root,Vector3(.95,1.05,2.29),1.8,1.7)
	for n in range(6):
		IRArt.block(root,Vector3(.27,.55,.10),Vector3(.18+n*.32,.83,2.40),timber)
	box(root,Vector3(2.5,.20,.68),Vector3(.95,1.12,2.65),timber,.07)
	box(root,Vector3(2.65,.19,1.0),Vector3(.15,4.02,2.83),timber,.08)
	for x in [-1.10,1.40]:
		IRArt.tube(root,Vector3(x,4.02,3.25),Vector3(x,4.94,3.25),.055,maker.trim())
	IRArt.tube(root,Vector3(-1.10,4.85,3.25),Vector3(1.4,4.85,3.25),.05,timber)
	for n in range(11):
		IRArt.tube(root,Vector3(-1.02+n*.235,4.10,3.24),Vector3(-1.02+n*.235,4.80,3.24),.025,timber)
	for x in [-.85,1.13]:
		maker.architecture.pot(root,Vector3(x,4.13,2.9),"rose",.63)
	var sign: Material=maker.paint("town_sign","466f68",.84)
	box(root,Vector3(3.9,.56,.15),Vector3(.12,3.04,2.50),sign,.08)
	label(root,["POCZTA","PRACOWNIA","HERBACIARNIA"][variant],Vector3(.12,3.04,2.60),3.55)
	var chimney: Vector3=Vector3(-1.6,height+1.1,-1.3)
	box(root,Vector3(.8,3.0,.8),chimney,maker.stone(),.10)
	box(root,Vector3(1.0,.20,1.0),chimney+Vector3.UP*1.4,maker.trim(),.06)
	maker.architecture.wall_lantern(root,Vector3(-2.0,2.25,2.53))
	if variant==0:
		box(root,Vector3(.65,1.1,.45),Vector3(-2.2,.9,2.6),maker.paint("post_red","aa5e53",.8),.15)
		box(root,Vector3(.44,.06,.025),Vector3(-2.2,1.23,2.84),timber,.015)
	else:
		for n in range(3):
			maker.ball(root,Vector3(.45+n*.55,1.32,2.7),Vector3(.25,.3,.25),maker.paint("shop_pots","c79a6c",.9))
	return finish(root)

func crane(author: RefCounted) -> Node3D:
	var root: Node3D=begin(author)
	var wood: Material=maker.architecture.weathered("a28b6c")
	var metal: Material=maker.paint("crane_iron","665e5d",.6,.4)
	box(root,Vector3(2,.35,2),Vector3(0,.1,0),maker.stone())
	IRArt.tube(root,Vector3(0,0,0),Vector3(.3,6.5,0),.24,wood,.17)
	IRArt.tube(root,Vector3(.2,5.9,0),Vector3(.1,6.9,4.2),.18,wood,.10)
	IRArt.tube(root,Vector3(.1,2.6,0),Vector3(.1,6.3,3.2),.12,wood)
	IRArt.tube(root,Vector3(.1,6.9,4.1),Vector3(.1,2.0,4.1),.025,maker.paint("rope","d3bb90",.95))
	var wheel: MeshInstance3D=IRArt.ring(root,.48,.065,Vector3(.4,1.5,.1),wood)
	wheel.rotation.y=PI*.5
	var hook: MeshInstance3D=IRArt.ring(root,.19,.035,Vector3(.1,1.85,4.1),metal)
	hook.rotation.x=PI*.5
	return finish(root)

func grotto(author: RefCounted) -> Node3D:
	var root: Node3D=begin(author)
	var stone: Material=maker.botanicals.mat("grotto_limestone",12)
	var control: Array[Vector3]=[Vector3(-4.4,-.6,0),Vector3(-4.5,2.4,0),Vector3(-3.1,5.1,0),Vector3(-.1,6.3,0),Vector3(2.9,5.1,0),Vector3(4.1,2.7,0),Vector3(4.3,-.6,0)]
	var radii: Array[float]=[1.25,1.35,1.2,1.4,1.15,1.3,1.3]
	for z in [-2.8,-1.7,-.6,.6,1.7,2.8]:
		var points: Array[Vector3]=[]
		for p in control: points.append(p+Vector3(0,0,z))
		maker.botanicals.path(root,points,radii,stone,Color("d0c8b0"),20,true)
	for side in [-1.0,1.0]:
		box(root,Vector3(2.0,3.0,5.8),Vector3(side*4.6,1.0,0),stone,.4)
		for n in range(3):
			var point: Vector3=Vector3(side*(2.7+n*.35),4.6-n*.8,-2.7)
			var crystal: CylinderMesh=CylinderMesh.new()
			crystal.top_radius=0
			crystal.bottom_radius=.23+n*.06
			crystal.height=1.1+n*.16
			crystal.radial_segments=5
			var glow: StandardMaterial3D=StandardMaterial3D.new()
			glow.albedo_color=Color("86b8b0") if side<0 else Color("c1abd1")
			glow.emission_enabled=true
			glow.emission=glow.albedo_color
			IRArt.part(root,crystal,point,glow).rotation.z=PI
	for n in range(3):
		var crystal: CylinderMesh=CylinderMesh.new()
		crystal.top_radius=0
		crystal.bottom_radius=.23+n*.035
		crystal.height=.85+n*.16
		crystal.radial_segments=6
		var glow: StandardMaterial3D=StandardMaterial3D.new()
		glow.albedo_color=Color("9ac3bc") if n%2==0 else Color("b3a4cb")
		glow.emission_enabled=true
		glow.emission=glow.albedo_color
		IRArt.part(root,crystal,Vector3(-1.6+n*1.6,4.7,-2.7),glow).rotation.z=PI
	return finish(root)

func forest_fern(author: RefCounted) -> Node3D:
	var root: Node3D=begin(author)
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(11):
		var a: float=TAU*n/11
		var ray: Vector3=Vector3(cos(a),0,sin(a))
		var points: Array[Vector3]=[]
		var widths: Array[float]=[]
		for j in range(15):
			var t: float=j/14.0
			var p: Vector3=ray*(.25+2.7*t)+Vector3.UP*(.15+3.8*sin(t*PI*.55))
			points.append(p)
			widths.append(lerpf(.07,.004,t))
			if j>1:
				for side in [-1.0,1.0]:
					var normal: Vector3=(Vector3.UP+ray*.4).normalized()
					var basis: Basis=Basis.looking_at(-normal,ray).rotated(normal,side*.95)
					maker.botanicals.leaf(leaves,p,basis,(.65+.24*sin(t*PI))*(1-t*.7),.13,Color("73944d").lerp(Color("b0b767"),t*.5))
		maker.botanicals.path(root,points,widths,maker.botanicals.mat("fern_stems",16,true),Color("7b8b4b"),6)
	IRArt.part(root,leaves.commit(),Vector3.ZERO,maker.botanicals.mat("fern_leaves",14,true))
	return finish(root)

func boulder(author: RefCounted) -> Node3D:
	var root: Node3D=begin(author)
	var sphere: SphereMesh=SphereMesh.new()
	sphere.radial_segments=24
	sphere.rings=16
	sphere.radius=1
	sphere.height=2
	var arrays: Array=sphere.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray=PackedColorArray()
	for i in range(points.size()):
		var p: Vector3=points[i]
		var scale_value: float=1+.16*sin(p.x*5+p.y*3)*cos(p.z*4)+.09*sin(p.z*7-p.y)
		points[i]=p*Vector3(2.6,1.8,2.0)*scale_value+Vector3.UP*.45
		colors.append(Color("c8c5aa").lerp(Color("70845c"),smoothstep(.1,.85,p.y)*.7))
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh: ArrayMesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var st: SurfaceTool=SurfaceTool.new()
	st.create_from(mesh,0)
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,maker.botanicals.mat("moss_boulders",12))
	return finish(root)

func lantern_mushroom(author: RefCounted) -> Node3D:
	var root: Node3D=begin(author)
	var stem: Array[Vector2]=[Vector2(.17,0),Vector2(.13,.15),Vector2(.11,.6),Vector2(.16,1.0)]
	var cap: Array[Vector2]=[Vector2(.02,1.0),Vector2(.36,.97),Vector2(.67,1.02),Vector2(.64,1.15),Vector2(.43,1.39),Vector2(.18,1.50),Vector2(.01,1.52)]
	maker.lathe(root,stem,Vector3.ZERO,maker.paint("mushroom_stem","d5ccb4",.88),24)
	var glow: StandardMaterial3D=StandardMaterial3D.new()
	glow.albedo_color=Color("8db6ad")
	glow.roughness=.53
	glow.emission_enabled=true
	glow.emission=glow.albedo_color
	maker.lathe(root,cap,Vector3.ZERO,glow,32)
	for n in range(12):
		var a: float=TAU*n/12
		IRArt.tube(root,Vector3(cos(a)*.15,1.015,sin(a)*.15),Vector3(cos(a)*.56,1.04,sin(a)*.56),.014,maker.trim())
	return finish(root)
