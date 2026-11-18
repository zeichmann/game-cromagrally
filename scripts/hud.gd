class_name IRHUD
extends Control
## Resolution-independent per-viewport HUD and a procedural course map.

var vehicle: IRVehicle
var race: Node
var compact: bool = false
var info: Label
var speed_label: Label
var place_label: Label
var gate_hint: Label
var boost_label: Label
var warning: Label
var lap_label: Label
var map_rect: Rect2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	info = _label(20, Color("f7ebd5"))
	place_label = _label(38, Color("f7ebd5"))
	speed_label = _label(44, Color("f7ebd5"))
	gate_hint = _label(15, Color("f6d7a0"))
	boost_label=_label(16,Color("f4d79b"))
	warning=_label(24,Color("ffe0b0"))
	lap_label=_label(15,Color("f7ebd5"))
	for label in [info, place_label, speed_label, gate_hint,boost_label,warning,lap_label]:
		label.add_theme_color_override("font_shadow_color", Color(0.05, 0.1, 0.12, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)

func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _process(_dt: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle) or size.x < 10:
		return
	var margin: float = 22.0 if not compact else 12.0
	info.position = Vector2(margin, margin)
	info.text = "%s%d  /  %s\nLAP %d / 3   •   %s" % ["AI " if vehicle.demo_control else "P", vehicle.slot + 1, IRDriverArt.CHARACTER_NAMES[vehicle.character].to_upper(), mini(vehicle.progress.completed_laps + 1, 3), format_time(race.race_time)]
	info.add_theme_font_size_override("font_size", 18 if compact else 21)
	place_label.position = Vector2(margin, margin + (48.0 if compact else 62.0))
	place_label.text = "%d / 6" % race.place_of(vehicle)
	place_label.add_theme_font_size_override("font_size", 31 if compact else 42)
	speed_label.text = "%03d" % int(absf(vehicle.speed) * 3.6)
	speed_label.position = Vector2(margin, size.y - (72.0 if compact else 100.0))
	speed_label.add_theme_font_size_override("font_size", 38 if compact else 58)
	gate_hint.position = Vector2(margin + (82 if compact else 120), size.y - (40 if compact else 57))
	gate_hint.text = "KM/H" if not vehicle.progress.finished else "FINISHED"
	var map_size: float = minf(175.0 if compact else 230.0, size.x * 0.25)
	map_rect = Rect2(size.x - map_size - margin, margin, map_size, map_size * 0.85)
	boost_label.position=Vector2(map_rect.position.x,map_rect.end.y+18)
	var command: String="SHIFT" if vehicle.controller<0 else "B"
	if vehicle.controller<0 and vehicle.preferences!=null: command=OS.get_keycode_string(int(vehicle.preferences.bindings.boost))
	boost_label.text="WIND %d   •   BOOST %d\n%s  Boost%s"%[vehicle.seeds_collected,vehicle.boost_charge/3,command,"   •   GROTTO FOUND" if vehicle.secret_found else ""]
	boost_label.add_theme_font_size_override("font_size",12 if compact else 16)
	lap_label.position=Vector2(margin,margin+(92 if compact else 118))
	lap_label.add_theme_font_size_override("font_size",12 if compact else 15)
	var last: String=format_time(vehicle.progress.last_lap_time) if vehicle.progress.completed_laps>0 else "—"
	var best: String=format_time(vehicle.progress.best_lap) if is_finite(vehicle.progress.best_lap) else "—"
	var gap: String=""
	var own_place: int=race.place_of(vehicle)
	for other in race.vehicles:
		if race.place_of(other)==own_place-1 and other.progress.gate_times.has(vehicle.progress.last_gate_key):
			var split: float=float(vehicle.progress.gate_times[vehicle.progress.last_gate_key])-float(other.progress.gate_times[vehicle.progress.last_gate_key])
			gap="   GAP +%.2fs"%maxf(0,split)
	lap_label.text="LAST %s   BEST %s%s"%[last,best,gap]
	warning.position=Vector2(size.x*.25,size.y*.73)
	warning.size.x=size.x*.5
	warning.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size",17 if compact else 24)
	if vehicle.recovery_pending: warning.text="RECOVERY SPACE BLOCKED — WAIT"
	elif vehicle.off_course_time>.55: warning.text="RETURN TO TRACK   %.1fs"%maxf(0,2-vehicle.off_course_time)
	elif vehicle.wrong_way_time>.65: warning.text="WRONG WAY"
	elif vehicle.impact_timer>.1: warning.text="CONTACT"
	else: warning.text=""
	queue_redraw()

static func format_time(seconds: float) -> String:
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]

func _map_point(p: Vector3) -> Vector2:
	return map_rect.position + map_rect.size * 0.5 + Vector2(p.x, p.z) * map_rect.size.x / 280.0

func _draw() -> void:
	if vehicle == null or not is_instance_valid(vehicle) or map_rect.size.x == 0:
		return
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(.10,.08,.065,.80)
	panel.set_corner_radius_all(12)
	draw_style_box(panel,Rect2(6,6,minf(390,size.x*.65),118 if compact else 152))
	draw_style_box(panel,Rect2(6,size.y-(76 if compact else 106),190 if compact else 260,68 if compact else 98))
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(.12,.105,.085,.78)
	back.corner_radius_top_left = 16
	back.corner_radius_bottom_right = 16
	draw_style_box(back, map_rect.grow(10))
	var line: PackedVector2Array = PackedVector2Array()
	for p in vehicle.track.centers:
		line.append(_map_point(p))
	line.append(line[0])
	draw_polyline(line, Color("d7c5a5"), 3.0, true)
	var shortcut_line: PackedVector2Array=PackedVector2Array()
	for p in vehicle.track.shortcut: shortcut_line.append(_map_point(p))
	draw_polyline(shortcut_line,Color("b0ba88"),1.5,true)
	for car in race.vehicles:
		draw_circle(_map_point(car.global_position), 3.0, IRVehicle.COLORS[car.slot])
	draw_circle(_map_point(vehicle.global_position), 5.3, Color("fdf4dd"))
	draw_circle(_map_point(vehicle.global_position), 3.0, IRVehicle.COLORS[vehicle.slot])
