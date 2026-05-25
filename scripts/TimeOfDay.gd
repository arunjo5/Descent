class_name TimeOfDay
extends Node

signal time_changed(phase: int)

enum Phase { DAWN, DAY, DUSK, NIGHT }

var current: int = Phase.DAY
var environment: Environment = null
var sun: DirectionalLight3D = null


func set_phase(p: int) -> void:
	current = p
	_apply()
	emit_signal("time_changed", p)


func cycle() -> void:
	set_phase((current + 1) % 4)


func describe() -> String:
	return ["Dawn", "Day", "Dusk", "Night"][current]


func _apply() -> void:
	if environment == null or sun == null:
		return
	match current:
		Phase.DAWN:
			sun.rotation_degrees = Vector3(-14, -110, 0)
			sun.light_color = Color(1.0, 0.82, 0.65)
			sun.light_energy = 1.0
			_set_sky(
				Color(0.42, 0.52, 0.72),
				Color(1.0, 0.72, 0.6),
				Color(0.13, 0.15, 0.17),
				Color(0.55, 0.48, 0.42),
				0.6,
				Color(0.95, 0.78, 0.66),
				0.0035,
				16.0,
				0.1
			)
		Phase.DAY:
			sun.rotation_degrees = Vector3(-62, -25, 0)
			sun.light_color = Color(1.0, 1.0, 0.98)
			sun.light_energy = 1.25
			_set_sky(
				Color(0.18, 0.42, 0.82),
				Color(0.68, 0.82, 0.95),
				Color(0.11, 0.15, 0.15),
				Color(0.5, 0.6, 0.58),
				0.85,
				Color(0.68, 0.8, 0.92),
				0.002,
				5.0,
				0.04
			)
		Phase.DUSK:
			sun.rotation_degrees = Vector3(-12, -60, 0)
			sun.light_color = Color(1.0, 0.86, 0.6)
			sun.light_energy = 1.05
			_set_sky(
				Color(0.38, 0.48, 0.68),
				Color(1.0, 0.78, 0.45),
				Color(0.12, 0.14, 0.16),
				Color(0.55, 0.52, 0.45),
				0.72,
				Color(0.85, 0.76, 0.6),
				0.0035,
				14.0,
				0.1
			)
		Phase.NIGHT:
			sun.rotation_degrees = Vector3(-65, 20, 0)
			sun.light_color = Color(0.55, 0.62, 0.85)
			sun.light_energy = 0.12
			_set_sky(
				Color(0.02, 0.035, 0.07),
				Color(0.05, 0.08, 0.13),
				Color(0.01, 0.01, 0.02),
				Color(0.04, 0.06, 0.09),
				0.16,
				Color(0.1, 0.14, 0.22),
				0.008,
				2.0,
				0.05
			)


func _set_sky(
		top: Color, horizon: Color, ground_bot: Color, ground_hor: Color,
		ambient: float, fog_color: Color, fog_density: float,
		sun_angle_max: float = 30.0, sun_curve: float = 0.15
	) -> void:
	if environment.sky != null:
		var mat := environment.sky.sky_material as ProceduralSkyMaterial
		if mat != null:
			mat.sky_top_color = top
			mat.sky_horizon_color = horizon
			mat.ground_bottom_color = ground_bot
			mat.ground_horizon_color = ground_hor
			mat.sun_angle_max = sun_angle_max
			mat.sun_curve = sun_curve
	environment.ambient_light_energy = ambient
	environment.fog_light_color = fog_color
	environment.fog_density = fog_density
