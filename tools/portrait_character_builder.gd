extends "res://tools/storybook_driver_builder.gd"
## Third-generation drivers: explicit facial topology and fitted, layered clothing.
var portrait: RefCounted=preload("res://tools/portrait_geometry.gd").new()

func path(root: Node3D,controls: Array[Vector3],radius: float,mat: Material,bone: int=0,end_radius: float=-1) -> void:
	portrait.detail=detail
	portrait.path(root,controls,radius,mat,bone,end_radius)

func box(root: Node3D,size: Vector3,p: Vector3,mat: Material,bone: int=0,radius: float=.01) -> MeshInstance3D:
	var node: MeshInstance3D=IRTeaGeometry.rounded_box(root,size,p,mat,radius)
	node.set_meta("driver_bone",bone)
	return node

func face(root: Node3D,points: Array[Vector3],mat: Material,bone: int=0) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		var vertices: Array[Vector3]=[points[0],points[i],points[i+1]]
		if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).z>0: vertices.reverse()
		for p in vertices:
			st.set_uv(Vector2(p.x*2,p.y*2))
			st.add_vertex(p)
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,mat).set_meta("driver_bone",bone)

func torso(root: Node3D,mat: Material) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profiles: Array[Vector3]=[Vector3(.30,.22,-.035),Vector3(.345,.24,.12),Vector3(.405,.225,.30),Vector3(.405,.19,.37),Vector3(.27,.14,.43)]
	var count: int=[48,36,24][detail]
	for row in range(profiles.size()-1):
		for n in range(count):
			var points: Array[Vector3]=[]
			for r in [profiles[row],profiles[row+1]]:
				for a in [TAU*n/count,TAU*(n+1)/count]: points.append(Vector3(cos(a)*r.x,r.z,sin(a)*r.y+.015))
			for k in [0,1,2,1,3,2]:
				st.set_uv(Vector2(n/float(count),points[k].y*2))
				st.add_vertex(points[k])
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,mat).set_meta("driver_bone",0)

func chest_z(x: float,y: float) -> float:
	var profiles: Array[Vector3]=[Vector3(.30,.22,-.035),Vector3(.345,.24,.12),Vector3(.405,.225,.30),Vector3(.405,.19,.37),Vector3(.27,.14,.43)]
	var r: Vector3=profiles[0]
	for i in range(profiles.size()-1):
		if y>=profiles[i].z:
			r=profiles[i].lerp(profiles[i+1],clampf((y-profiles[i].z)/(profiles[i+1].z-profiles[i].z),0,1))
	return -.005-r.y*sqrt(maxf(0,1-pow(x/r.x,2)))

func shirt(root: Node3D,mat: Material) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(16):
		for column in range(12):
			var points: Array[Vector3]=[]
			for t in [row/16.0,(row+1)/16.0]:
				for u in [column/12.0,(column+1)/12.0]:
					var x: float=(u-.5)*lerpf(.25,.30,t)
					var y: float=lerpf(.39,-.02,t)
					points.append(Vector3(x,y,chest_z(x,y)-.010))
			for k in [0,2,1,1,2,3]:
				st.set_uv(Vector2(points[k].x*2,points[k].y*2))
				st.add_vertex(points[k])
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,mat).set_meta("driver_bone",0)

func hat(root: Node3D) -> void:
	var felt: Material=material("v3_felt","1c1d21",.95,34)
	felt.cull_mode=BaseMaterial3D.CULL_DISABLED
	var gold: Material=material("v3_gold","caa35e",.34,3,.55)
	orb(root,Vector3(0,1.235,.045),Vector3(.43,.18,.275),felt,1)
	orb(root,Vector3(0,1.145,.015),Vector3(.445,.054,.290),material("v3_hat_band","9c4335",.79,35),1)
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int=[96,64,40][detail]
	var border: Array[Vector3]=[]
	for n in range(count):
		var a: float=TAU*n/count
		for row in range(9):
			var points: Array[Vector3]=[]
			for t in [row/9.0,(row+1)/9.0]:
				for angle in [a,TAU*(n+1)/count]:
					var c: float=cos(angle)
					var s: float=sin(angle)
					var fold: float=.34*pow(maxf(-s,0),3)+.12*pow(absf(c),6)+.16*pow(maxf(s,0),3)
					points.append(Vector3(c*lerpf(.27,.64,t),1.135+fold*pow(t,1.9),s*lerpf(.20,.43,t)))
			for k in [0,2,1,1,2,3]:
				st.set_uv(Vector2(points[k].x,points[k].z))
				st.add_vertex(points[k])
		var fold: float=.34*pow(maxf(-sin(a),0),3)+.12*pow(absf(cos(a)),6)+.16*pow(maxf(sin(a),0),3)
		border.append(Vector3(cos(a)*.64,1.135+fold,sin(a)*.43))
	border.append(border[0])
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,felt).set_meta("driver_bone",1)
	path(root,border,.010,gold,1)
	# Embossed insignia follows the folded front of the hat.
	if identity==0:
		path(root,[Vector3(0,1.275,-.409),Vector3(0,1.325,-.418),Vector3(0,1.403,-.430)],.0085,gold,1)
		path(root,[Vector3(-.047,1.355,-.424),Vector3(0,1.357,-.428),Vector3(.047,1.355,-.424)],.0075,gold,1)
		var anchor: Array[Vector3]=[]
		for i in range(17):
			var a: float=PI+PI*i/16
			anchor.append(Vector3(cos(a)*.065,1.323+sin(a)*.060,-.423))
		path(root,anchor,.009,gold,1)
		var ring: MeshInstance3D=IRArt.ring(root,.015,.004,Vector3(0,1.414,-.433),gold)
		ring.rotation.x=PI*.5
		ring.set_meta("driver_bone",1)
	else:
		for sign_value in [-1.0,1.0]:
			path(root,[Vector3(-.072,1.34+sign_value*.055,-.420),Vector3(0,1.34,-.424),Vector3(.072,1.34-sign_value*.055,-.429)],.007,gold,1)
		orb(root,Vector3(0,1.35,-.432),Vector3(.050,.050,.010),gold,1)
		orb(root,Vector3(0,1.329,-.444),Vector3(.027,.020,.006),gold,1)
		for side in [-1.0,1.0]:
			orb(root,Vector3(side*.019,1.362,-.443),Vector3(.010,.012,.003),felt,1)
			orb(root,Vector3(side*.010,1.326,-.452),Vector3(.004,.006,.002),felt,1)
		bow(root)

func bow(root: Node3D) -> void:
	var fabric: Material=material("v3_bow","bf557e",.66,35)
	fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	var center: Vector3=Vector3(.32,1.155,-.345)
	for side in [-1.0,1.0]:
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(12):
			for col in range(8):
				var points: Array[Vector3]=[]
				for u in [row/12.0,(row+1)/12.0]:
					for v in [col/8.0,(col+1)/8.0]:
						var width: float=.020+.092*sin(u*PI*.8)
						points.append(center+Vector3(side*(.01+u*.16),side*.025*u+(v-.5)*width*2,-sin(u*PI)*.043+pow((v-.5)*2,2)*.018))
				for k in [0,1,2,1,3,2]:
					st.set_uv(Vector2(points[k].x*5,points[k].y*5))
					st.add_vertex(points[k])
		st.index()
		st.generate_normals()
		IRArt.part(root,st.commit(),Vector3.ZERO,fabric).set_meta("driver_bone",1)
	orb(root,center+Vector3(0,0,-.035),Vector3(.030,.043,.026),fabric,1)

func ears(root: Node3D) -> void:
	if identity==0: return
	for side in [-1.0,1.0]:
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for back in [false,true]:
			for row in range(20):
				for col in range(12):
					var points: Array[Vector3]=[]
					for u in [row/20.0,(row+1)/20.0]:
						for v in [col/12.0,(col+1)/12.0]:
							points.append(ear_point(side,u,v,back))
					for k in ([0,2,1,1,2,3] if (side<0)==back else [0,1,2,1,3,2]):
						st.set_uv(Vector2(points[k].x,points[k].y))
						st.set_color(Color("efad9e") if back else Color("e99699").lerp(Color("f2b9a7"),absf(col/12.0-.5)*1.4))
						st.add_vertex(points[k])
		for boundary in range(4):
			for n in range(20):
				var points: Array[Vector3]=[]
				for t in [n/20.0,(n+1)/20.0]:
					var q: Vector2=[Vector2(t,0),Vector2(t,1),Vector2(0,t),Vector2(1,t)][boundary]
					for back in [false,true]: points.append(ear_point(side,q.x,q.y,back))
				for k in [0,2,1,1,2,3]:
					st.set_uv(Vector2(points[k].x,points[k].y))
					st.set_color(Color("efad9e"))
					st.add_vertex(points[k])
		st.index()
		st.generate_normals()
		var skin: StandardMaterial3D=material("v3_ear_skin","ffffff",.58,30)
		skin.vertex_color_use_as_albedo=true
		skin.vertex_color_is_srgb=true
		skin.cull_mode=BaseMaterial3D.CULL_DISABLED
		IRArt.part(root,st.commit(),Vector3.ZERO,skin).set_meta("driver_bone",1)

func ear_point(side: float,u: float,v: float,back: bool) -> Vector3:
	var w: float=sin(PI*pow(u,.75))*.135+.018*(1-u)+.025*u
	var p: Vector3=Vector3(side*(.345+.29*u),1.005+.095*sin(u*PI)-.14*u+(v-.5)*w*2,.005-.075*sin(u*PI)+.045*u+pow((v-.5)*2,2)*.070)
	p.z+=.018 if back else -.018
	return p

func clothing(root: Node3D) -> void:
	var coat: Material=material("v3_coat%d"%identity,"25485e" if identity==0 else "8e3444",.83,35)
	var lapel: Material=material("v3_lapel","343034",.82,35)
	var linen: Material=material("v3_linen","d8c7a1",.90,7)
	var leather: Material=material("v3_leather","624735",.78,35)
	var gold: Material=material("v3_gold","caa35e",.34,3,.55)
	var skin: Material=material("v3_hands%d"%identity,"98b54d" if identity==0 else "edb09f",.55,30)
	torso(root,coat)
	shirt(root,linen)
	var neck: MeshInstance3D=orb(root,Vector3(0,.402,.025),Vector3(.15,.075,.105),skin,1)
	neck.set_meta("blend_neck",true)
	for side in [-1.0,1.0]:
		var upper: Array[Vector3]=[Vector3(side*.105,.41,-.15),Vector3(side*.31,.355,-.188),Vector3(side*.235,.205,-.245),Vector3(side*.105,.285,-.248)]
		var lower: Array[Vector3]=[Vector3(side*.105,.285,-.248),Vector3(side*.235,.205,-.245),Vector3(side*.285,-.015,-.219),Vector3(side*.145,-.02,-.25)]
		for n in range(upper.size()): upper[n].z=chest_z(upper[n].x,upper[n].y)-.020
		for n in range(lower.size()): lower[n].z=chest_z(lower[n].x,lower[n].y)-.020
		face(root,upper,lapel)
		face(root,lower,lapel)
		path(root,[upper[0],upper[1],upper[2],upper[3],lower[3]],.007,gold)
		for y in [.04,.15,.26]: orb(root,Vector3(side*.255,y,chest_z(side*.255,y)-.030),Vector3(.015,.015,.008),gold,0)
		var arm: int=2 if side<0 else 3
		path(root,[Vector3(side*.385,.315,.025),Vector3(side*.455,.155,-.18),Vector3(side*.27,.075,-.475)],.112,coat,arm,.073)
		orb(root,Vector3(side*.39,.31,.02),Vector3(.126,.105,.16),coat,arm)
		var cuff: MeshInstance3D=orb(root,Vector3(side*.278,.083,-.453),Vector3(.084,.074,.058),lapel,arm)
		cuff.rotation.x=.45
		path(root,[Vector3(side*.349,.10,-.44),Vector3(side*.29,.135,-.46),Vector3(side*.213,.09,-.44)],.006,gold,arm)
		orb(root,Vector3(side*.258,.060,-.499),Vector3(.074,.056,.062),skin,arm)
		for finger in range(3):
			var x: float=side*(.216+finger*.032)
			path(root,[Vector3(x,.060,-.517),Vector3(x,.031,-.543),Vector3(x,.010,-.528)],.018,skin,arm,.014)
		path(root,[Vector3(side*.213,.066,-.479),Vector3(side*.191,.039,-.502),Vector3(side*.200,.021,-.517)],.021,skin,arm,.014)
		# Braided shoulder trim stays close to the fitted sleeve.
		path(root,[Vector3(side*.30,.385,-.03),Vector3(side*.40,.402,.015),Vector3(side*.48,.345,.04)],.008,gold,arm)
		for i in range(4): path(root,[Vector3(side*(.35+i*.026),.37,.077),Vector3(side*(.35+i*.026),.315,.092)],.004,gold,arm,.003)
		orb(root,Vector3(side*.165,-.055,-.10),Vector3(.158,.14,.22),leather,0)
		path(root,[Vector3(side*.165,-.07,-.16),Vector3(side*.18,-.20,-.25),Vector3(side*.185,-.31,-.32)],.087,leather,0,.075)
		orb(root,Vector3(side*.185,-.345,-.368),Vector3(.106,.072,.153),material("v3_boot","3d3430",.76,35),0)
	if identity==1:
		for layer in range(3):
			var st: SurfaceTool=SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for n in range(40):
				for row in range(4):
					var points: Array[Vector3]=[]
					for u in [n/40.0,(n+1)/40.0]:
						for v in [row/4.0,(row+1)/4.0]:
							var width: float=.085+layer*.029+v*.035
							points.append(Vector3((u-.5)*width*2,.355-layer*.065-v*(.082+.010*cos(u*TAU*5)),-.245-layer*.01-v*.018+sin(u*TAU*9)*.007))
					for k in [0,1,2,1,3,2]:
						st.set_uv(Vector2(points[k].x*3,points[k].y*3))
						st.add_vertex(points[k])
			st.index()
			st.generate_normals()
			IRArt.part(root,st.commit(),Vector3.ZERO,linen).set_meta("driver_bone",0)
	else:
		var strap: SurfaceTool=SurfaceTool.new()
		strap.begin(Mesh.PRIMITIVE_TRIANGLES)
		for n in range(24):
			var points: Array[Vector3]=[]
			for t in [n/24.0,(n+1)/24.0]:
				for side in [-1.0,1.0]:
					var x: float=lerpf(-.19,.17,t)+side*.023
					var y: float=lerpf(.33,-.03,t)+side*.023
					points.append(Vector3(x,y,chest_z(x,y)-.035))
			for k in [0,2,1,1,2,3]:
				strap.set_uv(Vector2(points[k].x*2,points[k].y*2))
				strap.add_vertex(points[k])
		strap.index()
		strap.generate_normals()
		IRArt.part(root,strap.commit(),Vector3.ZERO,leather).set_meta("driver_bone",0)
		for y in [.08,.24]:
			var center: Vector3=Vector3(.14-y,y,chest_z(.14-y,y)-.049)
			for edge in range(4):
				var p: Vector3=Vector3((-.032 if edge==0 else (.032 if edge==1 else 0)),(-.04 if edge==2 else (.04 if edge==3 else 0)),0)
				var size: Vector3=Vector3(.007,.08,.012) if edge<2 else Vector3(.064,.007,.012)
				var piece: MeshInstance3D=box(root,size,center+Basis(Vector3.BACK,PI*.25)*p,gold)
				piece.rotation.z=PI*.25
	# Folded neckerchief, knot and two cloth tails share the GPU scarf joints.
	var scarf: Material=material("v3_scarf","aa4533" if identity==0 else "a43a45",.83,7)
	scarf.cull_mode=BaseMaterial3D.CULL_DISABLED
	orb(root,Vector3(0,.423,-.005),Vector3(.202,.045,.165),scarf,4)
	orb(root,Vector3(.03,.385,-.197),Vector3(.039,.040,.027),scarf,4)
	for side in [-1.0,1.0]:
		face(root,[Vector3(.03,.385,-.22),Vector3(.03+side*.09,.255,-.25),Vector3(.03+side*.035,.235,-.25)],scarf,0)
		face(root,[Vector3(side*.05,.40,.14),Vector3(side*.18,.38,.31),Vector3(side*.21,.365,.61),Vector3(side*.11,.39,.59),Vector3(side*.02,.405,.24)],scarf,4)

func weight_parts(root: Node3D) -> void:
	for child in root.get_children():
		if not child is MeshInstance3D: continue
		var result: ArrayMesh=ArrayMesh.new()
		var bone: int=int(child.get_meta("driver_bone",0))
		for s in range(child.mesh.get_surface_count()):
			var arrays: Array=child.mesh.surface_get_arrays(s)
			var count: int=arrays[Mesh.ARRAY_VERTEX].size()
			var bones: PackedInt32Array=PackedInt32Array()
			var weights: PackedFloat32Array=PackedFloat32Array()
			bones.resize(count*4)
			weights.resize(count*4)
			for i in range(count):
				var p: Vector3=child.transform*arrays[Mesh.ARRAY_VERTEX][i]
				bones[i*4]=bone
				weights[i*4]=1
				if child.get_meta("blend_neck",false):
					var blend: float=smoothstep(.365,.505,p.y)
					bones[i*4+1]=0
					weights[i*4]=blend
					weights[i*4+1]=1-blend
				if bone==4 or bone==5:
					var blend: float=smoothstep(.25,.60,p.z)
					bones[i*4]=4
					bones[i*4+1]=5
					weights[i*4]=1-blend
					weights[i*4+1]=blend
			arrays[Mesh.ARRAY_BONES]=bones
			arrays[Mesh.ARRAY_WEIGHTS]=weights
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			result.surface_set_material(s,child.mesh.surface_get_material(s))
		child.mesh=result

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/characters/portrait_v3")
	for character in range(2):
		identity=character
		portrait.species=identity
		for profile in range(3):
			detail=profile
			portrait.detail=detail
			var model: Node3D=Node3D.new()
			portrait.head(model)
			portrait.eyes(model)
			ears(model)
			hat(model)
			clothing(model)
			weight_parts(model)
			var baked: MeshInstance3D=IRArt.bake(model,true)
			var importer: ImporterMesh=ImporterMesh.from_mesh(baked.mesh)
			importer.generate_lods(60.0,25.0,[])
			var mesh: ArrayMesh=importer.get_mesh()
			var key: String=("zabol" if identity==0 else "swinka")+"_driver"+["","_balanced","_performance"][detail]
			assert(ResourceSaver.save(mesh,"res://assets/characters/portrait_v3/"+key+".res",ResourceSaver.FLAG_COMPRESS)==OK)
			var count: int=0
			for s in range(mesh.get_surface_count()): count+=mesh.surface_get_array_len(s)
			report[key]={"vertices":count,"surfaces":mesh.get_surface_count(),"eye_center":str(portrait.eye_center())}
			print("PORTRAIT_DRIVER ",key," ",report[key])
			model.free()
	var file: FileAccess=FileAccess.open("res://assets/characters/portrait_v3/mesh_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("PORTRAIT_DRIVERS PASS: six explicit-topology meshes")
	quit()
