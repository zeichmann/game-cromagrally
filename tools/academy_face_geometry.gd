extends "res://tools/portrait_geometry.gd"
## Original three-dimensional sculpt guided by the canonical Academia Oli portraits.
## Surface derivatives provide smooth normals even at the lip and cranium seams.
var profile_species: int=-1
var radii: PackedFloat32Array=PackedFloat32Array()

func _build_profile() -> void:
	profile_species=species
	radii.resize(1025)
	for i in range(1025):
		var angle: float=TAU*i/1024.0
		var lower: float=0
		var upper: float=TAU
		for iteration in range(18):
			var middle: float=(lower+upper)*.5
			var q: Vector2=outline(middle)-Vector2(0,.804)
			var polar: float=fposmod(atan2(q.y,q.x),TAU)
			if polar<angle: lower=middle
			else: upper=middle
		radii[i]=(outline((lower+upper)*.5)-Vector2(0,.804)).length()
	radii[1024]=radii[0]

func _radial_distance(p: Vector2) -> float:
	if profile_species!=species: _build_profile()
	var index: float=fposmod(atan2(p.y,p.x),TAU)*1024.0/TAU
	var radius: float=lerpf(radii[floori(index)],radii[floori(index)+1],fposmod(index,1))
	return clampf(p.length()/radius,0,1)

func width() -> float: return .465 if species==0 else .425
func eye_center() -> Vector2: return Vector2(.226,.972) if species==0 else Vector2(.192,.948)
func eye_size() -> Vector2: return Vector2(.103,.123) if species==0 else Vector2(.090,.108)

func outline(a: float) -> Vector2:
	var s: float=sin(a)
	var x: float=width()*cos(a)*(1-.085*s)
	var y: float=.804+(.265 if s>0 and species==0 else (.335 if s>0 else .310))*s
	if species==0 and s>0:
		y+=.110*exp(-pow((absf(x)-.225)/.115,2))*sqrt(s)
	return Vector2(x,y)

func front_z(x: float,y: float) -> float:
	var direction: Vector2=Vector2(x,y-.804)
	var radial: float=_radial_distance(direction)
	var root: float=sqrt(maxf(0,1-radial*radial))
	var z: float=-.005-(.235 if species==0 else .255)*root
	var fade: float=smoothstep(0,.32,1-radial)
	if species==0:
		z-=.100*exp(-pow(x/.40,4)-pow((y-.752)/.100,2))*fade
		z-=.094*exp(-pow(x/.35,4)-pow((y-.550)/.115,2))*fade
		for side in [-1.0,1.0]:
			z-=.105*exp(-pow((x-side*.226)/.128,2)-pow((y-.974)/.160,2))*fade
			z-=.046*exp(-pow((x-side*.337)/.095,2)-pow((y-.715)/.105,2))*fade
	else:
		z-=.070*exp(-pow(x/.225,4)-pow((y-.795)/.118,2))*fade
		for side in [-1.0,1.0]:
			z-=.070*exp(-pow((x-side*.256)/.122,2)-pow((y-.724)/.120,2))*fade
			z-=.025*exp(-pow((x-side*.190)/.125,2)-pow((y-.948)/.155,2))*fade
	return z

func mouth(a: float) -> Vector2:
	var s: float=sin(a)
	var c: float=cos(a)
	if species==0:
		return Vector2(c*.328,.663+.060*c*c+s*(.012 if s>0 else .112))
	return Vector2(c*.213,.650+.038*c*c+s*(.009 if s>0 else .083))

func color(p: Vector3) -> Color:
	var skin: Color=Color("88ad30") if species==0 else Color("f0aa98")
	var front: float=smoothstep(.03,.22,-p.z)
	if species==0:
		var muzzle: float=exp(-pow(p.x/.40,4)-pow((p.y-.746)/.092,2))*front
		var chin: float=(1-smoothstep(.57,.70,p.y))*front
		skin=skin.lerp(Color("d4cd49"),muzzle*.88)
		skin=skin.lerp(Color("e5ce59"),chin*.98)
		var cheek: float=exp(-pow((absf(p.x)-.327)/.065,2)-pow((p.y-.742)/.064,2))*front
		skin=skin.lerp(Color("bea249"),cheek*.38)
	else:
		var blush: float=exp(-pow((absf(p.x)-.262)/.100,2)-pow((p.y-.743)/.084,2))*front
		skin=skin.lerp(Color("e77b80"),blush*.55)
		skin=skin.lerp(Color("ffccb1"),(1-smoothstep(.50,.66,p.y))*front*.30)
	return skin

func _front(a: float,t: float) -> Vector3:
	var m: Vector2=mouth(a)
	var p: Vector2=m.lerp(outline(a),t)
	return Vector3(p.x,p.y,-.005 if t>=1 else front_z(p.x,p.y)-.021*exp(-pow(t/.14,2)))

func _back(a: float,t: float) -> Vector3:
	var o: Vector2=outline(a)
	var phi: float=t*PI*.5
	return Vector3(o.x*cos(phi),.804+(o.y-.804)*cos(phi),.267*sin(phi)-.005)

func _pocket(a: float,t: float) -> Vector3:
	var lip: Vector3=_front(a,0)
	return Vector3(lip.x*(1-.98*t),.622+(lip.y-.622)*(1-.95*t),lerpf(lip.z,-.160,sin(t*PI*.5)))

func _normal(sample: Callable,u: float,v: float) -> Vector3:
	var du: Vector3=sample.call(u+.0008,v)-sample.call(u-.0008,v)
	var dv: Vector3=sample.call(u,v+.0008)-sample.call(u,v-.0008)
	return du.cross(dv).normalized()

func _grid(root: Node3D,sample: Callable,segments: int,rows: int,material: Material,zone: int) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows+1):
		var t: float=row/float(rows)
		for n in range(segments+1):
			var a: float=TAU*n/segments
			var p: Vector3=sample.call(a,t)
			var normal: Vector3=_normal(sample,a,t)
			if zone==2: normal=-normal
			if (zone==0 and row==rows) or (zone==1 and row==0):
				var tangent: Vector2=outline(a+.0008)-outline(a-.0008)
				normal=Vector3(tangent.y,-tangent.x,0).normalized()
			if zone==1 and row==rows: normal=Vector3.BACK
			var pigment: Color=color(p)
			if zone==2:
				pigment=pigment.lerp(Color("803932").lerp(Color("a9534a"),clampf((.64-p.y)*4,0,1)),smoothstep(0,.25,t))
			st.set_normal(normal)
			st.set_color(pigment)
			st.set_uv(Vector2(p.x+.5,p.y))
			st.add_vertex(p)
	for row in range(rows):
		for n in range(segments):
			var k: int=row*(segments+1)+n
			for i in ([k,k+1,k+segments+1,k+1,k+segments+2,k+segments+1] if zone==2 else [k,k+segments+1,k+1,k+1,k+segments+1,k+segments+2]): st.add_index(i)
	part(root,st.commit(),material)
	if zone==2:
		# A real cavity floor closes the small final ring; no background pinhole.
		var floor_surface: SurfaceTool=SurfaceTool.new()
		floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for n in range(segments):
			for p in [_pocket(TAU*n/segments,1),_pocket(TAU*(n+1)/segments,1),Vector3(0,.622,-.160)]:
				floor_surface.set_normal(Vector3.FORWARD)
				floor_surface.set_color(Color("803932"))
				floor_surface.add_vertex(p)
		part(root,floor_surface.commit(),material)

func head(root: Node3D) -> void:
	var skin: StandardMaterial3D=mat("academy_skin","ffffff",50,.46)
	skin.vertex_color_use_as_albedo=true
	skin.vertex_color_is_srgb=true
	var inner: StandardMaterial3D=mat("academy_mouth","ffffff",59,.57)
	inner.vertex_color_use_as_albedo=true
	inner.vertex_color_is_srgb=true
	var n: int=[144,96,64][detail]
	_grid(root,_front,n,[30,22,16][detail],skin,0)
	_grid(root,_back,n,[20,14,10][detail],skin,1)
	_grid(root,_pocket,n,[10,8,6][detail],inner,2)

func eye_z(p: Vector2,center: Vector2,size: Vector2) -> float:
	var q: Vector2=(p-center)/size
	return front_z(center.x,center.y)-.027-.060*sqrt(maxf(0,1-q.length_squared()))

func _eye_point(side: float,q: Vector2) -> Vector3:
	var c: Vector2=eye_center()*Vector2(side,1)
	var p: Vector2=c+q*eye_size()
	return Vector3(p.x,p.y,eye_z(p,c,eye_size()))

func _eye_disc(root: Node3D,side: float,factor: Vector2,shift: Vector2,offset: float,material: Material) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int=[48,32,24][detail]
	var rows: int=[9,7,5][detail]
	for row in range(rows+1):
		for i in range(n+1):
			var a: float=TAU*i/n
			var q: Vector2=Vector2(cos(a),sin(a))*maxf(.001,row/float(rows))
			var p: Vector3=_eye_point(side,q*factor+shift)
			p.z+=offset
			var normal: Vector3=Vector3((p.x-side*eye_center().x)/pow(eye_size().x,2),(p.y-eye_center().y)/pow(eye_size().y,2),-.060/pow(.060,2)).normalized()
			st.set_normal(normal)
			st.set_uv(q*.5+Vector2.ONE*.5)
			st.add_vertex(p)
	for row in range(rows):
		for i in range(n):
			var k: int=row*(n+1)+i
			for index in [k,k+n+1,k+1,k+1,k+n+1,k+n+2]: st.add_index(index)
	part(root,st.commit(),material)

func lid_point(side: float,upper: bool,u: float,v: float,blink: float=0) -> Vector3:
	var c: Vector2=eye_center()*Vector2(side,1)
	var size: Vector2=eye_size()
	var arch: float=sqrt(maxf(0,1-u*u))
	var tilt: float=side*u*.06
	var opened: float=(.84 if upper else -.76)*arch+tilt
	var closed: float=-.03+.07*arch+tilt
	var inner_y: float=lerpf(opened,closed,blink)
	var outer_y: float=(1.26 if upper else -1.15)*arch+tilt
	var q: Vector2=Vector2(u*(1+v*.17),lerpf(inner_y,outer_y,v))
	var p: Vector2=c+q*size
	var eye_depth: float=eye_z(p,c,size)-lerpf(.005,.017,blink)
	var facial_depth: float=front_z(p.x,p.y)-.006
	var z: float=lerpf(eye_depth,facial_depth,smoothstep(1.0,1.25,q.length()))
	z-=sin(v*PI)*.004
	return Vector3(p.x,p.y,z)

func _lid(root: Node3D,side: float,upper: bool) -> void:
	var n: int=[40,28,20][detail]
	var rows: int=[8,6,5][detail]
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows+1):
		for i in range(n+1):
			var u: float=-1+2.0*i/n
			var v: float=row/float(rows)
			var p: Vector3=lid_point(side,upper,u,v)
			var du: Vector3=lid_point(side,upper,u+.0005,v)-lid_point(side,upper,u-.0005,v)
			var dv: Vector3=lid_point(side,upper,u,v+.0005)-lid_point(side,upper,u,v-.0005)
			var normal: Vector3=du.cross(dv).normalized()*(-1 if upper else 1)
			st.set_normal(normal)
			var pigment: Color=color(p).lerp(Color("76912a") if species==0 else Color("d78379"),(1-v)*.12)
			if upper: pigment=pigment.lerp(Color("667f23") if species==0 else Color("ad6b61"),exp(-v*44)*.38)
			st.set_color(pigment)
			# Authored u/v are converted to a closed-lid delta after palette packing.
			st.set_uv(Vector2(u,v))
			st.add_vertex(p)
	for row in range(rows):
		for i in range(n):
			var k: int=row*(n+1)+i
			for index in ([k,k+1,k+n+1,k+1,k+n+2,k+n+1] if upper else [k,k+n+1,k+1,k+1,k+n+1,k+n+2]): st.add_index(index)
	var material: StandardMaterial3D=mat("upper_lid" if upper else "lower_lid","ffffff",54 if upper else 55,.48)
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	part(root,st.commit(),material)

func eyes(root: Node3D) -> void:
	for side in [-1.0,1.0]:
		_eye_disc(root,side,Vector2.ONE,Vector2.ZERO,0,mat("academy_sclera","f4e6ca",51,.22))
		var shift: Vector2=Vector2(-side*.035,-.035)
		_eye_disc(root,side,Vector2(.735,.735),shift,-.002,mat("academy_iris","a97028",52,.23))
		_eye_disc(root,side,Vector2(.467,.506),shift,-.004,mat("academy_pupil","100f0a",53,.16))
		for glint in [Vector3(-.024,.034,.010),Vector3(.022,-.026,.0038)]:
			var q: Vector2=Vector2(glint.x,glint.y)/eye_size()+shift
			var p: Vector3=_eye_point(side,q)
			orb(root,p+Vector3(0,0,-.009),Vector3(glint.z,glint.z*1.20,.0024),mat("academy_catchlight","fff6dd",53,.18))
		_lid(root,side,true)
		_lid(root,side,false)
		if species==1:
			var brow: Array[Vector3]=[]
			for n in range(9):
				var t: float=n/8.0
				var x: float=side*(.105+t*.17)
				var y: float=1.075+.025*sin(t*PI)-t*.015
				brow.append(Vector3(x,y,front_z(x,y)-.013))
			path(root,brow,.0075,mat("academy_brow","925544",56),1,.004)
			for n in range(4):
				var u: float=side*(.40+n*.13)
				var p: Vector3=lid_point(side,true,u,0)
				var lash: Array[Vector3]=[p,p+Vector3(side*.008,.012,-.005),p+Vector3(side*.016,.023,.001)]
				path(root,lash,.0025,mat("academy_lash","4e2b29",60),1,.0006)
				var lash_node: MeshInstance3D=root.get_child(-1)
				var arrays: Array=lash_node.mesh.surface_get_arrays(0)
				var uv: PackedVector2Array=PackedVector2Array()
				uv.resize(arrays[Mesh.ARRAY_VERTEX].size())
				uv.fill(Vector2(u,0))
				arrays[Mesh.ARRAY_TEX_UV]=uv
				var lash_mesh: ArrayMesh=ArrayMesh.new()
				lash_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				lash_node.mesh=lash_mesh
	if species==0:
		for side in [-1.0,1.0]:
			var x: float=side*.063
			eye_cap(root,Vector3(x,.782,front_z(x,.782)-.005),Vector2(.012,.008),.001,mat("academy_nostril","526823",50))
	else:
		snout(root)
		# Small upper incisors are partly covered by the muzzle, as in the portrait.
		for side in [-1.0,1.0]:
			orb(root,Vector3(side*.026,.650,front_z(side*.026,.650)+.015),Vector3(.025,.013,.018),mat("academy_teeth","f9dfb6",57,.30))
	var tongue: Vector3=Vector3(.012,.584 if species==0 else .599,front_z(0,.584)+.075)
	orb(root,tongue,Vector3(.102,.024,.050) if species==0 else Vector3(.063,.019,.034),mat("academy_tongue","c67b65",59,.43))

func snout(root: Node3D) -> void:
	var n: int=[64,44,32][detail]
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center_y: float=.795
	var size: Vector2=Vector2(.178,.102)
	var front: float=-.409
	for side in [-1.0,1.0]:
		var center: Vector2=Vector2(side*.064,center_y+.002)
		var inner: Array[Vector3]=[]
		var outer: Array[Vector3]=[]
		for i in range(n+1):
			var a: float=TAU*i/n
			var d: Vector2=Vector2(cos(a),sin(a))
			var aa: float=pow(d.x/size.x,2)+pow(d.y/size.y,2)
			var bb: float=2*(center.x*d.x/pow(size.x,2)+(center.y-center_y)*d.y/pow(size.y,2))
			var cc: float=pow(center.x/size.x,2)+pow((center.y-center_y)/size.y,2)-1
			var length: float=(-bb+sqrt(maxf(0,bb*bb-4*aa*cc)))/(2*aa)
			if d.x*side<-.001: length=minf(length,-center.x/d.x)
			var p: Vector2=center+d*length
			outer.append(Vector3(p.x,p.y,front))
			inner.append(Vector3(center.x+cos(a)*.025,center.y+sin(a)*.032,front-.014))
		for row in range(12):
			for i in range(n):
				var points: Array[Vector3]=[]
				var pigments: Array[Color]=[]
				for t in [row/12.0,(row+1)/12.0]:
					for k in [i,i+1]:
						var p: Vector3=inner[k].lerp(outer[k],t)
						p.z=front-.018*sqrt(maxf(0,1-pow(p.x/size.x,2)-pow((p.y-center_y)/size.y,2)))
						points.append(p)
						pigments.append(Color("e99588").lerp(Color("f4ad95"),smoothstep(.4,1,t)*.3))
				quad(st,points,pigments)
		for row in range(8):
			for i in range(n):
				var points: Array[Vector3]=[]
				var pigments: Array[Color]=[]
				for t in [row/8.0,(row+1)/8.0]:
					for k in [i,i+1]:
						var p: Vector3=Vector3(center.x+(inner[k].x-center.x)*(1-.98*t),center.y+(inner[k].y-center.y)*(1-.98*t),inner[k].z+.055*t)
						points.append(p)
						pigments.append(Color("e99588").lerp(Color("8f463f"),smoothstep(0,.65,t)))
				quad(st,points,pigments,true)
	for row in range(12):
		for i in range(n):
			var points: Array[Vector3]=[]
			var pigments: Array[Color]=[]
			for t in [row/12.0,(row+1)/12.0]:
				for a in [TAU*i/n,TAU*(i+1)/n]:
					var radius: float=1+.035*sin(t*PI)-.19*t
					points.append(Vector3(cos(a)*size.x*radius,center_y+sin(a)*size.y*radius,front+.091*t))
					pigments.append(Color("e99588").lerp(Color("f0aa98"),t))
			quad(st,points,pigments)
	var material: StandardMaterial3D=mat("academy_snout","ffffff",57,.48)
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	part(root,finish(st),material)
