extends SceneTree
## Extract notices from the exact engine binary used to run the prototype.

func _initialize() -> void:
	var notices: Dictionary = {
		"engine": Engine.get_version_info(),
		"godot_license": Engine.get_license_text(),
		"components": Engine.get_copyright_info(),
		"licenses": Engine.get_license_info(),
	}
	var file: FileAccess = FileAccess.open("res://docs/GODOT_NOTICES.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write engine notices")
		quit(1)
		return
	file.store_string(JSON.stringify(notices, "\t"))
	file.close()
	print("Saved exact engine and third-party notices to docs/GODOT_NOTICES.json")
	quit(0)
