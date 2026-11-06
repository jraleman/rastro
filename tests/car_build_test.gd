extends SceneTree

## Portable builds, mechanical effects and transactional saves without scenes or input.

const Catalog = preload("res://games/rastro/car_catalog.gd")
const Build = preload("res://games/rastro/car_build.gd")
const Garage = preload("res://games/rastro/garage_state.gd")

var _failures := PackedStringArray()
var _path := "user://rastro_build_test_%d.cfg" % Time.get_ticks_usec()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_builds()
	_test_rejected_builds()
	_test_mechanics()
	_test_garage()
	_test_refused_save()
	if FileAccess.file_exists(_path):
		_expect(DirAccess.remove_absolute(_path) == OK, "Remove only this test's save.")
	for failure in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Rastro car build and garage save tests passed.")
	quit(0 if _failures.is_empty() else 1)


func _test_builds() -> void:
	for id: String in Catalog.CAR_IDS:
		var build := Build.factory(id)
		_expect(Build.problem(build).is_empty(), "Every car starts as a valid free build.")
		var decoded := Build.decode(Build.encode(build))
		_expect(decoded.get("build") == build, "A portable build must round-trip exactly.")
	var independent := Build.factory(Catalog.CAR_IDS[0])
	independent["paint_id"] = "ember"
	_expect(Build.factory(Catalog.CAR_IDS[0])["paint_id"] == "factory",
		"Factory builds must not share mutable dictionaries.")


func _test_rejected_builds() -> void:
	for value: Variant in [null, [], 7, "res://car.tscn"]:
		_expect(not Build.problem(value).is_empty(), "Reject non-object build data.")
	for changes: Dictionary in [
		{"version": 2}, {"version": true}, {"format": "another-game"},
		{"car_id": "res://malicious.tscn"}, {"engine_id": "unlimited"},
		{"paint_id": Color.RED}, {"wheel_id": null}, {"tire_id": "unknown"},
		{"suspension_id": "unknown"}, {"rim_finish_id": "unknown"},
		{"ride_height_mm": true}, {"ride_height_mm": 1.5},
		{"ride_height_mm": -30}, {"ride_height_mm": 65},
		{"ride_height_mm": 6}, {"ride_height_mm": NAN},
		{"ride_height_mm": INF},
	]:
		var build := Build.factory(Catalog.CAR_IDS[0])
		build.merge(changes, true)
		_expect(not Build.problem(build).is_empty(), "Reject invalid build fields: %s" % changes)
	var incomplete := Build.factory(Catalog.CAR_IDS[0])
	incomplete.erase("engine_id")
	_expect(not Build.problem(incomplete).is_empty(), "Reject missing fields.")
	var extended := Build.factory(Catalog.CAR_IDS[0])
	extended["power_kw"] = 99999
	_expect(not Build.problem(extended).is_empty(), "Never trust imported performance claims.")
	for text: String in ["{", "", "[]", "x".repeat(Build.MAX_JSON_BYTES + 1)]:
		_expect(not str(Build.decode(text)["error"]).is_empty(), "Reject malformed or oversized JSON.")


func _test_mechanics() -> void:
	for id: String in Catalog.CAR_IDS:
		var build := Build.factory(id)
		var baseline := Build.specifications(build)
		build["paint_id"] = "lagoon"
		build["rim_finish_id"] = "bronze"
		_expect(Build.specifications(build) == baseline, "Paint and rim color cannot change handling.")
		build["engine_id"] = "turbo"
		var tuned := Build.specifications(build)
		_expect(tuned["power_kw"] > baseline["power_kw"]
			and tuned["power_per_tonne"] > baseline["power_per_tonne"],
			"Engine kits must change derived power, not only their label.")
		build["wheel_id"] = "five_spoke"
		_expect(Build.specifications(build)["mass_kg"] < tuned["mass_kg"],
			"Lightweight wheels reduce the actual derived mass.")
		build["tire_id"] = "trail"
		build["ride_height_mm"] = 60
		build["suspension_id"] = "rally"
		var trail := Build.specifications(build)
		_expect(trail["loose_grip"] > baseline["loose_grip"]
			and trail["road_grip"] < baseline["road_grip"],
			"Trail tires trade road grip for loose-surface grip.")
		_expect(trail["tire_radius_m"] > baseline["tire_radius_m"]
			and trail["clearance_mm"] > baseline["clearance_mm"] + 60,
			"Tire radius and ride height both affect ground clearance.")
		_expect(trail["spring_scale"] < baseline["spring_scale"]
			and trail["damping_scale"] > baseline["damping_scale"],
			"Suspension kits must carry distinct spring and damping factors.")


func _test_garage() -> void:
	var garage := Garage.new()
	for id: String in Catalog.CAR_IDS:
		var build := Build.factory(id)
		build["paint_id"] = "ember"
		build["engine_id"] = "intake"
		_expect(garage.apply_build(build).is_empty(), "Every car is editable immediately.")
	_expect(garage.save(_path) == OK and not garage.dirty, "Persist a complete garage.")
	var restored := Garage.new()
	_expect(restored.load_save(_path) == OK
		and restored.selected_car == garage.selected_car, "Restore the selected car.")
	for id: String in Catalog.CAR_IDS:
		restored.select_car(id)
		_expect(restored.current_build()["paint_id"] == "ember"
			and restored.current_build()["engine_id"] == "intake",
			"Each car must keep its own modifications.")
	var detached := restored.current_build()
	detached["engine_id"] = "turbo"
	_expect(restored.current_build()["engine_id"] == "intake", "Returned builds must be isolated.")
	var before := restored.current_build()
	detached["engine_id"] = "missing"
	_expect(not restored.apply_build(detached).is_empty()
		and restored.current_build() == before, "A failed import must not change any garage data.")
	var original := FileAccess.get_file_as_string(_path)
	_expect(restored.save(_path + "/blocked.cfg") != OK and restored.dirty,
		"A write failure must preserve unsaved changes for retry.")
	_expect(FileAccess.get_file_as_string(_path) == original,
		"A failed write must not damage the previous save.")
	_expect(restored.save(_path) == OK, "Retry after a write failure must succeed.")


func _test_refused_save() -> void:
	var config := ConfigFile.new()
	_expect(config.load(_path) == OK, "Load the test save before modifying it.")
	config.set_value("garage", "version", 99)
	_expect(config.save(_path) == OK, "Write a deliberately newer test save.")
	var original := FileAccess.get_file_as_string(_path)
	var garage := Garage.new()
	_expect(garage.load_save(_path) != OK and garage.load_blocked
		and not garage.last_problem.is_empty(), "Refuse a newer save with an explicit reason.")
	_expect(garage.save(_path) == ERR_UNAVAILABLE
		and FileAccess.get_file_as_string(_path) == original,
		"An unreadable save must never be replaced with factory defaults.")
	var invalid := Build.factory(Catalog.CAR_IDS[0])
	invalid["paint_id"] = "pine"
	_expect(not garage.apply_build(invalid).is_empty(), "A blocked garage cannot accept edits.")
	config.set_value("garage", "version", Garage.SAVE_VERSION)
	config.set_value("builds", Catalog.CAR_IDS[1], "{broken")
	config.save(_path)
	_expect(garage.load_save(_path) != OK and garage.load_blocked,
		"One broken car refuses the entire saved garage rather than partially restoring it.")
	DirAccess.remove_absolute(_path)
	_expect(garage.load_save(_path) == OK and not garage.load_blocked
		and garage.current_build() == Build.factory(Catalog.CAR_IDS[0]),
		"Deleting a damaged save allows a fresh factory garage on retry.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
