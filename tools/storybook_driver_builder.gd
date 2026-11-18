extends SceneTree
## Offline original sculpture. Continuous implicit heads, folded ears and a six-joint seated rig.
## This tool never runs in the game; the runtime loads the compressed weighted meshes.
const TETRA: Array= [[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
const CORNERS: Array[Vector3]=[Vector3(0,0,0),Vector3(1,0,0),Vector3(1,1,0),Vector3(0,1,0),Vector3(0,0,1),Vector3(1,0,1),Vector3(1,1,1),Vector3(0,1,1)]
var identity: int=0
var detail: int=0
var mats: Dictionary={}
var report: Dictionary={}

func _initialize() -> void:
	call_deferred("build")

func material(key: String,color: String,roughness: float=.65,kind: int=0,metal: float=0) -> StandardMaterial3D:
	if not mats.has(key):
		var mat: StandardMaterial3D=StandardMaterial3D.new()
		mat.albedo_color=Color(color)
		mat.roughness=roughness
		mat.metallic=metal
		mat.set_meta("palette_kind",kind)
		mats[key]=mat
	return mats[key]

func orb(root: Node3D,p: Vector3,radii: Vector3,mat: Material,bone: int) -> MeshInstance3D:
	var sphere: SphereMesh=SphereMesh.new()
	sphere.radius=1
	sphere.height=2
	sphere.radial_segments=[32,24,16][detail]
	sphere.rings=[20,14,10][detail]
	var part: MeshInstance3D=IRArt.part(root,sphere,p,mat)
	part.scale=radii
	part.set_meta("driver_bone",bone)
	return part

func rod(root: Node3D,a: Vector3,b: Vector3,r: float,mat: Material,bone: int) -> void:
	var part: MeshInstance3D=IRArt.tube(root,a,b,r,mat,r*.90)
	part.set_meta("driver_bone",bone)

func curve(root: Node3D,points: Array[Vector3],r: float,mat: Material,bone: int) -> void:
	for i in range(points.size()-1): rod(root,points[i],points[i+1],r,mat,bone)

func ellipsoid(p: Vector3,c: Vector3,r: Vector3) -> float:
	# Sign-correct ellipsoid approximation, used only for offline surface extraction.
	return ((p-c)/r).length()*minf(r.x,minf(r.y,r.z))-minf(r.x,minf(r.y,r.z))

func union_smooth(a: float,b: float,k: float=.055) -> float:
	var h: float=clampf(.5+.5*(b-a)/k,0,1)
	return lerpf(b,a,h)-k*h*(1-h)

func mouth_space(p: Vector3) -> Vector3:
	var w: float=.34 if identity==0 else .245
	return Vector3(p.x,p.y-.555-.10*pow(p.x/w,2),p.z+.30)

func head_shape(p: Vector3) -> float:
	var d: float
	if identity==0:
		d=ellipsoid(p,Vector3(0,.75,0),Vector3(.47,.33,.29))
		d=union_smooth(d,ellipsoid(p,Vector3(0,.66,-.18),Vector3(.43,.20,.20)))
		d=union_smooth(d,ellipsoid(p,Vector3(0,.52,-.045),Vector3(.40,.14,.275)))
		for side in [-1.0,1.0]:
			d=union_smooth(d,ellipsoid(p,Vector3(side*.245,.95,-.015),Vector3(.215,.22,.23)),.065)
	else:
		d=ellipsoid(p,Vector3(0,.77,0),Vector3(.435,.36,.295))
		for side in [-1.0,1.0]:
			d=union_smooth(d,ellipsoid(p,Vector3(side*.255,.65,-.075),Vector3(.215,.215,.24)),.075)
		d=union_smooth(d,ellipsoid(p,Vector3(0,.735,-.295),Vector3(.222,.11,.13)),.035)
	return d

func field(p: Vector3) -> float:
	var d: float=head_shape(p)
	for side in [-1.0,1.0]:
		if identity==0:
			d=maxf(d,-ellipsoid(p,Vector3(side*.245,.94,-.217),Vector3(.151,.176,.145)))
		else:
			d=maxf(d,-ellipsoid(p,Vector3(side*.087,.750,-.414),Vector3(.043,.046,.047)))
			d=maxf(d,-ellipsoid(p,Vector3(side*.19,.88,-.235),Vector3(.109,.135,.095)))
	var q: Vector3=mouth_space(p)
	var mouth: float=ellipsoid(q,Vector3.ZERO,Vector3(.335,.105,.195) if identity==0 else Vector3(.235,.092,.15))
	d=maxf(d,-mouth)
	return d

func field_normal(p: Vector3) -> Vector3:
	const E: float=.001
	return Vector3(field(p+Vector3(E,0,0))-field(p-Vector3(E,0,0)),field(p+Vector3(0,E,0))-field(p-Vector3(0,E,0)),field(p+Vector3(0,0,E))-field(p-Vector3(0,0,E))).normalized()

func pigment(p: Vector3) -> Color:
	var base: Color=Color("87a942") if identity==0 else Color("f6a9a3")
	var chin: Color=Color("e2d998") if identity==0 else Color("ffd1bb")
	base=base.lerp(chin,(1-smoothstep(.52,.72,p.y))*.70)
	var cheek: float=exp(-pow((absf(p.x)-.31)/.10,2)-pow((p.y-.69)/.10,2))*smoothstep(.04,.23,-p.z)
	base=base.lerp(Color("e59b79") if identity==0 else Color("ec8f94"),cheek*.40)
	var q: Vector3=mouth_space(p)
	var r: Vector3=Vector3(.335,.105,.195) if identity==0 else Vector3(.235,.092,.15)
	var cavity: float=(1-smoothstep(.008,.035,absf(ellipsoid(q,Vector3.ZERO,r))))*(1-smoothstep(-.025,.012,head_shape(p)))
	base=base.lerp(Color("632b28").lerp(Color("ad5855"),clampf((.58-p.y)*6,0,.7)),cavity)
	if identity==1:
		for side in [-1.0,1.0]:
			var nostril: float=absf(ellipsoid(p,Vector3(side*.087,.750,-.414),Vector3(.043,.046,.047)))
			base=base.lerp(Color("a75b61"),(1-smoothstep(.004,.018,nostril))*(1-smoothstep(-.017,.004,head_shape(p))))
	var freckles: float=sin(p.x*103+p.z*17)*sin(p.y*121+p.x*19)
	return base*(.986+maxf(freckles,0)*.025)

func emit_triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,outward: Vector3) -> void:
	if (b-a).cross(c-a).length_squared()<1e-14: return
	var points: Array[Vector3]=[a,b,c]
	# A tetrahedron's interpolant defines the winding. Sampling the nonlinear field
	# at a triangle centre can select the opposite CSG branch at a sharp lip.
	if (c-a).cross(b-a).dot(outward)<0:
		points=[a,c,b]
	for p in points:
		st.set_normal(field_normal(p))
		st.set_color(pigment(p))
		st.set_uv(Vector2(p.x+.5,p.y))
		st.add_vertex(p)

func intersect(a: Vector3,b: Vector3,da: float,db: float) -> Vector3:
	return a.lerp(b,da/(da-db))

func head(root: Node3D) -> void:
	var step: float=[.026,.040,.060][detail]
	var low: Vector3=Vector3(-.54,.35,-.48)
	var size: Vector3=Vector3(1.08,.87,.85)
	var nx: int=ceili(size.x/step)+1
	var ny: int=ceili(size.y/step)+1
	var nz: int=ceili(size.z/step)+1
	var values: PackedFloat32Array=PackedFloat32Array()
	values.resize(nx*ny*nz)
	for z in range(nz):
		for y in range(ny):
			for x in range(nx): values[x+nx*(y+ny*z)]=field(low+Vector3(x,y,z)*step)
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(nz-1):
		for y in range(ny-1):
			for x in range(nx-1):
				var points: Array[Vector3]=[]
				var ds: Array[float]=[]
				var positive: bool=false
				var negative: bool=false
				for corner in CORNERS:
					points.append(low+(Vector3(x,y,z)+corner)*step)
					var d: float=values[(x+int(corner.x))+nx*((y+int(corner.y))+ny*(z+int(corner.z)))]
					ds.append(d)
					positive=positive or d>=0
					negative=negative or d<0
				if not (positive and negative): continue
				for tetra in TETRA:
					var inside: Array[int]=[]
					var outside: Array[int]=[]
					for k in tetra:
						if ds[k]<0: inside.append(k)
						else: outside.append(k)
					if inside.is_empty() or outside.is_empty(): continue
					var positive_center: Vector3=Vector3.ZERO
					var negative_center: Vector3=Vector3.ZERO
					for k in outside: positive_center+=points[k]/outside.size()
					for k in inside: negative_center+=points[k]/inside.size()
					var outward: Vector3=positive_center-negative_center
					if inside.size()==1 or outside.size()==1:
						var one: int=inside[0] if inside.size()==1 else outside[0]
						var rest: Array[int]=outside if inside.size()==1 else inside
						var face: Array[Vector3]=[]
						for k in rest: face.append(intersect(points[one],points[k],ds[one],ds[k]))
						emit_triangle(st,face[0],face[1],face[2],outward)
					else:
						var a: Vector3=intersect(points[inside[0]],points[outside[0]],ds[inside[0]],ds[outside[0]])
						var b: Vector3=intersect(points[inside[0]],points[outside[1]],ds[inside[0]],ds[outside[1]])
						var c: Vector3=intersect(points[inside[1]],points[outside[0]],ds[inside[1]],ds[outside[0]])
						var d: Vector3=intersect(points[inside[1]],points[outside[1]],ds[inside[1]],ds[outside[1]])
						emit_triangle(st,a,b,c,outward)
						emit_triangle(st,b,d,c,outward)
	st.index()
	var skin: StandardMaterial3D=material("skin%d"%identity,"ffffff",.67,30)
	skin.vertex_color_use_as_albedo=true
	skin.vertex_color_is_srgb=true
	IRArt.part(root,st.commit(),Vector3.ZERO,skin).set_meta("driver_bone",1)

func eyes(root: Node3D) -> void:
	var eye_y: float=.94 if identity==0 else .88
	var eye_x: float=.245 if identity==0 else .19
	var eye_z: float=-.218 if identity==0 else -.239
	var scale_value: float=1.0 if identity==0 else .76
	var skin: Material=material("skin_plain%d"%identity,"8fac49" if identity==0 else "f4a8a0",.67,33)
	var white: Material=material("eye_white","fff7dd",.22,31)
	var iris: Material=material("eye_iris","875629",.24,32)
	var pupil: Material=material("eye_pupil","15191b",.18,32)
	var highlight: Material=material("eye_glint","fffce9",.15,32)
	for side in [-1.0,1.0]:
		orb(root,Vector3(side*eye_x,eye_y,eye_z),Vector3(.145,.167,.105)*scale_value,white,1)
		orb(root,Vector3(side*eye_x,eye_y-.006,eye_z-.097*scale_value),Vector3(.086,.105,.025)*scale_value,iris,1)
		orb(root,Vector3(side*eye_x,eye_y-.003,eye_z-.118*scale_value),Vector3(.053,.070,.013)*scale_value,pupil,1)
		orb(root,Vector3(side*eye_x-.023*scale_value,eye_y+.041*scale_value,eye_z-.130*scale_value),Vector3(.020,.023,.010)*scale_value,highlight,1)
		orb(root,Vector3(side*eye_x+.025*scale_value,eye_y-.030*scale_value,eye_z-.132*scale_value),Vector3(.007,.008,.006)*scale_value,highlight,1)
		var upper: Array[Vector3]=[]
		for n in range(17):
			var a: float=PI*n/16
			upper.append(Vector3(side*eye_x+cos(a)*.150*scale_value,eye_y+sin(a)*.169*scale_value,eye_z-.028))
		curve(root,upper,.016*scale_value,skin,1)
		if identity==1:
			var brow: Array[Vector3]=[]
			for n in range(9):
				var t: float=n/8.0
				brow.append(Vector3(side*eye_x+(t-.5)*.20,1.045+.027*sin(t*PI),-.22))
			curve(root,brow,.013,material("pig_brow","9b6358",.85),1)
			for n in range(3):
				var x: float=side*(eye_x+.056+n*.022)
				rod(root,Vector3(x,.953,-.281),Vector3(x+side*.025,.980+n*.004,-.274),.006,material("pig_lashes","493b3d",.8),1)
	# Tongue stays recessed behind the continuous jaw.
	orb(root,Vector3(0,.504,-.286),Vector3(.13,.037,.061) if identity==0 else Vector3(.09,.024,.044),material("tongue","d17a78",.63),1)
	if identity==1:
		for x in [-.047,.047]:
			orb(root,Vector3(x,.639,-.315),Vector3(.045,.022,.022),material("tooth","fff0cb",.58),1)
	else:
		for x in [-.067,.067]:
			orb(root,Vector3(x,.741,-.376),Vector3(.017,.011,.010),material("frog_nostril","52612c",.85,30),1)

func ears(root: Node3D) -> void:
	if identity==0: return
	# A thick, folded triangular pinna rather than spherical human-style ears.
	for side in [-1.0,1.0]:
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rows: int=14
		var cols: int=10
		for back in [false,true]:
			for row in range(rows):
				for col in range(cols):
					var quad: Array[Vector3]=[]
					for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
						var u: float=(row+corner.x)/rows
						var v: float=(col+corner.y)/cols
						var width: float=sin(PI*pow(u,.7))*.16+.015*(1-u)
						var p: Vector3=Vector3(side*(.34+.40*u),.99-.15*u+cos(u*PI)*.025+(v-.5)*width*2,-.01-.10*sin(u*PI)+(v-.5)*.04)
						p.z+=.035 if back else -.035
						quad.append(p)
					for k in ([0,2,1,2,3,1] if (side<0)==back else [0,1,2,2,1,3]):
						st.set_color(Color("f4a39c") if back else Color("e99190").lerp(Color("ffc0af"),absf((col/float(cols))-.5)*1.5))
						st.set_uv(Vector2(row/float(rows),col/float(cols)))
						st.add_vertex(quad[k])
		st.index()
		st.generate_normals()
		var mat: StandardMaterial3D=material("pig_ear","ffffff",.74,30)
		mat.vertex_color_use_as_albedo=true
		mat.vertex_color_is_srgb=true
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		IRArt.part(root,st.commit(),Vector3.ZERO,mat).set_meta("driver_bone",1)
		var edge: Array[Vector3]=[]
		for n in range(29):
			var u: float=(n if n<=14 else 28-n)/14.0
			var v: float=0 if n<=14 else 1
			var width: float=sin(PI*pow(u,.7))*.16+.015*(1-u)
			edge.append(Vector3(side*(.34+.40*u),.99-.15*u+cos(u*PI)*.025+(v-.5)*width*2,-.01-.10*sin(u*PI)+(v-.5)*.04))
		curve(root,edge,.018,material("ear_edge","f3ada3",.71,30),1)

func hat(root: Node3D) -> void:
	var felt: Material=material("hat_felt","383235",.87,34)
	felt.cull_mode=BaseMaterial3D.CULL_DISABLED
	var gold: Material=material("gold","d2a454",.38,3,.55)
	var band: Material=material("hat_band","a44b42",.78)
	orb(root,Vector3(0,1.235,.025),Vector3(.47,.20,.30),felt,1)
	orb(root,Vector3(0,1.167,.008),Vector3(.48,.068,.31),band,1)
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: Array[Vector3]=[]
	var count: int=[72,54,36][detail]
	for n in range(count+1):
		var a: float=TAU*n/count
		var wave: float=cos(3*(a+PI*.5))
		var p: Vector3=Vector3(cos(a)*(.59+wave*.10),1.20+wave*.19,sin(a)*(.40+wave*.09))
		edge.append(p)
		if n==count: continue
		var b: float=TAU*(n+1)/count
		var wb: float=cos(3*(b+PI*.5))
		var next: Vector3=Vector3(cos(b)*(.59+wb*.10),1.20+wb*.19,sin(b)*(.40+wb*.09))
		for row in range(6):
			var points: Array[Vector3]=[]
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
				var angle: float=lerpf(a,b,corner.y)
				var t: float=(row+corner.x)/6.0
				var w: float=cos(3*(angle+PI*.5))
				points.append(Vector3(cos(angle)*lerpf(.27,.59+w*.1,t),1.20+w*.19*pow(t,1.45),sin(angle)*lerpf(.20,.40+w*.09,t)))
			for k in [0,2,1,2,3,1]:
				st.set_uv(Vector2(points[k].x,points[k].z))
				st.add_vertex(points[k])
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,felt).set_meta("driver_bone",1)
	curve(root,edge,.016,gold,1)
	# Front crest sits on the raised central corner of the tricorne.
	if identity==0:
		rod(root,Vector3(0,1.24,-.465),Vector3(0,1.43,-.465),.012,gold,1)
		rod(root,Vector3(-.067,1.36,-.466),Vector3(.067,1.36,-.466),.011,gold,1)
		var anchor: Array[Vector3]=[]
		for n in range(13):
			var a: float=PI+PI*n/12
			anchor.append(Vector3(cos(a)*.083,1.33+sin(a)*.080,-.468))
		curve(root,anchor,.012,gold,1)
		orb(root,Vector3(0,1.44,-.467),Vector3(.026,.026,.008),gold,1)
	else:
		orb(root,Vector3(-.06,1.32,-.47),Vector3(.075,.073,.012),gold,1)
		orb(root,Vector3(-.06,1.295,-.486),Vector3(.037,.022,.007),felt,1)
		for x in [-.087,-.033]: orb(root,Vector3(x,1.34,-.485),Vector3(.012,.016,.006),felt,1)
		var bow: Material=material("pink_bow","d45d85",.66)
		for side in [-1.0,1.0]:
			var loop: MeshInstance3D=orb(root,Vector3(.34+side*.085,1.17,-.326),Vector3(.10,.085,.045),bow,1)
			loop.rotation.z=side*-.4
		orb(root,Vector3(.34,1.16,-.368),Vector3(.040,.045,.026),bow,1)

func clothing(root: Node3D) -> void:
	var coat: Material=material("coat%d"%identity,"3b657d" if identity==0 else "b34d51",.84,35)
	var lapel: Material=material("lapel","42383a",.82)
	var gold: Material=material("gold","d2a454",.38,3,.55)
	var linen: Material=material("ruff","eee0bd",.93,7)
	var scarf: Material=material("scarf%d"%identity,"be6446" if identity==0 else "b94e52",.82,7)
	var leather: Material=material("leather","795943",.81)
	var skin: Material=material("hand%d"%identity,"98ae53" if identity==0 else "f4a8a0",.68,30)
	orb(root,Vector3(0,.20,.005),Vector3(.31,.30,.23),coat,0)
	for side in [-1.0,1.0]:
		orb(root,Vector3(side*.23,.16,-.188),Vector3(.066,.24,.040),lapel,0).rotation.z=side*-.18
		rod(root,Vector3(side*.15,.39,-.175),Vector3(side*.25,-.01,-.196),.012,gold,0)
		for y in [.06,.19,.31]: orb(root,Vector3(side*.19,y,-.227),Vector3(.025,.025,.012),gold,0)
		var bone: int=2 if side<0 else 3
		rod(root,Vector3(side*.28,.30,0),Vector3(side*.39,.13,-.18),.11,coat,bone)
		rod(root,Vector3(side*.39,.13,-.18),Vector3(side*.255,.075,-.43),.095,coat,bone)
		orb(root,Vector3(side*.275,.09,-.385),Vector3(.108,.095,.052),gold,bone).rotation.x=.55
		orb(root,Vector3(side*.245,.055,-.46),Vector3(.085,.069,.093),skin,bone)
		orb(root,Vector3(side*.245,.037,-.505),Vector3(.065,.038,.035),skin,bone)
		orb(root,Vector3(side*.29,.35,-.015),Vector3(.13,.055,.15),gold,bone)
		for n in range(4):
			rod(root,Vector3(side*(.25+n*.023),.34,.04),Vector3(side*(.25+n*.023),.27,.045),.012,gold,bone)
		orb(root,Vector3(side*.16,-.035,-.10),Vector3(.16,.14,.23),leather,0)
		rod(root,Vector3(side*.17,-.05,-.19),Vector3(side*.19,-.30,-.32),.095,leather,0)
		orb(root,Vector3(side*.19,-.33,-.37),Vector3(.115,.075,.18),material("boot","4e4037",.73),0)
	# Scalloped, folded fabric rather than a necklace of disconnected spheres.
	for layer in range(3):
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for n in range(32):
			for row in range(5):
				var points: Array[Vector3]=[]
				for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
					var u: float=(n+corner.x)/32
					var v: float=(row+corner.y)/5
					var width: float=.11+layer*.036+v*.035
					points.append(Vector3((u-.5)*2*width,.365-layer*.068-v*(.085+.012*cos(u*TAU*5)),-.223-layer*.015-v*.016+sin(u*TAU*8)*.010))
				for k in [0,1,2,2,1,3]:
					st.set_uv(Vector2(points[k].x*3,points[k].y*3))
					st.add_vertex(points[k])
		st.index()
		st.generate_normals()
		IRArt.part(root,st.commit(),Vector3.ZERO,linen).set_meta("driver_bone",0)
	orb(root,Vector3(0,.405,-.005),Vector3(.23,.063,.205),scarf,4)
	var end: MeshInstance3D=orb(root,Vector3(.10,.36,.27),Vector3(.115,.030,.30),scarf,4)
	end.rotation.y=-.30
	orb(root,Vector3(.19,.355,.50),Vector3(.11,.025,.16),scarf,5).rotation.y=.3
	orb(root,Vector3(0,.38,-.229),Vector3(.04,.047,.024),gold,0)
	rod(root,Vector3(-.22,.35,-.23),Vector3(.21,.005,-.25),.030,leather,0)

func weight_parts(root: Node3D) -> void:
	for child in root.get_children():
		if not child is MeshInstance3D: continue
		var mesh: ArrayMesh=ArrayMesh.new()
		var bone: int=child.get_meta("driver_bone",0)
		for s in range(child.mesh.get_surface_count()):
			var arrays: Array=child.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=PackedInt32Array()
			var weights: PackedFloat32Array=PackedFloat32Array()
			bones.resize(vertices.size()*4)
			weights.resize(vertices.size()*4)
			for i in range(vertices.size()):
				var p: Vector3=child.transform*vertices[i]
				bones[i*4]=bone
				weights[i*4]=1
				if bone==1 and p.y<.56:
					var blend: float=smoothstep(.35,.56,p.y)
					bones[i*4+1]=0
					weights[i*4]=blend
					weights[i*4+1]=1-blend
				if bone==4 or bone==5:
					var blend: float=smoothstep(.27,.58,p.z)
					bones[i*4]=4
					bones[i*4+1]=5
					weights[i*4]=1-blend
					weights[i*4+1]=blend
			arrays[Mesh.ARRAY_BONES]=bones
			arrays[Mesh.ARRAY_WEIGHTS]=weights
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		child.mesh=mesh

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/characters/storybook_v2")
	for character in range(2):
		identity=character
		for profile in range(3):
			detail=profile
			var root_model: Node3D=Node3D.new()
			head(root_model)
			eyes(root_model)
			ears(root_model)
			hat(root_model)
			clothing(root_model)
			weight_parts(root_model)
			var packed: MeshInstance3D=IRArt.bake(root_model,true)
			var mesh: ArrayMesh=packed.mesh
			var importer: ImporterMesh=ImporterMesh.new()
			for s in range(mesh.get_surface_count()):
				importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(s),[],{},mesh.surface_get_material(s))
			importer.generate_lods(60,.15,[])
			mesh=importer.get_mesh()
			var name_value: String=("zabol" if identity==0 else "swinka")+"_driver"+["","_balanced","_performance"][detail]
			var path: String="res://assets/characters/storybook_v2/"+name_value+".res"
			var err: Error=ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)
			if err!=OK:
				push_error("Cannot save new driver "+path)
				quit(1)
				return
			var count: int=0
			for s in range(mesh.get_surface_count()): count+=mesh.surface_get_array_len(s)
			report[name_value]={"vertices":count,"surfaces":mesh.get_surface_count(),"bounds":str(mesh.get_aabb())}
			print("STORYBOOK_DRIVER ",name_value," ",report[name_value])
			root_model.free()
	var file: FileAccess=FileAccess.open("res://assets/characters/storybook_v2/mesh_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("STORYBOOK_DRIVERS PASS: six original weighted meshes")
	quit()
