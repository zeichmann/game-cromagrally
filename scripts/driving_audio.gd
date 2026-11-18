class_name IRDrivingAudio
extends Node3D
## Bounded spatial voices. Events are consumed outside the physics callback.
var car: IRVehicle
var engine: AudioStreamPlayer3D
var tires: AudioStreamPlayer3D
var rolling: AudioStreamPlayer3D
var effects: Array[AudioStreamPlayer3D]=[]
var streams: Dictionary={}
var last_boost: bool=false
var last_seeds: int=0
var effect_index: int=0
var event_counts: Dictionary={"impact":0,"landing":0,"boost":0,"pickup":0}

func _init(driver: IRVehicle) -> void:
	car=driver

func _ready() -> void:
	for key in ["impact","landing","boost","pickup"]:
		streams[key]=load("res://assets/audio/driving/"+key+".wav")
	engine=voice("sail_drive" if car.variant==0 else "flywheel_drive",true)
	tires=voice("tires",true)
	rolling=voice("rolling",true)
	for i in range(3): effects.append(voice("impact",false))

func voice(key: String,looping: bool) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D=AudioStreamPlayer3D.new()
	var stream: AudioStreamWAV=load("res://assets/audio/driving/"+key+".wav")
	if looping:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	player.stream=stream
	player.max_distance=42
	player.unit_size=7
	player.max_db=0
	player.volume_db=-70
	add_child(player)
	if looping: player.play()
	return player

func event(key: String,strength: float=1.0) -> void:
	var player: AudioStreamPlayer3D=effects[effect_index%effects.size()]
	effect_index+=1
	player.stream=streams[key]
	player.pitch_scale=1.0 if key!="impact" else .85+clampf(strength,0,1)*.3
	player.volume_db=lerpf(-25,-9,clampf(strength,0,1))
	player.play()
	event_counts[key]+=1

func silence() -> void:
	for voice_node in [engine,tires,rolling]:
		if is_instance_valid(voice_node): voice_node.volume_db=-80
	for voice_node in effects: voice_node.stop()

func _process(dt: float) -> void:
	var active: bool=car.drive_enabled and not car.freeze and not car.progress.finished
	var velocity: float=absf(car.speed)
	engine.pitch_scale=lerpf(engine.pitch_scale,.72+minf(velocity/car.max_speed(),1.4)*1.25+absf(car.throttle_input)*.22,1.0-exp(-6*dt))
	engine.volume_db=lerpf(engine.volume_db,-24+absf(car.throttle_input)*7 if active else -70,1.0-exp(-7*dt))
	var skid: float=clampf((car.slip_speed-1.8)/8.0,0,1) if active and car.grounded else 0.0
	tires.volume_db=lerpf(tires.volume_db,lerpf(-65,-13,skid),1.0-exp(-10*dt))
	tires.pitch_scale=1.0+skid*.25
	rolling.volume_db=lerpf(rolling.volume_db,-37+minf(velocity,40)*.35 if active and car.grounded else -70,1.0-exp(-7*dt))
	rolling.pitch_scale=.75+minf(velocity,40)*.025
	if active:
		if car.impact_feedback>0: event("impact",car.impact_feedback); car.impact_feedback=0
		if car.landing_feedback>0: event("landing",car.landing_feedback); car.landing_feedback=0
		if car.boost_remaining>0 and not last_boost: event("boost",.7)
		if car.seeds_collected>last_seeds: event("pickup",.45)
	last_boost=car.boost_remaining>0
	last_seeds=car.seeds_collected
