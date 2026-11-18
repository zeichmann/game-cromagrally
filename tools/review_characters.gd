extends SceneTree
## Native close view of both selectable racing meshes in the actual game world.

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	race.vehicle_picker.selected=1
	race._preview_selection(1)
	await process_frame
	race.set_process(false)
	race.menu.hide()
	var center: Vector3=race.vehicles[0].position
	var outward: Vector3=race.showroom_outward
	var side: Vector3=Vector3.UP.cross(outward).normalized()
	var pose: Transform3D=race.vehicles[0].transform
	for i in range(2):
		var car: IRVehicle=race.vehicles[i]
		car.visible=true
		car.transform=pose
		car.position=center+side*(-1.20+i*2.40)
	race.preview_camera.position=center+outward*4.4+Vector3.UP*2.5
	race.preview_camera.fov=42
	race.preview_camera.look_at(center+Vector3.UP*1.78)
	for i in range(2):
		var label: Label=Label.new()
		label.text=IRDriverArt.CHARACTER_NAMES[i]
		label.position=Vector2(60+i*720,785)
		label.size=Vector2(600,70)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",IRRace.MenuArt.DISPLAY)
		label.add_theme_font_size_override("font_size",38)
		label.add_theme_color_override("font_color",Color("fff5df"))
		label.add_theme_color_override("font_shadow_color",Color("24221f"))
		label.add_theme_constant_override("shadow_offset_y",2)
		race.ui.add_child(label)
	for i in range(12):
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/art-review/academy_drivers_pair.png")
	print("CHARACTER_REVIEW complete: both driver meshes in game, preview lighting")
	quit()
