class_name IRGpuMotion
extends Node
## CPU submits six control records. GPU integrates animation and constructs all bone poses.
signal snapshot_ready(data: PackedFloat32Array)
const Device=preload("res://scripts/gpu_motion_device.gd")
var race: IRRace
var texture: Texture2DRD
var initialized: bool=false
var epoch: int=1
var device: RefCounted

func _init(game: IRRace) -> void:
	race=game
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_priority=100

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		set_process(false)
		return
	if RenderingServer.get_rendering_device()==null:
		push_error("GPU animation requires Forward+ or Mobile; use Run.cmd or Run-light.cmd.")
		get_tree().quit(1)
		set_process(false)
		return
	texture=Texture2DRD.new()
	device=Device.new()
	device.initialized.connect(_publish,CONNECT_DEFERRED)
	device.snapshot_ready.connect(_deliver_snapshot,CONNECT_DEFERRED)
	device.failed.connect(_gpu_failure,CONNECT_DEFERRED)
	var source: RDShaderFile=load("res://shaders/gpu_motion.glsl")
	if source==null:
		_gpu_failure("The GPU animation program is missing. Import this project with Godot 4.7.2.")
		return
	RenderingServer.call_on_render_thread(device.initialize.bind(source.get_spirv()))

func _publish(atlas: RID) -> void:
	if not is_inside_tree():
		return
	texture.texture_rd_rid=atlas
	RenderingServer.global_shader_parameter_set("ir_motion_atlas",texture)
	RenderingServer.global_shader_parameter_set("ir_motion_enabled",true)
	initialized=true

func _process(dt: float) -> void:
	if not initialized:
		return
	var records: PackedFloat32Array=PackedFloat32Array()
	for i in range(6):
		var steer: float=0
		var speed: float=0
		var grade: float=0
		if i<race.vehicles.size():
			var car: IRVehicle=race.vehicles[i]
			steer=car.render_steer
			speed=car.speed
			if not race.model_preview:
				grade=race.track.tangents[car.nearest].y
		records.append_array(PackedFloat32Array([steer,speed,grade,float(epoch)]))
	RenderingServer.call_on_render_thread(device.step.bind(records.to_byte_array(),0.0 if get_tree().paused else minf(dt,.25)))

func dispatch_for_test(records: PackedFloat32Array,dt: float) -> void:
	RenderingServer.call_on_render_thread(device.step.bind(records.to_byte_array(),dt))

func snapshot_for_test() -> PackedFloat32Array:
	# Explicit validation only. Production rendering never reads the atlas back.
	RenderingServer.call_on_render_thread(device.readback_for_test)
	return await snapshot_ready

func _deliver_snapshot(data: PackedFloat32Array) -> void:
	snapshot_ready.emit(data)

func _gpu_failure(message: String) -> void:
	push_error(message)
	get_tree().quit(1)

func _exit_tree() -> void:
	initialized=false
	if texture!=null:
		RenderingServer.global_shader_parameter_set("ir_motion_enabled",false)
		RenderingServer.global_shader_parameter_set("ir_motion_atlas",null)
		texture.texture_rd_rid=RID()
		RenderingServer.call_on_render_thread(device.dispose)
