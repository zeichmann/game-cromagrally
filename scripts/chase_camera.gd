class_name IRChaseCamera
extends Camera3D
## Follow at render rate; sweep a sphere so the near plane cannot cross scenery.
var target: IRVehicle
var follow_yaw: float=0
var reverse_time: float=0
var arm_length: float=8.4
var initialized: bool=false
var last_target: Vector3
var obstruction: bool=false
var motion_effects: bool=true
var sweep: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()

func _ready() -> void:
	near=.12
	far=900
	fov=60
	var sphere: SphereShape3D=SphereShape3D.new()
	sphere.radius=.32
	sweep.shape=sphere
	sweep.collision_mask=5 # Ignore drivers, including the followed chassis.
	sweep.margin=.06

func reset_follow() -> void:
	initialized=false
	reverse_time=0

func update_follow(dt: float) -> void:
	if not is_instance_valid(target): return
	var snap: bool=not initialized or target.global_position.distance_to(last_target)>12
	last_target=target.global_position
	reverse_time=move_toward(reverse_time,1.0 if target.speed< -1.5 else 0.0,dt*2.0)
	var heading: float=target.rotation.y+(PI if reverse_time>.65 else 0.0)
	if snap: follow_yaw=heading
	else: follow_yaw=lerp_angle(follow_yaw,heading,1.0-exp(-5.5*dt))
	var forward: Vector3=-Basis(Vector3.UP,follow_yaw).z
	var focus: Vector3=target.global_position+Vector3.UP*1.25
	var distance: float=7.5+minf(absf(target.speed)*.035,1.5)
	var desired: Vector3=focus-forward*distance+Vector3.UP*2.65
	var motion: Vector3=desired-focus
	sweep.transform=Transform3D(Basis.IDENTITY,focus)
	sweep.motion=motion
	var fractions: PackedFloat32Array=get_world_3d().direct_space_state.cast_motion(sweep)
	var safe_length: float=maxf(.45,motion.length()*fractions[0]-.12)
	obstruction=fractions[0]<.995
	# Contract immediately; release gradually to avoid oscillating near walls.
	if snap or safe_length<arm_length: arm_length=safe_length
	else: arm_length=lerpf(arm_length,safe_length,1.0-exp(-3.5*dt))
	global_position=focus+motion.normalized()*arm_length
	var ahead: float=clampf(absf(target.speed)*.065,0,2.6)
	if not motion_effects: ahead=0
	look_at(focus+forward*ahead)
	var desired_fov: float=60.0+clampf(absf(target.speed)/45.0,0,1)*5.0+(4.0 if target.boost_remaining>0 else 0.0)
	if not motion_effects: desired_fov=60
	fov=desired_fov if snap else lerpf(fov,desired_fov,1.0-exp(-3.0*dt))
	initialized=true
