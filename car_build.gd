extends RefCounted

## Portable data only: never load resource paths or accept imported performance claims.

const Catalog = preload("res://games/rastro/car_catalog.gd")
const FORMAT := "dcs.car-build"
const VERSION := 1
const MAX_JSON_BYTES := 4096
const FIELDS := [
	"format", "version", "car_id", "paint_id", "wheel_id", "rim_finish_id",
	"tire_id", "suspension_id", "ride_height_mm", "engine_id",
]


## Canonical car ids are independent of Cube Trials' character-selection ids.
static func factory(car_id: String) -> Dictionary:
	assert(Catalog.CARS.has(car_id), "Unknown Rastro car: " + car_id)
	return {
		"format": FORMAT, "version": VERSION, "car_id": car_id,
		"paint_id": "factory", "wheel_id": "stock", "rim_finish_id": "silver",
		"tire_id": "road", "suspension_id": "stock", "ride_height_mm": 0,
		"engine_id": "stock",
	}


## Return an actionable error without partially accepting or coercing a build.
static func problem(value: Variant) -> String:
	if not value is Dictionary:
		return "A car build must be a JSON object."
	var build: Dictionary = value
	if build.size() != FIELDS.size():
		return "The build must contain exactly the version 1 car-build fields."
	for field: String in FIELDS:
		if not build.has(field):
			return "The build is missing '%s'." % field
	if not build["format"] is String or build["format"] != FORMAT:
		return "This is not a DCS car build."
	if not _integer(build["version"]) or build["version"] != VERSION:
		return "Unsupported car-build version. This garage reads version 1."
	if not build["car_id"] is String or not Catalog.CARS.has(build["car_id"]):
		return "Unknown car. Choose Nissan Cube, Hyundai Sonata or Honda CR-V."
	for field: String in Catalog.PARTS:
		if not build[field] is String or not Catalog.PARTS[field].has(build[field]):
			return "Unknown part for '%s'." % field
	var height: Variant = build["ride_height_mm"]
	if not _integer(height) or height < Catalog.MIN_RIDE_HEIGHT_MM \
		or height > Catalog.MAX_RIDE_HEIGHT_MM \
		or int(height) % Catalog.RIDE_HEIGHT_STEP_MM != 0:
		return "Ride height must be -25 to +60 mm, in 5 mm steps."
	return ""


## Both clipboard imports and saves pass through the same bounded validator.
static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_JSON_BYTES:
		return {"error": "Car builds must be at most 4 KB."}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"error": "Invalid JSON at line %d: %s" % [
			json.get_error_line(), json.get_error_message(),
		]}
	var error := problem(json.data)
	if not error.is_empty():
		return {"error": error}
	var build: Dictionary = json.data.duplicate(true)
	build["version"] = int(build["version"])
	build["ride_height_mm"] = int(build["ride_height_mm"])
	return {"build": build, "error": ""}


## Only choices are exported; consumers recompute tuning from their own adapter.
static func encode(build: Dictionary) -> String:
	assert(problem(build).is_empty(), "Cannot export an invalid car build.")
	return JSON.stringify(build, "\t", true)


## Garage estimates are observable now; actual driving belongs to future consumers.
static func specifications(build: Dictionary) -> Dictionary:
	assert(problem(build).is_empty(), "Cannot tune an invalid car build.")
	var car: Dictionary = Catalog.CARS[build["car_id"]]
	var wheel: Dictionary = Catalog.WHEELS[build["wheel_id"]]
	var tire: Dictionary = Catalog.TIRES[build["tire_id"]]
	var suspension: Dictionary = Catalog.SUSPENSIONS[build["suspension_id"]]
	var engine: Dictionary = Catalog.ENGINES[build["engine_id"]]
	var mass: float = car["mass_kg"] + wheel["mass_delta_kg"] \
		+ tire["mass_delta_kg"] + engine["mass_delta_kg"]
	var power: float = car["power_kw"] * engine["power_scale"]
	var tire_radius: float = car["tire_radius_m"] * tire["radius_scale"]
	return {
		"power_kw": power, "mass_kg": mass, "power_per_tonne": power * 1000.0 / mass,
		"road_grip": tire["road_grip"], "loose_grip": tire["loose_grip"],
		"spring_scale": suspension["spring_scale"],
		"damping_scale": suspension["damping_scale"],
		"tire_radius_m": tire_radius,
		"clearance_mm": car["clearance_mm"] + build["ride_height_mm"] \
			+ (tire_radius - float(car["tire_radius_m"])) * 1000.0,
	}


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value))
