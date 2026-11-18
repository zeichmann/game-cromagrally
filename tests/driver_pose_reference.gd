extends RefCounted
## Validation oracle only: original CPU pose, never loaded by gameplay.
const Rig=preload("res://scripts/academy_rig.gd")
static func pose(clock: float,steer: float,speed: float) -> Skeleton3D:
	var skeleton: Skeleton3D=Rig.skeleton()
	var wind: float=clampf(absf(speed)/25,0,1)
	skeleton.set_bone_pose_position(0,Vector3(0,sin(clock*1.8)*.002,0))
	skeleton.set_bone_pose_rotation(0,Quaternion.from_euler(Vector3(sin(clock*5)*minf(absf(speed)*.0006,.018),0,steer*.055)))
	skeleton.set_bone_pose_rotation(1,Quaternion.from_euler(Vector3(sin(clock*.8)*.009,-steer*.16+sin(clock*.6)*.022,-steer*.035)))
	skeleton.set_bone_pose_rotation(2,Quaternion.from_euler(Vector3(.15,steer*.12,.13+steer*.07)))
	skeleton.set_bone_pose_rotation(3,Quaternion.from_euler(Vector3(.15,steer*.12,-.13+steer*.07)))
	skeleton.set_bone_pose_rotation(4,Quaternion.from_euler(Vector3(sin(clock*5)*(.025+.09*wind),sin(clock*3)*.08*wind,0)))
	skeleton.set_bone_pose_rotation(5,Quaternion.from_euler(Vector3(sin(clock*5-.7)*(.035+.16*wind),sin(clock*3-1)*.10*wind,0)))
	return skeleton
