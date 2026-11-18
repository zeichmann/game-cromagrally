extends RefCounted
## Render-thread owner. Queued callables retain this object until GPU cleanup finishes.
signal initialized(atlas: RID)
signal snapshot_ready(data: PackedFloat32Array)
signal failed(message: String)
var rd: RenderingDevice
var atlas: RID
var shader: RID
var pipeline: RID
var inputs: RID
var uniforms: RID

func initialize(spirv: RDShaderSPIRV) -> void:
	rd=RenderingServer.get_rendering_device()
	shader=rd.shader_create_from_spirv(spirv)
	if not shader.is_valid():
		failed.emit("The graphics driver could not create the GPU animation shader.")
		return
	pipeline=rd.compute_pipeline_create(shader)
	if not pipeline.is_valid():
		failed.emit("The graphics driver could not create the GPU animation pipeline.")
		dispose()
		return
	var format: RDTextureFormat=RDTextureFormat.new()
	format.width=32
	format.height=8
	format.format=RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var blank: PackedByteArray=PackedByteArray()
	blank.resize(32*8*16)
	blank.fill(0)
	atlas=rd.texture_create(format,RDTextureView.new(),[blank])
	if not atlas.is_valid():
		failed.emit("The graphics driver does not support the GPU animation texture.")
		dispose()
		return
	var records: PackedFloat32Array=PackedFloat32Array()
	records.resize(24)
	records.fill(0)
	for actor in range(6):
		records[actor*4+3]=1
	inputs=rd.storage_buffer_create(96,records.to_byte_array())
	var controls: RDUniform=RDUniform.new()
	controls.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	controls.binding=0
	controls.add_id(inputs)
	var output: RDUniform=RDUniform.new()
	output.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE
	output.binding=1
	output.add_id(atlas)
	uniforms=rd.uniform_set_create([controls,output],shader,0)
	if not inputs.is_valid() or not uniforms.is_valid():
		failed.emit("The graphics driver could not bind GPU animation data.")
		dispose()
		return
	step(records.to_byte_array(),0)
	initialized.emit(atlas)

func step(records: PackedByteArray,dt: float) -> void:
	if not pipeline.is_valid():
		return
	rd.buffer_update(inputs,0,records.size(),records)
	var commands: int=rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(commands,pipeline)
	rd.compute_list_bind_uniform_set(commands,uniforms,0)
	var parameters: PackedByteArray=PackedFloat32Array([dt,0,0,0]).to_byte_array()
	rd.compute_list_set_push_constant(commands,parameters,parameters.size())
	rd.compute_list_dispatch(commands,7,1,1)
	rd.compute_list_end()

func readback_for_test() -> void:
	snapshot_ready.emit(rd.texture_get_data(atlas,0).to_float32_array())

func dispose() -> void:
	if rd==null:
		return
	for resource in [uniforms,pipeline,shader,inputs,atlas]:
		if resource.is_valid():
			rd.free_rid(resource)
	pipeline=RID()
	uniforms=RID()
	shader=RID()
	inputs=RID()
	atlas=RID()
