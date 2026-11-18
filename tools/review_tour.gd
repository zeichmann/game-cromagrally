extends SceneTree
## Native review of every tour shot and the return to normal gameplay controls.

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	await race.prepare_graphics()
	var prepared: bool=race.graphics_prepared and race.cameras.is_empty() and race.panes.get_child_count()==0 and race.is_processing_unhandled_input()
	var tour: Node=load("res://scripts/island_tour.gd").new(race)
	race.add_child(tour)
	tour.set_process(false)
	for index in range(tour.shots.size()):
		tour._update_camera(index*tour.SHOT_SECONDS+7.0)
		for frame in range(8):
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/art-review/living_tour_%02d.png"%[index+1])
		print("TOUR_REVIEW ",index+1," ",tour.shots[index].name)
	var event: InputEventAction=InputEventAction.new()
	event.action="ui_cancel"
	event.pressed=true
	tour._unhandled_input(event)
	await process_frame
	var valid: bool=prepared and race.ui.visible and race.menu.visible and race.phase==IRRace.Phase.MENU and race.is_processing() and race.is_physics_processing() and race.is_processing_unhandled_input() and race.vehicles[0].visible
	print("TOUR_RETURN ","PASS" if valid else "FAIL")
	race.queue_free()
	await process_frame
	quit(0 if valid else 1)
