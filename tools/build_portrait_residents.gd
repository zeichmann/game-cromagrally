extends SceneTree
func _initialize() -> void:
	var maker: RefCounted=load("res://tools/fairy_asset_builder.gd").new()
	var builder: RefCounted=load("res://tools/portrait_resident_builder.gd").new()
	for species in range(2):
		var model: Node3D=builder.resident(maker,species)
		if model==null:
			push_error("Failed to author resident geometry")
			quit(1)
			return
		maker.save_asset("resident_"+["rabbit","mouse"][species],model)
	if maker.report.size()!=2:
		quit(1)
		return
	var path: String="res://assets/fairytale/mesh_manifest.json"
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for key in maker.report: manifest[key]=maker.report[key]
	for key in manifest:
		for field in manifest[key]: manifest[key][field]=int(manifest[key][field])
	var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t")+"\n")
	print("PORTRAIT_RESIDENTS PASS: ",JSON.stringify(maker.report))
	quit()
