extends SceneTree
## Unmodified native captures at driving height and close detail views of the real district.
var race: IRRace
var count: int=0
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func capture(key: String,p: Vector3,target: Vector3,fov: float=55) -> void:
	race.preview_camera.position=p
	race.preview_camera.fov=fov
	race.preview_camera.look_at(target)
	for i in range(12): await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	if image.save_png("res://build/tea-review/"+key+".png")!=OK: failures+=1
	count+=1
	print("TEA_REVIEW ",key)
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute("res://build/tea-review")
	race=IRRace.new()
	root.add_child(race)
	for i in range(6): await RenderingServer.frame_post_draw
	race.set_process(false)
	race.set_physics_process(false)
	race.ui.hide()
	race.showroom_fill.hide()
	race.model_preview=false
	var track: IRTrack=race.track
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	var bend: Transform3D=IRTeaBendLayout.pose(track)
	for car in race.vehicles:
		car.process_mode=Node.PROCESS_MODE_DISABLED
		car.hide()
	var hero: IRVehicle=race.vehicles[0]
	hero.show()
	hero.visual.transform=Transform3D.IDENTITY
	for index in [10,15,19,24,29,35]:
		hero.nearest=index
		hero.position=track.centers[index]+Vector3.UP*.03
		hero.rotation.y=atan2(-track.tangents[index].x,-track.tangents[index].z)
		await capture("drive_%02d"%index,hero.position-track.tangents[index]*8+Vector3.UP*4.4,hero.position+track.tangents[index]*10+Vector3.UP*2,58)
	hero.hide()
	var house: Transform3D=world.landmarks.tea_hero
	await capture("bend_overview",bend*Vector3(12,12,26),bend*Vector3(-10,5,-3),56)
	await capture("teahouse",house*Vector3(13,8,20),house.origin+Vector3.UP*5.3,55)
	await capture("house_front",house*Vector3(0,5,22),house.origin+Vector3.UP*4.8,45)
	await capture("stream_bridge",bend*Vector3(-4,2.7,-14),bend*Vector3(-15,.8,-3),55)
	await capture("garden",bend*Vector3(-5,3.2,16),bend*Vector3(-13,.8,8.8),52)
	await capture("stone_arch",bend*Vector3(-13,.2,-8),bend*Vector3(1,-.5,-3.2),50)
	await capture("ancient_oak",bend*Vector3(-6,7.5,-25),bend*Vector3(-17,8,-8),58)
	await capture("stream_close",bend*Vector3(-29,.8,-11),bend*Vector3(-24,-1.5,IRTeaBendLayout.stream_z(-24)),48)
	var sign: Vector3=world.tea_bend.sign_node.global_position
	await capture("teapot_sign",sign+bend.basis*Vector3(4,1,5),sign-Vector3.UP*.7,40)
	print("TEA_REVIEW %s: %d captures"%["PASS" if failures==0 else "FAIL",count])
	quit(0 if failures==0 else 1)
