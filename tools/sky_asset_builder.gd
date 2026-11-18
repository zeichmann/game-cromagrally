extends RefCounted
## Original festival balloons: cloth envelopes, suspended baskets and rigging.

func balloon(variant: int, author: RefCounted) -> Node3D:
	var root: Node3D=Node3D.new()
	var profile: Array[Vector2]=[Vector2(.70,4.5),Vector2(1.55,5.4),Vector2(3.10,7.7),Vector2(4.05,10.4),Vector2(4.10,12.6),Vector2(3.30,14.7),Vector2(1.70,16.1),Vector2(.045,16.65)]
	var points: PackedVector3Array=PackedVector3Array()
	var normals: PackedVector3Array=PackedVector3Array()
	var uv: PackedVector2Array=PackedVector2Array()
	var colors: PackedColorArray=PackedColorArray()
	var indices: PackedInt32Array=PackedInt32Array()
	var rings: Array[Vector2]=[]
	for i in range(profile.size()-1):
		for step in range(4):
			rings.append(profile[i].cubic_interpolate(profile[i+1],profile[maxi(i-1,0)],profile[mini(i+2,profile.size()-1)],step/4.0))
	rings.append(profile[-1])
	for row in range(rings.size()):
		var before: Vector2=rings[maxi(row-1,0)]
		var after: Vector2=rings[mini(row+1,rings.size()-1)]
		var slope: float=(after.x-before.x)/maxf(after.y-before.y,.01)
		for side in range(49):
			var a: float=TAU*side/48.0
			var radius: float=maxf(rings[row].x,.045)*(1-.010*cos(a*8))
			points.append(Vector3(cos(a)*radius,rings[row].y,sin(a)*radius))
			normals.append(Vector3(cos(a),-slope,sin(a)).normalized())
			uv.append(Vector2(side/48.0*3,row/float(rings.size()-1)*2))
			var stripe: bool=(side/6)%2==0
			colors.append(Color("d9a5a5" if variant==0 else "9fb5ca") if stripe else Color("f0dfbd"))
	for row in range(rings.size()-1):
		for side in range(48):
			var a: int=row*49+side
			for index in [a,a+1,a+49,a+49,a+1,a+50]:
				indices.append(index)
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh: ArrayMesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var cloth: StandardMaterial3D=IRArt.textured("linen").duplicate()
	cloth.vertex_color_use_as_albedo=true
	cloth.vertex_color_is_srgb=true
	cloth.cull_mode=BaseMaterial3D.CULL_BACK
	IRArt.part(root,mesh,Vector3.ZERO,cloth)
	var basket: StandardMaterial3D=IRArt.pbr(Color("c9b591"),.88).duplicate()
	basket.set_meta("palette_kind",21)
	for side in [-1.0,1.0]:
		IRArt.block(root,Vector3(1.7,.95,.10),Vector3(0,.6,side*.70),basket)
		IRArt.block(root,Vector3(.10,.95,1.4),Vector3(side*.80,.6,0),basket)
		for y in [.16,1.10]:
			IRArt.block(root,Vector3(1.85,.11,.14),Vector3(0,y,side*.70),basket)
			IRArt.block(root,Vector3(.14,.11,1.5),Vector3(side*.80,y,0),basket)
		for other in [-1.0,1.0]:
			IRArt.tube(root,Vector3(side*.72,1.12,other*.61),Vector3(side*.62,4.52,other*.52),.025,IRArt.pbr(Color("d6c9ab"),.94))
	for i in range(6):
		IRArt.block(root,Vector3(1.7,.026,.018),Vector3(0,.25+i*.135,.76),basket)
	IRArt.block(root,Vector3(1.5,.08,1.25),Vector3(0,.17,0),basket)
	var metal: Material=IRArt.pbr(Color("6d6570"),.48,.4)
	for x in [-.42,.42]:
		IRArt.tube(root,Vector3(x,1.1,0),Vector3(x,2.2,0),.035,metal)
	IRArt.block(root,Vector3(.9,.12,.6),Vector3(0,2.2,0),metal)
	var burner: StandardMaterial3D=StandardMaterial3D.new()
	burner.albedo_color=Color("eac17d")
	burner.emission_enabled=true
	burner.emission=Color("edc78d")
	var flame: SphereMesh=SphereMesh.new()
	flame.radius=.13
	flame.height=.48
	flame.radial_segments=12
	flame.rings=6
	IRArt.part(root,flame,Vector3(0,2.47,0),burner)
	return root
