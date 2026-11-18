extends "res://tools/resident_builder.gd"
## Friendly original villagers with connected facial loops and fitted work clothes.
var portrait: RefCounted=preload("res://tools/portrait_geometry.gd").new()

func block(root: Node3D,size: Vector3,p: Vector3,mat: Material,bone: int=0,radius: float=.025) -> MeshInstance3D:
	var node: MeshInstance3D=IRTeaGeometry.rounded_box(root,size,p,mat,radius)
	node.set_meta("resident_bone",bone)
	return node

func path(root: Node3D,points: Array[Vector3],radius: float,mat: Material,bone: int=0,end_radius: float=-1) -> void:
	portrait.detail=2
	portrait.path(root,points,radius,mat,bone,end_radius)
	root.get_child(-1).set_meta("resident_bone",bone)

func coat(root: Node3D,mat: Material) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels: Array[Vector3]=[Vector3(.28,.21,.72),Vector3(.33,.23,.90),Vector3(.35,.21,1.15),Vector3(.32,.17,1.32),Vector3(.19,.13,1.43)]
	for row in range(levels.size()-1):
		for n in range(32):
			var points: Array[Vector3]=[]
			for r in [levels[row],levels[row+1]]:
				for a in [TAU*n/32,TAU*(n+1)/32]: points.append(Vector3(cos(a)*r.x,r.z,sin(a)*r.y))
			for k in [0,1,2,1,3,2]:
				st.set_uv(Vector2(points[k].x,points[k].y))
				st.add_vertex(points[k])
	st.index()
	st.generate_normals()
	IRArt.part(root,st.commit(),Vector3.ZERO,mat).set_meta("resident_bone",0)

func resident(author: RefCounted,species: int) -> Node3D:
	maker=author
	var root: Node3D=Node3D.new()
	portrait.species=species+2
	portrait.detail=2
	var head: Node3D=Node3D.new()
	portrait.head(head)
	portrait.eyes(head)
	var cream: Material=maker.paint("portrait_cream","e9d8b7",.88)
	var fur: Material=maker.paint("portrait_fur%d"%species,"bda889" if species==0 else "a28d7f",.88)
	fur.set_meta("palette_kind",44)
	var inner: Material=maker.paint("portrait_ear","d19c99",.85)
	for side in [-1.0,1.0]:
		if species==0:
			portrait.orb(head,Vector3(side*.235,1.36,.02),Vector3(.105,.36,.080),fur).rotation.z=-side*.16
			portrait.orb(head,Vector3(side*.235,1.37,-.049),Vector3(.061,.265,.020),inner).rotation.z=-side*.16
		else:
			portrait.orb(head,Vector3(side*.37,1.105,.035),Vector3(.177,.195,.074),fur)
			portrait.orb(head,Vector3(side*.37,1.105,-.026),Vector3(.123,.139,.024),inner)
		for n in range(3):
			var p: Vector3=Vector3(side*.08,.75-n*.02,-.32)
			var whisker: Array[Vector3]=[p,p+Vector3(side*.11,(n-1)*.015,-.005),p+Vector3(side*.21,(n-1)*.025,.03)]
			portrait.path(head,whisker,.0025,maker.paint("portrait_whisker","8b7a65",.9),1,.001)
	var merged: MeshInstance3D=IRArt.bake(head)
	var head_node: MeshInstance3D=IRArt.part(root,merged.mesh,Vector3(0,1.09,0),null)
	head_node.basis=Basis(Vector3.UP,PI).scaled(Vector3(.85,.78,.8))
	head_node.set_meta("resident_bone",1)
	head.free()
	var fabric: Material=maker.paint("portrait_coat%d"%species,"486471" if species==0 else "885a60",.87)
	fabric.set_meta("palette_kind",35)
	var dark: Material=maker.paint("portrait_piping","37464b",.87)
	dark.set_meta("palette_kind",35)
	var trousers: Material=maker.paint("portrait_pants","655b4e",.89)
	var leather: Material=maker.paint("portrait_boot","51443c",.86)
	var brass: Material=maker.paint("portrait_brass","baa06b",.55,.28)
	coat(root,fabric)
	orb(root,Vector3(0,1.43,.01),Vector3(.34,.18,.30),cream)
	for side in [-1.0,1.0]:
		path(root,[Vector3(side*.31,1.25,0),Vector3(side*.405,1.08,.015),Vector3(side*.43,.89,.045)],.105,fabric,2 if side<0 else 3,.075)
		block(root,Vector3(.155,.105,.16),Vector3(side*.43,.88,.045),dark,2 if side<0 else 3,.025)
		orb(root,Vector3(side*.44,.81,.07),Vector3(.17,.18,.18),fur,2 if side<0 else 3,20)
		for n in range(3): orb(root,Vector3(side*(.40+n*.035),.76,.12),Vector3(.045,.07,.055),fur,2 if side<0 else 3,12)
		path(root,[Vector3(side*.17,.74,0),Vector3(side*.19,.50,0),Vector3(side*.20,.22,.025)],.112,trousers,4 if side<0 else 5,.085)
		orb(root,Vector3(side*.20,.15,.09),Vector3(.25,.23,.40),leather,4 if side<0 else 5,24)
		for n in range(3): path(root,[Vector3(side*.20-.06,.235,.11+n*.045),Vector3(side*.20+.06,.235,.11+n*.045)],.006,cream,4 if side<0 else 5)
		path(root,[Vector3(side*.06,1.39,.12),Vector3(side*.20,1.27,.175),Vector3(side*.14,1.14,.205)],.014,dark)
	for y in [.90,1.05,1.20]: orb(root,Vector3(.07,y,.224),Vector3(.040,.040,.020),brass,0,16)
	# A cloth cap with a brim, panel seams and a small button.
	orb(root,Vector3(0,2.01,-.005),Vector3(.65,.19,.51),fabric,1,24)
	orb(root,Vector3(0,1.982,.21),Vector3(.60,.042,.29),dark,1,24)
	for side in [-1.0,1.0]: path(root,[Vector3(0,2.11,0),Vector3(side*.18,2.065,.12),Vector3(side*.29,2.00,.17)],.0045,cream,1)
	orb(root,Vector3(0,2.115,0),Vector3(.045,.034,.045),dark,1,16)
	# Messenger bag / apron define different silhouettes and occupations.
	if species==0:
		path(root,[Vector3(-.24,1.33,.17),Vector3(.02,1.05,.245),Vector3(.33,.80,.18)],.023,leather)
		block(root,Vector3(.28,.30,.13),Vector3(.35,.79,.17),leather,0,.06)
		block(root,Vector3(.29,.11,.15),Vector3(.35,.91,.18),dark,0,.035)
		block(root,Vector3(.05,.06,.015),Vector3(.35,.89,.264),brass,0,.008)
	else:
		block(root,Vector3(.40,.42,.04),Vector3(0,.90,.232),cream,0,.05)
		block(root,Vector3(.21,.14,.035),Vector3(.01,.88,.267),fabric,0,.025)
		path(root,[Vector3(-.12,1.12,.22),Vector3(0,1.13,.24),Vector3(.12,1.12,.22)],.010,cream)
	orb(root,Vector3(0,.83,-.26),Vector3(.22,.24,.22),cream)
	return weighted(root)
