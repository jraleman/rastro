extends RefCounted

## One build per car, committed atomically and never overwritten after a bad load.

const Catalog = preload("res://games/rastro/car_catalog.gd")
const Build = preload("res://games/rastro/car_build.gd")
const SAVE_PATH := "user://rastro_garage.cfg"
const SAVE_VERSION := 1
const MAX_SAVE_BYTES := 32768

var selected_car := Catalog.CAR_IDS[0]
var dirty := false
var load_blocked := false
var last_problem := ""
var _builds: Dictionary = {}


func _init() -> void:
	_factory_garage()


func _factory_garage() -> void:
	selected_car = Catalog.CAR_IDS[0]
	_builds.clear()
	for id: String in Catalog.CAR_IDS:
		_builds[id] = Build.factory(id)
	dirty = false


## Callers receive copies, so unvalidated UI edits cannot corrupt another car.
func current_build() -> Dictionary:
	return _builds[selected_car].duplicate(true)


func select_car(car_id: String) -> String:
	if not Catalog.CARS.has(car_id):
		return "Unknown garage car: " + car_id
	if selected_car != car_id:
		selected_car = car_id
		dirty = not load_blocked
	return ""


## A validated import replaces only its named car, including the current selection.
func apply_build(value: Variant) -> String:
	if load_blocked:
		return "The saved garage could not be read. Changes are disabled to protect it."
	var error := Build.problem(value)
	if not error.is_empty():
		return error
	var build: Dictionary = value.duplicate(true)
	build["version"] = int(build["version"])
	build["ride_height_mm"] = int(build["ride_height_mm"])
	selected_car = build["car_id"]
	_builds[selected_car] = build
	dirty = true
	return ""


## Validate everything before changing the in-memory garage.
func load_save(path := SAVE_PATH) -> Error:
	last_problem = ""
	if not FileAccess.file_exists(path):
		_factory_garage()
		load_blocked = false
		return OK
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _refuse_load(FileAccess.get_open_error(), "The garage file cannot be opened.")
	var size := file.get_length()
	file.close()
	if size > MAX_SAVE_BYTES:
		return _refuse_load(ERR_FILE_CORRUPT, "The garage file is larger than 32 KB.")
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		return _refuse_load(error, "The garage file is unreadable.")
	var version: Variant = config.get_value("garage", "version", null)
	if not version is int or version != SAVE_VERSION:
		return _refuse_load(ERR_FILE_UNRECOGNIZED, "Unsupported garage save version.")
	var selected: Variant = config.get_value("garage", "selected_car", null)
	if not selected is String or not Catalog.CARS.has(selected):
		return _refuse_load(ERR_FILE_CORRUPT, "The saved car selection is invalid.")
	var builds := {}
	for id: String in Catalog.CAR_IDS:
		var decoded := Build.decode(str(config.get_value("builds", id, "")))
		if not str(decoded["error"]).is_empty():
			return _refuse_load(ERR_FILE_CORRUPT, "%s: %s" % [id, decoded["error"]])
		var build: Dictionary = decoded["build"]
		if build["car_id"] != id:
			return _refuse_load(ERR_FILE_CORRUPT, "A saved build names the wrong car.")
		builds[id] = build
	_builds = builds
	selected_car = selected
	dirty = false
	load_blocked = false
	return OK


## The old save survives validation/write failures; failed loads prohibit writes.
func save(path := SAVE_PATH) -> Error:
	if load_blocked:
		last_problem = "Saving is disabled to protect the unreadable garage."
		return ERR_UNAVAILABLE
	var config := ConfigFile.new()
	config.set_value("garage", "version", SAVE_VERSION)
	config.set_value("garage", "selected_car", selected_car)
	for id: String in Catalog.CAR_IDS:
		var error := Build.problem(_builds[id])
		if not error.is_empty():
			last_problem = error
			return ERR_INVALID_DATA
		config.set_value("builds", id, Build.encode(_builds[id]))
	var temporary := path + ".saving"
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		last_problem = "Garage not saved: %s. Your previous save is unchanged." % error_string(error)
		if FileAccess.file_exists(temporary):
			var cleanup := DirAccess.remove_absolute(temporary)
			if cleanup != OK:
				push_warning("Rastro could not remove its staging file: " + error_string(cleanup))
		return error
	last_problem = ""
	dirty = false
	return OK


func _refuse_load(error: Error, message: String) -> Error:
	load_blocked = true
	last_problem = message + " Back up or delete this save from the main menu's Saves screen."
	return error
