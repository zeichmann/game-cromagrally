class_name IRVehicle
extends RigidBody3D
## Arcade tire forces over a dynamic Jolt chassis; the engine owns all contacts.
const Contacts=preload("res://scripts/vehicle_contacts.gd")

const COLORS: Array[Color] = [Color("ee7d53"), Color("49bbba"), Color("e9c96c"), Color("8b8dbf"), Color("96ba65"), Color("d48c9b")]
var track: IRTrack
var progress: IRProgress = IRProgress.new()
var slot: int = 0
var human: bool = false
var demo_control: bool = false
var controller: int = -1 # -1 keyboard; nonnegative is an actual Godot joypad ID.
var variant: int = 0
var character: int = 0
var drive_enabled: bool = false
var speed: float = 0.0
var nearest: int = 0
var off_course_time: float = 0.0
var stuck_time: float = 0.0
var last_position: Vector3
var visual: Node3D
var wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var fan: Node3D
var override_controls: Dictionary = {}
var grounded: bool=false
var ground_probe: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.new()
var dust: GPUParticles3D
var render_steer: float=0
var seeds_collected: int=0
var boost_charge: int=0
var boost_remaining: float=0
var secret_found: bool=false
var jump_cooldown: float=0
var splash: GPUParticles3D
var boost_trail: GPUParticles3D
var leaf_wake: GPUParticles3D
var steering_input: float=0
var throttle_input: float=0
var brake_input: float=0
var slip_speed: float=0
var surface: String="paving"
var air_time: float=0
var previous_vertical: float=0
var impact_timer: float=0
var impact_feedback: float=0
var landing_feedback: float=0
var impact_events: int=0
var landing_events: int=0
var recovery_cooldown: float=0
var recovery_pending: bool=false
var driving_audio: IRDrivingAudio
var ground_shadow: MeshInstance3D
var traffic: IRRaceTraffic=IRRaceTraffic.new()
var preferences: IRRacePreferences
var wrong_way_time: float=0
var wheel_probes: Array[Vector3]=[Vector3(-.85,0,-1.1),Vector3(.85,0,-1.1),Vector3(-.85,0,1.1),Vector3(.85,0,1.1)]

func _ready() -> void:
	Contacts.configure(self,variant)
	ground_probe.collision_mask=5 # Ground and walkable scenery, excluding cars.
	freeze=not can_process()
	_build_model()
	if DisplayServer.get_name()!="headless":
		driving_audio=IRDrivingAudio.new(self)
		add_child(driving_audio)
		ground_shadow=IRArt.part(self,QuadMesh.new(),Vector3(0,.035,0),IRArt.shader("ground_shadow"))
		ground_shadow.mesh.size=Vector2(2.9,4.1)
		ground_shadow.rotation.x=-PI*.5
		ground_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ground_shadow.hide()
	last_position = global_position

func _notification(what: int) -> void:
	# Disabling script callbacks alone would leave a rigid chassis simulating in
	# the showroom and capture tools. Freeze it when its process branch is disabled.
	if what==NOTIFICATION_DISABLED:
		freeze=true
		if is_instance_valid(driving_audio): driving_audio.silence()
	elif what==NOTIFICATION_ENABLED:
		freeze=false

func is_on_floor() -> bool:
	return grounded

func max_speed() -> float:
	return (39.0 if variant == 0 else 33.0)*(1.28 if boost_remaining>0 else 1.0)

func try_boost() -> bool:
	if not drive_enabled or progress.finished or boost_charge<3 or boost_remaining>0: return false
	boost_charge-=3
	boost_remaining=1.65
	return true

func _build_model() -> void:
	var model: IRVehicleArt = IRVehicleArt.new(variant, COLORS[slot % COLORS.size()], slot + 1,character)
	visual = model
	add_child(model)
	wheels = model.wheels
	front_wheels = model.steering
	fan = model.fan
	_build_dust()
	if DisplayServer.get_name()!="headless":
		splash=_build_spark("FordSplashGPU",Color(.65,.82,.83,.6),24,Vector3(0,-6,0),2.5,.55)
		boost_trail=_build_spark("WindBoostGPU",Color(1.0,.76,.34,.75),24,Vector3(0,.15,0),3.5,.48)
		leaf_wake=_build_spark("WoodlandLeavesGPU",Color.WHITE,16,Vector3(0,-1.2,0),2.5,1.0)
		leaf_wake.draw_pass_1=leaf_wake.draw_pass_1.duplicate()
		leaf_wake.draw_pass_1.material=IRArt.shader("leaf_wake")
		var leaves: ParticleProcessMaterial=leaf_wake.process_material
		leaves.angle_min=-180
		leaves.angle_max=180
		leaves.angular_velocity_min=-160
		leaves.angular_velocity_max=160

func _build_spark(node_name: String,color: Color,count: int,gravity: Vector3,velocity_value: float,life: float) -> GPUParticles3D:
	var node: GPUParticles3D=GPUParticles3D.new()
	node.name=node_name
	node.position=Vector3(0,.3,1.1)
	node.amount=count
	node.lifetime=life
	node.local_coords=false
	node.emitting=false
	node.visibility_aabb=AABB(Vector3(-22,-5,-22),Vector3(44,15,44))
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process: ParticleProcessMaterial=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=Vector3(.72,.05,.15)
	process.direction=Vector3(0,1,0) if gravity.y<0 else Vector3(0,.1,1)
	process.spread=28
	process.gravity=gravity
	process.initial_velocity_min=velocity_value*.6
	process.initial_velocity_max=velocity_value
	process.scale_min=.09
	process.scale_max=.22
	var fade: Gradient=Gradient.new()
	fade.colors=PackedColorArray([color,Color(color.r,color.g,color.b,0)])
	var ramp: GradientTexture1D=GradientTexture1D.new()
	ramp.gradient=fade
	process.color_ramp=ramp
	node.process_material=process
	var quad: QuadMesh=QuadMesh.new()
	quad.size=Vector2(.8,1.4)
	quad.material=IRArt.shader("racer_spark")
	node.draw_pass_1=quad
	add_child(node)
	return node

func _build_dust() -> void:
	if DisplayServer.get_name() == "headless":
		return
	dust = GPUParticles3D.new()
	dust.name = "WheelDustGPU"
	dust.position = Vector3(0, .25, 1.15)
	dust.amount = 48
	dust.lifetime = .85
	dust.emitting = false
	dust.local_coords = false
	dust.visibility_aabb = AABB(Vector3(-8,-2,-8),Vector3(16,8,16))
	dust.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(.78,.05,.15)
	process.direction = Vector3(0,.3,1)
	process.spread = 35
	process.initial_velocity_min = .6
	process.initial_velocity_max = 2.0
	process.gravity = Vector3(0,.8,0)
	process.scale_min = .2
	process.scale_max = .65
	var fade: Gradient = Gradient.new()
	fade.set_color(0,Color(.83,.66,.40,.30))
	fade.set_color(1,Color(.83,.66,.40,0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	dust.process_material = process
	var alpha: Gradient = Gradient.new()
	alpha.set_color(0,Color.WHITE)
	alpha.set_color(1,Color(1,1,1,0))
	var image: GradientTexture2D = GradientTexture2D.new()
	image.width = 64
	image.height = 64
	image.gradient = alpha
	image.fill = GradientTexture2D.FILL_RADIAL
	image.fill_from = Vector2(.5,.5)
	image.fill_to = Vector2(.5,1)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = image
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	dust.draw_pass_1 = quad
	add_child(dust)

func read_controls() -> Vector3:
	if not override_controls.is_empty():
		return Vector3(float(override_controls.get("steer", 0)), float(override_controls.get("throttle", 0)), float(override_controls.get("brake", 0)))
	if not human or demo_control or progress.finished:
		return _ai_controls()
	if controller < 0:
		if preferences!=null:
			return Vector3(float(preferences.down("right"))-float(preferences.down("left")),float(preferences.down("throttle"))-float(preferences.down("reverse")),float(preferences.down("brake")))
		var steer: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		var throttle: float = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		return Vector3(steer, throttle, float(Input.is_physical_key_pressed(KEY_SPACE)))
	if not Input.get_connected_joypads().has(controller):
		return Vector3(0, 0, 1)
	var steer: float = Input.get_joy_axis(controller, JOY_AXIS_LEFT_X)
	if absf(steer) < 0.12:
		steer = 0
	else:
		steer=signf(steer)*pow((absf(steer)-.12)/.88,1.25)
		if preferences!=null: steer=clampf(steer*preferences.sensitivity,-1,1)
	var throttle: float = Input.get_joy_axis(controller, JOY_AXIS_TRIGGER_RIGHT)
	if Input.is_joy_button_pressed(controller, JOY_BUTTON_A):
		throttle = 1
	var reverse: float = Input.get_joy_axis(controller, JOY_AXIS_TRIGGER_LEFT)
	return Vector3(steer, throttle - reverse, float(Input.is_joy_button_pressed(controller, JOY_BUTTON_X)))

func _ai_controls() -> Vector3:
	var grotto_approach: bool=nearest>=IRTrack.SHORTCUT_START-16 and nearest<=IRTrack.SHORTCUT_END+4
	var look_ahead: int = 9 + int(absf(speed) * 0.18)
	if grotto_approach: look_ahead=3
	# A physical chassis can take the early diagonal literally. Pass the entry
	# checkpoint before aiming into the grotto, then merge before the next gate.
	var target: Vector3 = track.ai_target(nearest,look_ahead,0)+track.right_at(posmod(nearest+look_ahead,IRTrack.SAMPLES))*traffic.lane
	if slot%3==1 and progress.next_gate==5 and nearest>=IRTrack.SHORTCUT_START-4 and nearest<=IRTrack.SHORTCUT_END+12:
		target=track.shortcut_target(global_position,3)
	var delta_to_target: Vector3 = target - global_position
	var desired_yaw: float = atan2(-delta_to_target.x, -delta_to_target.z)
	var angle: float = wrapf(desired_yaw - rotation.y, -PI, PI)
	var bend: float = track.tangents[nearest].angle_to(track.tangents[(nearest + 16) % IRTrack.SAMPLES])
	var target_speed: float = max_speed() * clampf(1.0 - bend * 0.8, 0.36, 0.95)
	if preferences!=null: target_speed*=[.8,.92,1.0][preferences.difficulty]
	if slot%3==1 and nearest>=IRTrack.SHORTCUT_START-12 and nearest<=IRTrack.SHORTCUT_END+4:
		# Brake before the narrow entrance and merge at a speed the physical
		# chassis can turn, rather than cutting the exit checkpoint at full speed.
		target_speed=minf(target_speed,track.shortcut_speed_limit(global_position,1.55 if variant==0 else 1.30))
	elif grotto_approach:
		target_speed=minf(target_speed,track.main_road_speed_limit(nearest,1.55 if variant==0 else 1.30))
	target_speed=minf(target_speed,traffic.speed_limit)
	var throttle: float = 1.0 if speed < target_speed else 0.0
	var brake: float = 0.55 if speed > target_speed + 3.0 else 0.0
	var steering_gain: float=3.2 if grotto_approach else 1.8
	return Vector3(clampf(-angle*steering_gain,-1.0,1.0),throttle,brake)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	grounded=false
	impact_timer=maxf(0,impact_timer-state.step)
	var hit_impulse: float=0
	for i in range(state.get_contact_count()):
		var other: Object=state.get_contact_collider_object(i)
		# Yaw is the only free rotation, so local and world up agree. Another
		# driver's roof never supplies tire traction or a ramp-jump trigger.
		if other is CollisionObject3D and other.collision_layer & 5 and state.get_contact_local_normal(i).y>.55:
			grounded=true
		if absf(state.get_contact_local_normal(i).y)<.7:
			hit_impulse=maxf(hit_impulse,state.get_contact_impulse(i).length()/mass)
	if hit_impulse>1.2 and impact_timer<=0:
		impact_feedback=clampf(hit_impulse/12,.15,1)
		impact_timer=.2
		impact_events+=1
	if track == null:
		return
	var dt: float=state.step
	# The wheels still reach the surface across small downhill gaps, even when
	# the flat chassis has briefly lost its contact manifold. Model that short
	# suspension reach with a ground-only ray and downforce, never a teleport.
	if not grounded and jump_cooldown<=1.72 and state.linear_velocity.y<=1.0:
		ground_probe.from=state.transform.origin+Vector3.UP*.15
		ground_probe.to=state.transform.origin-Vector3.UP*.45
		var support: Dictionary=state.get_space_state().intersect_ray(ground_probe)
		if not support.is_empty() and support.normal.y>.55:
			grounded=true
			state.linear_velocity+=Vector3.DOWN*18.0*dt
		else:
			var supports: int=0
			for wheel in wheel_probes:
				var p: Vector3=state.transform*wheel
				ground_probe.from=p+Vector3.UP*.16
				ground_probe.to=p-Vector3.UP*.48
				var wheel_hit: Dictionary=state.get_space_state().intersect_ray(ground_probe)
				if not wheel_hit.is_empty() and wheel_hit.normal.y>.55: supports+=1
			if supports>=2:
				grounded=true
				state.linear_velocity+=Vector3.DOWN*18.0*dt
	if grounded:
		if air_time>.14 and previous_vertical< -3:
			landing_feedback=clampf((-previous_vertical-3)/12,.15,1)
			landing_events+=1
		air_time=0
	else: air_time+=dt
	previous_vertical=state.linear_velocity.y
	nearest=track.closest_index(state.transform.origin)
	if drive_enabled and (not human or demo_control or progress.finished): traffic.update(self,state.get_space_state(),dt)
	surface=track.surface_at(state.transform.origin,nearest)
	var ground: Dictionary=IRTrack.SURFACES[surface]
	var controls: Vector3 = read_controls() if drive_enabled else Vector3(0, 0, 1)
	var input_rate: float=8.0 if not human or demo_control else 5.5
	if human and not demo_control and preferences!=null: input_rate*=preferences.sensitivity
	steering_input=move_toward(steering_input,controls.x,dt*(input_rate if absf(controls.x)>.05 else 9.0))
	throttle_input=move_toward(throttle_input,controls.y,dt*7)
	brake_input=controls.z
	boost_remaining=maxf(boost_remaining-dt,0)
	jump_cooldown=maxf(jump_cooldown-dt,0)
	if human and not demo_control:
		if (controller<0 and (preferences.down("boost") if preferences!=null else Input.is_physical_key_pressed(KEY_SHIFT))) or (controller>=0 and Input.is_joy_button_pressed(controller,JOY_BUTTON_B)):
			try_boost()
	render_steer=steering_input
	var forward: Vector3=-state.transform.basis.z
	var motion: Vector3=state.linear_velocity
	speed=motion.dot(forward)
	var traction: float=1.0 if grounded else .12
	var acceleration: float=22.0 if variant==0 else 17.0
	var new_speed: float=speed
	# Limit engine acceleration, not collision velocity. A hit can push a car
	# beyond its engine speed; drag and tire forces then slow it gradually.
	var opposing: bool=throttle_input*speed<0 and absf(speed)>1.2
	if opposing:
		new_speed=move_toward(speed,0,30.0*absf(throttle_input)*traction*dt)
	elif throttle_input>0 and speed<max_speed():
		var power: float=lerpf(1.0,.55,clampf(speed/max_speed(),0,1))
		new_speed=minf(speed+throttle_input*acceleration*power*float(ground.drive)*traction*dt,max_speed())
	elif throttle_input<0 and speed>-max_speed()*.35:
		new_speed=maxf(speed+throttle_input*acceleration*.7*float(ground.drive)*traction*dt,-max_speed()*.35)
	if absf(throttle_input) < 0.05:
		new_speed=move_toward(new_speed,0.0,(float(ground.drag)+.035*absf(speed))*traction*dt)
	elif float(ground.drag)>3:
		new_speed=move_toward(new_speed,0,float(ground.drag)*clampf(absf(speed)/8,0,1)*traction*dt)
	if controls.z > 0:
		new_speed=move_toward(new_speed,0.0,35.0*controls.z*traction*dt)
	var turn_rate: float = 1.55 if variant == 0 else 1.30
	var authority: float=lerpf(1.0,.78,clampf((absf(speed)-12)/30,0,1))
	var wanted_yaw: float=-steering_input*turn_rate*clampf(absf(speed)/4.5,0,1)*signf(speed)*authority
	if not grounded: wanted_yaw*=.18
	var spin: Vector3=state.angular_velocity
	spin.y=lerpf(spin.y,wanted_yaw,1.0-exp(-(3.5 if impact_timer>0 else (15.0 if grounded else 2.0))*dt))
	state.angular_velocity=spin
	var lateral: Vector3=motion-forward*speed
	lateral.y = 0
	slip_speed=lateral.length()
	var grip: float=float(ground.grip) if grounded else .4
	if brake_input>.1 and absf(steering_input)>.35: grip*=.78
	var horizontal: Vector3=forward*new_speed+lateral*exp(-grip*dt)
	motion.x=horizontal.x
	motion.z=horizontal.z
	if drive_enabled and nearest>=249 and nearest<=251 and absf(speed)>12 and jump_cooldown<=0 and grounded:
		motion.y=5.8
		jump_cooldown=2.0
		grounded=false
	state.linear_velocity=motion
	if drive_enabled: state.sleeping=false

func _physics_process(dt: float) -> void:
	if track==null: return
	recovery_cooldown=maxf(0,recovery_cooldown-dt)
	last_position=global_position
	nearest=track.closest_index(global_position)
	speed=linear_velocity.dot(-global_basis.z)
	var wet: bool=nearest>=145 and nearest<=152
	var route_forward: Vector3=track.tangents[nearest]
	if nearest>=IRTrack.SHORTCUT_START-3 and nearest<=IRTrack.SHORTCUT_END+3:
		var n: int=track.shortcut_nearest(global_position)
		if global_position.distance_to(track.shortcut[n])<IRTrack.SHORTCUT_WIDTH+1 and n<track.shortcut.size()-1:
			route_forward=(track.shortcut[n+1]-track.shortcut[n]).normalized()
	wrong_way_time=wrong_way_time+dt if drive_enabled and linear_velocity.dot(route_forward)< -2.0 else maxf(0,wrong_way_time-dt*2)
	# Recover below the sea immediately instead of spending the off-course
	# grace period beneath the island. Ordinary verges are physical terrain.
	if global_position.y< -8.0:
		respawn()
		return
	if dust != null:
		dust.emitting = drive_enabled and absf(speed) > 8 and is_on_floor() and not wet
	if splash!=null: splash.emitting=drive_enabled and wet and absf(speed)>5 and is_on_floor()
	if boost_trail!=null: boost_trail.emitting=drive_enabled and boost_remaining>0
	if leaf_wake!=null: leaf_wake.emitting=drive_enabled and nearest>72 and nearest<170 and absf(speed)>10 and is_on_floor()
	if track.driving_margin(global_position,nearest)>4.0:
		off_course_time += dt
	else:
		off_course_time = 0
	if drive_enabled and absf(speed) < 1.0:
		stuck_time += dt
	else:
		stuck_time = 0
	if (recovery_pending and recovery_cooldown<=0) or off_course_time > 2.0 or ((not human or demo_control) and stuck_time > 4.0) or _needs_gate_recovery():
		respawn()

func _needs_gate_recovery() -> bool:
	if not drive_enabled or progress.finished or (human and not demo_control):
		return false
	# An AI displaced around a gate must recover instead of driving an uncredited lap.
	var beyond: int=posmod(nearest-track.gate_index(progress.next_gate),IRTrack.SAMPLES)
	# Nearest-point projection can jump past the old twelve-sample window at
	# the grotto exit. Any clearly forward position in this half-lap is a miss.
	return beyond>6 and beyond<IRTrack.SAMPLES/2

func respawn() -> void:
	if recovery_cooldown>0 and global_position.y> -8: return
	var i: int = posmod(track.gate_index(progress.last_gate()) + 2, IRTrack.SAMPLES)
	var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
	query.shape=get_node("ChassisCollision").shape
	query.collision_mask=6
	query.exclude=[get_rid()]
	var recovered: bool=false
	for offset in [0,2,-1,4]:
		var index: int=posmod(i+offset,IRTrack.SAMPLES)
		var yaw: float=atan2(-track.tangents[index].x,-track.tangents[index].z)
		for lane in [(1.8 if slot%2 else -1.8),0.0,(-1.8 if slot%2 else 1.8)]:
			var p: Vector3=track.centers[index]+track.right_at(index)*lane+Vector3.UP*.5
			query.transform=Transform3D(Basis(Vector3.UP,yaw),p+Vector3.UP*.55)
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
				global_position=p
				rotation=Vector3(0,yaw,0)
				recovered=true
				break
		if recovered: break
	if not recovered:
		recovery_pending=true
		recovery_cooldown=.25
		return
	recovery_pending=false
	recovery_cooldown=.75
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	grounded=false
	sleeping=false
	reset_physics_interpolation()
	speed = 0
	boost_remaining=0
	jump_cooldown=0
	steering_input=0
	throttle_input=0
	impact_feedback=0
	landing_feedback=0
	air_time=0
	wrong_way_time=0
	traffic.timer=0
	traffic.lane=0
	traffic.lane_goal=0
	off_course_time = 0
	stuck_time = 0
	last_position = global_position
