class_name IRRaceTraffic
extends RefCounted
## Small deterministic lane planner. Physics still resolves every actual contact.
var peers: Array[IRVehicle]=[]
var lane: float=0
var lane_goal: float=0
var speed_limit: float=100
var decision: String="line"
var timer: float=0
var probe: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()

func _init() -> void:
	var box: BoxShape3D=BoxShape3D.new()
	box.size=Vector3(2.35,.7,3.45)
	probe.shape=box
	probe.collision_mask=4

func update(car: IRVehicle,space: PhysicsDirectSpaceState3D,dt: float) -> void:
	lane=move_toward(lane,lane_goal,dt*1.7)
	timer-=dt
	if timer>0: return
	timer=.15
	speed_limit=100
	var track: IRTrack=car.track
	var i: int=car.nearest
	var narrow: bool=i>=IRTrack.SHORTCUT_START-14 and i<=IRTrack.SHORTCUT_END+7
	var limit: float=minf(2.6,track.half_width_at(i)-1.35)
	var preferred: float=sin(car.slot*3.1)*1.1
	var candidates: Array[float]=[]
	candidates.assign([preferred,-limit,limit,0.0] if not narrow else [0.0])
	var forward: Vector3=(track.tangents[i]*Vector3(1,0,1)).normalized()
	var right: Vector3=track.right_at(i)
	var look: float=clampf(absf(car.speed)*1.05+7,10,30)
	var best_score: float=INF
	var best_lane: float=0
	for candidate in candidates:
		var score: float=absf(candidate-preferred)*.15+absf(candidate-lane)*.17
		var index: int=posmod(i+4,IRTrack.SAMPLES)
		var direction: Vector3=track.tangents[index]*Vector3(1,0,1)
		probe.transform=Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),track.centers[index]+track.right_at(index)*candidate+Vector3.UP*.8)
		if not space.intersect_shape(probe,1).is_empty(): score+=100
		for peer in peers:
			if not is_instance_valid(peer) or peer==car or peer.freeze: continue
			var relative: Vector3=peer.global_position-car.global_position
			var ahead: float=relative.dot(forward)
			if absf(relative.y)>2 or ahead< -4 or ahead>look: continue
			var other_lane: float=(peer.global_position-track.centers[i]).dot(right)
			if absf(other_lane-candidate)<2.55:
				score+=5.0*(1.0-maxf(ahead,0)/look)+2.0
		if score<best_score:
			best_score=score
			best_lane=candidate
	lane_goal=best_lane
	decision="pass" if absf(lane_goal-preferred)>1.0 else "line"
	if best_score>=100:
		speed_limit=0
		decision="blocked"
	# Brake while changing lanes, or when there is no safe passing corridor.
	for peer in peers:
		if not is_instance_valid(peer) or peer==car or peer.freeze: continue
		var relative: Vector3=peer.global_position-car.global_position
		var ahead: float=relative.dot(forward)
		var side: float=absf(relative.dot(right))
		if ahead>0 and ahead<look and side<2.4 and absf(relative.y)<2:
			var own_lane: float=(car.global_position-track.centers[i]).dot(right)
			if absf(lane_goal-own_lane)<2.2 or ahead<5.0:
				speed_limit=minf(speed_limit,maxf(0,peer.linear_velocity.dot(forward)+(ahead-4.5)*.8))
				decision="follow" if decision=="line" else "pass"
