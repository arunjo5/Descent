class_name WeatherSystem
extends Node

enum Weather { CLEAR, RAIN, SNOW, FOG }

var current: int = Weather.CLEAR
var environment: Environment = null
var aircraft: Node3D = null

var _follow: Node3D
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _base_fog: float = 0.0025


func _ready() -> void:
	_follow = Node3D.new()
	_follow.name = "WeatherFollow"
	add_child(_follow)
	_build_rain()
	_build_snow()
	if environment != null:
		_base_fog = environment.fog_density
	_apply()


func _process(_delta: float) -> void:
	if aircraft != null:
		_follow.global_position = Vector3(
			aircraft.global_position.x,
			aircraft.global_position.y + 20.0,
			aircraft.global_position.z
		)


func set_weather(w: int) -> void:
	current = w
	_apply()


func cycle() -> void:
	set_weather((current + 1) % 4)


func describe() -> String:
	return ["Clear", "Rain", "Snow", "Fog"][current]


# Called when TimeOfDay changes so we can re-layer our fog multiplier on
# top of the new base.
func on_time_changed(_phase: int) -> void:
	if environment != null:
		_base_fog = environment.fog_density
		_apply_fog()


func _apply() -> void:
	_rain.emitting = (current == Weather.RAIN)
	_snow.emitting = (current == Weather.SNOW)
	_apply_fog()


func _apply_fog() -> void:
	if environment == null:
		return
	var mult := 1.0
	match current:
		Weather.CLEAR: mult = 1.0
		Weather.RAIN:  mult = 2.8
		Weather.SNOW:  mult = 3.0
		Weather.FOG:   mult = 14.0
	environment.fog_density = _base_fog * mult


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 1200
	_rain.lifetime = 2.2
	_rain.preprocess = 1.5
	_rain.local_coords = false
	_rain.emitting = false
	_rain.visibility_aabb = AABB(Vector3(-150, -120, -150), Vector3(300, 160, 300))
	_follow.add_child(_rain)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(70, 0, 70)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 28.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 1.0
	pm.scale_max = 1.0
	pm.color = Color(0.85, 0.9, 1.0, 0.75)
	_rain.process_material = pm

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.04, 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.9, 1.0, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.use_particle_trails = false
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	_rain.draw_pass_1 = mesh


func _build_snow() -> void:
	_snow = GPUParticles3D.new()
	_snow.amount = 28000
	_snow.lifetime = 3.5
	_snow.preprocess = 2.0
	_snow.local_coords = false
	_snow.emitting = false
	_snow.visibility_aabb = AABB(Vector3(-220, -80, -220), Vector3(440, 130, 440))
	_follow.add_child(_snow)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(95, 22, 95)
	pm.direction = Vector3(0.35, -1, 0).normalized()
	pm.spread = 45.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.9
	pm.scale_max = 1.9
	pm.color = Color(1.0, 1.0, 1.0, 0.95)
	_snow.process_material = pm

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.24, 0.24)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	_snow.draw_pass_1 = mesh
