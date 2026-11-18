extends Control
## Race-entry graphics drawn as editable shapes, with no raster mockup or UI kit.

const PAPER=Color("f4eedf")
const INK=Color("24221f")
const MUTED=Color("756d60")
const RED=Color("bc402a")
const DISPLAY=preload("res://assets/fonts/BarlowCondensed-BlackItalic.ttf")
const BODY=preload("res://assets/fonts/Barlow-Medium.ttf")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	# The sloping edge follows the sail and racing-number shapes in the vehicles.
	var h: float=size.y
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(558,0),Vector2(486,h-52),Vector2(0,h-52)]),PackedColorArray([Color(0,0,0,.15)]))
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(548,0),Vector2(476,h-52),Vector2(0,h-52)]),PackedColorArray([PAPER]))
	draw_polygon(PackedVector2Array([Vector2(524,0),Vector2(536,0),Vector2(464,h-52),Vector2(452,h-52)]),PackedColorArray([RED]))
	# A small flag, rather than ornamental dashboard badges.
	for row in range(2):
		for column in range(8):
			if (column+row)%2==0:
				draw_rect(Rect2(56+column*11,19+row*11,11,11),INK)
	draw_rect(Rect2(0,h-52,size.x,52),INK)
	draw_line(Vector2(56,h-53),Vector2(size.x-40,h-53),PAPER,1)

static func flat(color: Color, border: Color=Color.TRANSPARENT, width: int=0) -> StyleBoxFlat:
	var style: StyleBoxFlat=StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=border
	style.set_border_width_all(width)
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=7
	style.content_margin_bottom=7
	return style

static func make_theme() -> Theme:
	var theme: Theme=Theme.new()
	theme.default_font=BODY
	theme.default_font_size=20
	var base: StyleBoxFlat=flat(Color.TRANSPARENT)
	base.border_color=INK
	base.border_width_bottom=1
	var hover: StyleBoxFlat=base.duplicate()
	hover.bg_color=Color("e5ddcc")
	var focus: StyleBoxFlat=flat(Color.TRANSPARENT,RED,2)
	for type in ["Button","OptionButton","CheckBox"]:
		theme.set_stylebox("normal",type,base)
		theme.set_stylebox("hover",type,hover)
		theme.set_stylebox("pressed",type,hover)
		theme.set_stylebox("focus",type,focus)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			theme.set_color(state,type,INK)
	theme.set_color("font_color","Label",INK)
	theme.set_icon("arrow","OptionButton",preload("res://assets/ui/selector_arrow.svg"))
	theme.set_constant("arrow_margin","OptionButton",9)
	theme.set_constant("modulate_arrow","OptionButton",0)
	theme.set_stylebox("normal","CheckBox",flat(Color.TRANSPARENT))
	theme.set_stylebox("hover","CheckBox",flat(Color.TRANSPARENT))
	theme.set_stylebox("pressed","CheckBox",flat(Color.TRANSPARENT))
	theme.set_icon("checked","CheckBox",preload("res://assets/ui/checkbox_on.svg"))
	theme.set_icon("unchecked","CheckBox",preload("res://assets/ui/checkbox_off.svg"))
	theme.set_constant("h_separation","CheckBox",10)
	theme.set_font_size("font_size","CheckBox",16)
	# Style the real selector popups too; the default dark theme must not leak through.
	theme.set_stylebox("panel","PopupMenu",flat(PAPER,INK,1))
	theme.set_stylebox("hover","PopupMenu",flat(INK))
	theme.set_color("font_color","PopupMenu",INK)
	theme.set_color("font_hover_color","PopupMenu",PAPER)
	theme.set_font_size("font_size","PopupMenu",20)
	theme.set_constant("v_separation","PopupMenu",12)
	return theme
