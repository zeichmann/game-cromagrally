extends RefCounted
## Rejected visual prototype; do not use it as the approved character design.
## Rebuild identity from docs/character-lookdev-v2 instead of recoloring this frog.
## Offline geometry adaptation. The GLB's chair never enters a racing mesh.
## Świnka has a distinct face, ears, snout and costume derived from her reference.

const SOURCE=preload("res://assets/characters/zabol-seated-v1.glb")
const SCALE: float=.21
const TURN: Basis=Basis(Vector3(-1,0,0),Vector3(0,1,0),Vector3(0,0,-1))
var character: int=0
var surfaces: Dictionary={}
var sphere: SphereMesh
var templates: Dictionary={}

func build(identity: int,detail: int=0) -> ArrayMesh:
	character=identity
	if not templates.has(identity):
		surfaces.clear()
		var source: Node3D=SOURCE.instantiate()
		_collect(source,Transform3D.IDENTITY,"")
		source.free()
		if character==1:
			_pig_details()
		_ribbon()
		var raw: ArrayMesh=ArrayMesh.new()
		for kind in surfaces:
			var st: SurfaceTool=surfaces[kind]
			st.index()
			st.generate_tangents()
			st.set_material(_material(kind))
			st.commit(raw)
		var template: ImporterMesh=ImporterMesh.new()
		for surface in range(raw.get_surface_count()):
			template.add_surface(Mesh.PRIMITIVE_TRIANGLES,raw.surface_get_arrays(surface),[],{},raw.surface_get_material(surface))
		# Vertices already share the bind space, so no bone scale correction is needed.
		template.generate_lods(60.0,25.0,[])
		templates[identity]=template
	var imported: ImporterMesh=templates[identity]
	# GPU skinning processes the resident vertex buffers even when a coarse index
	# LOD is drawn. Balanced and Performance also compact those resident buffers.
	var compact: ArrayMesh=ArrayMesh.new()
	for surface in range(imported.get_surface_count()):
		var arrays: Array=imported.get_surface_arrays(surface)
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var kind: String=imported.get_surface_material(surface).resource_name
		var threshold: float=0
		if detail==1:
			threshold=.0048 if kind=="skin" else (.0035 if kind=="eyes" else .012)
		elif detail==2:
			threshold=.0125 if kind=="skin" else (.009 if kind=="eyes" else .04)
		for lod in range(imported.get_surface_lod_count(surface)):
			if imported.get_surface_lod_size(surface,lod)<=threshold:
				indices=imported.get_surface_lod_indices(surface,lod)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in indices:
			st.set_normal(normals[index])
			st.set_uv(uvs[index])
			st.set_color(colors[index])
			st.set_bones(bones.slice(index*4,index*4+4))
			st.set_weights(weights.slice(index*4,index*4+4))
			st.add_vertex(vertices[index])
		st.index()
		st.generate_tangents()
		st.set_material(imported.get_surface_material(surface))
		st.commit(compact)
	var optimized: ImporterMesh=ImporterMesh.new()
	for surface in range(compact.get_surface_count()):
		optimized.add_surface(Mesh.PRIMITIVE_TRIANGLES,compact.surface_get_arrays(surface),[],{},compact.surface_get_material(surface))
	optimized.generate_lods(60.0,25.0,[])
	var lod_count: int=0
	for surface in range(optimized.get_surface_count()):
		lod_count+=optimized.get_surface_lod_count(surface)
	var result: ArrayMesh=optimized.get_mesh()
	result.resource_name=("ZabolDriver" if character==0 else "SwinkaDriver")+["High","Balanced","Performance"][detail]
	result.set_meta("lod_count",lod_count)
	result.set_meta("detail",detail)
	return result

func _surface(kind: String) -> SurfaceTool:
	if not surfaces.has(kind):
		var st: SurfaceTool=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[kind]=st
	return surfaces[kind]

func _kind(name: String,path: String,material: BaseMaterial3D) -> String:
	if material.metallic>.25:
		return "metal"
	# Godot gives repeated glTF mesh names numeric suffixes, including the second eye.
	for prefix in ["cream_eyeball","amber_iris","large_black_pupil","large_eye_glint","small_eye_glint"]:
		if name.begins_with(prefix):
			return "eyes"
	if name.contains("cavity") or name.begins_with("tongue"):
		return "mouth"
	if path.contains("broad_frog_face") or name.begins_with("palm") or name.contains("finger") or name.begins_with("thumb"):
		return "skin"
	if path.contains("zabol-volumetric-tricorn") or material.resource_name.contains("leather") or material.resource_name.contains("boot") or material.resource_name.contains("sole") or material.resource_name.contains("belt"):
		return "leather"
	if name.contains("scarf") or name.contains("gathered-fold") or name.contains("tail-raised-fold"):
		return "scarf"
	return "cloth"

func _collect(node: Node3D,parent_transform: Transform3D,parent_path: String) -> void:
	var path: String=parent_path+"/"+str(node.name)
	if node.name=="zabol-carved-captains-chair":
		return
	if character==1 and (str(node.name).begins_with("eye_turret") or str(node.name).begins_with("nostril") or node.name in ["upper_muzzle","lower_jaw"] or path.contains("raised-gold-anchor")):
		return
	var transform: Transform3D=parent_transform*node.transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D=node
		for surface in range(instance.mesh.get_surface_count()):
			var arrays: Array=instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
			var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var material: BaseMaterial3D=instance.get_active_material(surface)
			var kind: String=_kind(str(node.name),path,material)
			var st: SurfaceTool=_surface(kind)
			var normal_transform: Basis=transform.basis.inverse().transposed()
			var is_face: bool=path.contains("broad_frog_face")
			var is_hat: bool=path.contains("zabol-volumetric-tricorn")
			var is_eye: bool=path.contains("/eye_1/") or path.contains("/eye_-1/")
			var arm: bool=false
			for token in ["sleeve","shoulder","cuff","elbow","palm","finger","thumb"]:
				arm=arm or str(node.name).contains(token)
			var linear: Color=material.albedo_color.srgb_to_linear()
			for i in range(indices.size() if not indices.is_empty() else vertices.size()):
				var index: int=indices[i] if not indices.is_empty() else i
				var p: Vector3=transform*vertices[index]
				var n: Vector3=(normal_transform*normals[index]).normalized()
				var color: Color=linear*(colors[index] if not colors.is_empty() else Color.WHITE)
				if is_face:
					# Relax the wide-open portrait expression for a seated driving pose.
					var y: float=_smile_y(p)
					var dx: float=(_smile_y(p+Vector3(.0001,0,0))-y)/.0001
					var dy: float=(_smile_y(p+Vector3(0,.0001,0))-y)/.0001
					n=Vector3(n.x-dx*n.y/dy,n.y/dy,n.z).normalized()
					p.y=y
				if character==1:
					if is_face:
						if is_eye:
							var eye_center: Vector3=Vector3(signf(p.x)*.957,4.11,1.1373)
							p=eye_center+(p-eye_center)*.86
							p.y-=.42
						p=Vector3(p.x*.87,3.3+(p.y-3.3)*.92,p.z*.95)
						n=(n/Vector3(.87,.92,.95)).normalized()
					elif is_hat:
						p.x*=.94
						n=(n/Vector3(.94,1,1)).normalized()
					color=_pig_color(kind,material.resource_name,color)
					if str(node.name).begins_with("continuous_smile_lip"):
						color=Color("d38b80").srgb_to_linear()
				p=TURN*p*SCALE
				n=TURN*n
				var bone: int=1 if is_face or is_hat else (2 if p.x<0 else 3) if arm else 0
				var weight: float=clampf((.38-p.y)/.16,0,1) if arm else 1.0
				_vertex(st,p,n,uvs[index] if not uvs.is_empty() else Vector2.ZERO,color,bone,weight)
	for child in node.get_children():
		if child is Node3D:
			_collect(child,transform,path)

func _smile_y(p: Vector3) -> float:
	return p.y+.50*(2.80-p.y)*exp(-pow((p.y-2.76)/.70,4))+.20*pow(minf(absf(p.x)/1.55,1.0),2)*exp(-pow((p.y-2.76)/.60,2))

func _pig_color(kind: String,name: String,color: Color) -> Color:
	if kind=="skin":
		return Color("de8f81").srgb_to_linear().lerp(Color("efb39b").srgb_to_linear(),clampf((color.get_luminance()-.10)/.60,0,1))
	var replacements: Dictionary={"midnight-teal-wool":"33292b","raised-teal-lapels":"50383a","deep-blue-coat-seams":"211d20","olive-brocade-waistcoat":"b84432","waistcoat-stitching":"e2aa6a","orange-silk-neckerchief":"b73932","scarf-raised-folds":"d95642","scarf-fold-shadow":"7d2726"}
	return Color(replacements[name]).srgb_to_linear() if replacements.has(name) else color

func _material(kind: String) -> StandardMaterial3D:
	var m: StandardMaterial3D=StandardMaterial3D.new()
	m.resource_name=kind
	m.vertex_color_use_as_albedo=true
	m.roughness={"cloth":.78,"skin":.50,"eyes":.19,"leather":.59,"metal":.33,"mouth":.56,"scarf":.70}[kind]
	if kind=="skin" and character==1:
		m.roughness=.58
		m.metallic_specular=.35
	if kind=="metal":
		m.metallic=.68
	if kind in ["skin","eyes"]:
		m.clearcoat_enabled=true
		m.clearcoat=.12 if kind=="skin" else .65
		m.clearcoat_roughness=.38 if kind=="skin" else .15
	if kind in ["mouth","scarf"]:
		m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m

func _vertex(st: SurfaceTool,p: Vector3,n: Vector3,uv: Vector2,color: Color,bone: int,weight: float=1) -> void:
	st.set_bones(PackedInt32Array([bone,0,0,0]))
	st.set_weights(PackedFloat32Array([weight,1-weight,0,0]))
	st.set_normal(n)
	st.set_uv(uv)
	st.set_color(color)
	st.add_vertex(p)

func _triangle(kind: String,a: Vector3,b: Vector3,c: Vector3,color: Color,bone: int=1) -> void:
	var normal: Vector3=(c-a).cross(b-a)
	if normal.length_squared()<.000000000001:
		return
	normal=normal.normalized()
	var st: SurfaceTool=_surface(kind)
	for p in [a,b,c]:
		_vertex(st,TURN*p*SCALE,TURN*normal,Vector2(p.x,p.y),color.srgb_to_linear(),bone)

func _ellipsoid(kind: String,center: Vector3,radius: Vector3,color: Color) -> void:
	if sphere==null:
		sphere=SphereMesh.new()
		sphere.radius=1
		sphere.height=2
		sphere.radial_segments=40
		sphere.rings=24
	var arrays: Array=sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		_vertex(_surface(kind),TURN*(center+vertices[index]*radius)*SCALE,TURN*(normals[index]/radius).normalized(),uvs[index],color.srgb_to_linear(),1)

func _tube(kind: String,points: PackedVector3Array,radius: float,color: Color) -> void:
	var count: int=points.size()-1
	for i in range(count):
		var direction: Vector3=(points[i+1]-points[i]).normalized()
		var x: Vector3=direction.cross(Vector3.FORWARD if absf(direction.z)<.9 else Vector3.UP).normalized()
		var y: Vector3=direction.cross(x)
		for j in range(8):
			var a: Vector3=(x*cos(j*TAU/8)+y*sin(j*TAU/8))*radius
			var b: Vector3=(x*cos((j+1)*TAU/8)+y*sin((j+1)*TAU/8))*radius
			_triangle(kind,points[i]+a,points[i+1]+a,points[i]+b,color)
			_triangle(kind,points[i]+b,points[i+1]+a,points[i+1]+b,color)

func _pig_details() -> void:
	# A flared, softly pointed silhouette and a concave bowl distinguish pig ears.
	for side in [-1.0,1.0]:
		var outline: Array[Vector3]=[Vector3(1.05,4.10,.25),Vector3(1.43,4.41,.32),Vector3(1.96,4.15,.43),Vector3(2.42,4.23,.53),Vector3(2.15,3.59,.49),Vector3(1.44,3.46,.30)]
		for back in [false,true]:
			var color: Color=Color("edaa96") if back else Color("e5988e")
			for ring in range(14):
				for segment in range(40):
					var corners: Array[Vector3]=[]
					for off in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
						var t: float=float(ring+off.x)/14
						var u: float=float(segment+off.y)/40*outline.size()
						var index: int=floori(u)%outline.size()
						var edge: Vector3=outline[index].cubic_interpolate(outline[(index+1)%outline.size()],outline[posmod(index-1,outline.size())],outline[(index+2)%outline.size()],fmod(u,1.0))
						var p: Vector3=Vector3(1.61,3.86,.43 if not back else .23).lerp(edge,t)
						p.x*=side
						corners.append(p)
					if back==(side<0):
						_triangle("skin",corners[0],corners[1],corners[2],color)
						_triangle("skin",corners[1],corners[3],corners[2],color)
					else:
						_triangle("skin",corners[0],corners[2],corners[1],color)
						_triangle("skin",corners[1],corners[2],corners[3],color)
		# Eyebrows and a few tapered lashes follow the existing dimensional eyes.
		var brow: PackedVector3Array=[]
		for i in range(17):
			var t: float=float(i)/16
			brow.append(Vector3(side*(.32+t*.80),4.22+sin(t*PI)*.10,1.14))
		_tube("leather",brow,.033,Color("8a5048"))
		for lash in range(3):
			var x: float=side*(1.04+lash*.055)
			_tube("leather",PackedVector3Array([Vector3(x,3.83+lash*.04,1.24),Vector3(x+side*.10,3.94+lash*.05,1.30),Vector3(x+side*.16,4.04+lash*.04,1.28)]),.014,Color("422a29"))
	_snout()
	# Replace the anchor with a raised pig emblem, as in Świnka's portrait.
	_ellipsoid("metal",Vector3(0,5.55,1.26),Vector3(.28,.26,.075),Color("dfa84b"))
	for side in [-1.0,1.0]:
		_ellipsoid("metal",Vector3(side*.22,5.74,1.26),Vector3(.12,.16,.075),Color("dfa84b"))
		_ellipsoid("leather",Vector3(side*.095,5.60,1.34),Vector3(.026,.035,.012),Color("33261e"))
	_ellipsoid("metal",Vector3(0,5.45,1.35),Vector3(.16,.11,.06),Color("edbe67"))
	for side in [-1.0,1.0]:
		_ellipsoid("leather",Vector3(side*.06,5.45,1.41),Vector3(.023,.032,.009),Color("553820"))

func _snout() -> void:
	# The front surface has two actual openings, with recessed walls and dark caps.
	var center: Vector3=Vector3(0,3.21,1.43)
	_ellipsoid("skin",center-Vector3(0,0,.10),Vector3(.68,.40,.12),Color("e49284"))
	for row in range(56):
		for region in range(3):
			for column in range(14):
				var corners: Array[Vector3]=[]
				for off in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var y: float=lerpf(-.40,.40,float(row+off.y)/56)
					var extent: float=.68*sqrt(maxf(0,1-pow(y/.40,2)))
					var hole: float=.10*sqrt(maxf(0,1-pow((y-.025)/.145,2)))
					var limits: Array[Vector2]=[Vector2(-extent,clampf(-.265-hole,-extent,extent)),Vector2(clampf(-.265+hole,-extent,extent),clampf(.265-hole,-extent,extent)),Vector2(clampf(.265+hole,-extent,extent),extent)]
					var x: float=lerpf(limits[region].x,limits[region].y,float(column+off.x)/14)
					var z: float=.24*sqrt(maxf(0,1-pow(x/.68,2)-pow(y/.40,2)))
					corners.append(center+Vector3(x,y,z))
				_triangle("skin",corners[0],corners[2],corners[1],Color("f0a18e"))
				_triangle("skin",corners[1],corners[2],corners[3],Color("f0a18e"))
	for side in [-1.0,1.0]:
		_ellipsoid("mouth",center+Vector3(side*.265,.025,.025),Vector3(.097,.14,.012),Color("722e32"))
		for j in range(48):
			var corners: Array[Vector3]=[]
			for off in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var a: float=float(j+off.x)*TAU/48
				var x: float=side*.265+cos(a)*.10
				var y: float=.025+sin(a)*.145
				var z: float=.24*sqrt(maxf(0,1-pow(x/.68,2)-pow(y/.40,2)))
				corners.append(center+Vector3(x,y,lerpf(z,.025,off.y)))
			_triangle("skin",corners[0],corners[2],corners[1],Color("cc7a72"))
			_triangle("skin",corners[1],corners[2],corners[3],Color("cc7a72"))

func _ribbon() -> void:
	var st: SurfaceTool=_surface("scarf")
	for i in range(16):
		for off in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
			var t: float=float(i+off.x)/16
			st.set_bones(PackedInt32Array([4,5,0,0]))
			st.set_weights(PackedFloat32Array([1-t,t,0,0]))
			st.set_color(Color("ba4933").srgb_to_linear())
			st.set_uv(Vector2(off.y,t))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3((off.y*2-1)*lerpf(.10,.055,t),.40-sin(t*PI)*.08,.12+t*.60))
