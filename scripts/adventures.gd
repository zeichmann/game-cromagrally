class_name IRAdventures
extends Node3D
## Race rules run in physics; collectible motion and vehicle effects are GPU rendered.
var race: IRRace
var items: Array[Dictionary]=[]
var batch: MultiMeshInstance3D

func _init(game: IRRace) -> void:
	race=game

func _ready() -> void:
	add_to_group("adventures")
	var seed_model: Node3D=Node3D.new()
	var gold: Material=IRArt.pbr(Color("c79d43"),.38,.5)
	IRArt.ellipsoid(seed_model,Vector3(.19,.43,.13),Vector3.ZERO,gold).rotation.z=.35
	IRArt.ring(seed_model,.25,.018,Vector3.ZERO,gold).rotation.x=PI*.5
	var mesh: ArrayMesh=IRArt.bake(seed_model).mesh
	seed_model.free()
	var multi: MultiMesh=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.use_custom_data=true
	multi.mesh=mesh
	for i in range(10,IRTrack.SAMPLES,10):
		var p: Vector3=race.track.centers[i]+race.track.right_at(i)*sin(i*.7)*1.5+Vector3.UP*1.1
		items.append({"position":p,"cooldown":0.0})
	for n in [8,16,24]:
		items.append({"position":race.track.shortcut[n]+Vector3.UP*1.1,"cooldown":0.0})
	multi.instance_count=items.size()
	for n in range(items.size()):
		multi.set_instance_transform(n,Transform3D(Basis.IDENTITY,items[n].position))
		multi.set_instance_color(n,Color("e8c987"))
		multi.set_instance_custom_data(n,Color(n*1.71,0,1,0))
	batch=MultiMeshInstance3D.new()
	batch.multimesh=multi
	batch.material_override=IRArt.shader("wind_seed")
	batch.extra_cull_margin=.3
	add_child(batch)
	var ford: ShaderMaterial=IRArt.shader("ford_water")
	race.track._strip(-IRTrack.HALF_WIDTH,IRTrack.HALF_WIDTH,.045,Color.WHITE,false,ford,145,152).name="ShallowFord"

func reset() -> void:
	if batch==null: return
	for n in range(items.size()):
		items[n].cooldown=0.0
		batch.multimesh.set_instance_custom_data(n,Color(n*1.71,0,1,0))

func tick(dt: float) -> void:
	for n in range(items.size()):
		if items[n].cooldown>0:
			items[n].cooldown=maxf(items[n].cooldown-dt,0)
			if items[n].cooldown==0: batch.multimesh.set_instance_custom_data(n,Color(n*1.71,0,1,0))
			continue
		for car in race.vehicles:
			if car.progress.finished or not car.drive_enabled: continue
			if car.global_position.distance_to(items[n].position)<1.85:
				car.seeds_collected+=1
				car.boost_charge=mini(car.boost_charge+1,9)
				items[n].cooldown=8.0
				batch.multimesh.set_instance_custom_data(n,Color(n*1.71,0,0,0))
				break
	for car in race.vehicles:
		if car.progress.finished or not car.drive_enabled: continue
		if not car.secret_found and car.progress.next_gate==5 and car.global_position.distance_to(race.track.shortcut[16])<3:
			car.secret_found=true
			car.boost_charge=mini(car.boost_charge+3,9)
		if (not car.human or car.demo_control) and car.boost_charge>=3:
			var bend: float=race.track.tangents[car.nearest].angle_to(race.track.tangents[(car.nearest+15)%IRTrack.SAMPLES])
			if bend<.23: car.try_boost()

func apply_quality(profile: int) -> void:
	batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if profile==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
