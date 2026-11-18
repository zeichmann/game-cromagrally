class_name IRWaterfallPath
extends RefCounted
## Shared geometry and height-field definitions keep the spring, creek and cliff connected.

const PROFILE: Array[Vector2]=[Vector2(-69.3,-9),Vector2(-69.3,-7),Vector2(-68.2,-4),Vector2(-68.1,2.6),Vector2(-68.0,3.4),Vector2(-65.0,3.7),Vector2(-65.2,9.6),Vector2(-65.0,10.4),Vector2(-61.8,10.8),Vector2(-61.4,17.9),Vector2(-61.2,18.6),Vector2(-58.8,19.0)]
const FLOW: Array[Vector3]=[Vector3(-61.6,18.6,7),Vector3(-61.9,16.4,7.1),Vector3(-62.2,13,7),Vector3(-62.4,11.1,7),Vector3(-64.0,10.9,7.1),Vector3(-65.5,10.55,7),Vector3(-65.8,8.0,7),Vector3(-66.1,4.05,7.2),Vector3(-67.4,3.9,7.3),Vector3(-68.4,3.6,7.3),Vector3(-69.0,.5,7.2),Vector3(-69.7,-4,7),Vector3(-69.9,-7,7)]

static func creek_height(x: float) -> float:
	return 18.6+clampf((x+61.3)/16.8,0,1)*3.0

static func creek_z(x: float) -> float:
	return 7.0+sin((x+44.5)*.18)

static func creek_width(x: float) -> float:
	return lerpf(2.7,1.1,clampf((x+61.3)/16.8,0,1))

static func cliff_point(profile: Vector2, row: float, z: float) -> Vector3:
	var edge: float=pow(absf(z-7)/15.0,3.0)
	var x: float=profile.x+edge*8.0+sin(z*.77+row*.53)*.30+sin(z*2.1+row*.31)*.12
	# Broad, connected outcrops are part of the cliff skin, not separate spheres.
	x-=1.9*exp(-pow((z+1.7)/3.1,2)-pow((profile.y-7.8)/4.4,2))
	x-=2.4*exp(-pow((z-16.3)/3.3,2)-pow((profile.y-13.0)/4.7,2))
	x-=1.7*exp(-pow((z-18.1)/2.6,2)-pow((profile.y-.9)/3.8,2))
	# Keep the eroded channel behind its water sheet, including the upper lip.
	var channel: float=1.0-smoothstep(3.3,4.4,absf(z-7))
	x=lerpf(x,maxf(x,profile.x+.06),channel)
	var y: float=profile.y-maxf(absf(z-7)-10,0.0)*.6+sin(z*1.7+row*.8)*.09
	return Vector3(x,y,z)

static func adjust_ground(p: Vector3, height: float) -> float:
	var plateau: float=smoothstep(-64,-59.0,p.x)*(1.0-smoothstep(-34,-26,p.x))*(1.0-smoothstep(10,22,absf(p.z-7)))
	height=lerpf(height,creek_height(p.x)+.70,plateau)
	var pond_distance: float=Vector2((p.x+41)*.95,(p.z-7)*.85).length()
	var rim: float=1.0-smoothstep(6.0,11.0,pond_distance)
	height=lerpf(height,maxf(height,22.1),rim)
	var extent: float=smoothstep(-63,-61,p.x)*(1.0-smoothstep(-44.5,-40,p.x))
	var distance: float=absf(p.z-creek_z(p.x))
	var half_width: float=creek_width(p.x)
	var bank: float=(1.0-smoothstep(half_width+1,half_width+4.5,distance))*extent
	height=lerpf(height,maxf(height,creek_height(p.x)+.6),bank)
	var creek: float=(1.0-smoothstep(half_width,half_width+1.2,distance))*extent
	height=lerpf(height,creek_height(p.x)-.65,creek)
	var pond: float=1.0-smoothstep(4.8,6.4,pond_distance)
	height=lerpf(height,20.8,pond)
	# The height field stays behind the vertical cliff skin and its stepped ledges.
	var edge_shift: float=pow(absf(p.z-7)/15.0,3.0)*8.0
	var local_x: float=p.x-edge_shift
	var cap: float=height
	if local_x<-67.0:
		cap=-9.4
	elif local_x<-63.8:
		cap=3.15
	elif local_x<-59.8:
		cap=10.1
	var cut: float=1.0-smoothstep(9.0,15.0,absf(p.z-7))
	return lerpf(height,minf(height,cap),cut)
