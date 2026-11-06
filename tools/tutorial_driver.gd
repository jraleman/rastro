extends RefCounted

## Records the real workbench widgets and camera adapter, never assigned car poses.

signal keycap_requested(text: String)

const Catalog = preload("res://games/rastro/car_catalog.gd")
const Build = preload("res://games/rastro/car_build.gd")
const Garage = preload("res://games/rastro/garage_state.gd")
const Options = preload("res://games/rastro/rastro_options.gd")
const STEPS: Array[Dictionary] = [
	{"time": 0.0, "title": "Start with any of three cars",
		"body": "The Cube, Sonata and CR-V are all free. Each car keeps its own build."},
	{"time": 6.0, "title": "Find your color",
		"body": "Choose a named paint swatch. Paint changes the body, not the mechanical estimates."},
	{"time": 11.0, "title": "Build your wheels and tires",
		"body": "Choose wheel geometry, rim finish and tires. Tires trade road and loose-surface grip."},
	{"time": 16.5, "title": "Tune suspension and engine",
		"body": "Ride height, spring/damper and engine kits change fictional build estimates. No driving yet."},
	{"time": 23.0, "title": "Inspect your own work",
		"body": "Drag or use A/D to orbit; Q/E zooms. R frames the car without resetting any parts."},
	{"time": 28.0, "title": "Keep a portable build",
		"body": "Changes autosave. Export copies version 1 JSON; Cube Trials loading is still future work."},
]

var _done: Dictionary[String, bool] = {}
var _initial_yaw := 0.0
var _camera_moved := false
var _camera_zoomed := false


func configure(variant: String) -> bool:
	_done.clear()
	_camera_moved = false
	_camera_zoomed = false
	return variant == "solo"


func steps() -> Array[Dictionary]:
	return STEPS


func duration() -> float:
	return 34.0


func settings_overrides() -> Dictionary:
	var values := {"ui/scale": 1.0}
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		values[binding["key"]] = binding["default"]
	return values


func configure_session(session: Node) -> void:
	session.call("configure_single_player")


func start(scene: Node) -> void:
	var ui: Control = scene.get("_garage")
	_initial_yaw = float(ui.get("view").get("yaw"))
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2.ONE
	pointer.global_position = Vector2.ONE
	scene.get_viewport().push_input(pointer, true)


func update(scene: Node, time: float, _delta: float) -> void:
	if not bool(scene.get("_round_active")):
		return
	var ui: Control = scene.get("_garage")
	if _once("crv", time >= 1.5):
		_choose(ui, "car_id", "honda_crv")
	if _once("sonata", time >= 3.5):
		_choose(ui, "car_id", "hyundai_sonata")
	if _once("cube", time >= 5.5):
		_choose(ui, "car_id", "nissan_cube")
	if _once("paint", time >= 7.0):
		var paint := ui.get("_paint_buttons")["lagoon"] as Button
		_reveal(ui, paint)
		paint.pressed.emit()
	if _once("wheels", time >= 11.8):
		_choose(ui, "wheel_id", "five_spoke")
	if _once("rims", time >= 12.8):
		_choose(ui, "rim_finish_id", "bronze")
	if _once("tires", time >= 14.0):
		_choose(ui, "tire_id", "trail")
	if _once("springs", time >= 17.2):
		_choose(ui, "suspension_id", "rally")
	if _once("height", time >= 18.5):
		var height := ui.get("_controls")["ride_height_mm"] as HSlider
		_reveal(ui, height)
		height.value = 35
	if _once("engine", time >= 20.0):
		_choose(ui, "engine_id", "turbo")
	if _once("estimates", time >= 21.0):
		_reveal(ui, ui.get("_specs") as Control)
	if _once("orbit", time >= 23.4):
		_key(scene, KEY_D, true)
		keycap_requested.emit("D")
	if _once("orbit_stop", time >= 24.6):
		_key(scene, KEY_D, false)
		_camera_moved = not is_equal_approx(float(ui.get("view").get("yaw")), _initial_yaw)
	if _once("zoom", time >= 24.7):
		_key(scene, KEY_Q, true)
		keycap_requested.emit("Q")
	if _once("zoom_stop", time >= 25.1):
		_key(scene, KEY_Q, false)
		_camera_zoomed = float(ui.get("view").get("zoom")) < 1.0
	if _once("frame", time >= 26.0):
		_key(scene, KEY_R, true)
		_key(scene, KEY_R, false)
		keycap_requested.emit("R")
	if _once("export", time >= 29.0):
		var export_button := ui.get("_export") as Button
		_reveal(ui, export_button)
		export_button.pressed.emit()


func validate_finished(scene: Node) -> bool:
	_key(scene, KEY_D, false)
	_key(scene, KEY_Q, false)
	var expected := Build.factory("nissan_cube")
	expected.merge({
		"paint_id": "lagoon", "wheel_id": "five_spoke", "rim_finish_id": "bronze",
		"tire_id": "trail", "suspension_id": "rally", "ride_height_mm": 35, "engine_id": "turbo",
	}, true)
	var state: RefCounted = scene.get("_state")
	var ui: Control = scene.get("_garage")
	var saved := Garage.new()
	var text := ui.get("_transfer_text") as TextEdit
	var complete: bool = state.call("current_build") == expected \
		and saved.load_save(str(scene.get("garage_save_path"))) == OK \
		and saved.current_build() == expected \
		and Build.decode(text.text).get("build") == expected \
		and (ui.get("_transfer") as Window).visible \
		and _camera_moved and _camera_zoomed \
		and is_equal_approx(float(ui.get("view").get("zoom")), 1.0)
	for milestone: String in [
		"crv", "sonata", "cube", "paint", "wheels", "rims", "tires", "springs",
		"height", "engine", "estimates", "orbit", "orbit_stop", "zoom", "zoom_stop", "frame", "export",
	]:
		complete = complete and _done.get(milestone, false)
	if not complete:
		push_error("Rastro tutorial must customize, save, inspect and export the actual car.")
	(ui.get("_transfer") as Window).hide()
	return complete


func _choose(ui: Control, field: String, id: String) -> void:
	var picker: OptionButton
	var index: int
	if field == "car_id":
		picker = ui.get("_car_picker") as OptionButton
		index = Catalog.CAR_IDS.find(id)
	else:
		picker = ui.get("_controls")[field] as OptionButton
		index = Catalog.PARTS[field].keys().find(id)
	_reveal(ui, picker)
	picker.select(index)
	picker.item_selected.emit(index)


func _reveal(ui: Control, control: Control) -> void:
	(ui.get("_scroll") as ScrollContainer).ensure_control_visible(control)


func _key(scene: Node, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	scene.get_viewport().push_input(event, true)


func _once(key: String, ready: bool) -> bool:
	if not ready or _done.has(key):
		return false
	_done[key] = true
	return true
