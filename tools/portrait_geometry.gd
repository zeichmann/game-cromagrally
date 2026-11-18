extends RefCounted
## Explicit facial edge loops: continuous cheeks/lips, inset eye caps and a closed mouth pocket.
## Ordinary 3D mesh authoring offline. No boolean cuts or image billboards.
var species: int=0
var detail: int=0
var materials: Dictionary={}

func mat(key: String,hex: String,kind: int=30,roughness: float=.55) -> StandardMaterial3D:
	key="%d/%s"%[species,key]
	if not materials.has(key):
		var value: StandardMaterial3D=StandardMaterial3D.new()
		value.albedo_color=Color(hex)
		value.roughness=roughness
		value.set_meta("palette_kind",kind)
		materials[key]=value
	return materials[key]

func part(root: Node3D,mesh: Mesh,material: Material,bone: int=1) -> MeshInstance3D:
	var node: MeshInstance3D=IRArt.part(root,mesh,Vector3.ZERO,material)
	node.set_meta("driver_bone",bone)
	return node

func orb(root: Node3D,p: Vector3,size: Vector3,material: Material,bone: int=1) -> MeshInstance3D:
	var sphere: SphereMesh=SphereMesh.new()
	sphere.radius=1
	sphere.height=2
	sphere.radial_segments=[32,24,16][detail]
	sphere.rings=[18,14,10][detail]
	var node: MeshInstance3D=part(root,sphere,material,bone)
	node.position=p
	node.scale=size
	return node

func path(root: Node3D,controls: Array[Vector3],radius: float,material: Material,bone: int=1,end_radius: float=-1) -> void:
	var points: Array[Vector3]=[]
	var radii: Array[float]=[]
	var subdivisions: int=2 if species>=2 else 5
	for i in range(controls.size()-1):
		for n in range(subdivisions):
			var t: float=n/float(subdivisions)
			points.append(controls[i].cubic_interpolate(controls[i+1],controls[maxi(i-1,0)],controls[mini(i+2,controls.size()-1)],t))
			radii.append(lerpf(radius,radius if end_radius<0 else end_radius,(i+t)/(controls.size()-1)))
	points.append(controls[-1])
	radii.append(radius if end_radius<0 else end_radius)
	var builder: RefCounted=load("res://tools/botanical_builder.gd").new()
	builder.path(root,points,radii,material,Color.WHITE,[10,8,6][detail])
	root.get_child(-1).set_meta("driver_bone",bone)

func width() -> float: return .505 if species==0 else (.455 if species==1 else .425)
func eye_center() -> Vector2: return Vector2(.235,.975) if species==0 else Vector2(.195,.955)
func eye_size() -> Vector2: return Vector2(.112,.143) if species==0 else Vector2(.094,.120)

func outline(a: float) -> Vector2:
	var s: float=sin(a)
	var x: float=width()*cos(a)*(1-.045*s)
	var y: float=.80+(.295 if s>0 and species==0 else .37)*s
	if species==0 and s>0:
		y+=.105*exp(-pow((absf(x)-.245)/.125,2))*sqrt(s)
	return Vector2(x,y)

func front_z(x: float,y: float) -> float:
	var e: float=maxf(0,1-pow(x/(width()*1.04),2)-pow((y-.80)/.39,2))
	var z: float=-.055-.205*sqrt(e)
	if species==0:
		z-=.095*exp(-pow(x/.43,4)-pow((y-.735)/.125,2))
		z-=.045*exp(-pow(x/.37,4)-pow((y-.52)/.11,2))
		for side in [-1.0,1.0]:
			z-=.062*exp(-pow((x-side*.235)/.17,2)-pow((y-.985)/.19,2))
			z-=.033*exp(-pow((x-side*.36)/.12,2)-pow((y-.66)/.13,2))
	elif species==1:
		z-=.147*exp(-pow(x/.224,4)-pow((y-.785)/.105,4))
		for side in [-1.0,1.0]:
			z-=.055*exp(-pow((x-side*.29)/.14,2)-pow((y-.66)/.13,2))
			z+=.035*exp(-pow((x-side*.077)/.025,2)-pow((y-.794)/.031,2))
	else:
		z-=.090*exp(-pow(x/.245,4)-pow((y-.70)/.15,2))
		for side in [-1.0,1.0]: z-=.032*exp(-pow((x-side*.24)/.15,2)-pow((y-.70)/.15,2))
	return z

func mouth(a: float) -> Vector2:
	var s: float=sin(a)
	if species>=2: return Vector2(cos(a)*.16,.610+.018*pow(cos(a),2)+s*(.008 if s>0 else .032))
	var radius: float=.350 if species==0 else .255
	return Vector2(cos(a)*radius,.610+.065*pow(cos(a),2)+s*(.035 if s>0 else (.150 if species==0 else .125)))

func color(p: Vector3) -> Color:
	var skin: Color=[Color("98b54d"),Color("f2b4a7"),Color("bba482"),Color("a28d7f")][species]
	var chin: Color=[Color("e4d994"),Color("ffcfb7"),Color("eee0bc"),Color("e9d5bc")][species]
	var lower: float=(1-smoothstep(.51,.74,p.y))*(.75 if species==0 else .38)
	skin=skin.lerp(chin,lower)
	var front: float=smoothstep(.06,.25,-p.z)
	var cheek: float=exp(-pow((absf(p.x)-(.32 if species<2 else .23))/.105,2)-pow((p.y-.69)/.105,2))*front
	skin=skin.lerp(Color("c7905d") if species==0 else Color("e58e92"),cheek*(.23 if species==0 else .32))
	if species>=2:
		var muzzle: float=exp(-pow(p.x/.255,4)-pow((p.y-.69)/.125,4))*front
		skin=skin.lerp(chin,muzzle*.80)
	return skin

func vertex(st: SurfaceTool,p: Vector3,pigment: Color,uv: Vector2=Vector2(-1,-1)) -> void:
	st.set_color(pigment)
	st.set_uv(Vector2(p.x+.6,p.y) if uv.x<0 else uv)
	st.add_vertex(p)

func quad(st: SurfaceTool,points: Array[Vector3],colors: Array[Color],reverse: bool=false,uv: Array[Vector2]=[]) -> void:
	for k in ([0,1,2,1,3,2] if reverse else [0,2,1,1,2,3]):
		vertex(st,points[k],colors[k],uv[k] if not uv.is_empty() else Vector2(-1,-1))

func finish(st: SurfaceTool) -> ArrayMesh:
	st.index()
	st.generate_normals()
	return st.commit()

func head(root: Node3D) -> void:
	# Villagers occupy a much smaller portion of the driving view than the pilot.
	var segments: int=48 if species>=2 else [192,128,80][detail]
	var rings: int=14 if species>=2 else [40,28,19][detail]
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lip: Array[Vector3]=[]
	var edge: Array[Vector3]=[]
	for n in range(segments+1):
		var a: float=TAU*n/segments
		var m: Vector2=mouth(a)
		lip.append(Vector3(m.x,m.y,front_z(m.x,m.y)-.022))
		var o: Vector2=outline(a)
		edge.append(Vector3(o.x,o.y,front_z(o.x,o.y)))
	for row in range(rings):
		for n in range(segments):
			var points: Array[Vector3]=[]
			var colors: Array[Color]=[]
			for t in [row/float(rings),(row+1)/float(rings)]:
				for k in [n,n+1]:
					var m: Vector3=lip[k].lerp(edge[k],t)
					m.z=front_z(m.x,m.y)-.022*exp(-pow(t/.085,2))
					points.append(m)
					colors.append(color(m))
			quad(st,points,colors)
	var back_rings: int=7 if species>=2 else [18,14,10][detail]
	for row in range(back_rings):
		for n in range(segments):
			var points: Array[Vector3]=[]
			var colors: Array[Color]=[]
			for t in [row/float(back_rings),(row+1)/float(back_rings)]:
				var phi: float=t*PI*.5*.97
				for k in [n,n+1]:
					var o: Vector3=edge[k]
					var p: Vector3=Vector3(o.x*cos(phi),.8+(o.y-.8)*cos(phi),lerpf(o.z,.275,sin(phi)))
					points.append(p)
					colors.append(color(p))
			quad(st,points,colors)
	var phi: float=PI*.5*.97
	for n in range(segments):
		var a: Vector3=Vector3(edge[n].x*cos(phi),.8+(edge[n].y-.8)*cos(phi),lerpf(edge[n].z,.275,sin(phi)))
		var b: Vector3=Vector3(edge[n+1].x*cos(phi),.8+(edge[n+1].y-.8)*cos(phi),lerpf(edge[n+1].z,.275,sin(phi)))
		for p in [a,Vector3(0,.8,.276),b]: vertex(st,p,color(p))
	var pocket_rings: int=4 if species>=2 else [12,9,6][detail]
	for row in range(pocket_rings):
		for n in range(segments):
			var points: Array[Vector3]=[]
			var colors: Array[Color]=[]
			for t in [row/float(pocket_rings),(row+1)/float(pocket_rings)]:
				for k in [n,n+1]:
					var p: Vector3=Vector3(lip[k].x*(1-t*.86),.585+(lip[k].y-.585)*(1-t*.74),lip[k].z+sin(t*PI*.5)*(.19 if species<2 else .065))
					points.append(p)
					var inside: Color=Color("70342d").lerp(Color("b35b51"),clampf((.62-p.y)*3.5,0,.8))
					colors.append(color(lip[k]).lerp(inside,smoothstep(0,.15,t)))
			quad(st,points,colors,true)
	for n in range(segments):
		var a: Vector3=Vector3(lip[n].x*.14,.585+(lip[n].y-.585)*.26,lip[n].z+(.19 if species<2 else .065))
		var b: Vector3=Vector3(lip[n+1].x*.14,.585+(lip[n+1].y-.585)*.26,lip[n+1].z+(.19 if species<2 else .065))
		for p in [a,b,Vector3(0,.585,-.10)]: vertex(st,p,Color("6e302b"))
	var skin: StandardMaterial3D=mat("skin","ffffff",44 if species>=2 else 30)
	skin.vertex_color_use_as_albedo=true
	skin.vertex_color_is_srgb=true
	part(root,finish(st),skin)

func eye_cap(root: Node3D,center: Vector3,radius: Vector2,depth: float,material: Material) -> void:
	var segments: int=[48,36,24][detail]
	var rings: int=[10,8,6][detail]
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rings):
		for n in range(segments):
			var points: Array[Vector3]=[]
			var uv: Array[Vector2]=[]
			for r in [maxf(.005,row/float(rings)),(row+1)/float(rings)]:
				for a in [TAU*n/segments,TAU*(n+1)/segments]:
					points.append(center+Vector3(cos(a)*radius.x*r,sin(a)*radius.y*r,-depth*sqrt(maxf(0,1-r*r))))
					uv.append(Vector2(cos(a)*r,sin(a)*r)*.5+Vector2.ONE*.5)
			quad(st,points,[Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE],false,uv)
	part(root,finish(st),material)

func eye_z(p: Vector2,center: Vector2,size: Vector2) -> float:
	var r2: float=pow((p.x-center.x)/size.x,2)+pow((p.y-center.y)/size.y,2)
	return front_z(p.x,p.y)-.004-.033*sqrt(maxf(0,1-r2))

func eye_layer(root: Node3D,center: Vector2,size: Vector2,factor: Vector2,offset: float,material: Material) -> void:
	var segments: int=20 if species>=2 else [48,36,24][detail]
	var rings: int=4 if species>=2 else [10,8,6][detail]
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rings):
		for n in range(segments):
			var points: Array[Vector3]=[]
			var uv: Array[Vector2]=[]
			for r in [maxf(.005,row/float(rings)),(row+1)/float(rings)]:
				for a in [TAU*n/segments,TAU*(n+1)/segments]:
					var q: Vector2=center+Vector2(cos(a),sin(a))*size*factor*r
					points.append(Vector3(q.x,q.y,eye_z(q,center,size)+offset))
					uv.append(Vector2(cos(a)*r,sin(a)*r)*.5+Vector2.ONE*.5)
			quad(st,points,[Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE],false,uv)
	part(root,finish(st),material)

func eyes(root: Node3D) -> void:
	var c: Vector2=eye_center()
	var size: Vector2=eye_size()
	var z: float=-.303 if species==0 else (-.245 if species==1 else -.272)
	var skin: Material=mat("lid","a2b757" if species==0 else ("edb09f" if species==1 else "baa58e"),43)
	for side in [-1.0,1.0]:
		var center: Vector3=Vector3(side*c.x,c.y,z)
		var location: Vector2=Vector2(center.x,center.y)
		eye_layer(root,location,size,Vector2.ONE,0,mat("sclera","f8edda",31,.28))
		eye_layer(root,location,size,Vector2(.61,.61),-.002,mat("iris","a1743d",42,.24))
		eye_layer(root,location,size,Vector2(.34,.39),-.004,mat("pupil","141812",32,.20))
		for glint in [Vector3(-.022,.030,.011),Vector3(.018,-.022,.004)]:
			var q: Vector2=location+Vector2(glint.x,glint.y)
			orb(root,Vector3(q.x,q.y,eye_z(q,location,size)-.008),Vector3(glint.z,glint.z*1.2,.003),mat("glint","fff4dc",32,.20))
		var upper: Array[Vector3]=[]
		for n in range(21):
			var a: float=PI*n/20
			var p: Vector2=location+Vector2(cos(a),sin(a))*size*1.02
			upper.append(Vector3(p.x,p.y,front_z(p.x,p.y)-.010))
		path(root,upper,.013,skin)
		if species==1:
			var brow: Array[Vector3]=[]
			for n in range(11):
				var t: float=n/10.0
				var x: float=side*c.x+(t-.5)*.175
				var y: float=1.101+.022*sin(t*PI)
				brow.append(Vector3(x,y,front_z(x,y)-.012))
			path(root,brow,.010,mat("brow","885948",30))
			for n in range(4):
				var a: float=.28+n*.18 if side>0 else PI-.28-n*.18
				var p: Vector3=center+Vector3(cos(a)*size.x,sin(a)*size.y,-.008)
				path(root,[p,p+Vector3(side*.012,.018,-.008),p+Vector3(side*.022,.028,-.003)],.0035,mat("lashes","4c3531",43),1,.001)
	if species==0:
		for side in [-1.0,1.0]:
			var p: Vector3=Vector3(side*.067,.767,front_z(side*.067,.767)-.004)
			eye_cap(root,p,Vector2(.013,.009),.001,mat("nostril","607630",30))
	elif species==1:
		snout(root)
	else:
		orb(root,Vector3(0,.755,front_z(0,.755)-.015),Vector3(.043,.030,.022),mat("nose","765449",30))
	if species<2:
		orb(root,Vector3(0,.505,front_z(0,.505)+.045),Vector3(.115,.026,.055) if species==0 else Vector3(.080,.023,.045),mat("tongue","cc7d72",30))
		if species==1:
			for x in [-.030,.030]: orb(root,Vector3(x,.628,front_z(x,.645)+.035),Vector3(.028,.016,.018),mat("teeth","f7e9ce",30))

func snout(root: Node3D) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int=[80,56,36][detail]
	var rings: int=[14,10,7][detail]
	for side in [-1.0,1.0]:
		var inner: Array[Vector3]=[]
		var outer: Array[Vector3]=[]
		var center: Vector2=Vector2(side*.077,.794)
		for n in range(segments+1):
			var a: float=TAU*n/segments
			var d: Vector2=Vector2(cos(a),sin(a))
			var b: float=2*(center.x*d.x/pow(.225,2)+(center.y-.790)*d.y/pow(.122,2))
			var aa: float=pow(d.x/.225,2)+pow(d.y/.122,2)
			var cc: float=pow(center.x/.225,2)+pow((center.y-.790)/.122,2)-1
			var t: float=(-b+sqrt(maxf(0,b*b-4*aa*cc)))/(2*aa)
			if d.x*side<-.001: t=minf(t,-center.x/d.x)
			var p: Vector2=center+d*t
			outer.append(Vector3(p.x,p.y,-.405-.020*sqrt(maxf(0,1-pow(p.x/.225,2)-pow((p.y-.790)/.122,2)))))
			var q: Vector2=center+Vector2(cos(a)*.030,sin(a)*.039)
			inner.append(Vector3(q.x,q.y,-.405-.024*sqrt(maxf(0,1-pow(q.x/.225,2)-pow((q.y-.790)/.122,2)))))
		for row in range(rings):
			for n in range(segments):
				var points: Array[Vector3]=[]
				var colors: Array[Color]=[]
				for t in [row/float(rings),(row+1)/float(rings)]:
					for k in [n,n+1]:
						var p: Vector3=inner[k].lerp(outer[k],t)
						p.z=-.405-.024*sqrt(maxf(0,1-pow(p.x/.225,2)-pow((p.y-.790)/.122,2)))
						points.append(p)
						colors.append(Color("ed9b98").lerp(Color("f7b2a5"),smoothstep(.45,1,t)*.45))
				quad(st,points,colors)
		# The two real nostril pockets have rounded rims and dark recessed floors.
		for row in range(8):
			for n in range(segments):
				var points: Array[Vector3]=[]
				var colors: Array[Color]=[]
				for t in [row/8.0,(row+1)/8.0]:
					for k in [n,n+1]:
						var p: Vector3=Vector3(center.x+(inner[k].x-center.x)*(1-.85*t),center.y+(inner[k].y-center.y)*(1-.85*t),inner[k].z+.050*t)
						points.append(p)
						colors.append(Color("ed9b98").lerp(Color("8d454b"),smoothstep(0,.55,t)))
				quad(st,points,colors,true)
		for n in range(segments):
			for p in [Vector3(center.x+(inner[n].x-center.x)*.15,center.y+(inner[n].y-center.y)*.15,inner[n].z+.050),Vector3(center.x+(inner[n+1].x-center.x)*.15,center.y+(inner[n+1].y-center.y)*.15,inner[n+1].z+.050),Vector3(center.x,center.y,-.376)]:
				vertex(st,p,Color("8d454b"))
	# Rounded outer wall connects the oval nose pad to the facial muzzle.
	for row in range(8):
		for n in range(segments):
			var points: Array[Vector3]=[]
			var colors: Array[Color]=[]
			for t in [row/8.0,(row+1)/8.0]:
				for a in [TAU*n/segments,TAU*(n+1)/segments]:
					var p: Vector3=Vector3(cos(a)*(.225+.012*sin(t*PI)-.040*t),.790+sin(a)*(.122+.010*sin(t*PI)-.025*t),-.405+.085*t)
					points.append(p)
					colors.append(Color("ed9b98").lerp(Color("f7b2a5"),.45).lerp(Color("f2b4a7"),t))
			quad(st,points,colors)
	var skin: StandardMaterial3D=mat("snout","ffffff",30)
	skin.vertex_color_use_as_albedo=true
	skin.vertex_color_is_srgb=true
	part(root,finish(st),skin)
