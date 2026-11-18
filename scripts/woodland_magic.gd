extends Node3D
## Localised particles and light shafts. No per-frame script animation.
var world: IRFairytaleWorld
var motes: Array[GPUParticles3D]=[]

func _init(island: IRFairytaleWorld) -> void:
	world=island

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	for i in [83,111,139,-1]:
		var p: Vector3=world.landmarks.crystal_grotto.origin if i<0 else world.track.centers[i]+world.track.right_at(i)*2
		var node: GPUParticles3D=GPUParticles3D.new()
		node.position=p+Vector3.UP*2
		node.amount=32
		node.lifetime=7
		node.preprocess=3
		node.visibility_aabb=AABB(Vector3(-8,-3,-8),Vector3(16,10,16))
		node.visibility_range_end=55
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var process: ParticleProcessMaterial=ParticleProcessMaterial.new()
		process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents=Vector3(6,1.6,6)
		process.direction=Vector3(.4,.1,.3)
		process.spread=180
		process.gravity=Vector3.ZERO
		process.initial_velocity_min=.10
		process.initial_velocity_max=.32
		process.scale_min=.7
		process.scale_max=1.4
		var fade: Gradient=Gradient.new()
		fade.offsets=PackedFloat32Array([0,.2,.8,1])
		fade.colors=PackedColorArray([Color(1,.8,.4,0),Color(1,.85,.5,.6),Color(1,.85,.5,.4),Color(1,.8,.4,0)])
		var ramp: GradientTexture1D=GradientTexture1D.new()
		ramp.gradient=fade
		process.color_ramp=ramp
		node.process_material=process
		var quad: QuadMesh=QuadMesh.new()
		quad.size=Vector2(.16,.16)
		quad.material=IRArt.shader("forest_mote")
		node.draw_pass_1=quad
		add_child(node)
		motes.append(node)
		if i<0:
			process.emission_box_extents=Vector3(2.3,1.0,2.0)
			continue
		var cone: CylinderMesh=CylinderMesh.new()
		cone.top_radius=.08
		cone.bottom_radius=1.45
		cone.height=8.0
		cone.radial_segments=24
		var shaft: MeshInstance3D=IRArt.part(self,cone,p+Vector3(1,4,.2),IRArt.shader("forest_shaft"))
		shaft.rotation_degrees=Vector3(12,0,-18)
		shaft.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.visibility_range_end=65
	for n in range(2):
		var light: OmniLight3D=OmniLight3D.new()
		light.position=world.landmarks.crystal_grotto.origin+Vector3((n*2-1)*2.2,2.5,0)
		light.light_color=Color("a8c6b2") if n==0 else Color("b9a9cc")
		light.light_energy=.35
		light.omni_range=5
		light.distance_fade_enabled=true
		light.distance_fade_begin=45
		light.distance_fade_length=10
		add_child(light)

func apply_quality(profile: int) -> void:
	for node in motes: node.amount=[32,22,14][profile]
