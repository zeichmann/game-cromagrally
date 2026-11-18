class_name IRProgress
extends RefCounted
## Ordered gate progression is independent of rendering, physics and assets.

var gate_count: int = 16
var laps_to_finish: int = 3
var next_gate: int = 1
var completed_laps: int = 0
var finished: bool = false
var finish_time: float = -1.0
var last_lap_time: float = 0.0
var lap_started_at: float = 0.0
var best_lap: float = INF
var gate_times: Dictionary={}
var last_gate_key: String=""

func cross_gate(gate: int, forward: bool, race_time: float) -> bool:
	if finished or not forward or gate != next_gate:
		return false
	last_gate_key="%d:%d"%[completed_laps,gate]
	gate_times[last_gate_key]=race_time
	if gate == 0:
		completed_laps += 1
		last_lap_time = race_time - lap_started_at
		best_lap = minf(best_lap, last_lap_time)
		lap_started_at = race_time
		if completed_laps >= laps_to_finish:
			finished = true
			finish_time = race_time
	next_gate = (next_gate + 1) % gate_count
	return true

func last_gate() -> int:
	return posmod(next_gate - 1, gate_count)

func ranking_score(track_fraction: float) -> float:
	if finished:
		return float(laps_to_finish) + 1.0 / (1.0 + finish_time)
	var base: float = float(last_gate()) / float(gate_count)
	var fraction: float = fposmod(track_fraction - base, 1.0)
	# A skipped gate cannot improve the score beyond its legal segment.
	return float(completed_laps) + base + minf(fraction, 0.999 / gate_count)
