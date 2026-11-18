extends RefCounted
## Shared rest pose for the two seated Akademia Oli drivers. Forward is -Z.

const NAMES: Array[String]=["torso","head","arm_left","arm_right","scarf","scarf_tip"]
const RESTS: Array[Vector3]=[Vector3.ZERO,Vector3(0,.44,0),Vector3(-.28,.30,0),Vector3(.28,.30,0),Vector3(0,.39,.04),Vector3(0,0,.30)]
const LABELS: Array[String]=["Żabol","Świnka"]

static func skeleton() -> Skeleton3D:
	var result: Skeleton3D=Skeleton3D.new()
	result.name="PilotSkeleton"
	for i in range(NAMES.size()):
		result.add_bone(NAMES[i])
		if i>0:
			result.set_bone_parent(i,4 if i==5 else 0)
		result.set_bone_rest(i,Transform3D(Basis.IDENTITY,RESTS[i]))
	result.reset_bone_poses()
	return result
