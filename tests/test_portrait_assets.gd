extends SceneTree
## Catch lost facial parts, deforming lower jaws and sails hiding the selected driver.
var failures: int=0
var assertions: int=0
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for identity in range(2):
		var previous: int=1000000
		for profile in range(3):
			var driver: IRDriverArt=IRDriverArt.new(Color.WHITE,identity)
			root.add_child(driver)
			driver.set_detail(profile)
			var count: int=0
			var eye_vertices: int=0
			var jaw_vertices: int=0
			var face_rigid: bool=true
			var left_nostril: int=0
			var right_nostril: int=0
			for s in range(driver.skinned.mesh.get_surface_count()):
				var arrays: Array=driver.skinned.mesh.surface_get_arrays(s)
				var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
				var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
				count+=positions.size()
				for i in range(positions.size()):
					var family: int=roundi(arrays[Mesh.ARRAY_TEX_UV2][i].x)
					var p: Vector3=positions[i]
					if family in [31,32,42,43,51,52,53,54,55,56,60,65,66,67,68,69]:
						eye_vertices+=1
						face_rigid=face_rigid and bones[i*4]==1 and weights[i*4]>.999
					if family in [30,50,59] and p.y>.43 and p.y<.70 and p.z<-.20:
						jaw_vertices+=1
						face_rigid=face_rigid and bones[i*4]==1 and weights[i*4]>.999
					if identity==1 and family in [30,57] and p.z<-.36 and p.y>.75 and p.y<.84 and arrays[Mesh.ARRAY_COLOR][i].r<.40:
						if p.x<0: left_nostril+=1
						else: right_nostril+=1
			check(face_rigid and eye_vertices>100 and jaw_vertices>100,"Facial surfaces were lost or lower jaw follows the torso")
			check(count<previous and count<70000,"Driver detail levels exceed their vertex budget")
			if identity==1: check(left_nostril>15 and right_nostril>15,"One of the recessed nostrils disappeared during mesh packing")
			previous=count
			driver.free()
	var car: IRVehicleArt=IRVehicleArt.new()
	root.add_child(car)
	var sail_left: float=INF
	for node in car.find_children("*","MeshInstance3D",true,false):
		if node.material_override is ShaderMaterial and node.material_override.shader.resource_path.ends_with("/sail.gdshader"):
			for p in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: sail_left=minf(sail_left,(node.global_transform*p).x)
	var head_right: float=(car.driver.global_transform*Vector3(.64,1.3,0)).x
	check(sail_left>head_right,"Sail still crosses the driver's hat silhouette from behind")
	car.free()
	print("PORTRAIT_ASSET_TEST %s: %d assertions, %d failures"%["PASS" if failures==0 else "FAIL",assertions,failures])
	quit(0 if failures==0 else 1)
