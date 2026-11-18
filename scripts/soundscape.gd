extends Node3D
## Positional ambience with bounded range. Audio processing is separate from GPU graphics.
var race: IRRace
var sources: Array[AudioStreamPlayer3D]=[]

func _init(game: IRRace) -> void:
	race=game

func _ready() -> void:
	add_to_group("soundscape")
	if DisplayServer.get_name()=="headless": return
	var world: IRFairytaleWorld=get_tree().get_first_node_in_group("fairytale_world")
	loop("market",world.landmarks.fountain.origin+Vector3.UP*2,-8,48)
	loop("workshop",world.landmarks.town_workshop.origin+Vector3.UP*2,-7,28)
	loop("forest",race.track.centers[95]+Vector3.UP*3,-5,58)
	loop("forest",race.track.centers[140]+Vector3.UP*4,-9,45)
	loop("brook",Vector3(-65,9,7),-1,65)
	var bend: Transform3D=IRTeaBendLayout.pose(race.track)
	loop("brook",bend*Vector3(-11,-1.5,IRTeaBendLayout.stream_z(-11)),-9,30)
	loop("harbor",world.landmarks.boathouse.origin+Vector3.UP*3,-5,55)

func loop(file: String,p: Vector3,volume: float,distance: float) -> void:
	var stream: AudioStreamWAV=load("res://assets/audio/"+file+".wav")
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	var player: AudioStreamPlayer3D=AudioStreamPlayer3D.new()
	player.stream=stream
	player.position=p
	player.volume_db=volume
	player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.max_distance=distance
	player.autoplay=true
	add_child(player)
	sources.append(player)
