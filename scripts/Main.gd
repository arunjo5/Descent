extends Node3D

const RUNWAY_LENGTH := 400.0
const RUNWAY_WIDTH  := 30.0
const GROUND_SIZE   := 4000.0

enum CamMode { CHASE, SIDE }
var _cam_mode: int = CamMode.CHASE
var _camera_initialized: bool = false

var aircraft: AircraftController
var wind_system: WindSystem
var evaluator: LandingEvaluator
var hud: FlightHUD
var follow_camera: Camera3D
var time_of_day: TimeOfDay
var weather: WeatherSystem
var approach_lights: ApproachLights

var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_water()
	_build_runway()
	_build_approach_lights()
	_build_buildings()
	_build_control_tower()
	_build_wind_system()
	_build_aircraft()
	_build_camera()
	_build_evaluator()
	_build_hud()
	_build_time_and_weather()


func _process(delta: float) -> void:
	_update_follow_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("quit_game"):
		get_tree().quit()
	elif event.is_action_pressed("camera_toggle"):
		_cam_mode = (CamMode.SIDE if _cam_mode == CamMode.CHASE else CamMode.CHASE)
	elif event.is_action_pressed("debug_clean_approach"):
		_restart()
	elif event.is_action_pressed("debug_hard_landing"):
		_debug_hard_landing()
	elif event.is_action_pressed("debug_off_runway"):
		_debug_off_runway()
	elif event.is_action_pressed("debug_toggle_wind"):
		wind_system.toggle_strong()
	elif event.is_action_pressed("cycle_time_of_day"):
		time_of_day.cycle()
	elif event.is_action_pressed("cycle_weather"):
		weather.cycle()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var procedural := ProceduralSkyMaterial.new()
	procedural.sky_top_color = Color(0.35, 0.55, 0.85)
	procedural.sky_horizon_color = Color(0.75, 0.85, 0.95)
	procedural.ground_bottom_color = Color(0.15, 0.2, 0.18)
	procedural.ground_horizon_color = Color(0.6, 0.65, 0.55)
	procedural.sun_angle_max = 30.0
	procedural.sun_curve = 0.15
	sky.sky_material = procedural
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.82, 0.9)
	env.fog_density = 0.0025

	_world_environment = WorldEnvironment.new()
	_world_environment.environment = env
	add_child(_world_environment)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, -30, 0)
	_sun.light_energy = 1.05
	_sun.shadow_enabled = true
	add_child(_sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.42, 0.22)
	mat.roughness = 0.95
	ground.material_override = mat

	ground.position = Vector3(0, -0.01, 0)
	add_child(ground)


func _build_water() -> void:
	var water := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(500, 900)
	water.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.32, 0.45)
	mat.metallic = 0.35
	mat.roughness = 0.18
	water.material_override = mat

	water.position = Vector3(-400, 0.05, 100)
	add_child(water)


func _build_runway() -> void:
	var runway_root := Node3D.new()
	runway_root.name = "Runway"
	add_child(runway_root)

	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(RUNWAY_WIDTH, 0.1, RUNWAY_LENGTH)
	slab.mesh = slab_mesh

	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.18, 0.18, 0.2)
	asphalt.roughness = 0.9
	slab.material_override = asphalt
	runway_root.add_child(slab)

	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.95, 0.95, 0.9)
	dash_mat.emission_enabled = true
	dash_mat.emission = Color(0.95, 0.95, 0.9)
	dash_mat.emission_energy_multiplier = 0.15

	var dash_count := 9
	var dash_length := 12.0
	var dash_spacing := RUNWAY_LENGTH / float(dash_count)
	for i in dash_count:
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.5, 0.02, dash_length)
		dash.mesh = dm
		dash.material_override = dash_mat
		var z := -RUNWAY_LENGTH * 0.5 + dash_spacing * (i + 0.5)
		dash.position = Vector3(0, 0.07, z)
		runway_root.add_child(dash)

	for end_sign: float in [-1.0, 1.0]:
		for bar_i in 6:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.0, 0.02, 4.0)
			bar.mesh = bm
			bar.material_override = dash_mat
			var x := -RUNWAY_WIDTH * 0.5 + 3.5 + bar_i * (RUNWAY_WIDTH - 7.0) / 5.0
			var z := end_sign * (RUNWAY_LENGTH * 0.5 - 6.0)
			bar.position = Vector3(x, 0.07, z)
			runway_root.add_child(bar)

	for side: float in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.4, 0.02, RUNWAY_LENGTH - 6.0)
		edge.mesh = em
		edge.material_override = dash_mat
		edge.position = Vector3(side * (RUNWAY_WIDTH * 0.5 - 0.5), 0.07, 0)
		runway_root.add_child(edge)


func _build_approach_lights() -> void:
	approach_lights = ApproachLights.new()
	approach_lights.name = "ApproachLights"
	approach_lights.runway_length = RUNWAY_LENGTH
	add_child(approach_lights)


func _build_buildings() -> void:
	var terminal_mat := StandardMaterial3D.new()
	terminal_mat.albedo_color = Color(0.78, 0.78, 0.72)
	terminal_mat.roughness = 0.7

	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.15, 0.3, 0.45)
	window_mat.metallic = 0.5
	window_mat.roughness = 0.15
	window_mat.emission_enabled = true
	window_mat.emission = Color(0.2, 0.35, 0.5)
	window_mat.emission_energy_multiplier = 0.25

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.32, 0.32, 0.34)
	roof_mat.roughness = 0.85

	# Terminal on the +X side of the runway.
	var terminal := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(40, 14, 110)
	terminal.mesh = tm
	terminal.material_override = terminal_mat
	terminal.position = Vector3(85, 7, -20)
	add_child(terminal)

	var terminal_roof := MeshInstance3D.new()
	var trm := BoxMesh.new()
	trm.size = Vector3(42, 0.6, 112)
	terminal_roof.mesh = trm
	terminal_roof.material_override = roof_mat
	terminal_roof.position = Vector3(85, 14.3, -20)
	add_child(terminal_roof)

	var window_band_lower := MeshInstance3D.new()
	var wblm := BoxMesh.new()
	wblm.size = Vector3(0.4, 3.0, 100)
	window_band_lower.mesh = wblm
	window_band_lower.material_override = window_mat
	window_band_lower.position = Vector3(64.95, 4.0, -20)
	add_child(window_band_lower)

	var window_band_upper := MeshInstance3D.new()
	var wbum := BoxMesh.new()
	wbum.size = Vector3(0.4, 3.0, 100)
	window_band_upper.mesh = wbum
	window_band_upper.material_override = window_mat
	window_band_upper.position = Vector3(64.95, 9.5, -20)
	add_child(window_band_upper)

	# Two hangars on the -X side.
	var hangar_specs: Array[Vector3] = [
		Vector3(-75, 6, -90),
		Vector3(-75, 6, 70),
	]
	for spec in hangar_specs:
		var hangar := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(38, 12, 48)
		hangar.mesh = hm
		hangar.material_override = terminal_mat
		hangar.position = spec
		add_child(hangar)

		var door := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.3, 10, 32)
		door.mesh = dm
		door.material_override = roof_mat
		door.position = spec + Vector3(19.05, -1, 0)
		add_child(door)


func _build_control_tower() -> void:
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.82, 0.8, 0.74)
	base_mat.roughness = 0.7

	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.65, 0.65, 0.62)
	shaft_mat.roughness = 0.6

	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.2, 0.4, 0.55)
	cabin_mat.metallic = 0.4
	cabin_mat.roughness = 0.12
	cabin_mat.emission_enabled = true
	cabin_mat.emission = Color(0.25, 0.45, 0.6)
	cabin_mat.emission_energy_multiplier = 0.4

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.28, 0.28, 0.3)
	roof_mat.roughness = 0.85

	var tower_x := 70.0
	var tower_z := 215.0

	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(10, 6, 10)
	base.mesh = bm
	base.material_override = base_mat
	base.position = Vector3(tower_x, 3, tower_z)
	add_child(base)

	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 1.4
	sm.bottom_radius = 1.6
	sm.height = 22
	shaft.mesh = sm
	shaft.material_override = shaft_mat
	shaft.position = Vector3(tower_x, 17, tower_z)
	add_child(shaft)

	var cabin := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.6
	cm.bottom_radius = 3.0
	cm.height = 4
	cabin.mesh = cm
	cabin.material_override = cabin_mat
	cabin.position = Vector3(tower_x, 30, tower_z)
	add_child(cabin)

	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.0
	rm.bottom_radius = 3.8
	rm.height = 1.8
	roof.mesh = rm
	roof.material_override = roof_mat
	roof.position = Vector3(tower_x, 32.9, tower_z)
	add_child(roof)


func _build_wind_system() -> void:
	wind_system = WindSystem.new()
	wind_system.name = "WindSystem"
	add_child(wind_system)


func _build_aircraft() -> void:
	aircraft = AircraftController.new()
	aircraft.name = "Aircraft"
	aircraft.wind_system = wind_system
	add_child(aircraft)
	_build_aircraft_visual(aircraft)


func _build_aircraft_visual(parent: Node3D) -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.93, 0.94, 0.95)
	body_mat.metallic = 0.35
	body_mat.roughness = 0.28

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.12, 0.22, 0.42)
	accent_mat.roughness = 0.45

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.12, 0.12, 0.13)
	dark_mat.roughness = 0.6

	var engine_mat := StandardMaterial3D.new()
	engine_mat.albedo_color = Color(0.75, 0.76, 0.78)
	engine_mat.metallic = 0.6
	engine_mat.roughness = 0.25

	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.06, 0.12, 0.22)
	window_mat.metallic = 0.4
	window_mat.roughness = 0.12

	var fuselage := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.85
	fm.bottom_radius = 0.85
	fm.height = 9.0
	fuselage.mesh = fm
	fuselage.material_override = body_mat
	fuselage.rotation_degrees = Vector3(90, 0, 0)
	fuselage.position = Vector3(0, 0, 0)
	parent.add_child(fuselage)

	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.05
	nm.bottom_radius = 0.85
	nm.height = 1.8
	nose.mesh = nm
	nose.material_override = body_mat
	nose.rotation_degrees = Vector3(-90, 0, 0)
	nose.position = Vector3(0, 0, -5.4)
	parent.add_child(nose)

	var tailcone := MeshInstance3D.new()
	var tcm := CylinderMesh.new()
	tcm.top_radius = 0.2
	tcm.bottom_radius = 0.85
	tcm.height = 1.6
	tailcone.mesh = tcm
	tailcone.material_override = body_mat
	tailcone.rotation_degrees = Vector3(90, 0, 0)
	tailcone.position = Vector3(0, 0, 5.3)
	parent.add_child(tailcone)

	var cockpit := MeshInstance3D.new()
	var ckm := BoxMesh.new()
	ckm.size = Vector3(1.0, 0.5, 2.4)
	cockpit.mesh = ckm
	cockpit.material_override = window_mat
	cockpit.position = Vector3(0, 0.55, -3.2)
	parent.add_child(cockpit)

	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.12, 0.22, 0.42)
	stripe_mat.roughness = 0.4
	var stripe := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(0.05, 0.18, 9.5)
	stripe.mesh = stm
	stripe.material_override = stripe_mat
	stripe.position = Vector3(0.83, 0.15, 0)
	parent.add_child(stripe)
	var stripe2 := MeshInstance3D.new()
	stripe2.mesh = stm
	stripe2.material_override = stripe_mat
	stripe2.position = Vector3(-0.83, 0.15, 0)
	parent.add_child(stripe2)

	for i in 5:
		for side: float in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var win_mesh := BoxMesh.new()
			win_mesh.size = Vector3(0.05, 0.35, 0.5)
			w.mesh = win_mesh
			w.material_override = window_mat
			w.position = Vector3(side * 0.83, 0.55, -1.5 + i * 0.85)
			parent.add_child(w)

	for side: float in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wmesh := BoxMesh.new()
		wmesh.size = Vector3(4.6, 0.18, 1.6)
		wing.mesh = wmesh
		wing.material_override = body_mat
		wing.position = Vector3(side * 2.9, -0.2, 0.6)
		wing.rotation_degrees = Vector3(0, side * -22.0, side * -3.0)
		parent.add_child(wing)

		var flap_pivot := Node3D.new()
		flap_pivot.position = Vector3(side * 2.5, -0.22, 1.45)
		flap_pivot.rotation_degrees = Vector3(0, side * -22.0, 0)
		parent.add_child(flap_pivot)

		var flap := MeshInstance3D.new()
		var fpm := BoxMesh.new()
		fpm.size = Vector3(2.6, 0.09, 0.5)
		flap.mesh = fpm
		flap.material_override = dark_mat
		flap.position = Vector3(0, 0, 0.25)
		flap_pivot.add_child(flap)
		aircraft.flap_visuals.append(flap_pivot)

		var winglet := MeshInstance3D.new()
		var wlm := BoxMesh.new()
		wlm.size = Vector3(0.12, 0.7, 0.7)
		winglet.mesh = wlm
		winglet.material_override = accent_mat
		var wing_tip_z := 0.6 + 4.6 * 0.5 * sin(deg_to_rad(22.0))
		var wing_tip_x := side * (2.9 + 4.6 * 0.5 * cos(deg_to_rad(22.0)))
		winglet.position = Vector3(wing_tip_x, 0.0, wing_tip_z)
		parent.add_child(winglet)

	for side: float in [-1.0, 1.0]:
		var pylon := MeshInstance3D.new()
		var pym := BoxMesh.new()
		pym.size = Vector3(0.12, 0.5, 1.2)
		pylon.mesh = pym
		pylon.material_override = body_mat
		pylon.position = Vector3(side * 0.95, 0.3, 3.2)
		parent.add_child(pylon)

		var nacelle := MeshInstance3D.new()
		var nm2 := CylinderMesh.new()
		nm2.top_radius = 0.55
		nm2.bottom_radius = 0.55
		nm2.height = 1.9
		nacelle.mesh = nm2
		nacelle.material_override = engine_mat
		nacelle.rotation_degrees = Vector3(90, 0, 0)
		nacelle.position = Vector3(side * 1.25, 0.55, 3.4)
		parent.add_child(nacelle)

		var intake := MeshInstance3D.new()
		var im := CylinderMesh.new()
		im.top_radius = 0.55
		im.bottom_radius = 0.45
		im.height = 0.25
		intake.mesh = im
		intake.material_override = dark_mat
		intake.rotation_degrees = Vector3(90, 0, 0)
		intake.position = Vector3(side * 1.25, 0.55, 2.45)
		parent.add_child(intake)

	var tail_fin := MeshInstance3D.new()
	var tfm := BoxMesh.new()
	tfm.size = Vector3(0.14, 2.2, 1.6)
	tail_fin.mesh = tfm
	tail_fin.material_override = body_mat
	tail_fin.position = Vector3(0, 1.3, 4.7)
	tail_fin.rotation_degrees = Vector3(0, 0, 0)
	parent.add_child(tail_fin)

	var fin_accent := MeshInstance3D.new()
	var fam := BoxMesh.new()
	fam.size = Vector3(0.15, 0.5, 1.4)
	fin_accent.mesh = fam
	fin_accent.material_override = accent_mat
	fin_accent.position = Vector3(0, 2.05, 4.8)
	parent.add_child(fin_accent)

	var hstab := MeshInstance3D.new()
	var hsm := BoxMesh.new()
	hsm.size = Vector3(3.6, 0.14, 1.0)
	hstab.mesh = hsm
	hstab.material_override = body_mat
	hstab.position = Vector3(0, 2.3, 4.9)
	parent.add_child(hstab)

	var gear_specs: Array[Vector3] = [
		Vector3(0, -0.95, -3.0),
		Vector3(-1.4, -0.95, 0.7),
		Vector3(1.4, -0.95, 0.7),
	]
	for spec in gear_specs:
		var strut := MeshInstance3D.new()
		var strut_mesh := CylinderMesh.new()
		strut_mesh.top_radius = 0.08
		strut_mesh.bottom_radius = 0.08
		strut_mesh.height = 0.6
		strut.mesh = strut_mesh
		strut.material_override = dark_mat
		strut.position = spec + Vector3(0, 0.3, 0)
		parent.add_child(strut)
		aircraft.gear_visuals.append(strut)

		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.25
		wheel_mesh.bottom_radius = 0.25
		wheel_mesh.height = 0.18
		wheel.mesh = wheel_mesh
		wheel.material_override = dark_mat
		wheel.rotation_degrees = Vector3(0, 0, 90)
		wheel.position = spec
		parent.add_child(wheel)
		aircraft.gear_visuals.append(wheel)


func _build_camera() -> void:
	follow_camera = Camera3D.new()
	follow_camera.name = "FollowCamera"
	follow_camera.current = true
	follow_camera.fov = 70.0
	add_child(follow_camera)


func _update_follow_camera(delta: float) -> void:
	if aircraft == null:
		return
	var target_pos: Vector3
	var look_at_pos: Vector3 = aircraft.global_position

	if _cam_mode == CamMode.CHASE:
		var offset := aircraft.global_transform.basis * Vector3(0, 4.5, 18.0)
		target_pos = aircraft.global_position + offset
	else:
		target_pos = aircraft.global_position + Vector3(35, 6, 0)

	if not _camera_initialized:
		follow_camera.global_position = target_pos
		_camera_initialized = true
	else:
		var t := clampf(delta * 6.0, 0.0, 1.0)
		follow_camera.global_position = follow_camera.global_position.lerp(target_pos, t)
	follow_camera.look_at(look_at_pos, Vector3.UP)


func _build_evaluator() -> void:
	evaluator = LandingEvaluator.new()
	evaluator.name = "LandingEvaluator"
	evaluator.aircraft = aircraft
	add_child(evaluator)
	evaluator.aircraft_landed.connect(_on_aircraft_landed)


func _build_hud() -> void:
	hud = FlightHUD.new()
	hud.name = "FlightHUD"
	hud.aircraft = aircraft
	hud.wind_system = wind_system
	add_child(hud)


func _build_time_and_weather() -> void:
	time_of_day = TimeOfDay.new()
	time_of_day.name = "TimeOfDay"
	time_of_day.environment = _world_environment.environment
	time_of_day.sun = _sun
	add_child(time_of_day)

	weather = WeatherSystem.new()
	weather.name = "WeatherSystem"
	weather.environment = _world_environment.environment
	weather.aircraft = aircraft
	add_child(weather)

	time_of_day.time_changed.connect(weather.on_time_changed)
	time_of_day.time_changed.connect(approach_lights.on_time_of_day_changed)

	hud.time_of_day = time_of_day
	hud.weather = weather
	time_of_day.set_phase(TimeOfDay.Phase.DAY)


func _on_aircraft_landed(result: Dictionary) -> void:
	hud.show_landing_result(result)


func _restart() -> void:
	aircraft.reset_aircraft()
	evaluator.reset()
	hud.hide_landing_result()


func _debug_hard_landing() -> void:
	aircraft.reset_aircraft_at(Vector3(0, 6, 140), 60.0, -9.0, 0.0)
	evaluator.reset()
	hud.hide_landing_result()


func _debug_off_runway() -> void:
	aircraft.reset_aircraft_at(Vector3(80, 40, 350), 50.0, -3.0, 10.0)
	evaluator.reset()
	hud.hide_landing_result()
