class_name IRVillageLife
extends Node3D
## Static instance records. Every joint, patrol, tail, wing and floating motion is GPU driven.
var world: IRFairytaleWorld
var banks: Array[Dictionary]=[]
var spots: Array[Dictionary]=[]
var material: ShaderMaterial

func _init(island: IRFairytaleWorld) -> void:
	world=island

func _ready() -> void:
	add_to_group("village_life")
	material=IRPaletteMesh.material(false).duplicate()
	material.shader=load("res://shaders/palette_resident.gdshader")
	var track: IRTrack=world.track
	# Walking stays along the pavements: patrols never enter the driving ribbon.
	for i in [11,17,24,31,42,47,61,67]:
		for side in [-1.0,1.0]:
			var p: Vector3=world.on_roadside(i,side*(track.half_width_at(i)+1.75))
			p.y=track.centers[i].y+.12
			var mode: int=1 if i%3==0 else (2 if i%3==1 else 0)
			var yaw: float=world.yaw_facing_track(i,side>0)
			if mode==2: yaw+=PI*.5
			if i in [24,31]:
				var local: Vector3=Vector3(-12.0,-.28,8.6 if i==24 else 11.6) if side<0 else Vector3(8.8,0,5.2 if i==24 else -10.5)
				p=IRTeaBendLayout.pose(track)*local
				if side>0: p.y=world.terrain.surface_height(p)+.06
				mode=1 if i==24 else 0
			add_spot("resident_rabbit" if i%2 else "resident_mouse",p,yaw,.90+(i%3)*.05,mode,.75 if mode==2 else 0)
	var plaza: Vector3=world.landmarks.fountain.origin
	for n in range(9):
		var a: float=n*TAU/9
		var p: Vector3=plaza+Vector3(cos(a)*6.8,0,sin(a)*6.8)
		p.y=world.terrain.surface_height(p)+.04
		add_spot("resident_mouse" if n%2 else "resident_rabbit",p,-a,.88,1 if n%3==0 else 0)
	for i in [223,239,281,300,339,352]:
		var p: Vector3=world.on_roadside(i,track.half_width_at(i)+2.4)
		p.y=world.terrain.surface_height(p)
		add_spot("resident_rabbit",p,world.yaw_facing_track(i,true),.95,1)
	for key in ["town_post","town_workshop","cottage_blue","bakery"]:
		var pose: Transform3D=world.landmarks[key]
		var p: Vector3=pose*Vector3(.5,4.2,2.9) if key=="town_workshop" else pose*Vector3(-1.5,0,3.5)
		if key!="town_workshop": p.y=world.terrain.surface_height(p)+.12
		add_spot("resident_cat",p,pose.basis.get_euler().y,1.1,6)
	var harbor: Vector3=world.on_roadside(344,-37)
	for n in range(7):
		var p: Vector3=harbor+track.tangents[344]*((n-3)*2.1)
		p.y=-6.92
		if n<3:
			var x: float=-20-n*2.1
			p=IRTeaBendLayout.pose(track)*Vector3(x,IRTeaBendLayout.water_y(x)+.04,IRTeaBendLayout.stream_z(x))
		add_spot("resident_duck",p,n*.4,1.1,5,.7)
	for n in range(14):
		var i: int=(n*31+15)%IRTrack.SAMPLES
		var p: Vector3=world.on_roadside(i,13+(n%3)*4)
		p.y=maxf(world.terrain.surface_height(p),track.centers[i].y)+8+(n%4)*1.8
		add_spot("resident_gull",p,n*1.1,1.1,4,4.0)
	_build_batches()

func add_spot(asset: String,p: Vector3,yaw: float,size: float,role: int,patrol: float=0) -> void:
	if asset not in ["resident_duck","resident_gull"]:
		var frame: Transform3D=IRTeaBendLayout.pose(world.track)
		var local: Vector3=frame.affine_inverse()*p
		if absf(local.x)<35 and local.y<1.4:
			var delta: float=local.z-IRTeaBendLayout.stream_z(local.x)
			var clearance: float=IRTeaBendLayout.stream_half_width(local.x)+.85+patrol
			if absf(delta)<clearance:
				local.z=IRTeaBendLayout.stream_z(local.x)+(1.0 if delta>=0 else -1.0)*clearance
				p=frame*local
				p.y=world.terrain.surface_height(p)+.08
	spots.append({"asset":asset,"pose":Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),p),"custom":Color(spots.size()*1.73,role,patrol,0)})

func _build_batches() -> void:
	var groups: Dictionary={}
	for spot in spots:
		var p: Vector3=spot.pose.origin
		var key: String=spot.asset+"/%d_%d"%[floori(p.x/40),floori(p.z/40)]
		if not groups.has(key): groups[key]=[]
		groups[key].append(spot)
	for key in groups:
		var group: Array=groups[key]
		var center: Vector3=group[0].pose.origin
		var variants: Array[MultiMesh]=[]
		for quality in range(3):
			var selected: Array=[]
			for n in range(group.size()):
				if quality==1 and n%4==3: continue
				if quality==2 and n%2==1: continue
				selected.append(group[n])
			var multi: MultiMesh=MultiMesh.new()
			multi.transform_format=MultiMesh.TRANSFORM_3D
			multi.use_custom_data=true
			multi.mesh=world.meshes[group[0].asset]
			multi.instance_count=selected.size()
			for n in range(selected.size()):
				var pose: Transform3D=selected[n].pose
				pose.origin-=center
				multi.set_instance_transform(n,pose)
				multi.set_instance_custom_data(n,selected[n].custom)
			variants.append(multi)
		var node: MultiMeshInstance3D=MultiMeshInstance3D.new()
		node.multimesh=variants[0]
		node.position=center
		node.material_override=material
		node.extra_cull_margin=7 if group[0].asset=="resident_gull" else 2
		node.visibility_range_end=95
		node.visibility_range_end_margin=10
		add_child(node)
		banks.append({"node":node,"variants":variants})
	set_meta("residents",spots.size())

func apply_quality(profile: int) -> void:
	for bank in banks:
		bank.node.multimesh=bank.variants[profile]
		bank.node.visibility_range_end=[95.0,75.0,60.0][profile]
		bank.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if profile<2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
