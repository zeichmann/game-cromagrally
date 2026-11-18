extends SceneTree

func _initialize() -> void:
	var builder: RefCounted=load("res://tools/fairy_asset_builder.gd").new()
	builder.build()
	if builder.report.size()!=IRFairytaleWorld.ASSET_NAMES.size():
		push_error("Incomplete fairytale asset build")
		quit(1)
		return
	quit()
