class_name IRSettingsPanel
extends PanelContainer
var race: IRRace
var capture_action: String=""
var key_buttons: Dictionary={}
var from_race: bool=false

func _init(game: IRRace) -> void:
	race=game
	from_race=race.phase!=IRRace.Phase.MENU
	process_mode=Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	position=Vector2(44,30)
	custom_minimum_size=Vector2(570,0)
	add_theme_stylebox_override("panel",race._panel_style())
	var outer: VBoxContainer=VBoxContainer.new()
	outer.add_theme_constant_override("separation",14)
	add_child(outer)
	var scroll: ScrollContainer=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(520,minf(610,race.ui.size.y-190))
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box: VBoxContainer=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",10)
	scroll.add_child(box)
	race._text(box,"DRIVING SETTINGS",30)
	var profile: OptionButton=OptionButton.new()
	for label in ["High","Balanced","Performance"]: profile.add_item(label)
	profile.selected=race.quality_picker.selected
	profile.item_selected.connect(func(value: int): race.quality_picker.selected=value; race._quality_selected(value))
	box.add_child(profile)
	var opponents: OptionButton=OptionButton.new()
	for label in ["Opponents: Easy","Opponents: Normal","Opponents: Hard"]: opponents.add_item(label)
	opponents.selected=race.preferences.difficulty
	opponents.item_selected.connect(func(value: int): race.preferences.difficulty=value)
	box.add_child(opponents)
	slider(box,"Master volume",0,1,.05,race.preferences.volume,func(value: float): race.preferences.volume=value; race.preferences.apply_audio())
	slider(box,"Steering sensitivity",.5,1.6,.1,race.preferences.sensitivity,func(value: float): race.preferences.sensitivity=value)
	var motion: CheckBox=CheckBox.new()
	motion.text="Speed zoom and camera anticipation"
	motion.button_pressed=race.preferences.camera_motion
	motion.toggled.connect(func(value: bool): race.preferences.camera_motion=value)
	box.add_child(motion)
	var keys: GridContainer=GridContainer.new()
	keys.columns=4
	keys.add_theme_constant_override("h_separation",14)
	box.add_child(keys)
	for action in IRRacePreferences.DEFAULT_KEYS:
		race._text(keys,str(action).capitalize(),15)
		var button: Button=Button.new()
		button.custom_minimum_size=Vector2(115,34)
		button.pressed.connect(capture.bind(str(action)))
		keys.add_child(button)
		key_buttons[action]=button
	refresh_keys()
	race._text(box,"Select a key, then press its replacement. Esc cancels.\nArrow keys also work with the default driving bindings.",13)
	var crews: GridContainer=GridContainer.new()
	crews.columns=3
	crews.add_theme_constant_override("h_separation",14)
	box.add_child(crews)
	for i in range(4):
		race._text(crews,"PLAYER %d"%(i+1),14)
		var ride: OptionButton=OptionButton.new()
		for label in ["Sail cart","Flywheel"]: ride.add_item(label)
		ride.selected=race.vehicle_picker.selected if i==0 else race.preferences.rides[i]
		ride.item_selected.connect(select_ride.bind(i))
		crews.add_child(ride)
		var actor: OptionButton=OptionButton.new()
		for label in IRDriverArt.CHARACTER_NAMES: actor.add_item(label)
		actor.selected=race.character_picker.selected if i==0 else race.preferences.characters[i]
		actor.item_selected.connect(select_actor.bind(i))
		crews.add_child(actor)
	race._text(box,"Vehicle and character choices apply to the next race.",13)
	race._button(outer,"SAVE AND BACK",close_panel,true)

func slider(box: VBoxContainer,title: String,low: float,high: float,step: float,value: float,change: Callable) -> void:
	var label: Label=race._text(box,"%s  %.2f"%[title,value],15)
	var control: HSlider=HSlider.new()
	control.min_value=low
	control.max_value=high
	control.step=step
	control.value=value
	control.value_changed.connect(func(next: float): label.text="%s  %.2f"%[title,next]; change.call(next))
	box.add_child(control)

func select_ride(value: int,player: int) -> void:
	race.preferences.rides[player]=value
	if player==0: race.vehicle_picker.selected=value

func select_actor(value: int,player: int) -> void:
	race.preferences.characters[player]=value
	if player==0: race.character_picker.selected=value

func refresh_keys() -> void:
	for action in key_buttons:
		key_buttons[action].text="PRESS KEY…" if action==capture_action else OS.get_keycode_string(int(race.preferences.bindings[action]))

func capture(action: String) -> void:
	capture_action=action
	refresh_keys()

func _input(event: InputEvent) -> void:
	if capture_action!="" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode!=KEY_ESCAPE: race.preferences.rebind(capture_action,event.physical_keycode)
		capture_action=""
		refresh_keys()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==int(race.preferences.bindings.pause):
		close_panel()
		get_viewport().set_input_as_handled()

func close_panel() -> void:
	race._save_preferences()
	if from_race: race._pause()
	else:
		race.overlay.hide()
		race._preview_selection(0)
	queue_free()
