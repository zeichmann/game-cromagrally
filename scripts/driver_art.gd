class_name IRDriverArt
extends Node3D
## Authored skin weights; pose generation and weighted deformation both run on the GPU.

const Rig=preload("res://scripts/academy_rig.gd")
const MESHES: Array[ArrayMesh]=[preload("res://assets/characters/academy_v5/zabol_driver.res"),preload("res://assets/characters/academy_v5/swinka_driver.res")]
const BALANCED: Array[ArrayMesh]=[preload("res://assets/characters/academy_v5/zabol_driver_balanced.res"),preload("res://assets/characters/academy_v5/swinka_driver_balanced.res")]
const PERFORMANCE: Array[ArrayMesh]=[preload("res://assets/characters/academy_v5/zabol_driver_performance.res"),preload("res://assets/characters/academy_v5/swinka_driver_performance.res")]
const CHARACTER_NAMES: Array[String]=Rig.LABELS
const BONE_COUNT: int=6
static var gpu_materials: Dictionary={}
var identity: int=0
var skinned: MeshInstance3D
var detail: int=0

func _init(_color: Color=Color.WHITE,character: int=0) -> void:
	identity=clampi(character,0,MESHES.size()-1)
	skinned=MeshInstance3D.new()
	skinned.name="ZabolDriverGPU" if identity==0 else "SwinkaDriverGPU"
	skinned.skeleton=NodePath("")
	add_child(skinned)
	set_detail(0)

func set_detail(profile: int) -> void:
	detail=clampi(profile,0,2)
	skinned.mesh=[MESHES,BALANCED,PERFORMANCE][detail][identity]
	for surface in range(skinned.mesh.get_surface_count()):
		var source: ShaderMaterial=skinned.mesh.surface_get_material(surface)
		if not gpu_materials.has(source):
			var material: ShaderMaterial=source.duplicate()
			if not source.shader.resource_path.ends_with("academy_cornea.gdshader"):
				var suffix: String="_double" if "_double" in source.shader.resource_path else ""
				material.shader=load("res://shaders/palette_driver"+suffix+".gdshader")
			else:
				material.set_shader_parameter("cornea_gain",.75)
			gpu_materials[source]=material
		skinned.set_surface_override_material(surface,gpu_materials[source])
	skinned.custom_aabb=skinned.mesh.get_aabb().grow(.4)
	skinned.set_instance_shader_parameter("ir_eye_center",Vector2(.226,.972) if identity==0 else Vector2(.192,.948))
	skinned.set_instance_shader_parameter("ir_academy_species",identity)
