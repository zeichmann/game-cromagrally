extends Node3D
## Authored accents simulated on GPU; no per-frame script callbacks.
var world: IRFairytaleWorld
var particles: Array[GPUParticles3D]=[]
func _init(island: IRFairytaleWorld) -> void:
	world=island
func _ready() -> void:
	_rainbow()
	if DisplayServer.get_name()!="headless":
		_smoke()
		_petals()

func emitter(p: Vector3,count: int,life: float,extent: Vector3,material: ShaderMaterial,size: Vector2) -> GPUParticles3D:
	var node: GPUParticles3D=GPUParticles3D.new()
	node.position=p
	node.amount=count
	node.lifetime=life
	node.preprocess=minf(life,4.0)
	node.local_coords=false
	node.visibility_aabb=AABB(Vector3(-12,-12,-12),Vector3(24,30,24))
	node.visibility_range_end=100
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=extent
	var quad: QuadMesh=QuadMesh.new()
	quad.size=size
	quad.material=material
	node.draw_pass_1=quad
	node.process_material=process
	add_child(node)
	particles.append(node)
	return node

func _smoke() -> void:
	var node: GPUParticles3D=emitter(world.landmarks.bakery*Vector3(2.25,10,-1.5),28,5.0,Vector3(.18,.08,.18),IRArt.shader("storybook_smoke"),Vector2.ONE)
	var process: ParticleProcessMaterial=node.process_material
	process.direction=Vector3(.15,1,0)
	process.spread=18
	process.gravity=Vector3(.08,.04,0)
	process.initial_velocity_min=.65
	process.initial_velocity_max=1.05
	process.scale_min=.75
	process.scale_max=1.9
	var fade: Gradient=Gradient.new()
	fade.offsets=PackedFloat32Array([0,.15,.65,1])
	fade.colors=PackedColorArray([Color(1,.92,.78,0),Color(1,.94,.85,.38),Color(1,.96,.90,.22),Color(1,1,1,0)])
	var ramp: GradientTexture1D=GradientTexture1D.new()
	ramp.gradient=fade
	process.color_ramp=ramp

func _petals() -> void:
	var node: GPUParticles3D=emitter(world.landmarks.elder_gate*Vector3(-1,10,0),48,9.0,Vector3(7,.5,3),IRArt.shader("storybook_petal"),Vector2(.18,.12))
	var process: ParticleProcessMaterial=node.process_material
	process.direction=Vector3(.20,-1,.05)
	process.spread=35
	process.gravity=Vector3(.06,-.09,.025)
	process.initial_velocity_min=.12
	process.initial_velocity_max=.35
	process.scale_min=.6
	process.scale_max=1.5
	process.angle_min=-180
	process.angle_max=180
	process.angular_velocity_min=-35
	process.angular_velocity_max=35
	process.color=Color("f3d2a1")

func _rainbow() -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors: Array[Color]=[Color("f7b1b0"),Color("efc99b"),Color("f0dfaa"),Color("b5cfaf"),Color("a4c9dc"),Color("c1b6de")]
	for band in range(6):
		for segment in range(56):
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
				var angle: float=PI*(segment+offset.x)/56
				var radius: float=6.5+(band+offset.y)*.13
				st.set_uv(Vector2((segment+offset.x)/56,(band+offset.y)/6))
				st.set_color(colors[band])
				st.set_normal(Vector3.LEFT)
				st.add_vertex(Vector3(-71.0,8.5+sin(angle)*radius,7+cos(angle)*radius))
	var arc: MeshInstance3D=IRArt.part(self,st.commit(),Vector3.ZERO,IRArt.shader("storybook_rainbow"))
	arc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arc.visibility_range_end=120

func apply_quality(profile: int) -> void:
	for index in range(particles.size()):
		particles[index].amount=([28,48][index] if profile==0 else ([18,30][index] if profile==1 else [12,18][index]))
