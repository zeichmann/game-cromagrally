class_name IRRace
extends Node
const MenuArt=preload("res://scripts/menu_art.gd")
## Independent prototype session, original UI and shared-world split-screen.

enum Phase { MENU, COUNTDOWN, RACING, RESULTS }
var phase: Phase = Phase.MENU
var stage: Node3D
var track: IRTrack
var vehicles: Array[IRVehicle] = []
var cameras: Array[Camera3D] = []
var camera_targets: Array[IRVehicle] = []
var human_count: int = 1
var race_time: float = 0.0
var countdown: float = 3.0
var first_finish_at: float = -1.0
var preview_camera: Camera3D
var ui: Control
var panes: Control
var overlay: Control
var menu: PanelContainer
var status: Label
var player_picker: OptionButton
var vehicle_picker: OptionButton
var character_picker: OptionButton
var keyboard_picker: CheckBox
var center_text: Label
var huddles: Array[IRHUD] = []
var record: float = INF
var record_label: Label
var sound: AudioStreamPlayer
var paused: bool = false
var test_mode: bool = false
var orbit: float = 0.4
var title_font: Font
var quality_picker: OptionButton
var world_environment: Environment
var sun: DirectionalLight3D
var showroom_fill: DirectionalLight3D
var model_preview: bool=false
var showroom_outward: Vector3=Vector3.RIGHT
var preview_clock: float=0.0
var vehicle_note: Label
var graphics_prepared: bool=false
var gpu_motion: IRGpuMotion
var preferences: IRRacePreferences=IRRacePreferences.new()
var controls_hint: Label
var adventures: IRAdventures

func _ready() -> void:
	preferences.read()
	if DisplayServer.get_name()!="headless": preferences.apply_audio()
	gpu_motion=IRGpuMotion.new(self)
	add_child(gpu_motion)
	get_viewport().use_occlusion_culling=true
	process_mode = Node.PROCESS_MODE_ALWAYS
	test_mode = OS.get_cmdline_user_args().has("--race-test")
	stage = Node3D.new()
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stage)
	_setup_lighting()
	track = IRTrack.new()
	stage.add_child(track)
	adventures=IRAdventures.new(self)
	stage.add_child(adventures)
	stage.add_child(load("res://scripts/soundscape.gd").new(self))
	preview_camera = Camera3D.new()
	preview_camera.far = 2200
	preview_camera.fov = 56
	stage.add_child(preview_camera)
	preview_camera.current = true
	sound = AudioStreamPlayer.new()
	sound.volume_db = -18
	add_child(sound)
	_read_record()
	_build_ui()
	_create_field(1, false)
	_show_menu()
	get_viewport().size_changed.connect(_layout_views)
	Input.joy_connection_changed.connect(_joy_changed)
	# A --script harness owns its launch sequence. Avoid starting a second tour
	# when that harness passes the same user flag to inspect a selected tour.
	var script_harness: bool=OS.get_cmdline_args().has("--script") or OS.get_cmdline_args().has("-s")
	if not script_harness:
		if DisplayServer.get_name()!="headless": call_deferred("_prepare_and_launch")
		else: _launch_requested_mode()

func _prepare_and_launch() -> void:
	await prepare_graphics()
	_launch_requested_mode()

func prepare_graphics() -> void:
	if graphics_prepared or DisplayServer.get_name()=="headless":
		return
	var preparation: RefCounted=load("res://scripts/graphics_warmup.gd").new()
	await preparation.run(self)
	graphics_prepared=true

func _launch_requested_mode() -> void:
	if test_mode:
		_start_race(4, true)
	elif OS.get_cmdline_user_args().has("--demo-four"):
		_start_race(4, true)
	elif OS.get_cmdline_user_args().has("--island-tour") or OS.get_cmdline_user_args().has("--tea-tour"):
		add_child(load("res://scripts/island_tour.gd").new(self))

func _setup_lighting() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	var settings: Environment = Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ShaderMaterial=IRArt.shader("storybook_sky")
	sky_material.set_shader_parameter("panorama",load("res://assets/textures/storybook_sky_panorama_v2.png"))
	sky.sky_material=sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b4b8d2")
	settings.ambient_light_energy = .55
	settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	settings.tonemap_exposure = .78
	settings.adjustment_enabled = true
	settings.adjustment_saturation = 1.02
	settings.adjustment_contrast=1.06
	settings.fog_enabled = true
	settings.fog_light_color = Color("bfc0d1")
	settings.fog_density = .0013
	settings.fog_sky_affect = 0.15
	settings.ssao_radius = 1.4
	settings.ssao_intensity = 1.2
	settings.ssil_intensity=.55
	settings.ssil_radius=3.0
	world_environment = settings
	environment.environment = settings
	stage.add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-27,-45,0)
	sun.light_color = Color("ffdcac")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250
	stage.add_child(sun)
	showroom_fill=DirectionalLight3D.new()
	showroom_fill.name="CharacterPreviewFill"
	showroom_fill.light_color=Color("ffe4c6")
	showroom_fill.light_energy=.32
	showroom_fill.shadow_enabled=false
	stage.add_child(showroom_fill)

func _create_field(players: int, demo: bool) -> void:
	gpu_motion.epoch+=1
	if adventures!=null: adventures.reset()
	for car in vehicles:
		car.queue_free()
	vehicles.clear()
	var pads: Array[int] = Input.get_connected_joypads()
	var keyboard_first: bool = keyboard_picker.button_pressed if keyboard_picker != null else true
	var pad_index: int = 0
	for i in range(6):
		var car: IRVehicle = IRVehicle.new()
		car.track = track
		car.preferences=preferences
		car.slot = i
		car.variant = (vehicle_picker.selected if i==0 else preferences.rides[i]) if i<players else i%2
		car.character=(character_picker.selected if i==0 else preferences.characters[i]) if i<players else i%2
		if demo:
			car.variant = i % 2
			car.character=i%2
		car.human = i < players
		car.demo_control = demo
		if car.human and not demo:
			if i == 0 and keyboard_first:
				car.controller = -1
			else:
				car.controller = pads[pad_index] if pad_index < pads.size() else -2
				pad_index += 1
		stage.add_child(car)
		car.global_transform = track.spawn_transform(i)
		car.last_position = car.global_position
		vehicles.append(car)
	for car in vehicles: car.traffic.peers.assign(vehicles)

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.theme=MenuArt.make_theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	panes = Control.new()
	panes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panes)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	center_text = Label.new()
	center_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_text.position = Vector2(-180, -75)
	center_text.size = Vector2(360, 150)
	center_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_text.add_theme_font_size_override("font_size", 72)
	center_text.add_theme_color_override("font_color", Color("fff1cb"))
	center_text.add_theme_font_override("font",MenuArt.DISPLAY)
	center_text.add_theme_color_override("font_shadow_color", MenuArt.INK)
	center_text.add_theme_constant_override("shadow_offset_y", 4)
	ui.add_child(center_text)
	_make_menu()

func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuArt.flat(MenuArt.PAPER,MenuArt.INK,1)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	return style

func _text(parent: Node, text: String, font_size: int, color: Color = Color("24221f")) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, accent: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 62 if accent else 40)
	button.add_theme_font_size_override("font_size", 32 if accent else 18)
	if accent:
		button.add_theme_font_override("font",MenuArt.DISPLAY)
		button.add_theme_stylebox_override("normal",MenuArt.flat(MenuArt.RED))
		button.add_theme_stylebox_override("hover",MenuArt.flat(Color("a63221")))
		button.add_theme_stylebox_override("pressed",MenuArt.flat(MenuArt.INK))
		var focus: StyleBoxFlat=MenuArt.flat(Color.TRANSPARENT,MenuArt.INK,2)
		focus.set_expand_margin_all(4)
		button.add_theme_stylebox_override("focus",focus)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			button.add_theme_color_override(state,MenuArt.PAPER)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _make_menu() -> void:
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ui.add_child(menu)
	var surface: Control=Control.new()
	menu.add_child(surface)
	var backdrop: Control=MenuArt.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(backdrop)
	var box: VBoxContainer = VBoxContainer.new()
	box.position=Vector2(56,58)
	box.size=Vector2(370,0)
	box.add_theme_constant_override("separation", 12)
	surface.add_child(box)
	_text(box,"ISLAND RACING CLUB",15,MenuArt.RED)
	var title: Label=_text(box, "WINDWARD\nCIRCUIT", 90)
	title.add_theme_font_override("font",MenuArt.DISPLAY)
	title.add_theme_constant_override("line_spacing",-22)
	_text(box,"01  /  WINDWARD ISLAND",19)
	var rule: ColorRect=ColorRect.new()
	rule.color=MenuArt.INK
	rule.custom_minimum_size.y=2
	box.add_child(rule)
	var crew: HBoxContainer=HBoxContainer.new()
	crew.add_theme_constant_override("separation",18)
	box.add_child(crew)
	var ride: VBoxContainer=VBoxContainer.new()
	ride.add_theme_constant_override("separation",3)
	ride.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	crew.add_child(ride)
	_text(ride, "YOUR RIDE", 14, MenuArt.MUTED)
	vehicle_picker = OptionButton.new()
	vehicle_picker.add_item("Sail cart")
	vehicle_picker.add_item("Flywheel")
	vehicle_picker.selected=preferences.rides[0]
	vehicle_picker.custom_minimum_size.y = 46
	vehicle_picker.add_theme_font_size_override("font_size",26)
	ride.add_child(vehicle_picker)
	var character_box: VBoxContainer=VBoxContainer.new()
	character_box.add_theme_constant_override("separation",3)
	character_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	crew.add_child(character_box)
	_text(character_box,"CHARACTER",14,MenuArt.MUTED)
	character_picker=OptionButton.new()
	for name in IRDriverArt.CHARACTER_NAMES:
		character_picker.add_item(name)
	character_picker.selected=preferences.characters[0]
	character_picker.custom_minimum_size.y=46
	character_picker.add_theme_font_size_override("font_size",26)
	character_box.add_child(character_picker)
	character_picker.item_selected.connect(_preview_selection)
	vehicle_note=_text(box,"Light chassis. Quick on the turn.",16,MenuArt.MUTED)
	vehicle_picker.item_selected.connect(_preview_selection)
	var setup: HBoxContainer=HBoxContainer.new()
	setup.add_theme_constant_override("separation",18)
	box.add_child(setup)
	var drivers: VBoxContainer=VBoxContainer.new()
	drivers.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	setup.add_child(drivers)
	_text(drivers,"LOCAL DRIVERS",14,MenuArt.MUTED)
	player_picker = OptionButton.new()
	for n in range(1, 5):
		player_picker.add_item("%d driver%s" % [n, "" if n == 1 else "s"])
	player_picker.custom_minimum_size.y=42
	drivers.add_child(player_picker)
	player_picker.item_selected.connect(func(_index: int): status.text="")
	var details: VBoxContainer=VBoxContainer.new()
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	setup.add_child(details)
	_text(details,"DETAIL",14,MenuArt.MUTED)
	quality_picker = OptionButton.new()
	quality_picker.add_item("High")
	quality_picker.add_item("Balanced")
	quality_picker.add_item("Performance")
	quality_picker.selected = 2 if OS.get_cmdline_user_args().has("--performance") else preferences.quality
	quality_picker.custom_minimum_size.y = 42
	details.add_child(quality_picker)
	quality_picker.item_selected.connect(_quality_selected)
	keyboard_picker = CheckBox.new()
	keyboard_picker.text = "PLAYER 1 USES KEYBOARD"
	keyboard_picker.button_pressed = true
	box.add_child(keyboard_picker)
	keyboard_picker.toggled.connect(func(_enabled: bool): status.text="")
	_button(box, "START RACE", _request_start, true)
	var actions: HBoxContainer=HBoxContainer.new()
	actions.add_theme_constant_override("separation",20)
	box.add_child(actions)
	var demo: Button=_button(actions,"WATCH A RACE",func(): _start_race(4,true))
	demo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(actions, "EXIT", func(): get_tree().quit())
	_button(box,"SETTINGS / LOCAL CREW",_open_settings)
	status = _text(box, "", 15, MenuArt.RED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 370
	record_label = _text(box, "BEST  /  " + (IRHUD.format_time(record) if is_finite(record) else "—"), 16, MenuArt.MUTED)
	var footer: Label=_text(surface,"WASD / RT   Drive    SPACE / X   Brake    SHIFT / B   Boost    R / Y   Recover    ESC   Pause    M   Sound",16,MenuArt.PAPER)
	controls_hint=footer
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left=56
	footer.offset_top=-38
	footer.offset_right=880
	footer.offset_bottom=-10
	_update_controls_hint()
	var course: Label=_text(surface,"6 RACERS    /    3 LAPS",18,MenuArt.PAPER)
	course.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	course.offset_left=-260
	course.offset_top=-39
	course.offset_right=-40
	course.offset_bottom=-10

func _request_start() -> void:
	var players: int = player_picker.selected + 1
	var required_pads: int = players - (1 if keyboard_picker.button_pressed else 0)
	if Input.get_connected_joypads().size() < required_pads:
		status.text = "Connect %d gamepad%s or choose WATCH A RACE." % [required_pads,"" if required_pads==1 else "s"]
		return
	_start_race(players, false)
	_save_preferences()

func _save_preferences() -> void:
	preferences.quality=quality_picker.selected
	preferences.rides[0]=vehicle_picker.selected
	preferences.characters[0]=character_picker.selected
	_update_controls_hint()
	if not test_mode and not OS.get_cmdline_args().has("--script"): preferences.save()

func _quality_selected(_index: int) -> void:
	_apply_quality()
	_save_preferences()

func _open_settings() -> void:
	if phase!=Phase.MENU:
		paused=true
		get_tree().paused=true
	for child in overlay.get_children(): child.queue_free()
	overlay.show()
	var shade: ColorRect=ColorRect.new()
	shade.color=Color(.04,.03,.02,.58)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(IRSettingsPanel.new(self))

func _update_controls_hint() -> void:
	if not is_instance_valid(controls_hint): return
	var keys: Dictionary=preferences.bindings
	controls_hint.text="%s/%s/%s/%s  Drive    %s  Brake    %s  Boost    %s  Recover    %s  Pause    %s  Sound"%[OS.get_keycode_string(int(keys.throttle)),OS.get_keycode_string(int(keys.left)),OS.get_keycode_string(int(keys.reverse)),OS.get_keycode_string(int(keys.right)),OS.get_keycode_string(int(keys.brake)),OS.get_keycode_string(int(keys.boost)),OS.get_keycode_string(int(keys.recover)),OS.get_keycode_string(int(keys.pause)),OS.get_keycode_string(int(keys.mute))]

func _show_menu() -> void:
	get_viewport().audio_listener_enable_3d=true
	showroom_fill.visible=true
	get_viewport().disable_3d=false
	get_tree().paused = false
	paused = false
	phase = Phase.MENU
	if not vehicles.is_empty() and (vehicles[0].character!=character_picker.selected or vehicles[0].variant!=vehicle_picker.selected):
		_create_field(1,false)
	menu.visible = true
	panes.visible = false
	overlay.visible = false
	center_text.visible = false
	preview_camera.current = true
	for car in vehicles:
		car.drive_enabled = false
	get_viewport().gui_release_focus()
	_arrange_showroom()
	_apply_quality()
	preview_camera.fov=48
	preview_camera.near=.1
	model_preview=true

func _preview_selection(_index: int) -> void:
	if phase==Phase.MENU:
		vehicle_note.text="Light chassis. Quick on the turn." if vehicle_picker.selected==0 else "Heavy chassis. Holds its line."
		_create_field(1,false)
		_arrange_showroom()
		_apply_quality()

func _arrange_showroom() -> void:
	if vehicles.is_empty():
		return
	for car in vehicles:
		car.visible=car==vehicles[0]
		car.process_mode=Node.PROCESS_MODE_DISABLED
		car.visual.process_mode=Node.PROCESS_MODE_ALWAYS
	var car: IRVehicle=vehicles[0]
	var hero: int=26
	var direction: Vector3=track.tangents[hero]
	showroom_outward=((track.centers[hero]-Vector3(43,0,25))*Vector3(1,0,1)).normalized()
	var facing: Vector3=showroom_outward.rotated(Vector3.UP,.55)
	showroom_fill.look_at_from_position(track.centers[hero]+showroom_outward*4+Vector3.UP*3,track.centers[hero]+Vector3.UP*1.8)
	car.transform=Transform3D(Basis(Vector3.UP,atan2(-facing.x,-facing.z)),track.centers[hero])
	var normal: Vector3=track.right_at(hero).cross(direction).normalized()
	var local_normal: Vector3=car.basis.inverse()*normal
	car.visual.rotation.x=atan2(local_normal.z,local_normal.y)
	car.visual.rotation.z=atan2(-local_normal.x,local_normal.y)

func _apply_quality() -> void:
	if quality_picker==null:
		return
	var index: int=quality_picker.selected
	var forward: bool=RenderingServer.get_current_rendering_method()=="forward_plus"
	RenderingServer.directional_shadow_atlas_set_size(2048 if index<2 else 1024,true)
	if forward:
		RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_HIGH,RenderingServer.SHADOW_QUALITY_SOFT_LOW,RenderingServer.SHADOW_QUALITY_HARD][index])
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_HIGH,true,.5,4,20,90)
	world_environment.ssao_enabled=index==0 and forward
	world_environment.ssil_enabled=index==0 and forward
	sun.directional_shadow_max_distance=[160.0,100.0,65.0][index]
	sun.shadow_enabled=index<2
	sun.directional_shadow_mode=[DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,DirectionalLight3D.SHADOW_ORTHOGONAL][index]
	sun.light_angular_distance=.8 if index==0 and forward else 0.0
	get_viewport().msaa_3d=Viewport.MSAA_4X if index==0 else (Viewport.MSAA_2X if index==1 else Viewport.MSAA_DISABLED)
	for camera in cameras: camera.get_viewport().scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
	_layout_views()
	for camera in cameras:
		camera.get_viewport().msaa_3d=Viewport.MSAA_4X if index==0 else Viewport.MSAA_DISABLED
		camera.get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED if index==0 else Viewport.SCREEN_SPACE_AA_FXAA
		if index>0 and forward and camera.get_viewport().scaling_3d_scale<1.0:
			camera.get_viewport().scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR
	for car in vehicles:
		(car.visual as IRVehicleArt).driver.set_detail(index)
		if car.ground_shadow!=null: car.ground_shadow.visible=index==2
	for world in get_tree().get_nodes_in_group("fairytale_world"):
		world.apply_quality(index)
	if adventures!=null: adventures.apply_quality(index)

func _start_race(players: int, demo: bool) -> void:
	showroom_fill.visible=false
	# clear_current(false) below leaves the UI viewport without a 3D camera.
	# Keeping the viewport enabled also permits orderly destruction of shared worlds.
	model_preview=false
	get_tree().paused = false
	paused = false
	phase = Phase.COUNTDOWN
	race_time = 0
	countdown = 3.0
	first_finish_at = -1
	human_count = players
	_create_field(players, demo)
	menu.visible = false
	overlay.visible = false
	panes.visible = true
	center_text.visible = true
	preview_camera.clear_current(false)
	get_viewport().audio_listener_enable_3d=false
	for child in panes.get_children():
		child.queue_free()
	cameras.clear()
	camera_targets.clear()
	huddles.clear()
	for i in range(players):
		var container: SubViewportContainer = SubViewportContainer.new()
		container.name = "PlayerView%d" % i
		container.stretch = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panes.add_child(container)
		var viewport: SubViewport = SubViewport.new()
		viewport.world_3d = get_viewport().world_3d
		viewport.audio_listener_enable_3d=i==0
		viewport.use_occlusion_culling=true
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		viewport.msaa_3d = Viewport.MSAA_2X
		viewport.scaling_3d_scale = 1.0 if quality_picker.selected == 0 else (.75 if players > 1 else 1.0)
		if quality_picker.selected == 2:
			viewport.scaling_3d_scale = .50
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		container.add_child(viewport)
		var camera: IRChaseCamera = IRChaseCamera.new()
		camera.target=vehicles[i]
		camera.fov = 58
		camera.far = 900
		viewport.add_child(camera)
		camera.current = true
		camera.global_position = vehicles[i].global_position + vehicles[i].global_basis.z * 9.0 + Vector3.UP * 5.0
		camera.look_at(vehicles[i].global_position + Vector3.UP, Vector3.UP)
		cameras.append(camera)
		camera_targets.append(vehicles[i])
		var hud: IRHUD = IRHUD.new()
		hud.vehicle = vehicles[i]
		hud.race = self
		hud.compact = players > 1
		container.add_child(hud)
		hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		huddles.append(hud)
	_layout_views()
	_apply_quality()
	for car in vehicles:
		if car.dust != null:
			car.dust.amount = 24 if quality_picker.selected == 2 else 48

func _layout_views() -> void:
	if panes == null or not panes.visible:
		return
	var dimensions: Vector2 = ui.size
	var columns: int = 1 if human_count == 1 else 2
	var rows: int = 2 if human_count > 2 else 1
	var panel_size: Vector2 = dimensions / Vector2(columns, rows)
	for i in range(cameras.size()):
		var container: SubViewportContainer = cameras[i].get_parent().get_parent()
		container.position = Vector2(i % columns, i / columns) * panel_size
		container.size = panel_size - Vector2.ONE * 2.0
		var base_scale: float=[1.0,.75,.50][quality_picker.selected]
		var display_scale: Vector2=get_viewport().get_screen_transform().get_scale()
		var pixel_scale: float=minf(absf(display_scale.x),absf(display_scale.y)) if DisplayServer.get_name()!="headless" else 1.0
		(cameras[i].get_viewport() as SubViewport).scaling_3d_scale=clampf(base_scale*pixel_scale,.25,2.0)

func _process(dt: float) -> void:
	if phase == Phase.MENU:
		preview_clock+=dt
		if model_preview and not vehicles.is_empty():
			var target: Vector3=vehicles[0].position+Vector3.UP*1.45
			var outward: Vector3=showroom_outward.rotated(Vector3.UP,sin(preview_clock*.16)*.15)
			preview_camera.position=vehicles[0].position+outward*5.8+Vector3.UP*2.3
			preview_camera.look_at(target)
			preview_camera.look_at(target-preview_camera.basis.x*1.05)
		if not status.text.begins_with("Connect"):
			var pads: int=Input.get_connected_joypads().size()
			status.text="KEYBOARD READY" if pads==0 and keyboard_picker.button_pressed else "%d GAMEPAD%s CONNECTED" % [pads,"" if pads==1 else "S"]
	if paused:
		return
	for i in range(cameras.size()):
		var car: IRVehicle = camera_targets[i]
		if not is_instance_valid(car):
			continue
		var camera: Camera3D = cameras[i]
		if camera is IRChaseCamera:
			camera.motion_effects=preferences.camera_motion
			camera.update_follow(dt)
	if phase == Phase.COUNTDOWN:
		center_text.text = str(ceili(countdown))
	elif phase == Phase.RACING:
		center_text.visible = race_time < 0.7
		center_text.text = "GO"
		if first_finish_at>=0 and race_time-first_finish_at<3:
			center_text.visible=true
			center_text.text="FINISH!"

func _physics_process(dt: float) -> void:
	if paused or phase == Phase.MENU or phase == Phase.RESULTS:
		return
	if phase == Phase.COUNTDOWN:
		var before: int = ceili(countdown)
		countdown -= dt
		if ceili(countdown) != before:
			_tone(530.0 if countdown > 0 else 920.0)
		if countdown <= 0:
			phase = Phase.RACING
			for car in vehicles:
				car.drive_enabled = true
		return
	race_time += dt
	adventures.tick(dt)
	if test_mode and floori(race_time / 10.0) != floori((race_time - dt) / 10.0):
		var leader: IRVehicle = vehicles[0]
		print("RACE_TEST t=%.0f gate=%d index=%d speed=%.2f floor=%s pos=%s controls=%s" % [race_time, leader.progress.next_gate, leader.nearest, leader.speed, leader.is_on_floor(), leader.global_position, leader.read_controls()])
		for runner in vehicles:
			if runner.slot%3==1 and not runner.progress.finished:
				print("RACE_TEST shortcut_car=%d lap=%d gate=%d index=%d speed=%.2f"%[runner.slot,runner.progress.completed_laps,runner.progress.next_gate,runner.nearest,runner.speed])
	for car in vehicles:
		if not car.progress.finished and track.crossed_gate(car.last_position, car.global_position, car.progress.next_gate):
			var gate: int = car.progress.next_gate
			car.progress.cross_gate(gate, true, race_time)
			if gate == 0:
				if test_mode:
					print("RACE_TEST car=%d lap=%d time=%.2f" % [car.slot, car.progress.completed_laps, race_time])
				if car.human:
					_tone(780)
				if car.progress.finished and car.human and first_finish_at < 0:
					first_finish_at = race_time
	var all_finished: bool = true
	for car in vehicles:
		if (car.human or test_mode) and not car.progress.finished:
			all_finished = false
	if (all_finished and (test_mode or first_finish_at<0 or race_time-first_finish_at>=3)) or (not test_mode and first_finish_at > 0 and race_time - first_finish_at > 30):
		_finish_race()
	if test_mode and race_time > 240:
		push_error("RACE_TEST timed out before every AI completed three legal laps")
		for car in vehicles:
			print("car %d next_gate %d nearest %d pos %s" % [car.slot, car.progress.next_gate, car.nearest, car.global_position])
		get_tree().quit(1)

func place_of(car: IRVehicle) -> int:
	var place: int = 1
	var score: float = car.progress.ranking_score(float(car.nearest) / IRTrack.SAMPLES)
	for other in vehicles:
		if other != car and other.progress.ranking_score(float(other.nearest) / IRTrack.SAMPLES) > score:
			place += 1
	return place

func _finish_race() -> void:
	phase = Phase.RESULTS
	for car in vehicles:
		car.drive_enabled = false
	if test_mode:
		print("RACE_TEST PASS: six vehicles, three ordered laps, four independent viewports")
		get_tree().quit(0)
		return
	var best: float = INF
	for car in vehicles:
		if car.human and not car.demo_control and car.progress.finished:
			best = minf(best, car.progress.finish_time)
	if best < record:
		record = best
		_save_record()
		if record_label != null:
			record_label.text = "BEST  /  " + IRHUD.format_time(record)
	var lines: String = ""
	var sorted: Array[IRVehicle] = vehicles.duplicate()
	sorted.sort_custom(func(a: IRVehicle, b: IRVehicle): return place_of(a) < place_of(b))
	for car in sorted:
		var actor: String=IRDriverArt.CHARACTER_NAMES[car.character]
		lines += "%d.   %s / %s   •   %s\n" % [place_of(car), "Player %d" % (car.slot + 1) if car.human else "AI %d" % (car.slot + 1),actor, IRHUD.format_time(car.progress.finish_time) if car.progress.finished else "DNF"]
		if is_finite(car.progress.best_lap): lines+="       Best lap  %s\n"%IRHUD.format_time(car.progress.best_lap)
	_dialog("RACE COMPLETE", lines, false)

func _dialog(title: String, body: String, is_pause: bool) -> void:
	for child in overlay.get_children():
		child.queue_free()
	overlay.visible = true
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(44, 38)
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_text(box, title, 32)
	_text(box, body, 18)
	if is_pause:
		_button(box, "CONTINUE", _resume, true)
		_button(box,"DRIVING SETTINGS",_open_settings)
	_button(box, "RESTART RACE", func(): _start_race(human_count, vehicles[0].demo_control))
	_button(box, "MAIN MENU", _show_menu)
	_button(box, "QUIT", func(): get_tree().quit())

func _resume() -> void:
	paused = false
	get_tree().paused = false
	overlay.visible = false

func _pause(message: String = "The race clock is stopped.") -> void:
	paused = true
	get_tree().paused = true
	_dialog("PAUSED", message, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==int(preferences.bindings.mute):
		AudioServer.set_bus_mute(0,not AudioServer.is_bus_mute(0))
	var pause_pressed: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == int(preferences.bindings.pause)
	pause_pressed = pause_pressed or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	if pause_pressed and phase != Phase.MENU and phase != Phase.RESULTS:
		if paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == int(preferences.bindings.recover):
		for car in vehicles:
			if car.human and car.controller == -1 and phase == Phase.RACING and not paused:
				car.respawn()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		for car in vehicles:
			if car.human and car.controller == event.device and phase == Phase.RACING and not paused:
				car.respawn()

func _joy_changed(device: int, connected: bool) -> void:
	if connected:
		status.text = "Controller connected."
		return
	if phase == Phase.RACING or phase == Phase.COUNTDOWN:
		for car in vehicles:
			if car.human and not car.demo_control and car.controller == device:
				_pause("Controller disconnected. Reconnect it or return\nto the menu to assign devices again.")

func _tone(frequency: float) -> void:
	if test_mode:
		return
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var frames: int = 4410
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var envelope: float = minf(float(i) / 180.0, 1.0) * pow(1.0 - float(i) / frames, 2.0)
		var sample: int = int(sin(TAU * frequency * float(i) / stream.mix_rate) * envelope * 12000)
		data.encode_s16(i * 2, sample)
	stream.data = data
	sound.stream = stream
	sound.play()

func _read_record() -> void:
	if test_mode or not FileAccess.file_exists("user://m1_records.json"):
		return
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://m1_records.json"))
	if content is Dictionary and content.get("version", 0) == 1:
		var value: Variant = content.get("best_race", -1)
		if (value is float or value is int) and float(value) > 0:
			record = float(value)

func _save_record() -> void:
	if not is_finite(record) or test_mode:
		return
	var file: FileAccess = FileAccess.open("user://m1_records.tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": 1, "best_race": record}))
	file.close()
	DirAccess.rename_absolute("user://m1_records.tmp", "user://m1_records.json")
