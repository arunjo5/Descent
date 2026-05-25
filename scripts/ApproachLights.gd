class_name ApproachLights
extends Node3D

@export var runway_length: float = 400.0
@export var station_count: int = 12
@export var first_station_offset: float = 12.0
@export var station_spacing: float = 18.0
@export var sequence_hz: float = 1.4
@export var wave_width: float = 2.8

var _materials: Array[StandardMaterial3D] = []
var _base_brightness: float = 0.4
var _peak_brightness: float = 3.5
var _time: float = 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	var threshold_z := runway_length * 0.5
	for i in station_count:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.3)
		mat.emission_energy_multiplier = _base_brightness
		_materials.append(mat)

		var z := threshold_z + first_station_offset + i * station_spacing
		for x_offset: float in [-3.0, 0.0, 3.0]:
			var marker := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.25
			cm.bottom_radius = 0.25
			cm.height = 0.4
			marker.mesh = cm
			marker.material_override = mat
			marker.position = Vector3(x_offset, 0.5, z)
			add_child(marker)


func _process(delta: float) -> void:
	_time += delta
	# Wave head moves from farthest station (n-1) down to threshold (0) at sequence_hz cycles/sec.
	var phase := fmod(_time * sequence_hz, 1.0)
	var head := (1.0 - phase) * float(station_count)
	for i in station_count:
		var dist := head - float(i)
		var brightness := _base_brightness
		if dist >= 0.0 and dist < wave_width:
			var glow := 1.0 - dist / wave_width
			brightness = lerpf(_base_brightness, _peak_brightness, glow)
		_materials[i].emission_energy_multiplier = brightness


func on_time_of_day_changed(phase: int) -> void:
	match phase:
		TimeOfDay.Phase.DAWN:
			_base_brightness = 1.2
			_peak_brightness = 4.0
		TimeOfDay.Phase.DAY:
			_base_brightness = 0.35
			_peak_brightness = 2.8
		TimeOfDay.Phase.DUSK:
			_base_brightness = 1.6
			_peak_brightness = 5.0
		TimeOfDay.Phase.NIGHT:
			_base_brightness = 2.5
			_peak_brightness = 7.0
