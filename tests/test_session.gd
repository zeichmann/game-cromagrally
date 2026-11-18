extends SceneTree
## Exercises session transitions against the real scene, without hardware pads.

var assertions: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var race: IRRace = IRRace.new()
	root.add_child(race)
	await process_frame
	check(race.phase == IRRace.Phase.MENU and race.menu.visible, "A normal launch must open the menu")
	check(race.model_preview and race.vehicles[0].visible and not race.vehicles[1].visible,"The menu must show the selected vehicle")
	check(race.vehicles[0].freeze,"The showroom must freeze the rigid chassis as well as its script")
	race.vehicle_picker.selected=1
	race._preview_selection(1)
	await process_frame
	check(race.vehicles[0].variant==1 and race.model_preview,"Vehicle selection must update the live preview")
	race.character_picker.selected=1
	race._preview_selection(1)
	await process_frame
	check(race.vehicles[0].character==1 and (race.vehicles[0].visual as IRVehicleArt).driver.identity==1,"Character selection must instantiate Świnka")
	check(race.vehicles[0].variant==1,"Character selection must preserve the chosen vehicle")
	race.vehicle_picker.selected=0
	race._preview_selection(0)
	await process_frame
	check(race.vehicles[0].character==1 and race.vehicles[0].variant==0,"Świnka must also drive the sail cart")
	check(race.vehicles.size() == 6, "A complete six-car field must exist")
	race._start_race(4, true)
	await process_frame
	check(not race.model_preview and race.vehicles[0].process_mode==Node.PROCESS_MODE_INHERIT,"Starting must replace the frozen preview with active racing vehicles")
	check(not race.vehicles[0].freeze and not race.vehicles[0].can_sleep,"The racing chassis must simulate immediately after standing still")
	check(race.cameras.size() == 4 and race.huddles.size() == 4, "Four players need four cameras and HUDs")
	check(race.vehicles[0].variant != race.vehicles[1].variant, "The demonstration must include both original vehicle designs")
	check(race.vehicles[0].character!=race.vehicles[1].character,"The demonstration must show both Akademia Oli characters")
	for i in range(4):
		var viewport: SubViewport = race.cameras[i].get_parent()
		check(viewport.world_3d == root.world_3d, "Each view must share one physical world")
		check(race.camera_targets[i] == race.vehicles[i], "Each camera must follow a distinct player")
		check(viewport.size.x > 100 and viewport.size.y > 100, "Each viewport must have a usable size")
		check(race.vehicles[i].demo_control, "The demonstration must explicitly use AI")
	race.phase = IRRace.Phase.RACING
	race.race_time = 12.0
	race._pause()
	var frozen_position: Vector3 = race.vehicles[0].global_position
	for frame in range(5):
		await physics_frame
	check(is_equal_approx(race.race_time, 12.0), "Pause must freeze the race clock")
	check(race.vehicles[0].global_position.is_equal_approx(frozen_position), "Pause must freeze the shared simulation")
	check(race.overlay.visible and paused, "Pause must open an interactive overlay")
	race._resume()
	check(not paused and not race.overlay.visible, "Continue must resume the world and dismiss the overlay")
	# Simulate an assigned device disappearing, without pretending a real pad exists.
	race.vehicles[0].demo_control = false
	race.vehicles[0].controller = 42
	race._joy_changed(42, false)
	check(paused and race.paused, "An assigned controller disconnect must pause the race")
	race._start_race(2, true)
	await process_frame
	check(not paused and race.phase == IRRace.Phase.COUNTDOWN, "Restart must clear pause and restore the countdown")
	check(race.cameras.size() == 2 and race.human_count == 2, "Restart must replace the old split-screen layout")
	check(race.vehicles.size() == 6 and race.vehicles[0].progress.completed_laps == 0, "Restart must create a fresh field and progression")
	race.vehicles[0].progress.completed_laps = 3
	race.vehicles[0].progress.finished = true
	race.vehicles[0].progress.finish_time = 90
	race.vehicles[1].progress.completed_laps = 3
	race.vehicles[1].progress.finished = true
	race.vehicles[1].progress.finish_time = 91
	race._finish_race()
	check(race.phase == IRRace.Phase.RESULTS and race.overlay.visible, "Finishing must show results")
	check(race.place_of(race.vehicles[0]) == 1 and race.place_of(race.vehicles[1]) == 2, "Results must sort by finish time")
	race._show_menu()
	check(race.phase == IRRace.Phase.MENU and race.menu.visible and not race.panes.visible, "Returning to menu must hide the old race views")
	check(race.vehicles[0].character==race.character_picker.selected,"Returning from a demonstration must restore the selected character")
	race._start_race(1, true)
	await process_frame
	check(race.cameras.size() == 1 and race.vehicles[0].progress.completed_laps == 0, "A new single-player race must not inherit completed laps")
	race.free()
	await process_frame
	print("SESSION_TEST %s: %d assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
