extends RefCounted
## Close-range composition following the new road widths, with open sightlines and passages.
var world: IRFairytaleWorld

func build(island: IRFairytaleWorld) -> void:
	world=island
	var track: IRTrack=world.track
	for i in [10,17,24,31,45,66]:
		for side in [-1.0,1.0]:
			if side>0 and i in [24,31]: continue
			var p: Vector3=world.on_roadside(i,side*(track.half_width_at(i)+5.65))
			p.y=track.centers[i].y-.48
			var asset: String=["town_post","town_workshop","town_tea"][(i/7+int(side+1))%3]
			world.place(asset,p,world.yaw_facing_track(i,side>0),.97,Color.WHITE,false)
	# A second row and small lanes make the village deeper than a single line of houses.
	for i in [13,30,47,64]:
		var p: Vector3=world.on_roadside(i,-28)
		if IRTeaBendLayout.reserved(track,p): continue
		world.place("cottage_rose" if i%2 else "cottage_blue",p,world.yaw_facing_track(i,false)+.13,.9)
		world.garden_path(world.on_roadside(i,-track.half_width_at(i)-2.1),p+track.right_at(i)*4,1.5)
	for i in range(77,159,7):
		for side in [-1.0,1.0]:
			var p: Vector3=world.on_roadside(i,side*(track.half_width_at(i)+5.1))
			if not world.on_path(p,2.2):
				world.place("giant_fern",p,i*.7,.95+(i%3)*.12)
			var rock: Vector3=world.on_roadside(i+3,side*(track.half_width_at(i+3)+3.9))
			if not world.on_path(rock,2.0): world.place("moss_boulder",rock,i*.37,.75+(i%4)*.13)
	var midpoint: Vector3=track.shortcut[16]
	var direction: Vector3=(track.shortcut[18]-track.shortcut[14]).normalized()
	world.place("crystal_grotto",midpoint-Vector3.UP*.2,atan2(-direction.x,-direction.z),1,Color.WHITE,false)
	for n in range(18):
		var i: int=82+n*4
		var side: float=-1 if n%2 else 1
		var p: Vector3=world.on_roadside(i,side*(track.half_width_at(i)+2.6+n%3*.55))
		if not world.on_path(p,1.2): world.place("lantern_mushroom",p,n*1.6,.45+(n%4)*.12)
	for n in range(6):
		var p: Vector3=midpoint+track.right_at(108)*(3.4 if n%2 else -3.4)+direction*(n/2-1)*1.7
		p.y=midpoint.y-.15
		world.place("lantern_mushroom",p,n,.60+(n%3)*.14,Color.WHITE,false)
	var across: Vector3=direction.cross(Vector3.UP).normalized()
	for n in range(6):
		var p: Vector3=midpoint+across*(7.5 if n%2 else -7.5)+direction*(n/2-1)*4.3-Vector3.UP*1.0
		if world.clear_of_road(p,3.5): world.place("moss_boulder",p,n*.9,1.3,Color.WHITE,false)
	for n in range(7):
		var p: Vector3=world.on_roadside(332+n*5,-49-n%3*7)
		p.y=-8.5
		world.place("moss_boulder",p,n*1.3,2.0+(n%3)*.7,Color.WHITE,false)
	var crane: Vector3=world.on_roadside(344,-22)+track.tangents[344]*11
	crane.y=-4.18
	world.place("port_crane",crane,world.yaw_facing_track(344,false),1,Color.WHITE,false)
	_rope_bridge()
	world=null

func _rope_bridge() -> void:
	var root: Node3D=Node3D.new()
	world.add_child(root)
	var timber: StandardMaterial3D=StandardMaterial3D.new()
	timber.albedo_color=Color("9a8260")
	timber.roughness=.88
	timber.set_meta("palette_kind",21)
	var rope: Material=IRArt.pbr(Color("beab87"),.95)
	for side in [-1.0,1.0]:
		var last: Vector3=Vector3.ZERO
		for i in range(160,175):
			var base: Vector3=world.on_roadside(i,side*(world.track.half_width_at(i)+.35))
			var p: Vector3=base+Vector3.UP*(1.35+2.1*pow((i-167)/7.0,2))
			IRArt.tube(root,base+Vector3.UP*.08,p,.025,rope)
			if i>160:
				IRArt.tube(root,last,p,.037,rope)
				IRArt.tube(root,last-Vector3.UP*.68,p-Vector3.UP*.68,.024,rope)
			last=p
		for i in [160,174]:
			var base: Vector3=world.on_roadside(i,side*(world.track.half_width_at(i)+.65))
			IRArt.tube(root,base-Vector3.UP*.25,base+Vector3.UP*6.7,.16,timber,.13)
	for i in [160,174]:
		var p: Vector3=world.track.centers[i]+Vector3.UP*6.6
		var side: Vector3=world.track.right_at(i)*(world.track.half_width_at(i)+.85)
		IRArt.tube(root,p-side,p+side,.13,timber)
	IRArt.bake(root)
