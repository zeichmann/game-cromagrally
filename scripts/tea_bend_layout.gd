class_name IRTeaBendLayout
extends RefCounted
## Shared, deterministic coordinates for the road, stream, scenery and validation.
const INDEX: int=24
const HOUSE: Vector3=Vector3(-12.8,-.52,3.2)
const TREE: Vector3=Vector3(-17.6,-.70,-8.2)

static func pose(track: IRTrack) -> Transform3D:
	var forward: Vector3=track.tangents[INDEX]
	forward.y=0
	forward=forward.normalized()
	return Transform3D(Basis(forward.cross(Vector3.UP),Vector3.UP,-forward),track.centers[INDEX])

static func stream_z(x: float) -> float:
	return -3.2+1.65*sin(x*.125)+.6*sin(x*.28+.3)

static func stream_half_width(x: float) -> float:
	return 1.55+.20*sin(x*.17+.7)+.12*cos(x*.33)

static func water_y(x: float) -> float:
	return -1.65+.018*x+.08*sin(x*.11)-18.0*smoothstep(26.0,36.0,-x)

static func adjust_ground(track: IRTrack,p: Vector3,height: float) -> float:
	var frame: Transform3D=pose(track)
	var local: Vector3=frame.affine_inverse()*p
	if absf(local.x)>39 or absf(local.z+3.2)>11: return height
	var distance: float=absf(local.z-stream_z(local.x))
	var half_width: float=stream_half_width(local.x)
	var envelope: float=1-smoothstep(36,39,absf(local.x))
	var cut: float=(1-smoothstep(half_width-.15,half_width+2.8,distance))*envelope
	height=lerpf(height,minf(height,frame.origin.y+water_y(local.x)-.75),cut)
	# A conservative underlay stays below the denser, smooth bank mesh.
	return height-.45*(1-smoothstep(half_width+2.5,half_width+4.2,distance))*envelope

static func reserved(track: IRTrack,p: Vector3) -> bool:
	var local: Vector3=pose(track).affine_inverse()*p
	return local.x>-32 and local.x<14 and local.z>-19 and local.z<16
