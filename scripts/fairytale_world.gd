class_name IRFairytaleWorld
extends Node3D
## Six authored districts, batched by district and mesh. All small props use sampled terrain.

const ASSET_NAMES: Array[String]=[
	"cottage_blue","cottage_rose","cottage_peach",
	"elder_gate","bakery","castle_crag","boathouse",
	"town_post","town_workshop","town_tea","port_crane","crystal_grotto","giant_fern","moss_boulder","lantern_mushroom",
	"resident_rabbit","resident_mouse","resident_cat","resident_gull","resident_duck",
	"tree_oak","tree_blossom","tree_willow","tree_birch","tree_cypress",
	"flowering_bush","hanging_ivy","water_lily","footbridge",
	"garden_fence","garden_planter","mailbox","rose_arbor","dock_supplies",
	"balloon_coral","balloon_blue",
	"flowers_daisy","flowers_rose","flowers_lavender","fern","mushroom",
	"arch","turret","castle_keep","lantern","stone_rail","pavilion",
	"boat","boat_coral","boat_sage","lighthouse","hedge","fountain","bench",
	"windmill","windmill_rotor","market_stall"
]
var track: IRTrack
static var batch_cell_size: float=48.0
var terrain: IRSceneryArt
var rng: RandomNumberGenerator=RandomNumberGenerator.new()
var meshes: Dictionary={}
var batches: Dictionary={}
var placements: Dictionary={}
var landmarks: Dictionary={}
var paths: SurfaceTool=SurfaceTool.new()
var path_corridors: Array[Dictionary]=[]
var building_footprints: Array[Dictionary]=[]
var prop_clearances: Array[Dictionary]=[]
var supports: Node3D
var support_material: ShaderMaterial
var fountain_flows: Array[IRFountainFlow]=[]
var quality_batches: Array[Dictionary]=[]
var atmosphere: Node3D
var life: IRVillageLife
var magic: Node3D
var tea_bend: IRTeaBend
var collisions: IRWorldCollisions

func _init(course: IRTrack, landscape: IRSceneryArt) -> void:
	track=course
	terrain=landscape
	rng.seed=471930

func _ready() -> void:
	add_to_group("fairytale_world")
	collisions=IRWorldCollisions.new()
	collisions.name="SolidScenery"
	add_child(collisions)
	for name_key in ASSET_NAMES:
		meshes[name_key]=load("res://assets/fairytale/"+name_key+".res")
	paths.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(track.shortcut.size()-1):
		path_corridors.append({"a":Vector2(track.shortcut[n].x,track.shortcut[n].z),"b":Vector2(track.shortcut[n+1].x,track.shortcut[n+1].z),"radius":IRTrack.SHORTCUT_WIDTH+.65})
	supports=Node3D.new()
	add_child(supports)
	support_material=ShaderMaterial.new()
	support_material.shader=load("res://shaders/storybook_surface.gdshader")
	support_material.set_shader_parameter("albedo_tex",load("res://assets/textures/fairy_masonry.png"))
	support_material.set_shader_parameter("world_mapping",true)
	_village()
	_grove()
	_waterfall_and_bridge()
	_castle()
	_gardens()
	_harbor()
	load("res://scripts/living_districts.gd").new().build(self)
	tea_bend=IRTeaBend.new(self)
	add_child(tea_bend)
	_roadside_gardens()
	_woodland()
	place("balloon_coral",Vector3(-145,34,-140),.4,1,Color.WHITE,false)
	place("balloon_blue",Vector3(95,45,-150),-.3,.85,Color.WHITE,false)
	place("balloon_coral",Vector3(-130,44,110),1.4,.7,Color("f5e3ed"),false)
	var solid_supports: MeshInstance3D=IRArt.bake(supports)
	collisions.add_visual("foundations_and_castle",solid_supports,true)
	paths.index()
	paths.generate_normals()
	var path_material: ShaderMaterial=ShaderMaterial.new()
	path_material.shader=load("res://shaders/storybook_surface.gdshader")
	path_material.set_shader_parameter("albedo_tex",load("res://assets/textures/fairy_paving.png"))
	IRArt.part(self,paths.commit(),Vector3.ZERO,path_material)
	_flush()
	terrain.trim_grass(self)
	_butterflies()
	atmosphere=load("res://scripts/storybook_atmosphere.gd").new(self)
	add_child(atmosphere)
	life=IRVillageLife.new(self)
	add_child(life)
	magic=load("res://scripts/woodland_magic.gd").new(self)
	add_child(magic)
	set_meta("placements",placements)

func on_roadside(i: int, offset: float) -> Vector3:
	return track.centers[posmod(i,IRTrack.SAMPLES)]+track.right_at(i)*offset

func yaw_facing_track(i: int, inside: bool) -> float:
	var outward: Vector3=-track.right_at(i) if inside else track.right_at(i)
	return atan2(outward.x,outward.z)

func clear_of_road(p: Vector3, margin: float) -> bool:
	var i: int=track.closest_index(p)
	return track.driving_margin(p,i)>margin

func place(asset: String, p: Vector3, yaw: float = 0, size: float = 1.0, color: Color = Color.WHITE, snap: bool = true) -> void:
	if IRTeaBendLayout.reserved(track,p):
		if asset.begins_with("tree_") or asset.begins_with("town_") or asset.begins_with("cottage_") or asset in ["hedge","garden_fence","mailbox","lantern"]:
			return
		if tea_bend==null and asset in ["flowering_bush","garden_planter"]: return
	if snap:
		p.y=terrain.surface_height(p)-.06
		if asset in ["pavilion","fountain","bench"]:
			p=_supported_position(asset,p,yaw,size)
	if asset in ["pavilion","fountain","bench"]:
		prop_clearances.append({"center":Vector2(p.x,p.z),"radius":({"pavilion":4.0,"fountain":3.2,"bench":1.7}[asset])*size})
	if asset=="fountain":
		var flow: IRFountainFlow=IRFountainFlow.new()
		flow.transform=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),p)
		add_child(flow)
		fountain_flows.append(flow)
	if asset.begins_with("cottage"):
		var minimum: Vector2=Vector2(-4.0,-3.8)
		var maximum: Vector2=Vector2(5.2,5.1)
		if asset=="cottage_peach":
			minimum.x=-7.1
			maximum.x=5.8
		building_footprints.append({"inverse":Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),p).affine_inverse(),"min":minimum,"max":maximum})
		var proportions: Vector3=Vector3(.84,1.10,.96) if asset=="cottage_rose" else (Vector3(1.12,.95,1) if asset=="cottage_peach" else Vector3.ONE)
		_box_occluder(p+Vector3.UP*2.3*proportions.y*size,yaw,Vector3(6.5,4.1,5.5)*proportions*size)
	if asset.begins_with("town_"):
		building_footprints.append({"inverse":Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),p).affine_inverse(),"min":Vector2(-3.2,-2.9),"max":Vector2(3.3,3.6)})
		_box_occluder(p+Vector3.UP*3.5*size,yaw,Vector3(4.7,6.0,4.1)*size)
	if asset=="bakery":
		building_footprints.append({"inverse":Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),p).affine_inverse(),"min":Vector2(-5.6,-4.7),"max":Vector2(5.6,5.4)})
		_box_occluder(p+Vector3.UP*2.8*size,yaw,Vector3(4.0,4.7,4.0)*size)
	var sector: int=track.closest_index(p)/64
	if not landmarks.has(asset):
		landmarks[asset]=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),p)
	var key: String="%d/%s"%[sector,asset]
	if batch_cell_size>0:
		key+="/%d_%d"%[floori(p.x/batch_cell_size),floori(p.z/batch_cell_size)]
	if not batches.has(key):
		batches[key]={"name":asset,"transforms":[],"colors":[]}
	batches[key].transforms.append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),p))
	batches[key].colors.append(color)
	placements[asset]=int(placements.get(asset,0))+1

func _box_occluder(p: Vector3, yaw: float, size: Vector3) -> void:
	var resource: BoxOccluder3D=BoxOccluder3D.new()
	resource.size=size
	var instance: OccluderInstance3D=OccluderInstance3D.new()
	instance.occluder=resource
	instance.position=p
	instance.rotation.y=yaw
	add_child(instance)

func _flush() -> void:
	for key in batches:
		var batch: Dictionary=batches[key]
		var name_key: String=batch.name
		var small: bool=name_key.begins_with("flowers") or name_key in ["fern","hanging_ivy","water_lily","mushroom","lantern_mushroom"]
		var tree: bool=name_key.begins_with("tree") or name_key in ["hedge","flowering_bush","elder_gate"]
		var sky_prop: bool=name_key.begins_with("balloon")
		var distance: float=900.0 if sky_prop else (75.0 if small else (205.0 if tree else 330.0))
		var transforms: Array[Transform3D]=[]
		var colors: Array[Color]=[]
		transforms.assign(batch.transforms)
		colors.assign(batch.colors)
		if small or name_key.begins_with("tree") or name_key=="flowering_bush":
			for i in range(transforms.size()-1,-1,-1):
				var margin: float=transforms[i].basis.get_scale().x*(1.4 if name_key=="flowering_bush" else 2.8) if not small else .48
				if on_path(transforms[i].origin,margin) or inside_building(transforms[i].origin,margin if not small else .1) or near_prop(transforms[i].origin,margin if not small else .2):
					transforms.remove_at(i)
					colors.remove_at(i)
					placements[name_key]-=1
		if transforms.is_empty():
			continue
		# Build from the surviving authored placements, before scatter recenters
		# them. Rendering distance and quality changes never remove these bodies.
		if name_key in IRWorldCollisions.SOLID_ASSETS:
			for pose in transforms: collisions.add_mesh(name_key,meshes[name_key],pose)
		IRArt.scatter(self,meshes[name_key],null,transforms,colors,distance,not small and not sky_prop)
		var instance: MultiMeshInstance3D=get_child(-1)
		instance.name=key.replace("/","_")
		instance.lod_bias=.8 if small else 1.0
		instance.visibility_range_end_margin=12
		instance.extra_cull_margin=.3 if tree or name_key.begins_with("boat") else .12
		if sky_prop:
			instance.extra_cull_margin=1.5
		if name_key=="elder_gate":
			instance.extra_cull_margin=.8
		var banks: Array[MultiMesh]=[instance.multimesh]
		for profile in [1,2]:
			if small:
				var subset: Array[Transform3D]=[]
				var shades: Array[Color]=[]
				for i in range(transforms.size()):
					if (profile==1 and i%4==0) or (profile==2 and i%2==1):
						continue
					var transform: Transform3D=transforms[i]
					transform.origin-=instance.position
					subset.append(transform)
					shades.append(colors[i])
				var multi: MultiMesh=MultiMesh.new()
				multi.transform_format=MultiMesh.TRANSFORM_3D
				multi.use_colors=true
				multi.mesh=IRQualityMesh.performance(meshes[name_key]) if profile==2 else meshes[name_key]
				multi.instance_count=subset.size()
				for i in range(subset.size()):
					multi.set_instance_transform(i,subset[i])
					multi.set_instance_color(i,shades[i])
				banks.append(multi)
			else:
				if profile==2 and (tree or name_key=="giant_fern"):
					var low: MultiMesh=MultiMesh.new()
					low.transform_format=MultiMesh.TRANSFORM_3D
					low.use_colors=true
					low.mesh=IRQualityMesh.performance(meshes[name_key])
					low.instance_count=transforms.size()
					for n in range(transforms.size()):
						var pose: Transform3D=transforms[n]
						pose.origin-=instance.position
						low.set_instance_transform(n,pose)
						low.set_instance_color(n,colors[n] if n<colors.size() else Color.WHITE)
					banks.append(low)
				else: banks.append(instance.multimesh)
		quality_batches.append({"node":instance,"banks":banks,"small":small,"tree":tree,"sky":sky_prop,"hero":name_key=="elder_gate"})
	batches.clear()

func apply_quality(profile: int) -> void:
	profile=clampi(profile,0,2)
	if tea_bend!=null: tea_bend.apply_quality(profile)
	if atmosphere!=null:
		atmosphere.apply_quality(profile)
	if life!=null:
		life.apply_quality(profile)
	if magic!=null: magic.apply_quality(profile)
	for flow in fountain_flows:
		flow.apply_quality(profile)
	for batch in quality_batches:
		var node: MultiMeshInstance3D=batch.node
		node.multimesh=batch.banks[profile]
		node.visible=true
		node.lod_bias=[1.0,.65,.4][profile]
		if batch.hero:
			node.lod_bias=[1.8,1.2,.75][profile]
		if batch.sky:
			node.visibility_range_end=900
		elif batch.small:
			node.visibility_range_end=[75.0,65.0,48.0][profile]
		elif batch.tree:
			node.visibility_range_end=[205.0,185.0,145.0][profile]
		else:
			node.visibility_range_end=[330.0,300.0,260.0][profile]

func wisteria(p: Vector3, width: float, yaw: float) -> void:
	var quad: QuadMesh=QuadMesh.new()
	quad.size=Vector2(width,width*.97)
	var material: ShaderMaterial=IRArt.shader("wisteria")
	material.set_shader_parameter("albedo_tex",load("res://assets/textures/wisteria_blossoms.png"))
	var instance: MeshInstance3D=IRArt.part(self,quad,p,material)
	instance.rotation.y=yaw
	instance.visibility_range_end=100
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func flower_bed(p: Vector3, width: float, depth: float, kind: String, yaw: float = 0.0, raised: bool = false) -> void:
	var basis: Basis=Basis(Vector3.UP,yaw)
	var columns: int=maxi(ceili(width/1.3),1)
	var rows: int=maxi(ceili(depth/1.2),1)
	var step_x: float=width/columns
	var step_z: float=depth/rows
	if raised:
		place("garden_planter",p,yaw)
	for x in range(columns):
		for z in range(rows):
			var point: Vector3=p+basis*Vector3((x+.5)*step_x-width*.5+rng.randf_range(-.14,.14)*step_x,0,(z+.5)*step_z-depth*.5+rng.randf_range(-.12,.12)*step_z)
			if clear_of_road(point,1.0) and terrain.surface_height(point)>-4.0:
				if raised:
					point.y=terrain.surface_height(point)+.15
				place("flowers_"+kind,point,rng.randf()*TAU,rng.randf_range(.65,.80) if raised else rng.randf_range(.75,1.15),Color.WHITE,not raised)

func garden_path(a: Vector3, b: Vector3, width: float = 1.6) -> void:
	path_corridors.append({"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"radius":width*.5})
	var delta: Vector3=b-a
	delta.y=0
	var side: Vector3=delta.normalized().cross(Vector3.UP)*width*.5
	var steps: int=maxi(ceili(delta.length()),2)
	for i in range(steps):
		var p: Vector3=a.lerp(b,i/float(steps))
		var q: Vector3=a.lerp(b,(i+1)/float(steps))
		var points: Array[Vector3]=[p-side,p+side,q-side,q+side]
		for k in range(4):
			points[k].y=terrain.surface_height(points[k])+.035
		for k in [0,2,1,1,2,3]:
			paths.set_uv(Vector2((k%2)*width*.6,(i+(1 if k>1 else 0))*.6))
			paths.add_vertex(points[k])

func garden_plaza(center: Vector3, radius: float) -> void:
	var point: Vector2=Vector2(center.x,center.z)
	path_corridors.append({"a":point,"b":point,"radius":radius})
	for ring in range(6):
		for segment in range(64):
			var a: float=TAU*segment/64
			var b: float=TAU*(segment+1)/64
			var points: Array[Vector3]=[]
			for distance in [radius*ring/6.0,radius*(ring+1)/6.0]:
				for angle in [a,b]:
					var p: Vector3=center+Vector3(cos(angle),0,sin(angle))*distance
					p.y=terrain.surface_height(p)+.04
					points.append(p)
			for index in ([0,2,3] if ring==0 else [0,2,1,1,2,3]):
				paths.set_uv(Vector2(points[index].x,points[index].z)*.6)
				paths.add_vertex(points[index])
	var inlay: SurfaceTool=SurfaceTool.new()
	inlay.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a: float=i*TAU/8
		var ray: Vector3=Vector3(cos(a),0,sin(a))
		var side: Vector3=ray.cross(Vector3.UP)
		var points: Array[Vector3]=[center+ray*3.2,center+ray*3.75-side*.17,center+ray*4.8,center+ray*3.75+side*.17]
		for index in [0,1,2,0,2,3]:
			var p: Vector3=points[index]
			p.y=terrain.surface_height(p)+.055
			inlay.set_normal(Vector3.UP)
			inlay.add_vertex(p)
	IRArt.part(supports,inlay.commit(),Vector3.ZERO,IRArt.pbr(Color("a0b1bd"),.72))

func on_path(p: Vector3, margin: float = 0) -> bool:
	var point: Vector2=Vector2(p.x,p.z)
	for corridor in path_corridors:
		var nearest: Vector2=Geometry2D.get_closest_point_to_segment(point,corridor.a,corridor.b)
		if point.distance_to(nearest)<corridor.radius+margin:
			return true
	return false

func inside_building(p: Vector3, margin: float = 0) -> bool:
	for footprint in building_footprints:
		var local: Vector3=footprint.inverse*p
		if local.x>footprint.min.x-margin and local.x<footprint.max.x+margin and local.z>footprint.min.y-margin and local.z<footprint.max.y+margin:
			return true
	return false

func near_prop(p: Vector3, margin: float = 0) -> bool:
	for zone in prop_clearances:
		if Vector2(p.x,p.z).distance_to(zone.center)<zone.radius+margin:
			return true
	return false

func _supported_position(asset: String, p: Vector3, yaw: float, size: float) -> Vector3:
	var basis: Basis=Basis(Vector3.UP,yaw)
	var radius: float=({"pavilion":3.85,"fountain":2.95,"bench":1.55}[asset])*size
	var high: float=p.y
	var low: float=p.y
	for i in range(16):
		var a: float=i*TAU/16.0
		var offset: Vector3=basis*Vector3(cos(a)*radius,0,sin(a)*radius*(.36 if asset=="bench" else 1.0))
		var height: float=terrain.surface_height(p+offset)
		high=maxf(high,height)
		low=minf(low,height)
	if high-low<.18:
		return p
	p.y=high-(.18*size if asset=="pavilion" else .025)
	var depth: float=p.y-low+.25
	if asset=="bench":
		var platform: MeshInstance3D=IRArt.block(supports,Vector3(radius*2,depth,1.15*size),Vector3(p.x,p.y-depth*.5,p.z),support_material)
		platform.rotation.y=yaw
	else:
		var base: CylinderMesh=CylinderMesh.new()
		base.top_radius=radius
		base.bottom_radius=radius+.12
		base.height=depth
		base.radial_segments=32 if asset=="fountain" else 8
		var plinth: MeshInstance3D=IRArt.part(supports,base,Vector3(p.x,p.y-depth*.5,p.z),support_material)
		plinth.rotation.y=yaw
	if asset=="pavilion":
		for i in range(6):
			var point: Vector3=p+basis*Vector3(0,0,4.0*size+i*.42)
			var ground: float=terrain.surface_height(point)-.06
			var top: float=lerpf(p.y+.48*size,ground,(i+.5)/6.0)
			if top>ground:
				var step: MeshInstance3D=IRArt.block(supports,Vector3(1.8*size,top-ground,.48),Vector3(point.x,(top+ground)*.5,point.z),support_material)
				step.rotation.y=yaw
	return p

func _village() -> void:
	for i in [7,21,37,51,63]:
		for side in [-1.0,1.0]:
			if i==21 and side>0: continue
			var offset: float=side*((track.half_width_at(i)+8.7) if i==37 and side>0 else 23.5)
			var p: Vector3=on_roadside(i,offset)
			if IRTeaBendLayout.reserved(track,p): continue
			if terrain.surface_height(p)<-2.0:
				continue
			var yaw: float=yaw_facing_track(i,side>0)
			var style: int=(i/7+int(side))%3
			var house: String="bakery" if i==37 and side>0 else ["cottage_blue","cottage_rose","cottage_peach"][style]
			place(house,p,yaw,1.0 if house=="bakery" else rng.randf_range(.87,1.08))
			var toward: Vector3=-track.right_at(i)*side
			garden_path(on_roadside(i,side*7.9),p+toward*3.8)
			var house_basis: Basis=Basis(Vector3.UP,yaw)
			for edge in [-1.0,1.0]:
				place("garden_fence",p+house_basis*Vector3(edge*3.6,0,6.6),yaw,.95)
				flower_bed(p+house_basis*Vector3(edge*3.25,0,5.7),2.0,1.4,"rose",yaw,true)
			place("mailbox",p+house_basis*Vector3(-2.1,0,6.8),yaw,.95)
			place("tree_blossom",p+track.tangents[i]*(11.5 if style==2 else 9.2),yaw,.82)
			place("lantern",on_roadside(i,side*9.2),0,.9)
	# Flower-covered stone gateway and festoon flags define the starting village.
	place("arch",track.centers[0]-Vector3.UP*.6,atan2(-track.tangents[0].x,-track.tangents[0].z),1,Color.WHITE,false)
	var basis: Basis=Basis(Vector3.UP,atan2(-track.tangents[0].x,-track.tangents[0].z))
	for side in [-1.0,1.0]:
		wisteria(track.centers[0]+basis*Vector3(side*6.7,6.9,.93),4.2,basis.get_euler().y)
	_bunting(44)
	var elder: Vector3=track.centers[57]-Vector3.UP*.7
	var elder_yaw: float=atan2(-track.tangents[57].x,-track.tangents[57].z)
	place("elder_gate",elder,elder_yaw,1.0,Color.WHITE,false)
	var elder_basis: Basis=Basis(Vector3.UP,elder_yaw)
	for root_side in [-13.0,12.0]:
		var contact: Vector3=elder+elder_basis*Vector3(root_side,0,0)
		prop_clearances.append({"center":Vector2(contact.x,contact.z),"radius":3.8})
	var plaza: Vector3=on_roadside(28,track.half_width_at(28)+13.0)
	garden_plaza(plaza,10.6)
	place("fountain",plaza,0,.9)
	garden_path(on_roadside(28,8),plaza,3.2)
	for n in range(3):
		var p: Vector3=plaza+track.tangents[28]*(-6+n*6)+track.right_at(28)*8
		place("market_stall",p,yaw_facing_track(28,true),.9)
		place("bench",plaza+track.tangents[28]*(-5+n*5)-track.right_at(28)*5,yaw_facing_track(28,false),.9)
	var mill: Vector3=Vector3(37,0,30)
	place("windmill",mill,.5,1)
	mill.y=terrain.surface_height(mill)
	var rotor: MeshInstance3D=IRArt.part(self,meshes.windmill_rotor,mill+Vector3(0,10.5,2.7),null)
	rotor.add_to_group("wind_rotors")
	rotor.set_instance_shader_parameter("ir_motion_part",5)
	var rotor_bounds: AABB=rotor.mesh.get_aabb()
	var reach: float=Vector2(maxf(absf(rotor_bounds.position.x),absf(rotor_bounds.end.x)),maxf(absf(rotor_bounds.position.y),absf(rotor_bounds.end.y))).length()
	rotor.custom_aabb=AABB(Vector3(-reach,-reach,rotor_bounds.position.z),Vector3(reach*2,reach*2,rotor_bounds.size.z)).grow(.05)
	for i in range(0,66,5):
		var p: Vector3=on_roadside(i,10.4)
		place("hedge",p,atan2(-track.tangents[i].x,-track.tangents[i].z)+PI*.5,.92)

func _bunting(i: int) -> void:
	var root_node: Node3D=Node3D.new()
	add_child(root_node)
	root_node.position=track.centers[i]
	root_node.rotation.y=atan2(-track.tangents[i].x,-track.tangents[i].z)
	var metal: Material=IRArt.pbr(Color("e4cfaa"),.6)
	for x in [-9.2,9.2]:
		IRArt.tube(root_node,Vector3(x,-.8,0),Vector3(x,6.5,0),.09,metal,.045)
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(24):
		var x: float=-9.1+n*.77
		var y: float=5.35+pow(absf(x)/9.2,2)*1.1
		var color: Color=[Color("d782a8"),Color("e8bd6b"),Color("a0b9cc"),Color("b3a0cf")][n%4]
		for p in [Vector3(x,y,0),Vector3(x+.33,y-.64,.025),Vector3(x+.66,y,0)]:
			st.set_color(color)
			st.set_normal(Vector3.BACK)
			st.add_vertex(p)
	var mat: StandardMaterial3D=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	IRArt.part(root_node,st.commit(),Vector3.ZERO,mat)
	IRArt.bake(root_node)

func _grove() -> void:
	for n in range(20):
		var i: int=72+n*3
		for side in [-1.0,1.0]:
			var p: Vector3=on_roadside(i,side*(track.half_width_at(i)+rng.randf_range(4.5,9.0)))
			if terrain.surface_height(p)>-3.0:
				place("tree_willow" if n%4==0 else "tree_oak",p,rng.randf()*TAU,rng.randf_range(.85,1.28),Color("dfebd2"))
	for n in range(28):
		var i: int=rng.randi_range(70,133)
		var p: Vector3=on_roadside(i,(-1 if n%2 else 1)*rng.randf_range(9.2,15))
		if terrain.surface_height(p)>-4.0:
			place("mushroom",p,rng.randf()*TAU,rng.randf_range(.35,.85))
			place("fern",p+Vector3(1.0,0,.4),rng.randf()*TAU,.8)
	var i: int=78
	place("arch",track.centers[i]-Vector3.UP*.6,atan2(-track.tangents[i].x,-track.tangents[i].z),1,Color.WHITE,false)
	wisteria(track.centers[i]+Vector3.UP*6.8,6.0,atan2(-track.tangents[i].x,-track.tangents[i].z))

func _waterfall_and_bridge() -> void:
	add_child(IRWaterfallGarden.new(terrain))
	for i in range(142,201,7):
		place("tree_blossom",on_roadside(i,17),rng.randf()*TAU,rng.randf_range(.85,1.15))
	for p in [Vector3(-64.0,10.8,-1),Vector3(-63.5,10.8,15),Vector3(-67.0,3.9,-.5),Vector3(-66.3,3.9,15.5)]:
		place("fern",p,rng.randf()*TAU,.8,Color.WHITE,false)
	for n in range(6):
		var p: Vector3=Vector3(-51+(n/2)*7.0,0,-6+(n%2)*27)
		place("tree_willow" if n%2 else "tree_birch",p,rng.randf()*TAU,.8)
	for row in [4,7,10]:
		var profile: Vector2=IRWaterfallPath.PROFILE[row]
		for z in [-3.0,-.8,15.0,17.8]:
			var anchor: Vector3=IRWaterfallPath.cliff_point(profile,row,z)+Vector3(-.08,.10,0)
			place("hanging_ivy",anchor,-PI*.5,rng.randf_range(.65,.85),Color.WHITE,false)
	for n in range(7):
		var a: float=n*2.4
		var p: Vector3=Vector3(-41+cos(a)*(1.2+n*.28),21.64,7+sin(a)*(1.2+n*.28))
		place("water_lily",p,a,rng.randf_range(.7,1),Color.WHITE,false)
	var bridge: Vector3=Vector3(-52,IRWaterfallPath.creek_height(-52)+.4,IRWaterfallPath.creek_z(-52))
	place("footbridge",bridge,0,1,Color.WHITE,false)
	garden_path(bridge+Vector3(0,0,4.7),Vector3(-36,0,16),1.5)
	garden_path(bridge-Vector3(0,0,4.7),Vector3(-24,0,-8),1.5)
	flower_bed(Vector3(-49,0,17),9,4,"daisy")
	flower_bed(Vector3(-54,0,-3),8,3,"lavender")
	for p in [Vector3(-58,0,-1),Vector3(-56,0,16),Vector3(-37,0,15),Vector3(-34,0,2)]:
		place("flowering_bush",p,rng.randf()*TAU,1.0)
	place("pavilion",Vector3(-36,0,16),atan2(-16,-10),.9)
	_build_bridge()
func _build_bridge() -> void:
	var material: ShaderMaterial=ShaderMaterial.new()
	material.shader=load("res://shaders/storybook_surface.gdshader")
	material.set_shader_parameter("albedo_tex",load("res://assets/textures/fairy_masonry.png"))
	var deck: Node3D=Node3D.new()
	add_child(deck)
	for i in range(177,201,3):
		var j: int=(i+3)%IRTrack.SAMPLES
		var center: Vector3=track.centers[i].lerp(track.centers[j],.5)
		var segment: MeshInstance3D=IRArt.block(deck,Vector3(15.7,.65,1),center-Vector3.UP*.44,material)
		segment.basis=track.curb_basis(i)
		for side in [-1.0,1.0]:
			var p: Vector3=center+track.right_at(i)*side*7.6
			place("stone_rail",p,atan2(-track.tangents[i].x,-track.tangents[i].z)+PI*.5,.93,Color.WHITE,false)
	# Open arches below the deck, with piers extending into the river.
	var center: Vector3=track.centers[189]
	var basis: Basis=Basis(Vector3.UP,atan2(-track.tangents[189].x,-track.tangents[189].z))
	for side in [-1.0,1.0]:
		for n in range(3):
			var z: float=(n-1)*10.5
			var pier: MeshInstance3D=IRArt.block(deck,Vector3(1.1,10.0,1.3),center+basis*Vector3(side*7.2,-5.7,z-5.1),material)
			pier.basis=basis
			var st: SurfaceTool=SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for step in range(20):
				var a: float=PI*step/20
				var b: float=PI*(step+1)/20
				var low_a: Vector3=Vector3(side*7.2,-4.9+sin(a)*3.6,z+cos(a)*5.0)
				var low_b: Vector3=Vector3(side*7.2,-4.9+sin(b)*3.6,z+cos(b)*5.0)
				for face in [-.55,.55]:
					var offset: Vector3=Vector3(face,0,0)
					var points: Array[Vector3]=[low_a+offset,low_a+Vector3(0,.9,0)+offset,low_b+offset,low_b+Vector3(0,.9,0)+offset]
					for index in ([0,1,2,2,1,3] if face<0 else [2,3,0,0,3,1]):
						st.set_normal(Vector3(signf(face),0,0))
						st.set_uv(Vector2(points[index].z*.35,points[index].y*.35))
						st.add_vertex(points[index])
			var arc: MeshInstance3D=IRArt.part(deck,st.commit(),center,material)
			arc.basis=basis
	IRArt.bake(deck)

func _castle() -> void:
	var origin: Vector3=Vector3(-20,0,-35)
	origin.y=terrain.surface_height(origin)-.1
	building_footprints.append({"inverse":Transform3D(Basis.IDENTITY,origin).affine_inverse(),"min":Vector2(-14,-11),"max":Vector2(14,21)})
	var lowest: float=origin.y
	for x in [-13.5,13.5]:
		for z in [-10.5,10.5]:
			lowest=minf(lowest,terrain.surface_height(origin+Vector3(x,0,z))-.3)
	var foundation: ShaderMaterial=ShaderMaterial.new()
	foundation.shader=load("res://shaders/storybook_surface.gdshader")
	foundation.set_shader_parameter("albedo_tex",load("res://assets/textures/fairy_masonry.png"))
	foundation.set_shader_parameter("world_mapping",true)
	var stonework: Node3D=Node3D.new()
	add_child(stonework)
	var crag: MeshInstance3D=IRArt.part(stonework,meshes.castle_crag,Vector3(origin.x,lowest-2.0,origin.z),null)
	crag.scale.y=origin.y-lowest+2.0
	placements["castle_crag"]=1
	# Creepers and low crowns soften the exposed ledges without obscuring the gate.
	for side in [-1.0,1.0]:
		for n in range(3):
			var ledge: Vector3=Vector3(origin.x+side*(17.1-n*.45),lerpf(lowest-2.0,origin.y,.51+n*.08),origin.z-8+n*7)
			place("hanging_ivy",ledge,side*PI*.5,1.3,Color.WHITE,false)
		place("flowering_bush",origin+Vector3(side*15.3,0,8.5),side*.4,.7,Color.WHITE,false)
	place("castle_keep",origin,.0,1,Color.WHITE,false)
	_box_occluder(origin+Vector3.UP*7.0,0,Vector3(16.5,13.5,10.5))
	for x in [-10.0,10.0]:
		for z in [-6.3,6.3]:
			place("turret",origin+Vector3(x,-.2,z),0,1.02 if z>0 else .86,Color.WHITE,false)
	# Stone promenade links the hill to the course, with rose verges and an overlook.
	for n in range(10):
		if n in [4,5]:
			continue
		var p: Vector3=origin+Vector3((n-4.5)*3.8,0,14.5)
		place("stone_rail",p,0,1)
	flower_bed(origin+Vector3(0,0,18),28,5,"rose")
	garden_path(origin+Vector3(0,0,6),origin+Vector3(0,0,29),3.2)
	var stair_end: Vector3=origin+Vector3(0,0,18)
	var stair_bottom: float=terrain.surface_height(stair_end)
	for n in range(10):
		var p: Vector3=origin+Vector3(0,0,10.8+n*.8)
		var top: float=lerpf(origin.y,stair_bottom,(n+.5)/10.0)
		var bottom: float=terrain.surface_height(p)-.15
		var height: float=maxf(top-bottom,.12)
		p.y=bottom+height*.5
		IRArt.block(stonework,Vector3(4.0,height,.9),p,foundation)
	IRArt.bake(stonework)
	for side in [-1.0,1.0]:
		place("lantern",origin+Vector3(side*3.7,0,19.3),0,.9)
		place("flowering_bush",origin+Vector3(side*7,0,20),0,1.2)
	for i in range(204,259,9):
		for side in [-1.0,1.0]:
			var p: Vector3=on_roadside(i,side*14.5)
			if terrain.surface_height(p)>-2.5:
				place("tree_blossom",p,rng.randf()*TAU,.92)
				place("lantern",on_roadside(i,side*9.4),0,1)
	place("arch",track.centers[223]-Vector3.UP*.6,atan2(-track.tangents[223].x,-track.tangents[223].z),1,Color.WHITE,false)

func _gardens() -> void:
	for i in [267,283,302,317]:
		var yaw: float=yaw_facing_track(i,true)
		var p: Vector3=on_roadside(i,22)
		flower_bed(p,12,8,"lavender",yaw)
		flower_bed(on_roadside(i,-14),7,4,"daisy",yaw)
		place("tree_blossom",p+track.tangents[i]*8,rng.randf()*TAU,.95)
		for n in range(5):
			place("hedge",p+track.tangents[i]*(n-2)*2.6+track.right_at(i)*5,atan2(track.tangents[i].x,track.tangents[i].z),1)
	place("pavilion",on_roadside(289,33),yaw_facing_track(289,true),1.15)
	garden_path(on_roadside(289,8),on_roadside(289,33),2.6)
	place("rose_arbor",on_roadside(289,20),yaw_facing_track(289,true),1.20)
	place("fountain",on_roadside(281,29),.0,.72)
	for i in [272,286,300,314]:
		place("bench",on_roadside(i,13),yaw_facing_track(i,true),.95)
	for i in range(264,324,7):
		place("lantern",on_roadside(i,9.3),0,.88)

func _harbor() -> void:
	var forward: Vector3=(track.tangents[344]*Vector3(1,0,1)).normalized()
	var quay: Vector3=on_roadside(344,-22)
	var lighthouse_position: Vector3=quay-forward*17
	lighthouse_position.y=-4.2
	place("lighthouse",lighthouse_position,.2,.87,Color.WHITE,false)
	var dock: Node3D=Node3D.new()
	add_child(dock)
	var stone: ShaderMaterial=ShaderMaterial.new()
	stone.shader=load("res://shaders/storybook_surface.gdshader")
	stone.set_shader_parameter("albedo_tex",load("res://assets/textures/fairy_masonry.png"))
	stone.set_shader_parameter("world_mapping",true)
	var foundation: MeshInstance3D=IRArt.block(dock,Vector3(7,5.8,7),Vector3(lighthouse_position.x,-7.1,lighthouse_position.z),stone)
	foundation.rotation.y=atan2(forward.x,forward.z)
	var boat_shadows: PackedVector4Array=PackedVector4Array()
	for n in range(5):
		var p: Vector3=quay+forward*((n-2)*5.0)
		p.y=-7.1
		var pier: MeshInstance3D=IRArt.block(dock,Vector3(6.0,5.8,5.1),p,stone)
		pier.rotation.y=atan2(forward.x,forward.z)
		var boat_position: Vector3=on_roadside(344,-32)+forward*((n-2)*7.3)
		boat_position.y=-7.1
		place(["boat_coral","boat","boat_sage","boat","boat_coral"][n],boat_position,atan2(forward.x,forward.z)+.06*(n-2),.85,Color.WHITE,false)
		var boat_yaw: float=atan2(forward.x,forward.z)+.06*(n-2)
		boat_shadows.append(Vector4(boat_position.x,boat_position.z,cos(boat_yaw),sin(boat_yaw)))
		var bollard: Vector3=p-track.right_at(344)*2.6+Vector3.UP*2.95
		IRArt.tube(dock,bollard,bollard+Vector3.UP*.55,.13,IRArt.pbr(Color("665e67"),.5,.45))
		IRArt.tube(dock,bollard+Vector3.UP*.4,boat_position+Vector3.UP*1.0,.024,IRArt.pbr(Color("d5c4a1"),.95))
	IRArt.shader("ocean").set_shader_parameter("boat_shadows",boat_shadows)
	var shadow_center: Vector3=on_roadside(344,-32)
	IRArt.shader("ocean").set_shader_parameter("boat_shadow_center",Vector2(shadow_center.x,shadow_center.z))
	var boathouse_position: Vector3=quay+forward*20.0
	boathouse_position.y=-6.7
	place("boathouse",boathouse_position,atan2(-track.right_at(344).x,-track.right_at(344).z),1,Color.WHITE,false)
	var boardwalk: MeshInstance3D=IRArt.block(dock,Vector3(3.0,.28,8.0),quay+forward*15.1+Vector3.UP*(-4.25-quay.y),IRArt.timber())
	boardwalk.rotation.y=atan2(forward.x,forward.z)
	for n in range(12):
		var p: Vector3=on_roadside(344,-8.0-n*1.05)
		var top: float=lerpf(track.centers[344].y-.5,-4.2,n/11.0)
		var bottom: float=minf(terrain.surface_height(p)-.1,top-.25)
		var step: MeshInstance3D=IRArt.block(dock,Vector3(4.0,top-bottom,1.2),Vector3(p.x,(top+bottom)*.5,p.z),stone)
		step.rotation.y=atan2(track.right_at(344).x,track.right_at(344).z)
	IRArt.bake(dock)
	for along in [-8.0,7.8,11.0]:
		var p: Vector3=quay+forward*along+track.right_at(344)*1.5
		p.y=-4.19
		place("dock_supplies",p,atan2(track.right_at(344).x,track.right_at(344).z),.72,Color.WHITE,false)
	for i in range(327,380,5):
		if absi(i-344)<=4:
			continue
		place("stone_rail",on_roadside(i,-8.1),atan2(-track.tangents[i].x,-track.tangents[i].z)+PI*.5,.9)
	for i in [329,350,367,378]:
		var p: Vector3=on_roadside(i,18)
		place("cottage_blue" if i%2 else "cottage_peach",p,yaw_facing_track(i,true),.9)
		flower_bed(on_roadside(i,11.7),6,3,"rose",yaw_facing_track(i,true))
		place("lantern",on_roadside(i,9),0,.9)

func _roadside_gardens() -> void:
	for i in range(0,IRTrack.SAMPLES,2):
		for side in [-1.0,1.0]:
			if i>174 and i<203:
				continue
			var kind: String="lavender" if i>255 and i<324 else ("daisy" if (i/18)%2 else "rose")
			var patch: float=sin(i*.17+side*.8)+.5*sin(i*.41-side*1.3)
			for n in range(3):
				if patch<-.6 or (n>0 and patch<.15+n*.25):
					continue
				var offset: float=track.half_width_at(i)+2.1+n*1.15+sin(i*.10+n)*.35
				var p: Vector3=on_roadside(i,side*offset)+track.tangents[i]*rng.randf_range(-.75,.75)
				if terrain.surface_height(p)>-4.0:
					var flower: String="daisy" if kind=="rose" and rng.randf()<.16 else kind
					place("flowers_"+flower,p,rng.randf()*TAU,rng.randf_range(.72,1.12))
	for i in range(0,IRTrack.SAMPLES,5):
		for side in [-1.0,1.0]:
			var p: Vector3=on_roadside(i,side*rng.randf_range(12,18))
			if terrain.surface_height(p)>-3.5:
				place("fern",p,rng.randf()*TAU,rng.randf_range(.65,1.1))

func _woodland() -> void:
	# Uneven groves fill the view behind nearby detail; preserve sightlines to the castle and cliff.
	for n in range(170):
		var a: float=rng.randf()*TAU
		var r: float=rng.randf_range(25,137)
		var p: Vector3=Vector3(cos(a)*r,0,sin(a)*r*.87)
		if not clear_of_road(p,6.0) or terrain.surface_height(p)<-3 or on_path(p,.8):
			continue
		if Vector2(p.x+20,p.z+35).length()<26 or Vector2(p.x+57,p.z-6).length()<20:
			continue
		var species: String=["tree_oak","tree_birch","tree_cypress","tree_oak","tree_blossom","tree_birch"][n%6]
		place(species,p,rng.randf()*TAU,rng.randf_range(.85,1.45),Color.WHITE.lerp(Color("d2e1c1"),rng.randf()*.4))
		if n%3==0:
			place("flowering_bush",p+Vector3(2.2,0,1.7),rng.randf()*TAU,rng.randf_range(.8,1.3))
	# A few larger silhouettes make the island read as a place rather than a ring of props.
	for p in [Vector3(25,0,23),Vector3(8,0,-9),Vector3(-58,0,-38),Vector3(42,0,-32)]:
		place("tree_oak",p,.7,2.05)

func _butterflies() -> void:
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for wing in range(2):
			var center: Vector3=Vector3(side*.16,0,-.10 if wing==0 else .14)
			var span: Vector2=Vector2(.18,.22) if wing==0 else Vector2(.145,.145)
			for j in range(24):
				var a: float=TAU*j/24
				var b: float=TAU*(j+1)/24
				for point in [center,center+Vector3(cos(a)*span.x*side,0,sin(a)*span.y),center+Vector3(cos(b)*span.x*side,0,sin(b)*span.y)]:
					st.set_uv(Vector2(absf(point.x)/.35,(point.z+.32)/.63))
					st.set_normal(Vector3.UP)
					st.add_vertex(point)
	var mesh: ArrayMesh=st.commit()
	for zone in range(6):
		var transforms: Array[Transform3D]=[]
		var colors: Array[Color]=[]
		for n in range(16):
			var p: Vector3=on_roadside(zone*64+rng.randi_range(0,63),rng.randf_range(9,15)*(-1 if n%2 else 1))
			p.y=terrain.surface_height(p)+rng.randf_range(1.1,2.6)
			transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.25,.42)),p))
			colors.append([Color("e8b255"),Color("bca0e9"),Color("f0acc5")][n%3])
		IRArt.scatter(self,mesh,IRArt.shader("fairy_butterfly"),transforms,colors,70,false)
