class_name WindSystem
extends Node

@export var base_wind: Vector3 = Vector3(1.5, 0.0, 0.0)
@export var strong_wind: Vector3 = Vector3(7.0, 0.0, -2.5)
@export var gust_amplitude: float = 0.8
@export var gust_frequency: float = 0.35

var strong_mode: bool = false
var _time: float = 0.0


func _ready() -> void:
	var speed := randf_range(0.5, 2.0)
	var angle := randf_range(0.0, TAU)
	base_wind = Vector3(cos(angle) * speed, 0.0, sin(angle) * speed)


func _process(delta: float) -> void:
	_time += delta


func get_wind_vector() -> Vector3:
	var w := strong_wind if strong_mode else base_wind
	var gust := sin(_time * TAU * gust_frequency) * gust_amplitude
	return w + Vector3(gust * 0.6, 0.0, gust * 0.2)


func toggle_strong() -> void:
	strong_mode = not strong_mode
	print("[WindSystem] strong_mode = %s" % strong_mode)


func describe() -> String:
	var w := get_wind_vector()
	var speed := Vector2(w.x, w.z).length()
	var from := -Vector2(w.x, w.z)
	var deg := rad_to_deg(atan2(from.x, -from.y))
	if deg < 0.0:
		deg += 360.0
	var tag := "  [STRONG]" if strong_mode else ""
	return "%0.1f m/s from %03d deg%s" % [speed, int(deg), tag]
