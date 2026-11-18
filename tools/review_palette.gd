extends SceneTree
## Native A/B check of packed materials, including the existing skinning buffers.

func _initialize() -> void:
	call_deferred("run")

func pack(node: Node) -> Vector2i:
	var counts: Vector2i=Vector2i.ZERO
	if node is MeshInstance3D and node.mesh!=null:
		var source: Mesh=node.mesh
		if node.material_override!=null:
			var mesh: ArrayMesh=ArrayMesh.new()
			for surface in range(source.get_surface_count()):
				var st: SurfaceTool=SurfaceTool.new()
				st.create_from(source,surface)
				st.set_material(node.material_override)
				st.commit(mesh)
			source=mesh
		counts.x+=source.get_surface_count()
		node.mesh=IRPaletteMesh.compact(source,false,true)
		node.material_override=null
		counts.y+=node.mesh.get_surface_count()
	for child in node.get_children():
		counts+=pack(child)
	return counts

func run() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	race.set_process(false)
	race.set_physics_process(false)
	race.stage.process_mode=Node.PROCESS_MODE_DISABLED
	race.menu.hide()
	var first: IRVehicle=race.vehicles[0]
	var second: IRVehicle=IRVehicle.new()
	second.track=race.track
	second.character=first.character
	second.variant=first.variant
	race.stage.add_child(second)
	var pose: Transform3D=first.transform
	var outward: Vector3=race.showroom_outward
	var side: Vector3=Vector3.UP.cross(outward).normalized()
	first.position=pose.origin-side*1.5
	second.transform=pose
	second.position=pose.origin+side*1.5
	(second.visual as IRVehicleArt).driver.set_detail((first.visual as IRVehicleArt).driver.detail)
	var counts: Vector2i=pack(second.visual)
	race.preview_camera.position=pose.origin+outward*6.7+Vector3.UP*3.0
	race.preview_camera.fov=46
	race.preview_camera.look_at(pose.origin+Vector3.UP*1.7)
	for i in range(2):
		var label: Label=Label.new()
		label.text="ORIGINAL" if i==0 else "PACKED MATERIALS"
		label.position=Vector2(100+i*720,800)
		label.add_theme_font_override("font",IRRace.MenuArt.DISPLAY)
		label.add_theme_font_size_override("font_size",25)
		race.ui.add_child(label)
	for i in range(10):
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/art-review/palette_comparison.png")
	print("PALETTE_REVIEW surfaces ",counts.x," -> ",counts.y)
	race.queue_free()
	await process_frame
	quit()
