extends SceneTree
## Captures the actual menu controls, keyboard focus, smaller window and pause.

func _initialize() -> void:
	call_deferred("review")

func shot(path: String) -> void:
	for i in range(8):
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func review() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	await shot("res://build/art-review/menu_forward_plus_high.png")
	await shot("res://build/art-review/academy_zabol_driver.png")
	race.character_picker.selected=1
	race._preview_selection(1)
	await shot("res://build/art-review/academy_swinka_driver.png")
	race.vehicle_picker.show_popup()
	await shot("res://build/art-review/menu_selector.png")
	race.vehicle_picker.get_popup().hide()
	race.vehicle_picker.selected=1
	race._preview_selection(1)
	await shot("res://build/art-review/menu_flywheel_forward_plus_high.png")
	for button in race.menu.find_children("*","Button",true,false):
		if button.text=="START RACE":
			button.grab_focus()
	await shot("res://build/art-review/menu_flywheel_focus.png")
	DisplayServer.window_set_size(Vector2i(1024,768))
	await shot("res://build/art-review/menu_1024x768.png")
	race.player_picker.selected=3
	race._request_start()
	await shot("res://build/art-review/menu_missing_controllers.png")
	race.player_picker.selected=0
	race._request_start()
	await process_frame
	race._pause()
	await shot("res://build/art-review/menu_pause.png")
	print("MENU_REVIEW complete: both Akademia Oli drivers, selector, focus, small window, missing controllers, pause")
	quit()
