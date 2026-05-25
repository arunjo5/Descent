class_name FlightHUD
extends CanvasLayer

var aircraft: AircraftController = null
var wind_system: WindSystem = null
var time_of_day: TimeOfDay = null
var weather: WeatherSystem = null

var _alt_label: Label
var _spd_label: Label
var _vs_label: Label
var _thr_label: Label
var _pitch_label: Label
var _roll_label: Label
var _flap_label: Label
var _gear_label: Label
var _wind_label: Label
var _weather_label: Label
var _tod_label: Label
var _hint_label: Label

var _result_panel: PanelContainer
var _result_title: Label
var _result_score: Label
var _result_details: Label


func _ready() -> void:
	layer = 10
	_build_ui()


func _process(_delta: float) -> void:
	if aircraft == null:
		return

	_alt_label.text   = "ALT      %6.1f m"  % aircraft.get_altitude()
	_spd_label.text   = "SPD      %6.1f m/s" % aircraft.get_forward_speed()
	var vs := aircraft.get_vertical_speed()
	_vs_label.text    = "V/S      %+6.1f m/s" % vs
	_vs_label.modulate = Color(1, 0.4, 0.4) if vs < -6.0 else Color(1, 1, 1)
	_thr_label.text   = "THR      %3d %%" % int(round(aircraft.throttle * 100.0))
	_pitch_label.text = "PITCH    %+5.1f deg" % aircraft.get_pitch_deg()
	_roll_label.text  = "ROLL     %+5.1f deg" % aircraft.get_roll_deg()
	_flap_label.text  = "FLAPS    %s" % ("DOWN" if aircraft.flaps_deployed else "UP")
	_gear_label.text  = "GEAR     %s" % ("DOWN" if aircraft.gear_deployed else "UP")
	_gear_label.modulate = Color(0.6, 1.0, 0.6) if aircraft.gear_deployed else Color(1.0, 0.6, 0.4)

	if wind_system != null:
		_wind_label.text = "WIND     %s" % wind_system.describe()
	if weather != null:
		_weather_label.text = "WX       %s" % weather.describe()
	if time_of_day != null:
		_tod_label.text = "TOD      %s" % time_of_day.describe()


func show_landing_result(result: Dictionary) -> void:
	_result_panel.visible = true
	_result_title.text = result.label
	match result.label:
		"Perfect Landing":
			_result_title.modulate = Color(0.4, 1.0, 0.5)
		"Safe Landing":
			_result_title.modulate = Color(0.6, 1.0, 0.7)
		"Hard Landing":
			_result_title.modulate = Color(1.0, 0.85, 0.4)
		"Gear-Up Landing":
			_result_title.modulate = Color(1.0, 0.6, 0.3)
		"Missed Runway":
			_result_title.modulate = Color(1.0, 0.5, 0.5)
		_:
			_result_title.modulate = Color(1.0, 0.4, 0.4)

	_result_score.text = "Score: %d / 100" % result.score
	_result_details.text = (
		"Descent rate:   %.2f m/s\n" % result.descent_rate +
		"Forward speed:  %.2f m/s\n" % result.forward_speed +
		"Centerline:     %.2f m\n"   % result.centerline_offset +
		"Pitch:          %+.1f deg\n"   % result.pitch_deg +
		"Roll:           %+.1f deg\n"   % result.roll_deg +
		"Heading off:    %.1f deg\n"    % result.heading_misalign_deg +
		"Gear:           %s\n"       % ("DOWN" if result.gear_deployed else "UP") +
		"Flaps:          %s\n\n"     % ("DOWN" if result.flaps_deployed else "UP") +
		"Press R to try again."
	)


func hide_landing_result() -> void:
	_result_panel.visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var telemetry_panel := PanelContainer.new()
	telemetry_panel.position = Vector2(20, 20)
	telemetry_panel.add_theme_stylebox_override("panel", _make_hud_stylebox())
	root.add_child(telemetry_panel)

	var telemetry := VBoxContainer.new()
	telemetry.add_theme_constant_override("separation", 3)
	telemetry_panel.add_child(telemetry)

	_alt_label     = _make_telemetry_label()
	_spd_label     = _make_telemetry_label()
	_vs_label      = _make_telemetry_label()
	_thr_label     = _make_telemetry_label()
	_pitch_label   = _make_telemetry_label()
	_roll_label    = _make_telemetry_label()
	_flap_label    = _make_telemetry_label()
	_gear_label    = _make_telemetry_label()
	_wind_label    = _make_telemetry_label()
	_weather_label = _make_telemetry_label()
	_tod_label     = _make_telemetry_label()

	for lbl in [_alt_label, _spd_label, _vs_label, _thr_label,
				_pitch_label, _roll_label, _flap_label, _gear_label,
				_wind_label, _weather_label, _tod_label]:
		telemetry.add_child(lbl)

	var hint_panel := PanelContainer.new()
	hint_panel.anchor_top = 1.0
	hint_panel.anchor_bottom = 1.0
	hint_panel.offset_top = -92
	hint_panel.offset_bottom = -16
	hint_panel.offset_left = 20
	hint_panel.offset_right = 580
	hint_panel.add_theme_stylebox_override("panel", _make_hud_stylebox())
	root.add_child(hint_panel)

	_hint_label = Label.new()
	_hint_label.text = (
		"W/S - throttle   Up/Down - pitch   Left/Right - roll   A/D - yaw\n" +
		"F - flaps   G - gear   C - camera   R - restart   Esc - quit\n" +
		"T - time of day   Y - weather"
	)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_hint_label.add_theme_font_size_override("font_size", 14)
	hint_panel.add_child(_hint_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 22)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -8
	crosshair.offset_top = -16
	root.add_child(crosshair)

	_result_panel = PanelContainer.new()
	_result_panel.anchor_left = 0.5
	_result_panel.anchor_right = 0.5
	_result_panel.anchor_top = 0.5
	_result_panel.anchor_bottom = 0.5
	_result_panel.offset_left = -200
	_result_panel.offset_right = 200
	_result_panel.offset_top = -180
	_result_panel.offset_bottom = 180
	_result_panel.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, 0.92)
	sb.border_color = Color(0.9, 0.9, 1.0, 0.7)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_result_panel.add_theme_stylebox_override("panel", sb)

	var result_vbox := VBoxContainer.new()
	result_vbox.add_theme_constant_override("separation", 8)
	_result_panel.add_child(result_vbox)

	_result_title = Label.new()
	_result_title.add_theme_font_size_override("font_size", 32)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_vbox.add_child(_result_title)

	_result_score = Label.new()
	_result_score.add_theme_font_size_override("font_size", 22)
	_result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_score.add_theme_color_override("font_color", Color(1, 1, 1))
	result_vbox.add_child(_result_score)

	_result_details = Label.new()
	_result_details.add_theme_font_size_override("font_size", 16)
	_result_details.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	result_vbox.add_child(_result_details)

	root.add_child(_result_panel)


func _make_telemetry_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	return lbl


func _make_hud_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.09, 0.78)
	sb.border_color = Color(0.55, 0.65, 0.78, 0.55)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb
