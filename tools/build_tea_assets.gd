extends SceneTree
## Offline authoring entry point; runtime loads these ordinary compressed meshes.
func _initialize() -> void:
	var author: RefCounted=load("res://tools/tea_asset_builder.gd").new()
	author.build()
	quit()
