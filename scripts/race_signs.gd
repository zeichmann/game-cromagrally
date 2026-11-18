extends Node3D
## Functional corner warnings, authored in road coordinates and batched once.
var track: IRTrack
func _init(course: IRTrack) -> void: track=course
func _ready() -> void:
	name="CornerWarnings"
	add_to_group("race_signs")
	var root: Node3D=Node3D.new()
	add_child(root)
	var timber: Material=IRArt.pbr(Color("726044"),.9)
	var face: Material=IRArt.pbr(Color("efe0b5"),.9)
	var ink: Material=IRArt.pbr(Color("a84c3d"),.85)
	for index in [86,94,134,157,211,239,268,321]:
		var before: Vector3=track.tangents[posmod(index-3,IRTrack.SAMPLES)]
		var after: Vector3=track.tangents[(index+12)%IRTrack.SAMPLES]
		var turn: float=signf(before.cross(after).y)
		if turn==0: turn=1
		var pole: Node3D=Node3D.new()
		root.add_child(pole)
		pole.position=track.centers[index]+track.right_at(index)*turn*(track.half_width_at(index)+1.6)-Vector3.UP*.65
		pole.rotation.y=atan2(-before.x,-before.z)
		IRArt.block(pole,Vector3(.11,2.5,.11),Vector3(0,1.25,0),timber)
		IRArt.block(pole,Vector3(1.5,.95,.13),Vector3(0,2.05,0),face)
		for n in [-1.0,1.0]:
			var bar: MeshInstance3D=IRArt.block(pole,Vector3(.6,.16,.035),Vector3(-turn*.02,2.05+n*.17,.085),ink)
			bar.rotation.z=n*turn*.65
		var model: MeshInstance3D=IRArt.bake(pole)
		model.reparent(root)
		pole.free()
	var visual: MeshInstance3D=IRArt.bake(root)
	visual.visibility_range_end=125
	visual.create_trimesh_collision()
	var body: StaticBody3D=visual.get_child(0)
	body.collision_layer=4
	body.collision_mask=2
