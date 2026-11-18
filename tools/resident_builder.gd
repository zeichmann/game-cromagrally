extends RefCounted
## Independently authored animal residents. Six weighted parts are animated in a GPU shader.
var maker: RefCounted

func orb(root: Node3D,p: Vector3,size: Vector3,mat: Material,bone: int=0,detail: int=16) -> MeshInstance3D:
	var sphere: SphereMesh=SphereMesh.new()
	sphere.radius=.5
	sphere.height=1.0
	sphere.radial_segments=detail
	sphere.rings=10
	var part: MeshInstance3D=IRArt.part(root,sphere,p,mat)
	part.scale=size
	part.set_meta("resident_bone",bone)
	return part

func rod(root: Node3D,a: Vector3,b: Vector3,radius: float,mat: Material,bone: int=0) -> void:
	var part: MeshInstance3D=IRArt.tube(root,a,b,radius,mat,radius*.8)
	part.set_meta("resident_bone",bone)

func weighted(root: Node3D) -> Node3D:
	for child in root.get_children():
		if not child is MeshInstance3D: continue
		var result: ArrayMesh=ArrayMesh.new()
		for surface in range(child.mesh.get_surface_count()):
			var arrays: Array=child.mesh.surface_get_arrays(surface)
			var count: int=arrays[Mesh.ARRAY_VERTEX].size()
			var bones: PackedInt32Array=PackedInt32Array()
			var weights: PackedFloat32Array=PackedFloat32Array()
			bones.resize(count*4)
			weights.resize(count*4)
			for i in range(count):
				bones[i*4]=int(child.get_meta("resident_bone",0))
				weights[i*4]=1.0
			arrays[Mesh.ARRAY_BONES]=bones
			arrays[Mesh.ARRAY_WEIGHTS]=weights
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			result.surface_set_material(surface,child.mesh.surface_get_material(surface))
		child.mesh=result
	maker=null
	return root

func resident(author: RefCounted,species: int) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var fur: Material=maker.paint("resident_fur%d"%species,"d3bd96" if species==0 else "ac9178",.9)
	var muzzle: Material=maker.paint("resident_muzzle","edddbe",.88)
	var inside: Material=maker.paint("resident_ear","cd9d98",.9)
	var jacket: Material=maker.paint("resident_jacket%d"%species,"708e94" if species==0 else "a27661",.85)
	var trousers: Material=maker.paint("resident_trousers","667375",.9)
	var black: Material=maker.paint("resident_eyes","242b2d",.35)
	var white: Material=maker.paint("resident_highlight","fff8e8",.4)
	orb(root,Vector3(0,1.02,0),Vector3(.75,.88,.50),jacket)
	orb(root,Vector3(0,1.33,.01),Vector3(.44,.21,.36),muzzle)
	orb(root,Vector3(0,1.72,.02),Vector3(.66,.65,.56),fur,1,24)
	for side in [-1.0,1.0]:
		var ear: MeshInstance3D=orb(root,Vector3(side*.23,2.15,0),Vector3(.20,.80,.15) if species==0 else Vector3(.40,.42,.17),fur,1)
		ear.rotation.z=-side*.18
		var inner: MeshInstance3D=orb(root,Vector3(side*.23,2.16,.068),Vector3(.12,.58,.04) if species==0 else Vector3(.27,.28,.04),inside,1)
		inner.rotation.z=-side*.18
		orb(root,Vector3(side*.15,1.76,.275),Vector3(.095,.12,.045),black,1,12)
		orb(root,Vector3(side*.15-.013,1.79,.298),Vector3(.026,.030,.012),white,1,10)
		orb(root,Vector3(side*.075,1.59,.30),Vector3(.17,.14,.15),muzzle,1)
		var arm: int=2 if side<0 else 3
		rod(root,Vector3(side*.31,1.25,0),Vector3(side*.43,.86,.03),.12,jacket,arm)
		orb(root,Vector3(side*.45,.81,.06),Vector3(.19,.20,.20),fur,arm)
		var leg: int=4 if side<0 else 5
		rod(root,Vector3(side*.19,.73,0),Vector3(side*.21,.23,.02),.13,trousers,leg)
		orb(root,Vector3(side*.21,.15,.08),Vector3(.26,.23,.43),maker.paint("resident_boots","655348",.86),leg)
	orb(root,Vector3(0,1.64,.395),Vector3(.10,.065,.075),inside,1)
	rod(root,Vector3(0,1.59,.385),Vector3(0,1.55,.367),.012,black,1)
	for y in [.90,1.09,1.24]:
		orb(root,Vector3(.05,y,.25),Vector3(.045,.045,.025),maker.paint("resident_buttons","c8ac70",.55,.35))
	# A cloth cap and satchel distinguish messenger and market keeper silhouettes.
	orb(root,Vector3(0,2.04,-.02),Vector3(.72,.22,.64),jacket,1)
	orb(root,Vector3(0,2.02,.22),Vector3(.72,.055,.34),jacket,1)
	rod(root,Vector3(-.27,1.3,.24),Vector3(.32,.76,.27),.037,maker.paint("satchel_leather","80624c",.82))
	orb(root,Vector3(.36,.77,.19),Vector3(.30,.35,.19),maker.paint("satchel_leather","80624c",.82))
	orb(root,Vector3(0,.85,-.30),Vector3(.24,.25,.24),muzzle)
	return weighted(root)

func cat(author: RefCounted) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var fur: Material=maker.paint("cat_ginger","bd946c",.9)
	var cream: Material=maker.paint("cat_cream","ead7ac",.9)
	orb(root,Vector3(0,.30,0),Vector3(.43,.48,.82),fur)
	orb(root,Vector3(0,.58,.34),Vector3(.48,.45,.43),fur,1)
	for side in [-1.0,1.0]:
		var cone: CylinderMesh=CylinderMesh.new()
		cone.top_radius=0
		cone.bottom_radius=.13
		cone.height=.28
		cone.radial_segments=4
		IRArt.part(root,cone,Vector3(side*.16,.86,.29),fur).set_meta("resident_bone",1)
		orb(root,Vector3(side*.10,.62,.54),Vector3(.08,.07,.026),maker.paint("cat_eye","677c43",.4),1,12)
		orb(root,Vector3(side*.10,.62,.555),Vector3(.025,.062,.016),maker.paint("resident_eyes","242b2d",.35),1,10)
		for z in [-.22,.22]:
			orb(root,Vector3(side*.15,.10,z),Vector3(.14,.19,.23),cream)
	orb(root,Vector3(0,.51,.56),Vector3(.11,.075,.07),maker.paint("cat_nose","ad7d7d",.8),1)
	var previous: Vector3=Vector3(0,.40,-.35)
	for n in range(9):
		var t: float=(n+1)/9.0
		var point: Vector3=Vector3(sin(t*1.6)*.28,.40+t*.55,-.35-t*.45)
		rod(root,previous,point,.055*(1-t*.7),fur,3)
		previous=point
	return weighted(root)

func bird(author: RefCounted,duck: bool=false) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	var feathers: Material=maker.paint("duck_feathers" if duck else "gull_feathers","d7c6a5" if duck else "e9e4d5",.9)
	var tips: Material=maker.paint("bird_tips","6a7580",.9)
	var beak: Material=maker.paint("bird_beak","d2aa61",.9)
	orb(root,Vector3(0,.16,0),Vector3(.38,.30,.62),feathers)
	orb(root,Vector3(0,.35,.25),Vector3(.25,.28,.26),maker.paint("duck_head","71836a",.88) if duck else feathers,1)
	orb(root,Vector3(0,.32,.43),Vector3(.13,.075,.24),beak,1)
	for side in [-1.0,1.0]:
		orb(root,Vector3(side*.09,.38,.34),Vector3(.025,.029,.019),maker.paint("resident_eyes","242b2d",.35),1,10)
		var wing: MeshInstance3D=orb(root,Vector3(side*(.18 if duck else .42),.18,-.02),Vector3(.12,.26,.40) if duck else Vector3(.72,.055,.36),tips,2 if side<0 else 3)
		wing.rotation.z=side*.12
	return weighted(root)
