extends SceneTree

## The actual GLBs retain independent finishes, grounded tires and editable suspension.

const Catalog = preload("res://games/rastro/car_catalog.gd")
const Build = preload("res://games/rastro/car_build.gd")
const Rig = preload("res://games/rastro/car_rig.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for id: String in Catalog.CAR_IDS:
		_test_car(id)
	for failure in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Rastro car geometry tests passed.")
	quit(0 if _failures.is_empty() else 1)


func _test_car(id: String) -> void:
	var car := Rig.new()
	get_root().add_child(car)
	var factory := Build.factory(id)
	car.configure(factory)
	var original := car.local_bounds()
	var body := car.get("_body") as MeshInstance3D
	var source := body.mesh.surface_get_material(0) as StandardMaterial3D
	var original_color := source.albedo_color
	_expect(car.wheels.size() == 4 and original.size.x > 3.5,
		"Each car must use its complete original 3D assembly.")
	var other := Rig.new()
	get_root().add_child(other)
	other.configure(factory)
	var build := factory.duplicate(true)
	build["paint_id"] = "ember"
	build["wheel_id"] = "five_spoke"
	build["rim_finish_id"] = "bronze"
	build["tire_id"] = "trail"
	build["suspension_id"] = "rally"
	build["ride_height_mm"] = 60
	car.configure(build)
	var tire_rise: float = Catalog.CARS[id]["tire_radius_m"] * 0.06
	_expect(is_equal_approx(car.chassis.position.y, 0.060 + tire_rise),
		"Ride height must move the body without lifting the tire contacts.")
	_expect(source.albedo_color == original_color
		and (other.get("_body") as MeshInstance3D).get_surface_override_material(0) == null,
		"Painting one car must not mutate imported resources or another car.")
	for index in 4:
		var wheel := car.wheels[index]
		_expect(wheel.has_node("RastroWheel")
			and not (wheel.get_node(Rig.PREFIXES[index] + "AlloyRims") as MeshInstance3D).visible,
			"Aftermarket wheels must replace the visible design, not just its label.")
		var tire := wheel.get_node(Rig.PREFIXES[index] + "Tires") as MeshInstance3D
		var bounds := wheel.transform * tire.transform * tire.get_aabb()
		_expect(absf(bounds.position.y) < 0.006,
			"All four tires must remain grounded after resizing.")
	var high := car.chassis.position.y
	build["ride_height_mm"] = -25
	car.configure(build)
	_expect(car.chassis.position.y < high, "Lowering must visibly change the chassis position.")
	build["wheel_id"] = "rally_disc"
	car.configure(build)
	_expect(car.wheels[0].get_node("RastroWheel").get_child_count() == 3,
		"Rally discs must use their own geometry rather than five-spoke arms.")
	car.configure(factory)
	_expect(car.local_bounds().is_equal_approx(original)
		and body.get_surface_override_material(0) == null,
		"Factory reset must restore exact stock geometry and authored paint.")
	for index in 4:
		_expect(not car.wheels[index].has_node("RastroWheel"),
			"Switching wheels must release old aftermarket assemblies.")
	car.free()
	other.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
