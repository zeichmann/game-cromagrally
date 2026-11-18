extends "res://tools/academy_face_geometry.gd"
## Layered eyes and softer facial volumes. All changing geometry stays on GPU.
var cornea_material: ShaderMaterial

func front_z(x: float,y: float) -> float:
	var z: float=super.front_z(x,y)
	var front: float=smoothstep(.03,.20,-z)
	var corner: float=.328 if species==0 else .213
	z+=.006*exp(-pow((absf(x)-corner)/.027,2)-pow((y-(.723 if species==0 else .688))/.036,2))*front
	if species==1: z-=.012*exp(-pow((absf(x)-.252)/.105,2)-pow((y-.756)/.086,2))*front
	return z

func mouth(a: float) -> Vector2:
	var s: float=sin(a)
	var c: float=cos(a)
	if species==0: return Vector2(c*.328,.663+.060*c*c+s*(.012 if s>0 else .078))
	return Vector2(c*.213,.650+.038*c*c+s*(.009 if s>0 else .054))

func color(p: Vector3) -> Color:
	var pigment: Color=super.color(p)
	var front: float=smoothstep(.08,.24,-p.z)
	if species==1:
		var cheek: float=exp(-pow((absf(p.x)-.255)/.095,2)-pow((p.y-.760)/.079,2))*front
		pigment=pigment.lerp(Color("e77c77"),cheek*.22)
		var warm: float=exp(-pow(p.x/.28,4)-pow((p.y-.975)/.12,2))*front
		pigment=pigment.lerp(Color("f5b69a"),warm*.12)
	return pigment

func eye_z(p: Vector2,center: Vector2,size: Vector2) -> float:
	var q: Vector2=(p-center)/size
	return front_z(center.x,center.y)-.012-.038*sqrt(maxf(0,1-q.length_squared()))

func lid_point(side: float,upper: bool,u: float,v: float,blink: float=0) -> Vector3:
	var c: Vector2=eye_center()*Vector2(side,1)
	var size: Vector2=eye_size()
	var arch: float=sqrt(maxf(0,1-u*u))
	var tilt: float=side*u*.075
	var opened: float=(.77 if upper else -.70)*arch+tilt
	var closed: float=-.025+.075*arch+tilt
	var inner: float=lerpf(opened,closed,blink)
	var outside: float=(1.22 if upper else -1.10)*arch+tilt
	var q: Vector2=Vector2(u*(1+v*.15),lerpf(inner,outside,v))
	var p: Vector2=c+q*size
	var optical: float=eye_z(p,c,size)-lerpf(.004,.016,blink)
	var face: float=front_z(p.x,p.y)-.003
	return Vector3(p.x,p.y,lerpf(optical,face,smoothstep(1.0,1.22,q.length()))-sin(v*PI)*.002)

func _eye_disc(root: Node3D,side: float,factor: Vector2,shift: Vector2,offset: float,material: Material) -> void:
	var kind: int=int(material.get_meta("palette_kind",0))
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int=[48,32,24][detail]
	var rings: int=[10,7,5][detail]
	var center: Vector2=eye_center()*Vector2(side,1)
	var size: Vector2=eye_size()
	var iris_shift: Vector2=Vector2(-side*.065,-.025)
	for row in range(rings+1):
		for n in range(segments+1):
			var a: float=TAU*n/segments
			var direction: Vector2=Vector2(cos(a),sin(a))
			var radius: float=maxf(.001,row/float(rings))
			var q: Vector2=shift+direction*factor*radius
			if kind==65:
				# Sclera is an annulus, leaving a real aperture for the recessed iris.
				q=(iris_shift+direction*Vector2(.710,.730)).lerp(direction,row/float(rings))
			var p2: Vector2=center+q*size
			var z: float=eye_z(p2,center,size)
			var normal: Vector3
			if kind in [66,67]:
				var r: Vector2=(q-iris_shift)/Vector2(.72,.74)
				z=front_z(center.x,center.y)-.038+.007*(1-r.length_squared())+offset
				normal=Vector3(-.014*r.x/(size.x*.72),-.014*r.y/(size.y*.74),-1).normalized()
			else:
				var divisor: float=sqrt(maxf(.0005,1-q.length_squared()))
				normal=Vector3(.038*q.x/(size.x*divisor),.038*q.y/(size.y*divisor),-1).normalized()
			st.set_normal(normal)
			st.set_color(Color.WHITE)
			st.set_uv(direction*radius*.5+Vector2.ONE*.5)
			st.add_vertex(Vector3(p2.x,p2.y,z))
	for row in range(rings):
		for n in range(segments):
			var k: int=row*(segments+1)+n
			for index in [k,k+segments+1,k+1,k+1,k+segments+1,k+segments+2]: st.add_index(index)
	part(root,st.commit(),material)

func _cornea(root: Node3D,side: float) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int=[48,32,24][detail]
	var rows: int=[10,7,5][detail]
	var center: Vector2=eye_center()*Vector2(side,1)
	var size: Vector2=eye_size()
	for row in range(rows+1):
		for i in range(n+1):
			var angle: float=TAU*i/n
			var r: float=maxf(.001,row/float(rows))
			var q: Vector2=Vector2(cos(angle),sin(angle))*r
			var p: Vector2=center+q*size
			var depth: float=.046
			var z: float=front_z(center.x,center.y)-.012-depth*sqrt(maxf(0,1-q.length_squared()))
			var divisor: float=sqrt(maxf(.0005,1-q.length_squared()))
			st.set_normal(Vector3(depth*q.x/(size.x*divisor),depth*q.y/(size.y*divisor),-1).normalized())
			st.set_color(Color.WHITE)
			st.set_uv(q*.5+Vector2.ONE*.5)
			st.set_uv2(Vector2(68,.16))
			st.add_vertex(Vector3(p.x,p.y,z))
	for row in range(rows):
		for i in range(n):
			var k: int=row*(n+1)+i
			for index in [k,k+n+1,k+1,k+1,k+n+1,k+n+2]: st.add_index(index)
	if cornea_material==null:
		cornea_material=ShaderMaterial.new()
		cornea_material.shader=load("res://shaders/academy_cornea.gdshader")
		cornea_material.set_shader_parameter("cornea_gain",.75)
	part(root,st.commit(),cornea_material)

func _wetline(root: Node3D,side: float) -> void:
	var points: Array[Vector3]=[]
	for n in range(21): points.append(lid_point(side,false,-.92+1.84*n/20,0)+Vector3(0,0,-.001))
	path(root,points,.0014,mat("organic_wetline","b9aa91",69,.22))
	var node: MeshInstance3D=root.get_child(-1)
	var arrays: Array=node.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array=PackedVector2Array()
	for p in arrays[Mesh.ARRAY_VERTEX]: uv.append(Vector2(clampf((p.x-side*eye_center().x)/eye_size().x,-.96,.96),0))
	arrays[Mesh.ARRAY_TEX_UV]=uv
	var mesh: ArrayMesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	node.mesh=mesh

func eyes(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_eye_disc(root,side,Vector2.ONE,Vector2.ZERO,0,mat("organic_sclera","f3ecdc",65,.47))
		var shift: Vector2=Vector2(-side*.065,-.025)
		_eye_disc(root,side,Vector2(.72,.74),shift,0,mat("organic_iris","ffffff",66,.56))
		_eye_disc(root,side,Vector2(.425,.465),shift,-.0012,mat("organic_pupil","0b0b08",67,.52))
		_lid(root,side,true)
		_lid(root,side,false)
		_wetline(root,side)
		_cornea(root,side)
		if species==1:
			var brow: Array[Vector3]=[]
			for n in range(9):
				var t: float=n/8.0
				var x: float=side*(.103+t*.169)
				var y: float=1.068+.025*sin(t*PI)-t*.010
				brow.append(Vector3(x,y,front_z(x,y)-.009))
			path(root,brow,.0055,mat("organic_brow","87503b",56),1,.002)
			for n in range(5):
				var u: float=side*(.30+n*.115)
				var p: Vector3=lid_point(side,true,u,0)
				var lash: Array[Vector3]=[p,p+Vector3(side*.006,.011,-.004),p+Vector3(side*.014,.024,.003)]
				path(root,lash,.0023,mat("organic_lashes","3f2520",60),1,.0005)
				var node: MeshInstance3D=root.get_child(-1)
				var arrays: Array=node.mesh.surface_get_arrays(0)
				var uv: PackedVector2Array=PackedVector2Array()
				uv.resize(arrays[Mesh.ARRAY_VERTEX].size())
				uv.fill(Vector2(u,0))
				arrays[Mesh.ARRAY_TEX_UV]=uv
				var mesh: ArrayMesh=ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				node.mesh=mesh
	if species==0:
		for side in [-1.0,1.0]: eye_cap(root,Vector3(side*.063,.782,front_z(side*.063,.782)-.004),Vector2(.012,.008),.001,mat("organic_nostril","526823",50))
	else:
		snout(root)
		for side in [-1.0,1.0]: orb(root,Vector3(side*.026,.650,front_z(side*.026,.650)+.015),Vector3(.025,.013,.018),mat("organic_teeth","f3dfbd",70,.36))
	var tongue_y: float=.608 if species==0 else .621
	orb(root,Vector3(.008,tongue_y,front_z(0,.584)+.085),Vector3(.094,.026,.052) if species==0 else Vector3(.060,.021,.036),mat("organic_tongue","bd7768",59,.51))
