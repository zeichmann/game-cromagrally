extends SceneTree
## Image evidence for both drivers: lid coverage, gaze and expressions in every profile.
var assertions: int=0
var failures: int=0
var view: SubViewport
var camera: Camera3D
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func capture() -> Image:
	for i in range(5): await RenderingServer.frame_post_draw
	var result: Image=view.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return result
func changed(a: Image,b: Image) -> int:
	var x: PackedByteArray=a.get_data()
	var y: PackedByteArray=b.get_data()
	var count: int=0
	for pixel in range(a.get_width()*a.get_height()):
		var delta: int=0
		for c in range(3): delta=maxi(delta,absi(x[pixel*4+c]-y[pixel*4+c]))
		if delta>6: count+=1
	return count
func eye_pixels(image: Image,identity: int,pupil: bool=false) -> int:
	var count: int=0
	var center: Vector2=Vector2(.226,.972) if identity==0 else Vector2(.192,.948)
	var size: Vector2=Vector2(.103,.123) if identity==0 else Vector2(.090,.108)
	for side in [-1.0,1.0]:
		# The shader's authored rest tilt is part of the eye position. Sample only
		# the aperture, excluding bright specular reflections on the surrounding lid.
		var angle: float=-.035 if identity==0 else .055
		var c: Vector2=(Vector2(center.x*side,center.y)-Vector2(0,.44)).rotated(angle)+Vector2(0,.44)
		var screen: Vector2=camera.unproject_position(Vector3(c.x,c.y,-.30))
		var right: Vector2=Vector2(size.x,0).rotated(angle)
		var up: Vector2=Vector2(0,size.y).rotated(angle)
		var vx: Vector2=camera.unproject_position(Vector3(c.x+right.x,c.y+right.y,-.30))-screen
		var vy: Vector2=camera.unproject_position(Vector3(c.x+up.x,c.y+up.y,-.30))-screen
		var inverse: Transform2D=Transform2D(vx,vy,screen).affine_inverse()
		var bounds: Rect2i=Rect2i(Vector2i(screen-Vector2.ONE*55),Vector2i(110,110)).intersection(Rect2i(0,0,400,400))
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				var q: Vector2=inverse*Vector2(x+.5,y+.5)
				if q.length_squared()>.82 or absf(q.y)>.70: continue
				var p: Color=image.get_pixel(x,y)
				if pupil:
					if maxf(p.r,maxf(p.g,p.b))<.12: count+=1
				elif p.r>.62 and p.g>.58 and p.b>.50 and absf(p.r-p.g)<.095 and p.g-p.b<.15: count+=1
	return count
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	DirAccess.make_dir_recursive_absolute("res://build/academy-review")
	root.disable_3d=true
	view=SubViewport.new()
	view.size=Vector2i(400,400)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.msaa_3d=Viewport.MSAA_4X
	root.add_child(view)
	var environment: WorldEnvironment=WorldEnvironment.new()
	var settings: Environment=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("d5c8b4")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=.55
	environment.environment=settings
	view.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-25,-25,0)
	sun.light_energy=1.1
	view.add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.1
	camera.position=Vector3(0,.83,-2)
	view.add_child(camera)
	camera.look_at(Vector3(0,.83,0))
	for identity in range(2):
		for profile in range(3):
			var driver: IRDriverArt=IRDriverArt.new(Color.WHITE,identity)
			driver.set_detail(profile)
			view.add_child(driver)
			driver.skinned.set_instance_shader_parameter("ir_face_state",Vector4(0,0,0,0))
			var calm: Image=await capture()
			var cornea: ShaderMaterial
			for surface in range(driver.skinned.mesh.get_surface_count()):
				var material: ShaderMaterial=driver.skinned.get_surface_override_material(surface)
				if material.shader.resource_path.ends_with("academy_cornea.gdshader"): cornea=material
			if cornea!=null:
				# A frontal key deliberately puts a highlight inside the visible aperture.
				# The ordinary key can reflect outside it on this orthographic camera.
				sun.rotation_degrees=Vector3(-10,170,0)
				var optical: Image=await capture()
				cornea.set_shader_parameter("cornea_gain",0.0)
				var dry: Image=await capture()
				var optical_pixels: int=changed(optical,dry)
				if profile==0:
					optical.save_png("res://build/academy-review/cornea_%d_enabled.png"%identity)
					dry.save_png("res://build/academy-review/cornea_%d_disabled.png"%identity)
				check(optical_pixels>100,"The separate cornea does not contribute a visible optical reflection")
				print("ORGANIC_CORNEA identity=%d profile=%d reflection_pixels=%d"%[identity,profile,optical_pixels])
				cornea.set_shader_parameter("cornea_gain",.75)
				sun.rotation_degrees=Vector3(-25,-25,0)
			else:
				check(false,"The physical cornea surface was lost")
			driver.skinned.set_instance_shader_parameter("ir_face_state",Vector4(0,1,0,0))
			var closed: Image=await capture()
			var white_open: int=eye_pixels(calm,identity)
			var white_closed: int=eye_pixels(closed,identity)
			var pupil_open: int=eye_pixels(calm,identity,true)
			var pupil_closed: int=eye_pixels(closed,identity,true)
			check(white_open>75 and white_closed<white_open*.12,"Eyelids leave a visible eye uncovered: %d/%d (%d -> %d)"%[identity,profile,white_open,white_closed])
			check(pupil_open>150 and pupil_closed<pupil_open*.10,"A closed eyelid still exposes the pupil")
			driver.skinned.set_instance_shader_parameter("ir_face_state",Vector4(1,0,0,0))
			var joyful: Image=await capture()
			var joy_pixels: int=changed(calm,joyful)
			check(joy_pixels>100,"Smile does not visibly deform the face")
			driver.skinned.set_instance_shader_parameter("ir_face_state",Vector4(0,0,.016,.004))
			var looking: Image=await capture()
			var gaze_pixels: int=changed(calm,looking)
			check(gaze_pixels>100,"Gaze does not visibly move the iris and pupil")
			print("ACADEMY_FACE identity=%d profile=%d sclera=%d->%d pupil=%d->%d joy_pixels=%d gaze_pixels=%d"%[identity,profile,white_open,white_closed,pupil_open,pupil_closed,joy_pixels,gaze_pixels])
			calm.save_png("res://build/academy-review/test_%d_%d_open.png"%[identity,profile])
			closed.save_png("res://build/academy-review/test_%d_%d_closed.png"%[identity,profile])
			driver.free()
	print("ACADEMY_FACE_TEST %s: %d assertions, %d failures"%["PASS" if failures==0 else "FAIL",assertions,failures])
	quit(0 if failures==0 else 1)
