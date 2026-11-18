extends RefCounted
## Shared rigid chassis setup. Contact manifolds, impulses and CCD run in Jolt.
## Public implementation: https://github.com/jrouwe/JoltPhysics
const CHASSIS_SIZE: Vector3=Vector3(2.2,1.1,3.3)
const LIGHT_MASS: float=280.0
const HEAVY_MASS: float=380.0

static func configure(body: RigidBody3D,variant: int) -> void:
	body.mass=LIGHT_MASS if variant==0 else HEAVY_MASS
	body.collision_layer=2
	body.collision_mask=7 # Ground (1), cars (2), buildings and solid props (4).
	body.continuous_cd=true
	# Six controlled chassis must react immediately when the countdown ends,
	# even after standing still long enough to enter the engine's sleep state.
	body.can_sleep=false
	body.contact_monitor=true
	body.max_contacts_reported=16
	body.axis_lock_angular_x=true
	body.axis_lock_angular_z=true
	body.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp=0
	body.angular_damp=0
	body.freeze_mode=RigidBody3D.FREEZE_MODE_STATIC
	var material: PhysicsMaterial=PhysicsMaterial.new()
	material.friction=.25
	material.bounce=.08
	body.physics_material_override=material
	var collider: CollisionShape3D=CollisionShape3D.new()
	collider.name="ChassisCollision"
	var shape: BoxShape3D=BoxShape3D.new()
	shape.size=CHASSIS_SIZE
	shape.margin=.025
	collider.shape=shape
	collider.position.y=CHASSIS_SIZE.y*.5
	body.add_child(collider)

# Offline footprint diagnostics only; never used to move racing cars.
static func separation(a: Transform3D,b: Transform3D) -> Vector3:
	var delta: Vector3=a.origin-b.origin
	if absf(delta.y)>1.25:
		return Vector3.ZERO
	delta.y=0
	if delta.length_squared()>16:
		return Vector3.ZERO
	var axes: Array[Vector3]=[a.basis.x,a.basis.z,b.basis.x,b.basis.z]
	var minimum: float=INF
	var normal: Vector3=Vector3.ZERO
	for axis in axes:
		axis.y=0
		axis=axis.normalized()
		var ra: float=absf(axis.dot(a.basis.x))*1.10+absf(axis.dot(a.basis.z))*1.65
		var rb: float=absf(axis.dot(b.basis.x))*1.10+absf(axis.dot(b.basis.z))*1.65
		var overlap: float=ra+rb-absf(delta.dot(axis))
		if overlap<=.00001:
			return Vector3.ZERO
		if overlap<minimum:
			minimum=overlap
			normal=axis*(1 if delta.dot(axis)>=0 else -1)
	return normal*minimum
