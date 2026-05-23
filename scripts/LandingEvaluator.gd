class_name LandingEvaluator
extends Node

signal aircraft_landed(result: Dictionary)

@export var runway_center: Vector3 = Vector3(0, 0, 0)
@export var runway_length: float = 400.0
@export var runway_width: float = 30.0
@export var runway_heading_deg: float = 0.0

# Aircraft center y at which the wheels contact the runway top.
@export var touchdown_height: float = 1.25

@export var safe_descent_rate: float = 3.0
@export var hard_descent_rate: float = 6.5
@export var crash_descent_rate: float = 10.0
@export var max_safe_roll_deg: float = 8.0
@export var crash_roll_deg: float = 25.0
@export var max_safe_pitch_deg: float = 12.0
@export var min_landing_speed: float = 22.0
@export var max_landing_speed: float = 65.0
@export var max_heading_misalign_deg: float = 15.0

var aircraft: AircraftController = null

var _has_touched_down: bool = false


func _physics_process(_delta: float) -> void:
	if aircraft == null or _has_touched_down:
		return
	if aircraft.crashed or aircraft.landed:
		return

	if aircraft.get_altitude() <= touchdown_height:
		_has_touched_down = true
		var result := _evaluate_touchdown()
		_apply_post_touchdown(result)
		emit_signal("aircraft_landed", result)
		_print_metrics(result)


func reset() -> void:
	_has_touched_down = false


func _evaluate_touchdown() -> Dictionary:
	var vs := aircraft.get_vertical_speed()
	var descent_rate := -vs
	var fwd_speed := aircraft.get_forward_speed()
	var roll := aircraft.get_roll_deg()
	var pitch := aircraft.get_pitch_deg()
	var heading := aircraft.get_heading_deg()
	var pos := aircraft.global_position
	var centerline_offset := absf(pos.x - runway_center.x)
	var on_runway_x := centerline_offset <= runway_width * 0.5
	var on_runway_z := absf(pos.z - runway_center.z) <= runway_length * 0.5
	var on_runway := on_runway_x and on_runway_z
	var heading_misalign := absf(_signed_angle_diff(heading, runway_heading_deg))

	var label := "Safe Landing"
	var crashed := false

	if not on_runway:
		label = "Missed Runway"
		crashed = true
	elif descent_rate >= crash_descent_rate or absf(roll) >= crash_roll_deg:
		label = "Crash"
		crashed = true
	elif not aircraft.gear_deployed:
		label = "Gear-Up Landing"
		crashed = true
	elif descent_rate >= hard_descent_rate:
		label = "Hard Landing"
	elif (descent_rate <= 1.6
			and absf(roll) <= 3.0
			and centerline_offset <= 4.0
			and heading_misalign <= 4.0
			and fwd_speed >= min_landing_speed
			and fwd_speed <= max_landing_speed
			and aircraft.flaps_deployed):
		label = "Perfect Landing"

	var score := _calculate_score(
		descent_rate, fwd_speed, roll, pitch,
		centerline_offset, heading_misalign,
		aircraft.gear_deployed, aircraft.flaps_deployed,
		on_runway, label
	)

	return {
		"label": label,
		"crashed": crashed,
		"score": score,
		"descent_rate": descent_rate,
		"forward_speed": fwd_speed,
		"roll_deg": roll,
		"pitch_deg": pitch,
		"heading_misalign_deg": heading_misalign,
		"centerline_offset": centerline_offset,
		"on_runway": on_runway,
		"gear_deployed": aircraft.gear_deployed,
		"flaps_deployed": aircraft.flaps_deployed,
	}


func _calculate_score(
		descent_rate: float, fwd_speed: float,
		roll: float, pitch: float,
		centerline_offset: float, heading_misalign: float,
		gear: bool, flaps: bool,
		on_runway: bool, label: String
	) -> int:
	var score := 0

	if descent_rate <= safe_descent_rate:
		score += 25
	elif descent_rate <= hard_descent_rate:
		var t := 1.0 - (descent_rate - safe_descent_rate) / (hard_descent_rate - safe_descent_rate)
		score += int(round(t * 25.0))

	if centerline_offset <= 2.0:
		score += 20
	elif centerline_offset <= runway_width * 0.5:
		var t := 1.0 - centerline_offset / (runway_width * 0.5)
		score += int(round(t * 20.0))

	if fwd_speed >= min_landing_speed and fwd_speed <= max_landing_speed:
		score += 15
	elif fwd_speed > 0.0:
		var dist := 0.0
		if fwd_speed < min_landing_speed:
			dist = min_landing_speed - fwd_speed
		else:
			dist = fwd_speed - max_landing_speed
		var t := clampf(1.0 - dist / 20.0, 0.0, 1.0)
		score += int(round(t * 15.0))

	if heading_misalign <= max_heading_misalign_deg:
		var t := 1.0 - heading_misalign / max_heading_misalign_deg
		score += int(round(t * 15.0))

	if gear:
		score += 10

	var stability := 1.0
	stability -= clampf(absf(roll) / max_safe_roll_deg, 0.0, 1.0) * 0.5
	stability -= clampf(absf(pitch) / max_safe_pitch_deg, 0.0, 1.0) * 0.5
	stability = clampf(stability, 0.0, 1.0)
	score += int(round(stability * 10.0))

	if flaps:
		score += 5

	match label:
		"Crash":
			score = int(score * 0.15)
		"Missed Runway":
			score = int(score * 0.25)
		"Gear-Up Landing":
			score = int(score * 0.4)
		"Hard Landing":
			score = int(score * 0.7)

	if not on_runway:
		score = mini(score, 30)

	return clampi(score, 0, 100)


func _apply_post_touchdown(result: Dictionary) -> void:
	if result.crashed:
		aircraft.crashed = true
		aircraft.velocity = Vector3.ZERO
	else:
		aircraft.landed = true
		var v := aircraft.velocity
		v.y = 0.0
		aircraft.velocity = v * 0.5
	var p := aircraft.global_position
	p.y = touchdown_height
	aircraft.global_position = p


func _print_metrics(r: Dictionary) -> void:
	print("--- Touchdown ---")
	print("  Result:           %s" % r.label)
	print("  Score:            %d / 100" % r.score)
	print("  Descent rate:     %.2f m/s" % r.descent_rate)
	print("  Forward speed:    %.2f m/s" % r.forward_speed)
	print("  Centerline off:   %.2f m" % r.centerline_offset)
	print("  Pitch:            %.2f deg" % r.pitch_deg)
	print("  Roll:             %.2f deg" % r.roll_deg)
	print("  Heading misalign: %.2f deg" % r.heading_misalign_deg)
	print("  Gear deployed:    %s" % r.gear_deployed)
	print("  Flaps deployed:   %s" % r.flaps_deployed)
	print("-----------------")


func _signed_angle_diff(a: float, b: float) -> float:
	return fmod(a - b + 540.0, 360.0) - 180.0
