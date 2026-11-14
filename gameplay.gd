extends GameShell

## A self-paced garage visit uses the shared pause/navigation, not racing round rules.

const Options = preload("res://games/rastro/rastro_options.gd")
const Build = preload("res://games/rastro/car_build.gd")
const GarageState = preload("res://games/rastro/garage_state.gd")
const GarageUI = preload("res://games/rastro/garage.gd")

@export var garage_save_path := GarageState.SAVE_PATH

var _state := GarageState.new()
var _garage: GarageUI
var _save_timer: Timer
var _held: Dictionary[StringName, bool] = {}
var _stick := Vector2.ZERO
var _pad_zoom := Vector2.ZERO
var _load_error := OK


func game_id() -> String:
	return Options.GAME_ID


func _prepare_session() -> void:
	GameSession.configure_single_player()
	super()


func _build_playfield() -> void:
	_load_error = _state.load_save(garage_save_path)
	_garage = GarageUI.new()
	_garage.name = "Garage"
	$HUD/Overlay.add_child(_garage)
	_garage.car_selected.connect(_select_car)
	_garage.part_changed.connect(_change_part)
	_garage.reset_requested.connect(_reset_car)
	_garage.export_requested.connect(func() -> void:
		_garage.show_export(Build.encode(_state.current_build())))
	_garage.import_submitted.connect(_import_build)
	_garage.pause_requested.connect(open_pause_menu)
	_garage.retry_requested.connect(_retry_save)
	_garage.modal_opened.connect(_release_controls)
	mount_hud_help(_garage.help_host)
	_hud_help_button.custom_minimum_size = Vector2.ONE * 66
	register_hud_controls(_garage.camera_controls, _garage._layout, false)
	register_hud_controls(_garage.view_help, _garage._layout, false)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(_persist)
	add_child(_save_timer)
	AudioManager.attach_ui_sounds(_garage)
	_refresh()
	_on_controls_changed()
	GameSession.controller_assignments_changed.connect(_release_controls)


func _configure_mode_ui() -> void:
	super()
	$HUD/Overlay/Margins.hide()
	_time_progress.hide()
	_callout.hide()
	_hint.hide()
	_play_again_button.text = "Return to garage"


func _activate_round() -> void:
	_garage.show()
	_garage.focus_car()


func _finish_round() -> void:
	_persist()
	_garage.hide()
	_release_controls()


func _update_round(delta: float, _time_left: float) -> void:
	if _garage.has_modal():
		return
	var orbit := Vector2(
		float(_held.get(Options.ORBIT_RIGHT, false)) - float(_held.get(Options.ORBIT_LEFT, false)),
		float(_held.get(Options.ORBIT_UP, false)) - float(_held.get(Options.ORBIT_DOWN, false)))
	orbit += Vector2(_deadzone(_stick.x), -_deadzone(_stick.y))
	if not orbit.is_zero_approx():
		_garage.view.orbit(orbit.limit_length() * delta * 1.5)
	var zoom_axis := float(_held.get(Options.ZOOM_OUT, false)) \
		- float(_held.get(Options.ZOOM_IN, false)) + _pad_zoom.y - _pad_zoom.x
	if not is_zero_approx(zoom_axis):
		_garage.view.zoom_by(exp(zoom_axis * delta))


func _handle_gameplay_input(event: InputEvent) -> void:
	if _garage.has_modal():
		return
	if event is InputEventKey:
		if event.echo:
			return
		for action: StringName in Options.HELD_ACTIONS:
			if event.is_action(action):
				_held[action] = event.pressed
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed(Options.RESET_VIEW):
			_garage.view.reset_view()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if event.device != _camera_device():
			return
		if event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_RIGHT_X:
				_stick.x = event.axis_value
			elif event.axis == JOY_AXIS_RIGHT_Y:
				_stick.y = event.axis_value
			else:
				return
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_pad_zoom.x = 1.0 if event.pressed else 0.0
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_pad_zoom.y = 1.0 if event.pressed else 0.0
		elif event.button_index == JOY_BUTTON_Y and event.pressed:
			_garage.view.reset_view()
		else:
			return
		get_viewport().set_input_as_handled()


func _select_car(id: String) -> void:
	var error := _state.select_car(id)
	if not error.is_empty():
		_garage.set_status(error, true)
		return
	_release_controls()
	_refresh()
	_queue_save()


func _change_part(field: String, value: Variant) -> void:
	var build := _state.current_build()
	build[field] = value
	var error := _state.apply_build(build)
	if not error.is_empty():
		_garage.set_status(error, true)
		return
	_refresh()
	_queue_save()


func _reset_car() -> void:
	var error := _state.apply_build(Build.factory(_state.selected_car))
	if not error.is_empty():
		_garage.set_status(error, true)
		return
	_refresh()
	_persist()


func _import_build(text: String) -> void:
	var decoded := Build.decode(text)
	var error: String = decoded["error"]
	if error.is_empty():
		error = _state.apply_build(decoded["build"])
	_garage.finish_import(error)
	if not error.is_empty():
		return
	_refresh()
	_persist()


func _refresh() -> void:
	_garage.refresh(_state.current_build(), _state.load_blocked)
	if _load_error != OK:
		_garage.set_status("Read-only factory preview. " + _state.last_problem, true)
	elif _state.dirty:
		_garage.set_status("Unsaved changes...")
	else:
		_garage.set_status("Garage saved." if FileAccess.file_exists(garage_save_path) \
			else "Factory garage. All parts are free; changes save automatically.")


func _queue_save() -> void:
	if _state.dirty and not _state.load_blocked:
		_save_timer.start()


func _persist() -> void:
	if is_instance_valid(_save_timer):
		_save_timer.stop()
	if not _state.dirty or _state.load_blocked:
		return
	var error := _state.save(garage_save_path)
	if is_instance_valid(_garage):
		_garage.set_status("Garage saved." if error == OK else _state.last_problem, error != OK)
	if error != OK:
		push_warning("Rastro: " + _state.last_problem)


func _retry_save() -> void:
	if _state.load_blocked:
		_load_error = _state.load_save(garage_save_path)
		_refresh()
	else:
		_persist()


func open_pause_menu() -> void:
	_release_controls()
	_persist()
	super()


func _on_controls_changed() -> void:
	super()
	_release_controls()
	if _garage != null:
		_garage.set_interface_scale(float(Settings.get_value("ui/scale")))


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key == "ui/scale" and _garage != null:
		_garage.set_interface_scale(float(Settings.get_value("ui/scale")))


func _release_controls() -> void:
	_held.clear()
	_stick = Vector2.ZERO
	_pad_zoom = Vector2.ZERO
	if _garage != null and _garage.view != null:
		_garage.view.release_contacts()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_controls()
		_persist()


func _exit_tree() -> void:
	_persist()


func _deadzone(value: float) -> float:
	var zone := clampf(Settings.controller_deadzone(), 0.0, 0.9)
	return signf(value) * maxf(0.0, absf(value) - zone) / (1.0 - zone)


func _camera_device() -> int:
	return GameSession.controller_device_for_player(PLAYER_ONE)


func _set_capture_inset(bottom: float) -> void:
	if _garage != null:
		_garage.offset_bottom = -maxf(bottom, 0.0)


func _describe_round_outcome(_one: int, _two: int) -> Dictionary:
	return {
		"result": "YOUR GARAGE", "subtitle": "Your cars and parts stay ready for the next visit.",
		"color": Color("e4b54e"),
	}


func _round_highlight_summary() -> String:
	return "Three free cars. One saved build per car. No competitions in this version."
