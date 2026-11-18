class_name IRRacePreferences
extends RefCounted
## Validated local preferences, separate from race records.
const DEFAULT_KEYS: Dictionary={"left":KEY_A,"right":KEY_D,"throttle":KEY_W,"reverse":KEY_S,"brake":KEY_SPACE,"boost":KEY_SHIFT,"recover":KEY_R,"pause":KEY_ESCAPE,"mute":KEY_M}
var bindings: Dictionary=DEFAULT_KEYS.duplicate()
var quality: int=0
var volume: float=.7
var sensitivity: float=1.0
var camera_motion: bool=true
var difficulty: int=1
var rides: Array[int]=[0,1,0,1]
var characters: Array[int]=[0,1,0,1]

func down(action: String) -> bool:
	if Input.is_physical_key_pressed(int(bindings[action])): return true
	var arrows: Dictionary={"left":KEY_LEFT,"right":KEY_RIGHT,"throttle":KEY_UP,"reverse":KEY_DOWN}
	return arrows.has(action) and int(bindings[action])==int(DEFAULT_KEYS[action]) and Input.is_physical_key_pressed(int(arrows[action]))

func rebind(action: String,physical_key: int) -> void:
	if not bindings.has(action) or physical_key<=0: return
	var previous: int=int(bindings[action])
	for other in bindings:
		if other!=action and int(bindings[other])==physical_key: bindings[other]=previous
	bindings[action]=physical_key

func read(path: String="user://race_settings.json") -> void:
	if not FileAccess.file_exists(path): return
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version",0)!=1: return
	if data.get("quality") is float or data.get("quality") is int: quality=clampi(int(data.quality),0,2)
	if data.get("volume") is float or data.get("volume") is int: volume=clampf(float(data.volume),0,1)
	if data.get("sensitivity") is float or data.get("sensitivity") is int: sensitivity=clampf(float(data.sensitivity),.5,1.6)
	if data.get("camera_motion") is bool: camera_motion=data.camera_motion
	if data.get("difficulty") is float or data.get("difficulty") is int: difficulty=clampi(int(data.difficulty),0,2)
	if data.get("bindings") is Dictionary:
		for action in DEFAULT_KEYS:
			var key: Variant=data.bindings.get(action)
			if (key is float or key is int) and int(key)>0 and int(key)<(1<<25): rebind(action,int(key))
	for i in range(4):
		if data.get("rides") is Array and data.rides.size()>i and (data.rides[i] is float or data.rides[i] is int): rides[i]=clampi(int(data.rides[i]),0,1)
		if data.get("characters") is Array and data.characters.size()>i and (data.characters[i] is float or data.characters[i] is int): characters[i]=clampi(int(data.characters[i]),0,1)

func save(path: String="user://race_settings.json") -> bool:
	var file: FileAccess=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"version":1,"quality":quality,"volume":volume,"sensitivity":sensitivity,"camera_motion":camera_motion,"difficulty":difficulty,"bindings":bindings,"rides":rides,"characters":characters}))
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,.0001)))
