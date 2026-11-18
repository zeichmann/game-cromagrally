class_name IRWaterfallGarden
extends Node3D

var terrain: IRSceneryArt

func _init(landscape: IRSceneryArt) -> void:
	terrain=landscape

func _ready() -> void:
	_cliff()
	_spring()
	_cascade()
	_mist()

func _cliff() -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns: int=60
	var profiles: Array[Vector2]=[]
	var row_values: Array[float]=[]
	for row in range(IRWaterfallPath.PROFILE.size()-1):
		for step in range(5):
			var t: float=step/5.0
			profiles.append(IRWaterfallPath.PROFILE[row].lerp(IRWaterfallPath.PROFILE[row+1],t))
			row_values.append(row+t)
	profiles.append(IRWaterfallPath.PROFILE[-1])
	row_values.append(IRWaterfallPath.PROFILE.size()-1)
	for row in range(profiles.size()):
		var profile: Vector2=profiles[row]
		for column in range(columns+1):
			var z: float=lerpf(-8,22,column/float(columns))
			var point: Vector3=IRWaterfallPath.cliff_point(profile,row_values[row],z)
			st.set_uv(Vector2(z*.10,point.y*.10))
			st.set_color(Color.WHITE.lerp(Color("8f9e8c"),(1.0-smoothstep(3.0,6.0,absf(z-7)))*.5))
			st.add_vertex(point)
	for row in range(profiles.size()-1):
		for column in range(columns):
			var a: int=row*(columns+1)+column
			for index in [a,a+columns+1,a+1,a+1,a+columns+1,a+columns+2]:
				st.add_index(index)
	st.generate_normals()
	var cliff_material: StandardMaterial3D=StandardMaterial3D.new()
	cliff_material.vertex_color_use_as_albedo=true
	cliff_material.vertex_color_is_srgb=true
	cliff_material.roughness=.9
	cliff_material.set_meta("palette_kind",12)
	var cliff: Node3D=Node3D.new()
	add_child(cliff)
	IRArt.part(cliff,st.commit(),Vector3.ZERO,cliff_material)
	var moss: StandardMaterial3D=StandardMaterial3D.new()
	moss.albedo_texture=load("res://assets/textures/meadow_albedo_v2.png")
	moss.albedo_color=Color("c4d0bc")
	moss.roughness=.95
	for row in [4,7,10]:
		for side in [-1.0,1.0]:
			var profile: Vector2=IRWaterfallPath.PROFILE[row]
			var back: Vector2=IRWaterfallPath.PROFILE[row+1]
			var patch: SurfaceTool=SurfaceTool.new()
			patch.begin(Mesh.PRIMITIVE_TRIANGLES)
			for n in range(12):
				var vertices: Array[Vector3]=[]
				for along in [n/12.0,(n+1)/12.0]:
					var z: float=7+side*(4.3+along*8.0)
					for across in [.12+.10*sin(z*1.6),.88+.05*sin(z*2.1)]:
						vertices.append(IRWaterfallPath.cliff_point(profile.lerp(back,across),row+across,z)+Vector3.UP*.055)
				for index in [0,2,1,1,2,3]:
					patch.set_uv(Vector2(vertices[index].x,vertices[index].z)*.27)
					patch.set_normal(Vector3.UP)
					patch.add_vertex(vertices[index])
			IRArt.part(cliff,patch.commit(),Vector3.ZERO,moss)
	IRArt.bake(cliff)

func _water_strip(points: Array[Vector3], widths: Array[float]) -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples: Array[Vector3]=[]
	var width_samples: Array[float]=[]
	for segment in range(points.size()-1):
		var steps: int=maxi(ceili(points[segment].distance_to(points[segment+1])*2.0),3)
		for step in range(steps):
			var t: float=step/float(steps)
			samples.append(points[segment].cubic_interpolate(points[segment+1],points[maxi(segment-1,0)],points[mini(segment+2,points.size()-1)],t))
			width_samples.append(lerpf(widths[segment],widths[segment+1],t))
	samples.append(points[-1])
	width_samples.append(widths[-1])
	var distance: float=0
	var total: float=0
	for i in range(samples.size()-1):
		total+=samples[i].distance_to(samples[i+1])
	var columns: int=8
	for row in range(samples.size()):
		if row>0:
			distance+=samples[row].distance_to(samples[row-1])
		for column in range(columns+1):
			var u: float=column/float(columns)
			st.set_uv(Vector2(u,distance/total))
			st.add_vertex(samples[row]+Vector3.BACK*lerpf(width_samples[row],-width_samples[row],u))
	for row in range(samples.size()-1):
		for column in range(columns):
			var a: int=row*(columns+1)+column
			for index in [a,a+columns+1,a+1,a+1,a+columns+1,a+columns+2]:
				st.add_index(index)
	st.generate_normals()
	var material: ShaderMaterial=IRArt.shader("cascade_water")
	material.render_priority=2
	var water: MeshInstance3D=IRArt.part(self,st.commit(),Vector3.ZERO,material)
	water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _spring() -> void:
	var points: Array[Vector3]=[]
	var widths: Array[float]=[]
	for i in range(28):
		var x: float=lerpf(-44.5,-61.6,i/27.0)
		points.append(Vector3(x,IRWaterfallPath.creek_height(x),IRWaterfallPath.creek_z(x)))
		widths.append(IRWaterfallPath.creek_width(x))
	_water_strip(points,widths)
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		var a: float=TAU*i/64
		var b: float=TAU*(i+1)/64
		for p in [Vector3(-41,21.6,7),Vector3(-41+cos(a)*5.7,21.6,7+sin(a)*6.3),Vector3(-41+cos(b)*5.7,21.6,7+sin(b)*6.3)]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p.x,p.z)*.1)
			st.add_vertex(p)
	var pond: MeshInstance3D=IRArt.part(self,st.commit(),Vector3.ZERO,IRArt.shader("ocean"))
	pond.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stones: Node3D=Node3D.new()
	add_child(stones)
	var rock: Mesh=terrain._rock_mesh()
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.albedo_color=Color("ddd9ca")
	material.roughness=.9
	material.set_meta("palette_kind",12)
	for i in range(16):
		var a: float=i*TAU/16
		if cos(a)<-.72:
			continue
		var p: Vector3=Vector3(-41+cos(a)*6.1,0,7+sin(a)*6.8)
		p.y=terrain.surface_height(p)
		var stone: MeshInstance3D=IRArt.part(stones,rock,p,material)
		stone.scale=Vector3(.7,.5,.8)*(1.0+sin(i*2.4)*.25)
	IRArt.bake(stones)

func _cascade() -> void:
	var points: Array[Vector3]=[]
	points.assign(IRWaterfallPath.FLOW)
	var widths: Array[float]=[]
	for i in range(points.size()):
		widths.append(2.7+sin(i*.7)*.25+i*.06)
	_water_strip(points,widths)
	var plane: PlaneMesh=PlaneMesh.new()
	plane.size=Vector2(14,16)
	var foam: MeshInstance3D=IRArt.part(self,plane,Vector3(-71.0,-6.97,7),IRArt.shader("plunge_foam"))
	foam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _mist() -> void:
	_spray(Vector3(-70.4,-6.7,7),64,4.0,1.0)
	_spray(Vector3(-64.7,10.95,7),24,2.0,.35)
	_spray(Vector3(-67.9,4.0,7.2),24,2.0,.30)

func _spray(origin: Vector3, count: int, life: float, size: float) -> void:
	var particles: GPUParticles3D=GPUParticles3D.new()
	particles.position=origin
	particles.scale=Vector3.ONE*size
	particles.amount=count
	particles.lifetime=life
	particles.preprocess=2.0
	particles.visibility_aabb=AABB(Vector3(-12,-3,-13),Vector3(24,18,26))
	var process: ParticleProcessMaterial=ParticleProcessMaterial.new()
	process.direction=Vector3(-.3,1,0)
	process.spread=65
	process.gravity=Vector3(-.10,.24,0)
	process.initial_velocity_min=.5
	process.initial_velocity_max=2.4
	process.scale_min=1.0
	process.scale_max=2.6
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=Vector3(.8,.3,4.2)
	var gradient: Gradient=Gradient.new()
	gradient.offsets=PackedFloat32Array([0,.18,.75,1])
	gradient.colors=PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,.7),Color(1,1,1,0)])
	var ramp: GradientTexture1D=GradientTexture1D.new()
	ramp.gradient=gradient
	process.color_ramp=ramp
	particles.process_material=process
	var quad: QuadMesh=QuadMesh.new()
	quad.size=Vector2(3,3)
	quad.material=IRArt.shader("fairy_mist")
	particles.draw_pass_1=quad
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
