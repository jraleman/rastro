extends SceneTree

## Real widgets, input adapters, portable dialogs, autosave, pause and protected loads.

const Catalog = preload("res://games/rastro/car_catalog.gd")
const Build = preload("res://games/rastro/car_build.gd")
const Garage = preload("res://games/rastro/garage_state.gd")
const Options = preload("res://games/rastro/rastro_options.gd")

var _failures := PackedStringArray()
var _path := "user://rastro_scene_test_%d.cfg" % Time.get_ticks_usec()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameCatalog.select(Options.GAME_ID)
	var manifest := GameCatalog.current()
	_expect(manifest != null and not manifest.uses_shell_round_rules
		and not manifest.supports_multiplayer and not manifest.has_store(),
		"Rastro must be an untimed solo garage, not a race or an economy.")
	var game := _create_game()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var ui: Control = game.get("_garage")
	var state: RefCounted = game.get("_state")
	_expect(bool(game.get("_round_active")) and (game.get_node("%RoundTimer") as Timer).is_stopped(),
		"The garage must stay open without a timer or result screen.")
	for index in Catalog.CAR_IDS.size():
		var picker := ui.get("_car_picker") as OptionButton
		picker.select(index)
		picker.item_selected.emit(index)
		_expect(state.get("selected_car") == Catalog.CAR_IDS[index]
			and ui.get("view").get("rig").get("car_id") == Catalog.CAR_IDS[index],
			"All three cars must be available immediately through the real selector.")
	var paints: Dictionary = ui.get("_paint_buttons")
	(paints["lagoon"] as Button).pressed.emit()
	for change: Dictionary in [
		{"field": "wheel_id", "index": 1}, {"field": "rim_finish_id", "index": 2},
		{"field": "tire_id", "index": 2}, {"field": "suspension_id", "index": 2},
		{"field": "engine_id", "index": 2},
	]:
		var picker := ui.get("_controls")[change["field"]] as OptionButton
		picker.select(change["index"])
		picker.item_selected.emit(change["index"])
	(ui.get("_controls")["ride_height_mm"] as HSlider).value = 60
	var modified: Dictionary = state.call("current_build")
	_expect(modified["paint_id"] == "lagoon" and modified["wheel_id"] == "five_spoke"
		and modified["engine_id"] == "turbo" and modified["ride_height_mm"] == 60,
		"Visible customization widgets must update the validated build.")
	_expect((ui.get("_specs") as Label).text.contains("150 kW"),
		"Mechanical controls must update the visible estimates.")
	await create_timer(0.45).timeout
	var restored := Garage.new()
	_expect(restored.load_save(_path) == OK and restored.current_build() == modified,
		"Autosave must persist the actual edited build, not only the selection.")
	await _test_transfer_dialogs(game, ui, modified)
	await _test_inputs(game, ui)
	await _test_pause(game, ui)
	game.free()
	await process_frame
	await _test_bad_load()
	if FileAccess.file_exists(_path):
		_expect(DirAccess.remove_absolute(_path) == OK, "Remove only this test's garage file.")
	await create_timer(0.2, true, false, true).timeout
	for failure in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Rastro garage scene and input tests passed.")
	quit(0 if _failures.is_empty() else 1)


func _create_game() -> Node:
	var game := (load("res://games/rastro/gameplay.tscn") as PackedScene).instantiate()
	game.set_script(load("res://games/rastro/tests/input_gameplay_fixture.gd"))
	game.set("garage_save_path", _path)
	return game


func _test_transfer_dialogs(game: Node, ui: Control, modified: Dictionary) -> void:
	var state: RefCounted = game.get("_state")
	(ui.get("_export") as Button).pressed.emit()
	var dialog := ui.get("_transfer") as ConfirmationDialog
	var text := ui.get("_transfer_text") as TextEdit
	_expect(dialog.visible and not text.editable
		and Build.decode(text.text).get("build") == modified, "Export must show the exact portable build.")
	dialog.hide()
	(ui.get("_import") as Button).pressed.emit()
	text.text = "{broken"
	dialog.confirmed.emit()
	_expect(dialog.visible and not (ui.get("_transfer_error") as Label).text.is_empty()
		and state.call("current_build") == modified,
		"Invalid imports must stay open with an error and preserve the garage.")
	var imported := Build.factory(Catalog.CAR_IDS[0])
	imported["paint_id"] = "ember"
	text.text = Build.encode(imported)
	dialog.confirmed.emit()
	_expect(not dialog.visible and state.call("current_build") == imported,
		"A valid import must replace and select its named car.")
	(ui.get("_reset") as Button).pressed.emit()
	var reset := ui.get("_reset_dialog") as ConfirmationDialog
	_expect(reset.visible and reset.get_cancel_button().has_focus(),
		"Destructive factory reset must ask, with Cancel focused.")
	reset.confirmed.emit()
	reset.hide()
	_expect(state.call("current_build") == Build.factory(Catalog.CAR_IDS[0]),
		"Confirmed reset restores only the selected car.")
	var picker := ui.get("_car_picker") as OptionButton
	picker.select(2)
	picker.item_selected.emit(2)
	_expect(state.call("current_build") == modified, "Resetting one car must keep another car's build.")
	await process_frame


func _test_inputs(game: Node, ui: Control) -> void:
	var view: Control = ui.get("view")
	view.grab_focus()
	var start := float(view.get("yaw"))
	_key(KEY_D, true)
	await create_timer(0.06).timeout
	_key(KEY_D, false)
	_expect(float(view.get("yaw")) > start, "Actual keyboard events must orbit the car.")
	var settings := get_root().get_node("Settings")
	var original := int(settings.call("binding_keycode", "controls/rastro_orbit_right"))
	settings.call("set_binding_key", "controls/rastro_orbit_right", KEY_Z, Options.GAME_ID)
	start = float(view.get("yaw"))
	_key(KEY_Z, true)
	await create_timer(0.06).timeout
	_key(KEY_Z, false)
	_expect(float(view.get("yaw")) > start, "Rebound camera keys must reach the same adapter.")
	settings.call("set_binding_key", "controls/rastro_orbit_right", original, Options.GAME_ID)
	start = float(view.get("yaw"))
	_pad_axis(40, JOY_AXIS_RIGHT_X, 1.0)
	await create_timer(0.06).timeout
	_expect(is_equal_approx(float(view.get("yaw")), start), "An unassigned gamepad must not inspect the car.")
	_pad_axis(41, JOY_AXIS_RIGHT_X, 1.0)
	await create_timer(0.06).timeout
	_pad_axis(41, JOY_AXIS_RIGHT_X, 0.0)
	_expect(float(view.get("yaw")) > start, "Assigned gamepad events must orbit with the real adapter.")
	var center := view.get_global_rect().get_center()
	start = float(view.get("yaw"))
	_touch(7, center, true)
	_drag(7, center + Vector2(30, 0), Vector2(30, 0))
	_touch(7, center + Vector2(30, 0), false)
	_expect(float(view.get("yaw")) < start, "A real GUI-routed touch drag must orbit the car.")
	var previous_zoom := float(view.get("zoom"))
	_touch(7, center - Vector2(40, 0), true)
	_touch(9, center + Vector2(40, 0), true)
	_drag(9, center + Vector2(80, 0), Vector2(40, 0))
	_touch(7, center - Vector2(40, 0), false)
	_touch(9, center + Vector2(80, 0), false)
	_expect(float(view.get("zoom")) < previous_zoom,
		"Two independent GUI-routed contacts must pinch-zoom without changing parts.")
	var before: Dictionary = (game.get("_state") as RefCounted).call("current_build")
	_key(KEY_R, true)
	_key(KEY_R, false)
	_expect(is_equal_approx(float(view.get("zoom")), 1.0)
		and (game.get("_state") as RefCounted).call("current_build") == before,
		"Frame car resets only the camera.")


func _test_pause(game: Node, ui: Control) -> void:
	_key(KEY_D, true)
	_key(KEY_ESCAPE, true)
	await process_frame
	_expect(paused and is_instance_valid(game.get("_pause_menu")),
		"Escape must open the real DCS pause overlay.")
	_expect((game.get("_held") as Dictionary).is_empty()
		and (ui.get("view").get("_touches") as Dictionary).is_empty(),
		"Pause must release held keys and touch contacts.")
	var restored := Garage.new()
	_expect(restored.load_save(_path) == OK
		and restored.current_build() == (game.get("_state") as RefCounted).call("current_build"),
		"Opening the menu must flush pending changes before leaving the garage.")
	(game.get("_pause_menu") as Node).call("go_back")
	await process_frame
	await process_frame
	_expect(not paused, "Closing the pause overlay resumes the garage.")
	_key(KEY_D, false)
	_key(KEY_ESCAPE, false)


func _test_bad_load() -> void:
	var config := ConfigFile.new()
	config.set_value("garage", "version", 99)
	_expect(config.save(_path) == OK, "Create a newer save fixture.")
	var original := FileAccess.get_file_as_string(_path)
	var game := _create_game()
	get_root().add_child(game)
	await process_frame
	var ui: Control = game.get("_garage")
	_expect((game.get("_state") as RefCounted).get("load_blocked")
		and (ui.get("_import") as Button).disabled
		and (ui.get("_status") as Label).text.begins_with("Read-only"),
		"A broken or newer save must visibly disable modification, not silently reset.")
	game.call("_change_part", "paint_id", "ember")
	game.free()
	await process_frame
	_expect(FileAccess.get_file_as_string(_path) == original,
		"Even a forced edit or scene exit must not overwrite an unreadable save.")


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	get_root().push_input(event, true)


func _pad_axis(device: int, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	get_root().push_input(event, true)


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	get_root().push_input(event, true)


func _drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	get_root().push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
