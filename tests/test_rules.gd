extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_rules.gd

var failures: int = 0
var assertions: int = 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var progress: IRProgress = IRProgress.new()
	check(not progress.cross_gate(0, true, 1), "The start line alone must not award a lap")
	check(not progress.cross_gate(1, false, 1), "Reverse crossings must be rejected")
	check(not progress.cross_gate(5, true, 1), "Skipped checkpoints must be rejected")
	check(progress.next_gate == 1 and progress.completed_laps == 0, "Rejected crossings must not mutate progress")
	check(progress.ranking_score(0.9) < 1.0 / 16.0, "Skipping most of the track cannot improve the legal segment")
	for lap in range(3):
		for gate in range(1, 17):
			check(progress.cross_gate(gate % 16, true, lap * 32.0 + gate * 2.0), "Every ordered forward checkpoint should count")
		check(progress.completed_laps == lap + 1, "Exactly one lap per complete checkpoint sequence")
	check(progress.finished and is_equal_approx(progress.finish_time, 96.0), "The third lap must finish and record time")
	check(is_equal_approx(progress.best_lap, 32.0), "Lap times must exclude earlier laps")
	check(not progress.cross_gate(1, true, 100), "Finished progress must be immutable")
	var earlier: IRProgress = IRProgress.new()
	earlier.finished = true
	earlier.finish_time = 95.0
	check(earlier.ranking_score(0) > progress.ranking_score(0), "Finishers must be ranked by elapsed time")
	var unfinished: IRProgress = IRProgress.new()
	unfinished.completed_laps = 2
	unfinished.next_gate = 0
	check(progress.ranking_score(0) > unfinished.ranking_score(0.999), "A finisher must outrank the final unfinished segment")

	var track: IRTrack = IRTrack.new()
	track.build_centerline()
	check(track.centers.size() == 384 and track.tangents.size() == 384, "The circuit must be closed and fully sampled")
	check(track.length_m > 500 and track.length_m < 900, "The original M1 circuit must have a plausible lap length")
	var before_shortcut: Vector3=track.ai_target(94,12,1)
	var main_target: Vector3=track.centers[106]+track.right_at(106)*sin(3.1)*minf(1.6,track.half_width_at(106)*.25)
	check(before_shortcut.is_equal_approx(main_target),"AI must stay on the main road until the grotto entry gate is credited")
	check(track.shortcut_target(track.shortcut[4],6).is_equal_approx(track.shortcut[10]),"The shortcut must follow its own waypoints instead of main-road projection")
	check(track.shortcut_target(track.shortcut[31],6).is_equal_approx(track.centers[122]),"The shortcut exit must guide cars through the next legal checkpoint")
	check(track.gate_index(16) == 0, "Checkpoint indexing must wrap at the finish line")
	var road: MeshInstance3D = track._strip(-IRTrack.HALF_WIDTH, IRTrack.HALF_WIDTH, 0, Color.WHITE)
	var normals: PackedVector3Array = road.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var all_normals_face_up: bool = true
	for normal in normals:
		all_normals_face_up = all_normals_face_up and normal.y > 0.7
	check(all_normals_face_up, "The generated road must face upward for rendering and collision")
	for gate in range(16):
		var i: int = track.gate_index(gate)
		var center: Vector3 = track.centers[i]
		var tangent: Vector3 = track.tangents[i]
		var right: Vector3 = track.right_at(i)
		check(track.crossed_gate(center - tangent * 2, center + tangent * 2, gate), "A legal forward crossing should count")
		check(not track.crossed_gate(center + tangent * 2, center - tangent * 2, gate), "Reverse geometry crossings should not count")
		var outside: Vector3 = right * (track.half_width_at(i) + 2.0)
		check(not track.crossed_gate(center - tangent * 2 + outside, center + tangent * 2 + outside, gate), "Driving around a gate must not count")
		check(not track.crossed_gate(center - tangent * 2 + Vector3.UP * 8, center + tangent * 2 + Vector3.UP * 8, gate), "Crossing high above a gate must not count")

	var car_a: IRVehicle = IRVehicle.new()
	var car_b: IRVehicle = IRVehicle.new()
	car_a.track = track
	car_b.track = track
	car_a.override_controls = {"steer": -0.7, "throttle": 1.0}
	car_b.override_controls = {"steer": 0.4, "brake": 1.0}
	check(car_a.read_controls().is_equal_approx(Vector3(-0.7, 1, 0)), "Player A must receive only its own controls")
	check(car_b.read_controls().is_equal_approx(Vector3(0.4, 0, 1)), "Player B must receive only its own controls")
	# A node must be in the tree for global_position to be meaningful.
	root.add_child(car_a)
	car_a.set_physics_process(false)
	car_a.slot=1
	car_a.nearest=94
	car_a.speed=28
	car_a.position=track.centers[94]
	car_a.rotation.y=atan2(-track.tangents[94].x,-track.tangents[94].z)
	check(car_a._ai_controls().z>0,"AI must brake before entering the narrow grotto")
	car_a.drive_enabled=true
	car_a.progress.next_gate=5
	car_a.nearest=track.gate_index(5)+18
	check(car_a._needs_gate_recovery(),"A nearest-point jump must not skip missed-checkpoint recovery")
	car_a.nearest=track.gate_index(5)-5
	check(not car_a._needs_gate_recovery(),"Approaching the next checkpoint must not trigger recovery")
	car_a.progress.next_gate = 8
	car_a.progress.completed_laps = 1
	car_a.position = Vector3(1000, -200, 1000)
	car_a.respawn()
	check(car_a.progress.next_gate == 8 and car_a.progress.completed_laps == 1, "Recovery must never award checkpoints or laps")
	check(car_a.position.distance_to(track.centers[track.gate_index(7) + 2]) < 3, "Recovery must use the last legal checkpoint")
	car_a.free()
	car_b.free()
	track.free()
	print("RULE_TEST %s: %d assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
