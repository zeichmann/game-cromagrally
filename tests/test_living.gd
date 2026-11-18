extends SceneTree
## Traversability, resident patrol safety and consumable/restart behaviour in the real scene.
var assertions: int=0
var failures: int=0
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var race: IRRace=IRRace.new()
	root.add_child(race)
	await process_frame
	race.set_process(false)
	race.set_physics_process(false)
	for car in race.vehicles: car.set_physics_process(false)
	var track: IRTrack=race.track
	check(track.half_width_at(24)<track.half_width_at(9) and track.half_width_at(110)<track.half_width_at(24),"Teahouse bridge, village approach and forest must differ in width")
	var continuous: bool=true
	for i in range(IRTrack.SAMPLES): continuous=continuous and absf(track.half_width_at(i)-track.half_width_at(i+1))<.7
	check(continuous,"Road width changes discontinuously")
	var main_length: float=0
	var alternate_length: float=0
	for i in range(IRTrack.SHORTCUT_START,IRTrack.SHORTCUT_END): main_length+=track.centers[i].distance_to(track.centers[i+1])
	for i in range(track.shortcut.size()-1): alternate_length+=track.shortcut[i].distance_to(track.shortcut[i+1])
	check(alternate_length<main_length*.98,"Grotto route does not save distance")
	check(track.shortcut[0].is_equal_approx(track.centers[IRTrack.SHORTCUT_START]) and track.shortcut[-1].is_equal_approx(track.centers[IRTrack.SHORTCUT_END]),"Shortcut does not merge at both ends")
	var shortcut_safe: bool=true
	for p in track.shortcut: shortcut_safe=shortcut_safe and track.driving_margin(p,track.closest_index(p))<0
	check(shortcut_safe,"Shortcut triggers the off-course rule")
	var world: IRFairytaleWorld=get_first_node_in_group("fairytale_world")
	check(world.life.spots.size()==56,"Missing village life placements")
	var patrol_clear: bool=true
	for spot in world.life.spots:
		if not spot.asset in ["resident_rabbit","resident_mouse"]: continue
		for sign_value in [-1.0,0.0,1.0]:
			var p: Vector3=spot.pose*(Vector3(0,0,sign_value*spot.custom.b))
			patrol_clear=patrol_clear and track.driving_margin(p,track.closest_index(p))>.5
	check(patrol_clear,"A resident patrol enters the driving ribbon")
	var weights_valid: bool=true
	for asset in ["resident_rabbit","resident_mouse","resident_cat","resident_duck","resident_gull"]:
		var mesh: ArrayMesh=world.meshes[asset]
		for s in range(mesh.get_surface_count()):
			var arrays: Array=mesh.surface_get_arrays(s)
			var count: int=arrays[Mesh.ARRAY_VERTEX].size()
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			weights_valid=weights_valid and weights.size()==count*4 and bones.size()==weights.size()
			if weights.size()!=count*4: continue
			for i in range(count): weights_valid=weights_valid and bones[i*4]>=0 and bones[i*4]<6 and absf(weights[i*4]-1)<.0001
	check(weights_valid,"Resident GPU joint attributes are missing or invalid")
	var grotto: Transform3D=world.landmarks.crystal_grotto
	var grotto_clear: bool=true
	var lowest_margin: float=INF
	var worst: String=""
	var grotto_mesh: ArrayMesh=world.meshes.crystal_grotto
	for s in range(grotto_mesh.get_surface_count()):
		var vertices: PackedVector3Array=grotto_mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in vertices:
			var global: Vector3=grotto*p
			var i: int=track.closest_index(global)
			var n: int=track.shortcut_nearest(global)
			var margin: float=INF
			if global.y<track.centers[i].y+3.1:
				margin=absf((global-track.centers[i]).dot(track.right_at(i)))-track.half_width_at(i)
			if global.y<track.shortcut[n].y+3.1:
				margin=minf(margin,Vector2(global.x-track.shortcut[n].x,global.z-track.shortcut[n].z).length()-IRTrack.SHORTCUT_WIDTH)
			if margin<lowest_margin:
				lowest_margin=margin
				worst="local="+str(p)+" main="+str(i)+" shortcut="+str(track.shortcut_nearest(global))+" main_margin="+str(absf((global-track.centers[i]).dot(track.right_at(i)))-track.half_width_at(i))
			grotto_clear=grotto_clear and margin>-.15
	check(grotto_clear,"Grotto wall intersects a drivable lane; margin="+str(lowest_margin)+" "+worst)
	var banks_valid: bool=true
	for bank in world.life.banks:
		var original: Dictionary={}
		for n in range(bank.variants[0].instance_count): original[str(bank.variants[0].get_instance_transform(n))]=true
		for variant in bank.variants:
			for n in range(variant.instance_count): banks_valid=banks_valid and original.has(str(variant.get_instance_transform(n)))
	check(banks_valid,"Quality switch moves residents")
	check(world.life.find_children("*","Skeleton3D",true,false).is_empty() and not world.life.is_processing(),"Residents use a CPU skeleton or frame script")
	var car: IRVehicle=race.vehicles[0]
	car.human=true
	car.demo_control=false
	car.drive_enabled=true
	var adventure: IRAdventures=race.adventures
	car.position=adventure.items[0].position
	adventure.tick(1.0/60)
	check(car.seeds_collected==1 and car.boost_charge==1,"Seed pickup did not award charge")
	adventure.tick(1.0/60)
	check(car.seeds_collected==1 and adventure.items[0].cooldown>0,"Collected seed can be collected repeatedly")
	car.position=Vector3(0,1000,0)
	adventure.tick(8.1)
	car.position=adventure.items[0].position
	adventure.tick(.016)
	check(car.seeds_collected==2,"Seed cannot be collected again after cooldown")
	car.boost_charge=2
	car.try_boost()
	check(car.boost_remaining==0 and car.boost_charge==2,"Boost can spend insufficient charge")
	car.boost_charge=6
	car.try_boost()
	car.try_boost()
	check(car.boost_remaining>0 and car.boost_charge==3,"Holding boost spends the same charge twice")
	car.respawn()
	check(car.boost_remaining==0 and car.boost_charge==3,"Recovery must end boost without granting or deleting reserve charge")
	car.progress.next_gate=4
	car.position=track.shortcut[16]
	adventure.tick(.016)
	check(not car.secret_found,"Secret can be claimed before the required checkpoint")
	car.progress.next_gate=5
	var before: int=car.boost_charge
	adventure.tick(.016)
	check(car.secret_found and car.boost_charge==mini(before+3,9),"Legal grotto passage does not award the secret")
	adventure.tick(.016)
	check(car.boost_charge==mini(before+3,9),"Secret awards charge more than once")
	car.progress.finished=true
	car.secret_found=false
	car.position=adventure.items[1].position
	before=car.seeds_collected
	adventure.tick(.016)
	check(car.seeds_collected==before,"Finished racer can still collect items")
	race._start_race(1,false)
	await process_frame
	check(race.vehicles[0].seeds_collected==0 and race.vehicles[0].boost_charge==0 and not race.vehicles[0].secret_found,"Restart keeps old adventure rewards")
	var reset_valid: bool=true
	for item in adventure.items: reset_valid=reset_valid and item.cooldown==0
	check(reset_valid,"Restart keeps collectible cooldowns")
	print("LIVING_TEST %s: %d assertions, %d failures; main %.3fm / shortcut %.3fm; grotto margin %.3fm"%["PASS" if failures==0 else "FAIL",assertions,failures,main_length,alternate_length,lowest_margin])
	race.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
