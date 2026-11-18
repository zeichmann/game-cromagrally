extends RefCounted
## Offline sculpting of broad, readable storybook forms. Runtime animation stays on GPU.
var maker: RefCounted

func lathe(root: Node3D,profile: Array[Vector2],position: Vector3,material: Material,segments: int=32) -> void:
	maker.lathe(root,profile,position,material,segments)

func rounded_box(root: Node3D,size: Vector3,center: Vector3,material: Material,radius: float=.18) -> MeshInstance3D:
	radius=minf(radius,minf(size.x,minf(size.y,size.z))*.45)
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector3=size*.5
	var inner: Vector3=half-Vector3.ONE*radius
	for axis in range(3):
		var u: int=(axis+1)%3
		var v: int=(axis+2)%3
		for sign_value in [-1.0,1.0]:
			for row in range(12):
				for column in range(12):
					var points: Array[Vector3]=[]
					var normals: Array[Vector3]=[]
					var uv: Array[Vector2]=[]
					for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
						var p: Vector3=Vector3.ZERO
						p[axis]=half[axis]*sign_value
						p[u]=lerpf(-half[u],half[u],(column+offset.x)/12.0)
						p[v]=lerpf(-half[v],half[v],(row+offset.y)/12.0)
						var core: Vector3=p.clamp(-inner,inner)
						var normal: Vector3=(p-core).normalized()
						points.append(core+normal*radius)
						normals.append(normal)
						uv.append(Vector2((column+offset.x)/12.0,(row+offset.y)/12.0))
					for index in ([0,2,1,1,2,3] if sign_value>0 else [0,1,2,2,1,3]):
						st.set_normal(normals[index])
						st.set_uv(uv[index])
						st.add_vertex(points[index])
	st.index()
	return IRArt.part(root,st.commit(),center,material)

func cottage_point(p: Vector3,variant: int) -> Vector3:
	var lift: float=smoothstep(.5,4.5,p.y)
	var roof: float=smoothstep(4.1,5.2,p.y)
	var phase: float=variant*.8
	var q: Vector3=p
	q.x=p.x*(1+.065*sin(clampf(p.y/5.2,0,1)*PI))+.13*sin(p.y*.64+phase)*lift
	q.z=p.z*(1+.035*sin(clampf(p.y/5.0,0,1)*PI))
	q.y+=lift*.07*sin(p.x*.8+phase)+roof*(.28*sin(p.z*.63+.4)+.18*pow(p.x/4,2))
	return q

func sculpt_cottage(mesh: ArrayMesh,variant: int) -> ArrayMesh:
	var result: ArrayMesh=ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in range(vertices.size()):
			var p: Vector3=vertices[i]
			var derivative: Basis=Basis((cottage_point(p+Vector3.RIGHT*.01,variant)-cottage_point(p-Vector3.RIGHT*.01,variant))/.02,(cottage_point(p+Vector3.UP*.01,variant)-cottage_point(p-Vector3.UP*.01,variant))/.02,(cottage_point(p+Vector3.BACK*.01,variant)-cottage_point(p-Vector3.BACK*.01,variant))/.02)
			vertices[i]=cottage_point(p,variant)
			normals[i]=(derivative.inverse().transposed()*normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface,mesh.surface_get_material(surface))
	return result

func branch(root: Node3D,controls: Array[Vector3],radii: Array[float],color: Color,radial: int=12) -> void:
	var points: Array[Vector3]=[]
	var sizes: Array[float]=[]
	for segment in range(controls.size()-1):
		for step in range(8):
			var t: float=step/8.0
			points.append(controls[segment].cubic_interpolate(controls[segment+1],controls[maxi(segment-1,0)],controls[mini(segment+2,controls.size()-1)],t))
			sizes.append(lerpf(radii[segment],radii[segment+1],t))
	points.append(controls[-1])
	sizes.append(radii[-1])
	maker.botanicals.path(root,points,sizes,maker.botanicals.mat("ancient_bark",13),color,maxi(radial,32) if radii[0]>1.0 else radial,true)

func elder_gate(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var bark: Color=Color("a2815a")
	branch(root,[Vector3(-13,-1,0),Vector3(-13.7,3,.5),Vector3(-12.5,8,-.3),Vector3(-13,14,-.5),Vector3(-9.5,20,.5),Vector3(-9,24,0)],[2.9,2.6,2.1,1.7,.9,.15],bark,18)
	branch(root,[Vector3(-12,7.7,0),Vector3(-9,10.8,.7),Vector3(-3.5,12.8,.4),Vector3(3.5,11.9,-.6),Vector3(9,8.4,.3),Vector3(12,.2,0)],[1.45,1.2,.95,.9,.9,1.45],bark,16)
	for i in range(7):
		var a: float=i*TAU/7
		var ray: Vector3=Vector3(cos(a),0,sin(a))
		branch(root,[Vector3(-13,1.0,0),Vector3(-13,0,0)+ray*2.3,Vector3(-13,-.3,0)+ray*4.8],[.7,.42,.025],bark,9)
	branch(root,[Vector3(-12,14,-.5),Vector3(-17,17,-2),Vector3(-20,19,-3)],[1.2,.7,.08],bark)
	branch(root,[Vector3(-9,17,0),Vector3(-2,17.5,1),Vector3(4,17,2)],[1.05,.65,.06],bark)
	branch(root,[Vector3(-9.5,11,.7),Vector3(-8,13,1.3),Vector3(-5.5,14.3,2)],[.55,.32,.03],bark)
	branch(root,[Vector3(6,10.7,-.3),Vector3(6.5,12.6,-1.0),Vector3(8,14,-1.5)],[.5,.24,.025],bark)
	var crowns: Array[Vector3]=[Vector3(-17,20,-3),Vector3(-12,23,-2),Vector3(-6,23,0),Vector3(-1,20.5,2),Vector3(5,18,2),Vector3(-13,21,4),Vector3(-7,24.5,-4),Vector3(9,16.8,-1),Vector3(-9,14.3,.4),Vector3(-5.3,14.8,1.9),Vector3(7.4,13.9,-1.5)]
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator=RandomNumberGenerator.new()
	rng.seed=919441
	for i in range(crowns.size()):
		var span: Vector3=Vector3(4.8 if i<4 else 3.6,3.3+(i%3)*.4,3.8) if i<8 else Vector3(3.3,1.9,2.8)
		maker.botanicals.volume(root,crowns[i],span,false,i*1.9,true)
		for j in range(45):
			var normal: Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(-.2,1),rng.randf_range(-1,1)).normalized()
			var p: Vector3=crowns[i]+normal*span*rng.randf_range(.9,1.05)
			var basis: Basis=Basis.looking_at(-normal).rotated(normal,rng.randf()*TAU)
			maker.botanicals.leaf(leaves,p,basis,.60,.19,Color("82984f").lerp(Color("a1ac60"),rng.randf()*.35))
	maker.window(root,Vector3(-13.2,6.1,2.5),1.15,1.6)
	for i in range(5):
		var x: float=-5+i*2.2
		var y: float=11.3-absf(x)*.06
		var vine: Array[Vector3]=[Vector3(x,y,.5),Vector3(x+.2,y-1.0,.6),Vector3(x+.35,y-1.6,.7)]
		var widths: Array[float]=[.045,.025,.005]
		maker.botanicals.path(root,vine,widths,maker.botanicals.mat("vine",16,true),Color("7e9853"),6)
		for n in range(5):
			maker.botanicals.leaf(leaves,Vector3(x+.2,y-n*.28,.6),Basis.from_euler(Vector3(.6,0,n*.7)),.35,.10,Color("8da15d"))
	IRArt.part(root,leaves.commit(),Vector3.ZERO,maker.botanicals.mat("leaves",14,true))
	maker=null
	return root

func bakery(author: RefCounted) -> Node3D:
	maker=author
	maker.architecture.maker=author
	var root: Node3D=Node3D.new()
	var bark: Material=maker.paint("bakery_bark","bc9169",.9)
	bark.set_meta("palette_kind",13)
	lathe(root,[Vector2(4.5,-.2),Vector2(4.1,.6),Vector2(3.7,2.3),Vector2(3.8,4.6),Vector2(3.1,6.6)],Vector3.ZERO,bark,48)
	for i in range(7):
		var a: float=i*TAU/7+.2
		var ray: Vector3=Vector3(cos(a),0,sin(a))
		branch(root,[ray*3.2+Vector3.UP,ray*4.2+Vector3.UP*.2,ray*5.9-Vector3.UP*.2],[.55,.35,.025],Color("bb946b"),9)
	var tiles: Material=maker.textured("bakery_roof","fairy_roof","bc765c",.70)
	lathe(root,[Vector2(5.05,5.7),Vector2(5.65,6.0),Vector2(5.45,6.5),Vector2(4.6,7.3),Vector2(3.4,8.2),Vector2(1.6,8.7),Vector2(.06,8.6)],Vector3.ZERO,tiles,56)
	lathe(root,[Vector2(5.05,5.58),Vector2(5.63,5.88),Vector2(5.65,6.02)],Vector3.ZERO,maker.trim(),56)
	maker.panel(root,Vector3(0,.2,3.99),2.35,3.75,maker.trim())
	maker.panel(root,Vector3(0,.32,4.03),1.95,3.45,maker.paint("bakery_door","617862",.8))
	for plank in range(9):
		var x: float=(plank-4)*.20
		var top: float=2.85+sqrt(maxf(.95*.95-x*x,0))
		IRArt.block(root,Vector3(.19,top-.4,.04),Vector3(x,(top+.4)*.5,4.08),maker.paint("bakery_plank%d"%(plank%2),"768b68" if plank%2 else "6c815f",.85))
	maker.ball(root,Vector3(.62,1.69,4.17),Vector3(.14,.14,.10),maker.paint("bakery_brass","d9b979",.35,.6))
	for side in [-1.0,1.0]:
		maker.window(root,Vector3(side*2.30,2.0,3.28),1.35,1.8)
		maker.architecture.pot(root,Vector3(side*2.0,.1,4.4),"rose",1.15)
	for j in range(3):
		rounded_box(root,Vector3(3.0+j*.35,.25,.85),Vector3(0,.15-j*.1,4.25+j*.5),maker.stone(),.12)
	# A projecting bakery counter and a golden pretzel identify the building from the road.
	rounded_box(root,Vector3(2.8,1.0,1.05),Vector3(-3.0,.55,4.1),maker.paint("bakery_counter","9b7659",.85),.10)
	for loaf in range(6):
		var p: Vector3=Vector3(-3.8+(loaf%3)*.75,1.15+(loaf/3)*.24,4.05+(loaf/3)*.15)
		maker.ball(root,p,Vector3(.64,.28,.46),maker.paint("bread","d5a35e",.91))
	var sign_material: Material=maker.paint("bakery_sign","5d775f",.85)
	rounded_box(root,Vector3(3.35,.80,.18),Vector3(0,4.65,4.15),sign_material,.10)
	var text: TextMesh=TextMesh.new()
	text.font=preload("res://assets/fonts/Barlow-Medium.ttf")
	text.text="PIEKARNIA"
	text.font_size=64
	text.pixel_size=.009
	text.depth=.015
	text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	IRArt.part(root,text,Vector3(0,4.63,4.28),maker.trim())
	var loop: Array[Vector3]=[]
	var radii: Array[float]=[]
	for i in range(65):
		var t: float=TAU*i/64
		loop.append(Vector3(sin(t*2)*.55,5.25+cos(t)*.43,4.30))
		radii.append(.07)
	maker.botanicals.path(root,loop,radii,maker.paint("pretzel_gold","e4b66d",.8),Color.WHITE,8)
	var chimney: Material=maker.stone()
	rounded_box(root,Vector3(1.0,3.9,1.0),Vector3(2.25,7.65,-1.5),chimney,.16)
	lathe(root,[Vector2(.60,9.50),Vector2(.68,9.7),Vector2(.48,9.94),Vector2(.34,9.94),Vector2(.34,9.75)],Vector3(2.25,0,-1.5),maker.paint("oven_clay","b77c61",.9),20)
	maker.architecture.maker=null
	maker=null
	return root

func castle_crag(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[Vector3]=[Vector3(20.4,0,17.2),Vector3(21.2,.10,17.8),Vector3(20.5,.16,17.4),Vector3(18.8,.20,16.1),Vector3(18.0,.46,14.9),Vector3(19.0,.49,15.6),Vector3(18.2,.58,15.0),Vector3(17.9,.61,14.8),Vector3(17.6,.88,14.4),Vector3(17.7,1,14.3)]
	for row in range(rows.size()-1):
		for segment in range(80):
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
				var angle: float=TAU*(segment+offset.x)/80
				var band_index: int=row+int(offset.y)
				var band: Vector3=rows[band_index]
				var swell: float=1.0+.04*sin(angle*7+band_index*.36)+.025*cos(angle*11-band_index*.2)
				var p: Vector3=Vector3(signf(cos(angle))*pow(absf(cos(angle)),.55)*band.x*swell,band.y,signf(sin(angle))*pow(absf(sin(angle)),.55)*band.z*swell)
				st.set_uv(Vector2(segment/80.0,row/5.0))
				var moss: float=.45 if band_index in [3,5,7,9] else .0
				st.set_color(Color("d6d0b7").lerp(Color("7c9565"),moss))
				st.add_vertex(p)
	# Keep the terrace shading separate from the vertical cliff at the rim.
	st.set_smooth_group(1)
	for segment in range(80):
		var a: float=TAU*segment/80
		var b: float=TAU*(segment+1)/80
		var ring: Array[Vector3]=[Vector3(0,1,0)]
		for angle in [a,b]:
			var swell: float=1.0+.04*sin(angle*7+9*.36)+.025*cos(angle*11-9*.2)
			ring.append(Vector3(signf(cos(angle))*pow(absf(cos(angle)),.55)*17.7*swell,1,signf(sin(angle))*pow(absf(sin(angle)),.55)*14.3*swell))
		for p in ring:
			st.set_uv(Vector2(p.x,p.z)*.1)
			st.set_color(Color("b2b895"))
			st.add_vertex(p)
	st.index()
	st.generate_normals()
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	material.roughness=.94
	material.set_meta("palette_kind",12)
	IRArt.part(root,st.commit(),Vector3.ZERO,material)
	maker=null
	return root

func boathouse(author: RefCounted) -> Node3D:
	maker=author
	maker.architecture.maker=author
	var root: Node3D=Node3D.new()
	var timber: Material=maker.architecture.weathered("aa967a")
	for x in [-2.55,2.55]:
		for z in [-2.4,2.4]:
			var post: Array[Vector3]=[Vector3(x,-.5,z),Vector3(x+.08,1.3,z),Vector3(x,2.8,z)]
			var widths: Array[float]=[.22,.20,.18]
			maker.botanicals.path(root,post,widths,timber,Color.WHITE,12)
	rounded_box(root,Vector3(6.0,.32,6.0),Vector3(0,2.5,0),timber,.12)
	var walls: Material=maker.paint("wall_boathouse","a1b4bd",.87)
	rounded_box(root,Vector3(4.8,3.65,4.6),Vector3(0,4.45,0),walls,.18)
	maker.architecture.gables(root,2.4,4.6,6.2,2.25,2.9,walls)
	var tiles: Material=maker.textured("boathouse_roof","fairy_roof","7e9b9c",.85)
	maker.roof(root,2.9,5.7,6.2,2.25,tiles)
	for side in [-1.0,1.0]:
		maker.window(root,Vector3(side*1.3,3.8,2.32),.8,1.35)
		var back: Node3D=Node3D.new()
		maker.window(back,Vector3(side*1.3,3.8,2.32),.85,1.35)
		maker.architecture.attach(root,back,Vector3.ZERO,PI)
	maker.panel(root,Vector3(0,2.7,2.33),1.1,2.4,maker.paint("boathouse_door","627e83",.86))
	for side in [-1.0,1.0]:
		for z in [-2.7,0,2.7]:
			IRArt.tube(root,Vector3(side*2.82,2.6,z),Vector3(side*2.82,3.7,z),.06,maker.trim())
		IRArt.tube(root,Vector3(side*2.82,3.5,-2.7),Vector3(side*2.82,3.5,2.7),.035,timber)
	for side in [-1.0,1.0]:
		IRArt.tube(root,Vector3(side*.8,2.65,2.8),Vector3(side*.8,2.65,5.1),.06,timber)
	for i in range(7):
		IRArt.block(root,Vector3(1.55,.12,.33),Vector3(0,2.57-i*.06,3.0+i*.34),timber)
	maker.architecture.maker=null
	maker=null
	return root
