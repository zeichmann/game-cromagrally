extends Node
## A repeatable native-world tour. Escape restores the ordinary game menu.

var race: IRRace
var shots: Array[Dictionary]=[]
var elapsed: float=0
var current: int=-1
var caption: Label
var fade: ColorRect
var previous_quality: int=0
var previous_input: bool=true
const SHOT_SECONDS: float=14.0

func _init(game: IRRace) -> void:
	race=game

func _ready() -> void:
	previous_quality=race.quality_picker.selected
	race.quality_picker.selected=2 if OS.get_cmdline_user_args().has("--performance") else 0
	race._apply_quality()
	race.set_process(false)
	race.set_physics_process(false)
	previous_input=race.is_processing_unhandled_input()
	race.set_process_unhandled_input(false)
	race.ui.hide()
	race.showroom_fill.hide()
	for car in race.vehicles:
		car.hide()
	_build_shots()
	_build_overlay()
	DisplayServer.window_set_title("Windward Circuit — Island Tour")
	_update_camera(0)

func _build_shots() -> void:
	var track: IRTrack=race.track
	var world: IRFairytaleWorld=get_tree().get_first_node_in_group("fairytale_world")
	var tea: Transform3D=world.landmarks.tea_hero
	shots.append({"name":"THE OLD OAK TEAHOUSE","a":tea*Vector3(13,7.5,22),"b":tea*Vector3(11,6.5,20),"target":tea.origin+Vector3.UP*5.6,"fov":57.0})
	var bend: Transform3D=IRTeaBendLayout.pose(track)
	shots.append({"name":"THE TEAHOUSE STREAM","a":bend*Vector3(-4,2.7,-14),"b":bend*Vector3(-7,2.4,-12),"target":bend*Vector3(-15,.8,-3),"fov":55.0})
	if OS.get_cmdline_user_args().has("--tea-tour"):
		shots.append({"name":"THE TEAHOUSE BRIDGE","a":track.centers[14]-track.tangents[14]*7+Vector3.UP*3.4,"b":track.centers[24]-track.tangents[24]*6+Vector3.UP*3.4,"target":track.centers[32]+Vector3.UP*2.5,"fov":58.0})
		shots.append({"name":"TEA UNDER THE OLD OAK","a":bend*Vector3(-5,3.2,16),"b":bend*Vector3(-6,2.8,15),"target":bend*Vector3(-13,.8,8.8),"fov":52.0})
		return
	shots.append({"name":"THE LIVING VILLAGE","a":track.centers[12]-track.tangents[12]*8+Vector3.UP*4.4,"b":track.centers[20]-track.tangents[20]*7+Vector3.UP*4.4,"target":track.centers[33]+Vector3.UP*2.0,"fov":58.0})
	var bakery: Transform3D=world.global_transform*world.landmarks.bakery
	shots.append({"name":"THE STUMP BAKERY","a":bakery*Vector3(14,9,23),"b":bakery*Vector3(11,8,21),"target":bakery.origin+Vector3.UP*4.5,"fov":52.0})
	shots.append({"name":"THE OLD TREE GATE","a":track.centers[49]-track.tangents[49]*8+Vector3.UP*4.4,"b":track.centers[56]-track.tangents[56]*6+Vector3.UP*4.4,"target":track.centers[65]+Vector3.UP*3,"fov":58.0})
	var pose: Transform3D=world.global_transform*world.landmarks.cottage_blue
	var front: Vector3=pose.basis.z.normalized()
	var side: Vector3=pose.basis.x.normalized()
	shots.append({"name":"COTTAGE GARDENS","a":pose.origin+front*16+side*7+Vector3.UP*7,"b":pose.origin+front*15+side*5+Vector3.UP*6.5,"target":pose.origin+Vector3.UP*3.8,"fov":52.0})
	shots.append({"name":"WISTERIA GROVE","a":track.centers[84]+Vector3.UP*5.2,"b":track.centers[91]+Vector3.UP*5.2,"target":track.centers[106]+Vector3.UP*4,"fov":60.0})
	var cave: Transform3D=world.landmarks.crystal_grotto
	shots.append({"name":"THE CRYSTAL SHORTCUT","a":cave*Vector3(0,3,-11),"b":cave*Vector3(.5,2.7,-9),"target":cave.origin+Vector3.UP*2.2,"fov":52.0})
	shots.append({"name":"THE WATERFALL","a":Vector3(-117,17,29),"b":Vector3(-111,19,20),"target":Vector3(-61,11,7),"fov":55.0})
	shots.append({"name":"THE HANGING BRIDGE","a":track.centers[159]-track.tangents[159]*7+Vector3.UP*4.6,"b":track.centers[166]-track.tangents[166]*6+Vector3.UP*4.4,"target":track.centers[180]+Vector3.UP*2.5,"fov":58.0})
	shots.append({"name":"SPRING GARDEN","a":Vector3(-65,39,39),"b":Vector3(-62,38,37),"target":Vector3(-39,27,-4),"fov":55.0})
	shots.append({"name":"CASTLE HILL","a":Vector3(-42,35,13),"b":Vector3(-30,34,17),"target":Vector3(-20,31,-35),"fov":52.0})
	var garden: Vector3=track.centers[289]
	shots.append({"name":"SEASIDE GARDENS","a":garden+track.right_at(289)*45+track.tangents[289]*15+Vector3.UP*14,"b":garden+track.right_at(289)*41+track.tangents[289]*18+Vector3.UP*12,"target":garden+track.right_at(289)*22+Vector3.UP*1.6,"fov":55.0})
	var quay: Vector3=track.centers[344]-track.right_at(344)*22
	var sea_a: Vector3=track.centers[344]-track.right_at(344)*62+track.tangents[344]*15
	var sea_b: Vector3=track.centers[344]-track.right_at(344)*57+track.tangents[344]*12
	sea_a.y=16
	sea_b.y=15
	quay.y=3.0
	shots.append({"name":"THE HARBOUR","a":sea_a,"b":sea_b,"target":quay,"fov":55.0})
	var boathouse: Transform3D=world.global_transform*world.landmarks.boathouse
	shots.append({"name":"THE FISHERMAN’S HOUSE","a":boathouse*Vector3(13,9,22),"b":boathouse*Vector3(10,8,20),"target":boathouse.origin+Vector3.UP*4,"fov":52.0})
	var plaza: Vector3=world.global_transform*world.landmarks.fountain.origin
	shots.append({"name":"VILLAGE SQUARE","a":plaza+Vector3(-9,6,7),"b":plaza+Vector3(-8,5.5,6),"target":plaza+Vector3.UP*1.5,"fov":55.0})

func _build_overlay() -> void:
	var layer: CanvasLayer=CanvasLayer.new()
	add_child(layer)
	var surface: Control=Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(surface)
	caption=Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	caption.position=Vector2(30,-48)
	caption.add_theme_font_override("font",preload("res://assets/fonts/Barlow-Medium.ttf"))
	caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_color",Color("f4eedf"))
	caption.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	caption.add_theme_constant_override("shadow_offset_y",1)
	surface.add_child(caption)
	var hint: Label=Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position=Vector2(-210,-46)
	hint.size=Vector2(180,28)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hint.text="ESC  ·  GAME MENU"
	hint.add_theme_font_override("font",preload("res://assets/fonts/Barlow-Medium.ttf"))
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("f4eedf"))
	hint.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	hint.add_theme_constant_override("shadow_offset_y",1)
	surface.add_child(hint)
	fade=ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color=Color.BLACK
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.add_child(fade)

func _process(dt: float) -> void:
	elapsed+=dt
	_update_camera(elapsed)

func _update_camera(time: float) -> void:
	var index: int=int(time/SHOT_SECONDS)%shots.size()
	var t: float=fmod(time,SHOT_SECONDS)/SHOT_SECONDS
	var shot: Dictionary=shots[index]
	var blend: float=t*t*(3-2*t)
	race.preview_camera.position=(shot.a as Vector3).lerp(shot.b,blend)
	race.preview_camera.fov=shot.fov
	race.preview_camera.look_at(shot.target)
	fade.color.a=maxf(1.0-smoothstep(0,.055,t),smoothstep(.945,1,t))
	if current!=index:
		current=index
		caption.text="%02d  /  %s"%[index+1,shot.name]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M:
		AudioServer.set_bus_mute(0,not AudioServer.is_bus_mute(0))
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		race.ui.show()
		race.set_process(true)
		race.set_physics_process(true)
		race.set_process_unhandled_input(previous_input)
		race.quality_picker.selected=previous_quality
		race._show_menu()
		DisplayServer.window_set_title("Windward Circuit — Art Preview")
		queue_free()
