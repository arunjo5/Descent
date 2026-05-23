class_name AircraftController
extends Node3D

@export_group("Thrust & Drag")
@export var max_thrust: float = 80.0
@export var throttle_change_rate: float = 0.6
@export var base_drag: float = 0.02
@export var flap_drag: float = 0.03
@export var gear_drag: float = 0.015

@export_group("Lift & Gravity")
@export var gravity: float = 9.8
# lift_coef * cruise_speed^2 ~ gravity at ~47 m/s.
@export var lift_coefficient: float = 0.0045
@export var flap_lift_bonus: float = 0.0012
@export var stall_speed: float = 18.0
@export var max_speed: float = 95.0

@export_group("Control rates")
@export var pitch_rate: float = 0.9
@export var roll_rate: float = 1.7
@export var yaw_rate: float = 0.5
@export var angular_damping: float = 3.5

@export_group("Starting state")
@export var start_position: Vector3 = Vector3(0, 50, 700)
@export var start_speed: float = 52.0
@export var start_throttle: float = 0.55
@export var start_pitch_deg: float = -2.5

var throttle: float = 0.0
var target_throttle: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO

var flaps_deployed: bool = false
var gear_deployed: bool = true
var crashed: bool = false
var landed: bool = false

var wind_system: WindSystem = null

var gear_visuals: Array[Node3D] = []
var flap_visuals: Array[Node3D] = []


func _ready() -> void:
	reset_aircraft()


func reset_aircraft() -> void:
	reset_aircraft_at(start_position, start_speed, start_pitch_deg, 0.0)


func reset_aircraft_at(pos: Vector3, spd: float, pitch_deg: float, yaw_deg: float) -> void:
	var b := Basis()
	b = b.rotated(Vector3.UP, deg_to_rad(yaw_deg))
	b = b.rotated(b.x, deg_to_rad(pitch_deg))
	global_transform = Transform3D(b, pos)

	velocity = -b.z * spd
	angular_velocity = Vector3.ZERO
	throttle = start_throttle
	target_throttle = start_throttle
	flaps_deployed = false
	gear_deployed = true
	crashed = false
	landed = false

	_update_visual_toggles()


func _physics_process(delta: float) -> void:
	if landed or crashed:
		return
	_read_input(delta)
	_integrate_flight(delta)


func _read_input(delta: float) -> void:
	if Input.is_action_pressed("throttle_up"):
		target_throttle = clampf(target_throttle + throttle_change_rate * delta, 0.0, 1.0)
	if Input.is_action_pressed("throttle_down"):
		target_throttle = clampf(target_throttle - throttle_change_rate * delta, 0.0, 1.0)
	throttle = lerpf(throttle, target_throttle, clampf(delta * 4.0, 0.0, 1.0))

	var pitch_input := 0.0
	if Input.is_action_pressed("pitch_down"):
		pitch_input += 1.0
	if Input.is_action_pressed("pitch_up"):
		pitch_input -= 1.0

	var roll_input := 0.0
	if Input.is_action_pressed("roll_left"):
		roll_input -= 1.0
	if Input.is_action_pressed("roll_right"):
		roll_input += 1.0

	var yaw_input := 0.0
	if Input.is_action_pressed("yaw_left"):
		yaw_input -= 1.0
	if Input.is_action_pressed("yaw_right"):
		yaw_input += 1.0

	var target_angular := Vector3(
		pitch_input * pitch_rate,
		yaw_input * yaw_rate,
		-roll_input * roll_rate
	)
	angular_velocity = angular_velocity.lerp(target_angular, clampf(delta * 6.0, 0.0, 1.0))


func _integrate_flight(delta: float) -> void:
	var b := global_transform.basis
	b = b.rotated(b.x, angular_velocity.x * delta)
	b = b.rotated(b.y, angular_velocity.y * delta)
	b = b.rotated(b.z, angular_velocity.z * delta)
	b = b.orthonormalized()
	global_transform = Transform3D(b, global_position)

	angular_velocity = angular_velocity.lerp(Vector3.ZERO, clampf(delta * angular_damping * 0.25, 0.0, 1.0))

	var forward := -b.z
	var up_local := b.y
	var forward_speed := velocity.dot(forward)

	var thrust_force := forward * (throttle * max_thrust)

	var lift_coef := lift_coefficient
	if flaps_deployed:
		lift_coef += flap_lift_bonus
	var stall_factor := clampf(forward_speed / stall_speed, 0.0, 1.0)
	var lift_magnitude := lift_coef * forward_speed * forward_speed * stall_factor
	var lift_force := up_local * lift_magnitude

	var gravity_force := Vector3.DOWN * gravity

	var drag_coef := base_drag
	if flaps_deployed:
		drag_coef += flap_drag
	if gear_deployed:
		drag_coef += gear_drag
	var speed := velocity.length()
	var drag_force := Vector3.ZERO
	if speed > 0.01:
		drag_force = -velocity.normalized() * (drag_coef * speed * speed)

	var wind_vec := Vector3.ZERO
	if wind_system != null:
		wind_vec = wind_system.get_wind_vector()

	var acceleration := thrust_force + lift_force + gravity_force + drag_force
	velocity += acceleration * delta
	velocity += wind_vec * delta

	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	global_position += velocity * delta


func _input(event: InputEvent) -> void:
	if landed or crashed:
		return
	if event.is_action_pressed("toggle_flaps"):
		flaps_deployed = not flaps_deployed
		_update_visual_toggles()
	elif event.is_action_pressed("toggle_gear"):
		gear_deployed = not gear_deployed
		_update_visual_toggles()


func _update_visual_toggles() -> void:
	for g in gear_visuals:
		if is_instance_valid(g):
			g.visible = gear_deployed
	for f in flap_visuals:
		if is_instance_valid(f):
			var deg := 25.0 if flaps_deployed else 0.0
			f.rotation_degrees = Vector3(deg, 0.0, 0.0)


func get_altitude() -> float:
	return global_position.y

func get_forward_speed() -> float:
	return velocity.dot(-global_transform.basis.z)

func get_vertical_speed() -> float:
	return velocity.y

func get_pitch_deg() -> float:
	var forward := -global_transform.basis.z
	return rad_to_deg(asin(clampf(forward.y, -1.0, 1.0)))

func get_roll_deg() -> float:
	var right := global_transform.basis.x
	return rad_to_deg(asin(clampf(-right.y, -1.0, 1.0)))

func get_heading_deg() -> float:
	var forward := -global_transform.basis.z
	return rad_to_deg(atan2(forward.x, -forward.z))
