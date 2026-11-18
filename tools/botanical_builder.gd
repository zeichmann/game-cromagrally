extends RefCounted
## Botanical silhouettes, curved stems and folded leaves; no transparent canopy billboards.

var materials: Dictionary={}
var rng: RandomNumberGenerator=RandomNumberGenerator.new()

func mat(key: String, kind: int, double_sided: bool = false) -> StandardMaterial3D:
	if not materials.has(key):
		var material: StandardMaterial3D=StandardMaterial3D.new()
		material.resource_name=key
		material.vertex_color_use_as_albedo=true
		material.vertex_color_is_srgb=true
		material.roughness=.87
		material.cull_mode=BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
		material.set_meta("palette_kind",kind)
		materials[key]=material
	return materials[key]

func path(root: Node3D, points: Array[Vector3], radii: Array[float], material: Material, color: Color, radial: int = 8, organic: bool = false) -> void:
	var vertices: PackedVector3Array=PackedVector3Array()
	var normals: PackedVector3Array=PackedVector3Array()
	var uv: PackedVector2Array=PackedVector2Array()
	var colors: PackedColorArray=PackedColorArray()
	var indices: PackedInt32Array=PackedInt32Array()
	var distance: float=0
	for row in range(points.size()):
		if row>0:
			distance+=points[row].distance_to(points[row-1])
		var axis: Vector3=(points[mini(row+1,points.size()-1)]-points[maxi(row-1,0)]).normalized()
		var x: Vector3=axis.cross(Vector3.BACK if absf(axis.z)<.9 else Vector3.RIGHT).normalized()
		var z: Vector3=x.cross(axis)
		var slope: float=(radii[mini(row+1,radii.size()-1)]-radii[maxi(row-1,0)])/maxf(points[mini(row+1,points.size()-1)].distance_to(points[maxi(row-1,0)]),.01)
		for side in range(radial+1):
			var angle: float=TAU*side/radial
			var ray: Vector3=x*cos(angle)+z*sin(angle)
			var shape: float=1.0
			var around: float=0.0
			var along: float=0.0
			if organic:
				shape+=.11*sin(angle*3+distance*.17)+.055*sin(angle*7-distance*.25)+.06*cos(distance*.9+angle*2)
				around=.33*cos(angle*3+distance*.17)+.385*cos(angle*7-distance*.25)-.12*sin(distance*.9+angle*2)
				along=.0187*cos(angle*3+distance*.17)-.01375*cos(angle*7-distance*.25)-.054*sin(distance*.9+angle*2)
			var tangent: Vector3=-x*sin(angle)+z*cos(angle)
			vertices.append(points[row]+ray*radii[row]*shape)
			normals.append((ray-tangent*around/shape-axis*(slope*shape+radii[row]*along)).normalized())
			uv.append(Vector2(side/float(radial),distance*.5))
			colors.append(color)
	for row in range(points.size()-1):
		for side in range(radial):
			var a: int=row*(radial+1)+side
			for index in [a,a+1,a+radial+1,a+radial+1,a+1,a+radial+2]:
				indices.append(index)
	for end in [0,points.size()-1]:
		var center: int=vertices.size()
		vertices.append(points[end])
		normals.append((points[0]-points[1]).normalized() if end==0 else (points[-1]-points[-2]).normalized())
		uv.append(Vector2(.5,.5))
		colors.append(color)
		for side in range(radial):
			var start: int=end*(radial+1)+side
			for index in ([center,start+1,start] if end==0 else [center,start,start+1]):
				indices.append(index)
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh: ArrayMesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	IRArt.part(root,mesh,Vector3.ZERO,material)

func leaf(st: SurfaceTool, p: Vector3, basis: Basis, length: float, width: float, color: Color) -> void:
	var points: Array[Vector3]=[]
	var uvs: Array[Vector2]=[]
	for row in range(3):
		var t: float=row*.5
		for side in [-1.0,0.0,1.0]:
			var w: float=sin(t*PI)*width
			points.append(Vector3(side*w,t*length,sin(t*PI)*((1.0-absf(side))*.07+.1)*length))
			uvs.append(Vector2((side+1)*.5,t))
	for row in range(2):
		for side in range(2):
			var a: int=row*3+side
			for index in [a,a+3,a+1,a+1,a+3,a+4]:
				var uv: Vector2=uvs[index]
				st.set_normal((basis*Vector3(-(uv.x-.5)*.3,-uv.y*.12,1).normalized()).normalized())
				st.set_uv(uv)
				st.set_color(color)
				st.add_vertex(p+basis*points[index])

func petal(st: SurfaceTool, center: Vector3, outward: Vector3, length: float, width: float, cup: float, color: Color, orientation: Basis = Basis.IDENTITY) -> void:
	var lateral: Vector3=outward.cross(Vector3.UP).normalized()
	var basis: Basis=Basis(lateral,outward,Vector3.UP)
	for row in range(4):
		var points: Array[Vector3]=[]
		var uvs: Array[Vector2]=[]
		for t in [row/4.0,(row+1)/4.0]:
			for side in [-1.0,1.0]:
				points.append(Vector3(side*pow(maxf(sin(t*PI),0.0),.65)*width,t*length,cup*t*t))
				uvs.append(Vector2((side+1)*.5,t))
		for index in [0,2,1,1,2,3]:
			var uv: Vector2=uvs[index]
			st.set_normal((orientation*basis*Vector3(0,-2*cup*uv.y/maxf(length,.01),1).normalized()).normalized())
			st.set_uv(uv)
			st.set_color(color.darkened((1-uv.y)*.12))
			st.add_vertex(center+orientation*basis*points[index])

func bloom(st: SurfaceTool, center: Vector3, radius: float, rose: bool, color: Color, normal: Vector3 = Vector3.UP) -> void:
	var layers: int=3 if rose else 1
	var orientation: Basis=Basis(Quaternion(Vector3.UP,normal))
	for layer in range(layers):
		var count: int=8 if not rose else 11-layer*2
		var size: float=radius*(1.0-layer*.29)
		for i in range(count):
			var a: float=TAU*i/count+layer*.57
			petal(st,center+normal*layer*radius*.15,Vector3(cos(a),0,sin(a)),size,size*(.78 if rose else .28),size*(.80 if rose else .18),color,orientation)

func volume(root: Node3D, p: Vector3, size: Vector3, blossom: bool, seed_value: float,hero: bool = false) -> void:
	var sphere: SphereMesh=SphereMesh.new()
	sphere.radial_segments=32 if hero else 24
	sphere.rings=20 if hero else 14
	sphere.radius=1
	sphere.height=2
	var arrays: Array=sphere.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray=PackedColorArray()
	for i in range(points.size()):
		var v: Vector3=points[i]
		var ridges: float=sin(v.x*9.0+seed_value)*cos(v.z*8.0+v.y*3.0)
		points[i]=v*(1.0+ridges*.055+sin(v.y*17+v.x*6)*.018)
		var shade: float=.82+.16*smoothstep(-.6,.8,v.y)+sin(v.x*3+seed_value)*.025
		colors.append(Color(shade,shade,shade))
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh: ArrayMesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance: MeshInstance3D=IRArt.part(root,mesh,p,mat("blossom_volume" if blossom else "leaf_volume",10 if blossom else 9))
	instance.scale=size

func tree(kind: String) -> Node3D:
	if kind=="cypress":
		return cypress()
	if kind=="birch":
		return slender_tree(kind)
	rng.seed=512413+kind.hash()
	var root: Node3D=Node3D.new()
	var bark: Material=mat("bark",13)
	var bark_color: Color=Color("97806b")
	path(root,[Vector3(0,-.2,0),Vector3(.09,1.0,.04),Vector3(.30,2.4,.09),Vector3(.12,3.8,.24),Vector3(.42,5.4,.10),Vector3(.3,6.8,.18)],[.52,.37,.27,.22,.16,.07],bark,bark_color,12)
	for i in range(6):
		var a: float=i*TAU/6+.25
		var ray: Vector3=Vector3(cos(a),0,sin(a))
		path(root,[Vector3(0,.32,0),ray*.45+Vector3.UP*.12,ray*1.1-Vector3.UP*.04,ray*1.4-Vector3.UP*.15],[.18,.14,.065,.015],bark,bark_color,7)
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flowers: SurfaceTool=SurfaceTool.new()
	flowers.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blossom: bool=kind=="blossom"
	var lobe_centers: Array[Vector3]=[]
	for i in range(6):
		var a: float=i*2.4
		var center: Vector3=Vector3(cos(a)*1.45,5.0+(i%3)*.65,sin(a)*1.45)
		lobe_centers.append(center)
		path(root,[Vector3(.2,2.7+i*.25,.10),center*.55+Vector3.UP*1.3,center-Vector3.UP*.45],[.17,.11,.035],bark,bark_color,8)
		volume(root,center,Vector3(1.30,1.35,1.25) if blossom else Vector3(1.22,1.25,1.18),blossom,i*1.7)
	volume(root,Vector3(.25,6.5,.2),Vector3(1.32,1.35,1.25) if blossom else Vector3(1.25,1.28,1.22),blossom,6.3)
	if kind=="willow":
		for i in range(18):
			var a: float=i*TAU/18
			var ray: Vector3=Vector3(cos(a),0,sin(a))
			var points: Array[Vector3]=[]
			var radii: Array[float]=[]
			for j in range(8):
				var t: float=j/7.0
				points.append(ray*(1.0+1.9*sin(t*PI*.55))+Vector3(.2,6.9-4.0*t*t,.1))
				radii.append(lerpf(.055,.006,t))
				if j>0:
					for side in [-1.0,1.0]:
						var normal: Vector3=(ray+Vector3.UP*.3).normalized()
						var basis: Basis=Basis.looking_at(-normal,Vector3.DOWN).rotated(normal,side*.8)
						leaf(leaves,points[-1],basis,.40,.065,Color("819e55").darkened(rng.randf()*.16))
			path(root,points,radii,bark,bark_color,6)
	else:
		for i in range(1200 if not blossom else 320):
			var center: Vector3=lobe_centers[i%lobe_centers.size()]
			var direction: Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(-.7,1),rng.randf_range(-1,1)).normalized()
			var p: Vector3=center+direction*rng.randf_range(1.12,1.48 if blossom else 1.66)
			var basis: Basis=Basis.looking_at(-direction,Vector3.UP).rotated(direction,rng.randf()*TAU)
			leaf(leaves,p-basis.y*.18,basis,rng.randf_range(.30,.52),rng.randf_range(.11,.20),Color("688c48").lerp(Color("a4b96b"),rng.randf()*.6))
		if blossom:
			for i in range(240):
				var center: Vector3=lobe_centers[i%lobe_centers.size()]
				var direction: Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(-.25,1),rng.randf_range(-1,1)).normalized()
				bloom(flowers,center+direction*rng.randf_range(1.22,1.46),.14,false,Color("fff1de").lerp(Color("f1b9c7"),rng.randf()*.6),direction)
	IRArt.part(root,leaves.commit(),Vector3.ZERO,mat("leaves",14,true))
	if blossom:
		IRArt.part(root,flowers.commit(),Vector3.ZERO,mat("petals",15,true))
	return root

func cypress_radius(t: float) -> float:
	return .025+1.55*pow(maxf(sin(t*PI*.96),0),.65)*pow(1.0-t,.33)

func cypress() -> Node3D:
	rng.seed=714102
	var root: Node3D=Node3D.new()
	path(root,[Vector3(0,-.15,0),Vector3(.08,1.0,0),Vector3(.1,4.5,.1),Vector3(.2,9,.12)],[.28,.20,.12,.025],mat("bark",13),Color("8b7860"),10)
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(26):
		for side in range(24):
			for offset in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var t: float=(row+offset.x)/26.0
				var a: float=TAU*(side+offset.y)/24.0
				var r: float=cypress_radius(t)*(1+.06*sin(a*7+t*18)+.025*cos(a*13-t*28))
				var slope: float=(cypress_radius(minf(t+.01,1))-cypress_radius(maxf(t-.01,0)))/(.02*10.2)
				st.set_uv(Vector2(a/TAU*1.8,t*2.8))
				st.set_normal(Vector3(cos(a),-slope,sin(a)).normalized())
				st.set_color(Color("95ac8b").lightened(.04*sin(a*3+t*6)))
				st.add_vertex(Vector3(cos(a)*r+.15*t,1.0+t*10.2,sin(a)*r))
	IRArt.part(root,st.commit(),Vector3.ZERO,mat("leaf_volume",9))
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(260):
		var t: float=rng.randf_range(.04,.95)
		var a: float=rng.randf()*TAU
		var ray: Vector3=Vector3(cos(a),.2,sin(a)).normalized()
		var p: Vector3=Vector3(cos(a)*cypress_radius(t)+.15*t,1+t*10.2,sin(a)*cypress_radius(t))
		leaf(leaves,p,Basis.looking_at(-ray,Vector3.UP).rotated(ray,a),.19,.055,Color("6d8b59"))
	IRArt.part(root,leaves.commit(),Vector3.ZERO,mat("leaves",14,true))
	return root

func slender_tree(kind: String) -> Node3D:
	rng.seed=27145+kind.hash()
	var root: Node3D=Node3D.new()
	var birch: bool=kind=="birch"
	var bark: Material=mat("birch_bark" if birch else "bark",18 if birch else 13)
	var color: Color=Color("ded8c5") if birch else Color("8b7860")
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stem in range(2 if birch else 1):
		var origin: Vector3=Vector3(stem*.35,0,stem*.1)
		var lean: Vector3=Vector3(-.5 if stem else .4,0,.24)
		path(root,[origin-Vector3.UP*.15,origin+Vector3.UP*2+lean*.1,origin+Vector3.UP*5+lean*.55,origin+Vector3.UP*8+lean,origin+Vector3.UP*10.6+lean*1.3],[.22,.16,.11,.055,.015],bark,color,10)
		for branch in range(7):
			var a: float=branch*2.4+stem*1.7
			var height: float=5.0+branch*.72
			var reach: float=.75*(1-branch*.06)
			var center: Vector3=origin+Vector3(cos(a)*reach,height,sin(a)*reach)+lean*.6
			path(root,[origin+Vector3.UP*(height-1.3)+lean*.4,center-Vector3.UP*.5,center],[.065,.035,.009],bark,color,6)
			var size: Vector3=Vector3(1.05,1.6,1.05)
			volume(root,center,size,false,branch+stem)
			for i in range(35 if birch else 12):
				var direction: Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(-.65,1),rng.randf_range(-1,1)).normalized()
				var p: Vector3=center+direction*size*rng.randf_range(.83,1.10)
				var basis: Basis=Basis.looking_at(-direction,Vector3.UP).rotated(direction,rng.randf()*TAU)
				leaf(leaves,p,basis,.23 if birch else .18,.075,Color("a1b66d") if birch else Color("55774d"))
	IRArt.part(root,leaves.commit(),Vector3.ZERO,mat("leaves",14,true))
	return root

func flowering_bush() -> Node3D:
	rng.seed=241247
	var root: Node3D=Node3D.new()
	var flowers: SurfaceTool=SurfaceTool.new()
	flowers.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var a: float=i*2.4
		var center: Vector3=Vector3(cos(a)*.55,.8+(i%2)*.25,sin(a)*.55)
		volume(root,center,Vector3(.85,.7,.8),false,i)
		for j in range(8):
			var direction: Vector3=Vector3(rng.randf_range(-1,1),rng.randf_range(.05,1),rng.randf_range(-1,1)).normalized()
			bloom(flowers,center+direction*.78,.13,true,Color("edb4c4"),direction)
	IRArt.part(root,flowers.commit(),Vector3.ZERO,mat("petals",15,true))
	return root

func hanging_ivy() -> Node3D:
	rng.seed=514145
	var root: Node3D=Node3D.new()
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in range(3):
		var points: Array[Vector3]=[]
		var radii: Array[float]=[]
		for i in range(16):
			var t: float=i/15.0
			var p: Vector3=Vector3((strand-1)*.35+sin(t*8+strand)*.16,-t*(2.7+strand*.3),.07+sin(t*PI)*.13)
			points.append(p)
			radii.append(lerpf(.017,.004,t))
			if i>0:
				for side in [-1.0,1.0]:
					var normal: Vector3=Vector3(side*.15,.18,1).normalized()
					var basis: Basis=Basis.looking_at(-normal,Vector3.UP).rotated(normal,side*.95)
					leaf(leaves,p,basis,.24*(1-t*.25),.105,Color("6b8e56").lerp(Color("9aad73"),rng.randf()*.45))
		path(root,points,radii,mat("stems",16,true),Color("788c57"),6)
	IRArt.part(root,leaves.commit(),Vector3.ZERO,mat("plant_leaves",14,true))
	return root

func water_lily() -> Node3D:
	var root: Node3D=Node3D.new()
	var pad: SurfaceTool=SurfaceTool.new()
	pad.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a: float=lerpf(.17,TAU-.17,i/32.0)
		var b: float=lerpf(.17,TAU-.17,(i+1)/32.0)
		for p in [Vector3.ZERO,Vector3(cos(a)*.50,.025,sin(a)*.42),Vector3(cos(b)*.50,.025,sin(b)*.42)]:
			pad.set_normal(Vector3.UP)
			pad.set_uv(Vector2(p.x+.5,p.z+.5))
			pad.set_color(Color("789767").lightened(p.length()*.12))
			pad.add_vertex(p)
	IRArt.part(root,pad.commit(),Vector3.ZERO,mat("floating_pad",24,true))
	var petals: SurfaceTool=SurfaceTool.new()
	petals.begin(Mesh.PRIMITIVE_TRIANGLES)
	bloom(petals,Vector3(-.10,.07,.04),.25,true,Color("fff0e3"))
	IRArt.part(root,petals.commit(),Vector3.ZERO,mat("floating_petals",24,true))
	return root

func fern() -> Node3D:
	rng.seed=812107
	var root: Node3D=Node3D.new()
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in range(7):
		var a: float=frond*2.4
		var ray: Vector3=Vector3(cos(a),0,sin(a))
		var sideways: Vector3=ray.cross(Vector3.UP)
		var length: float=rng.randf_range(1.10,1.55)
		var points: Array[Vector3]=[]
		var radii: Array[float]=[]
		for i in range(12):
			var t: float=i/11.0
			var p: Vector3=ray*t*length+Vector3.UP*(sin(t*PI)*.90+t*.17)
			points.append(p)
			radii.append(lerpf(.018,.003,t))
			if i>0 and i<11:
				for side in [-1.0,1.0]:
					var normal: Vector3=(Vector3.UP+ray*.12).normalized()
					var direction: Vector3=(sideways*side+ray*.23).normalized()
					var basis: Basis=Basis.looking_at(-normal,direction)
					var span: float=.12+.24*sin(t*PI)*(1.0-t*.2)
					leaf(leaves,p,basis,span,.045,Color("71955b").lerp(Color("a2b66d"),t*.30))
		path(root,points,radii,mat("stems",16,true),Color("91a56b"),6)
	for stem in range(2):
		var curl: Array[Vector3]=[Vector3(stem*.10,0,0),Vector3(stem*.10,.25,0)]
		var radii: Array[float]=[.022,.018]
		for i in range(13):
			var a: float=i*TAU/12
			curl.append(Vector3(stem*.1+cos(a)*lerpf(.10,.025,i/12.0),.52+sin(a)*.10,stem*.14))
			radii.append(lerpf(.017,.005,i/12.0))
		path(root,curl,radii,mat("stems",16,true),Color("94aa68"),6)
	IRArt.part(root,leaves.commit(),Vector3.ZERO,mat("plant_leaves",14,true))
	return root

func flowers(kind: String) -> Node3D:
	rng.seed=51384+kind.hash()
	var root: Node3D=Node3D.new()
	var leaves: SurfaceTool=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var petals: SurfaceTool=SurfaceTool.new()
	petals.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int=3 if kind=="rose" else (5 if kind=="lavender" else 7)
	for i in range(count):
		var a: float=i*2.4
		var p: Vector3=Vector3(cos(a),0,sin(a))*sqrt(i/float(count))*.72
		var height: float=rng.randf_range(.48,.84) if kind!="lavender" else rng.randf_range(.75,1.10)
		var tip: Vector3=p+Vector3(rng.randf_range(-.09,.09),height,rng.randf_range(-.08,.08))
		path(root,[p,p.lerp(tip,.5)+Vector3(.035,0,0),tip],[.013,.010,.007],mat("stems",16,true),Color("557e48"),6)
		for side in [-1.0,1.0]:
			var outward: Vector3=Vector3(cos(a)*side,.7,sin(a)*side).normalized()
			var basis: Basis=Basis.looking_at(-Vector3.UP,outward)
			leaf(leaves,p.lerp(tip,.3),basis,.33,.075 if kind=="lavender" else .12,Color("668b4e"))
		if kind=="lavender":
			var nodes: Array[Vector3]=[]
			var radii: Array[float]=[]
			for j in range(11):
				var t: float=j/10.0
				nodes.append(tip+Vector3.UP*t*.32)
				radii.append(.008+sin(t*PI)*(.042 if j%2 else .075))
			path(root,nodes,radii,mat("lavender",15,true),Color("a593cc").lerp(Color("c1b1dd"),rng.randf()),6)
		else:
			bloom(petals,tip,.22 if kind=="rose" else .18,kind=="rose",Color("e9a3b4") if kind=="rose" else Color("fff4d7"))
			if kind=="daisy":
				var disk: SphereMesh=SphereMesh.new()
				disk.radial_segments=8
				disk.rings=3
				disk.radius=.047
				disk.height=.05
				var pollen: StandardMaterial3D=IRArt.pbr(Color("e6bf67"),.8).duplicate()
				pollen.cull_mode=BaseMaterial3D.CULL_DISABLED
				pollen.set_meta("palette_kind",15)
				IRArt.part(root,disk,tip+Vector3.UP*.013,pollen)
	IRArt.part(root,leaves.commit(),Vector3.ZERO,mat("plant_leaves",14,true))
	if kind!="lavender":
		IRArt.part(root,petals.commit(),Vector3.ZERO,mat("flower_petals",15,true))
	return root
