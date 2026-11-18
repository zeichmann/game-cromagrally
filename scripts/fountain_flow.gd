class_name IRFountainFlow
extends Node3D
## GPU-simulated spout and overflow; no per-frame CPU particle updates.

var emitters: Array[GPUParticles3D]=[]

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		return
	_emitter(Vector3(0,3.90,0),false,36)
	_emitter(Vector3(0,2.36,0),true,88)

func _emitter(p: Vector3, ring: bool, count: int) -> void:
	var particles: GPUParticles3D=GPUParticles3D.new()
	particles.position=p
	particles.amount=count
	particles.lifetime=1.25 if ring else 1.5
	particles.preprocess=1.2
	particles.visibility_aabb=AABB(Vector3(-4,-5,-4),Vector3(8,9,8))
	particles.visibility_range_end=65
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial=ParticleProcessMaterial.new()
	process.gravity=Vector3(0,-3.0,0)
	process.direction=Vector3.DOWN if ring else Vector3.UP
	process.spread=8 if ring else 20
	process.initial_velocity_min=.15 if ring else 1.3
	process.initial_velocity_max=.40 if ring else 1.8
	process.scale_min=.55
	process.scale_max=1.2
	if ring:
		process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_RING
		process.emission_ring_radius=1.27
		process.emission_ring_inner_radius=1.23
		process.emission_ring_height=.02
		process.emission_ring_axis=Vector3.UP
		process.radial_velocity_min=.20
		process.radial_velocity_max=.35
	var fade: Gradient=Gradient.new()
	fade.offsets=PackedFloat32Array([0,.12,.82,1])
	fade.colors=PackedColorArray([Color(.8,.94,1,.0),Color(.8,.94,1,.72),Color(.8,.94,1,.60),Color(.8,.94,1,0)])
	var ramp: GradientTexture1D=GradientTexture1D.new()
	ramp.gradient=fade
	process.color_ramp=ramp
	particles.process_material=process
	var drop: SphereMesh=SphereMesh.new()
	drop.radius=.035 if ring else .045
	drop.height=.12
	drop.radial_segments=6
	drop.rings=3
	var water: StandardMaterial3D=StandardMaterial3D.new()
	water.vertex_color_use_as_albedo=true
	water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness=.22
	drop.material=water
	particles.draw_pass_1=drop
	add_child(particles)
	emitters.append(particles)

func apply_quality(profile: int) -> void:
	visible=profile<2
	for i in range(emitters.size()):
		emitters[i].emitting=profile<2
		emitters[i].amount=([36,88][i] if profile==0 else [20,48][i])
