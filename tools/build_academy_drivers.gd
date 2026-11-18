extends SceneTree
const Builder=preload("res://tools/academy_driver_builder.gd")

func _initialize() -> void:
	var builder: RefCounted=Builder.new()
	for identity in range(2):
		for detail in range(3):
			var mesh: ArrayMesh=builder.build(identity,detail)
			var suffix: String=["","_balanced","_performance"][detail]
			var file: String="res://assets/characters/%s_driver%s.res" % ["zabol" if identity==0 else "swinka",suffix]
			var result: Error=ResourceSaver.save(mesh,file,ResourceSaver.FLAG_COMPRESS)
			if result!=OK:
				push_error("Could not save "+file)
				quit(1)
				return
			var vertices: int=0
			for surface in range(mesh.get_surface_count()):
				vertices+=mesh.surface_get_array_len(surface)
			print("ACADEMY_MESH %s: %d surfaces, %d vertices, %d surface LODs, bounds %s" % [file,mesh.get_surface_count(),vertices,mesh.get_meta("lod_count"),mesh.get_aabb()])
	quit()
