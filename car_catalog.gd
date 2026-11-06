extends RefCounted

## Game-owned parts and deliberately fictional tuning, not manufacturer specifications.

const CAR_IDS: Array[String] = ["nissan_cube", "hyundai_sonata", "honda_crv"]
const CARS := {
	"nissan_cube": {
		"title": "Nissan Cube", "root": "NissanCube", "body": "BrownBodywork",
		"paint": Color("84674a"), "power_kw": 82.0, "mass_kg": 1200.0,
		"clearance_mm": 145.0, "tire_radius_m": 0.324,
	},
	"hyundai_sonata": {
		"title": "Hyundai Sonata", "root": "HyundaiSonata", "body": "BodyPaint",
		"paint": Color("e7ebf0"), "power_kw": 135.0, "mass_kg": 1490.0,
		"clearance_mm": 135.0, "tire_radius_m": 0.338,
	},
	"honda_crv": {
		"title": "Honda CR-V", "root": "HondaCRV", "body": "BodyPaint",
		"paint": Color("07387f"), "power_kw": 114.0, "mass_kg": 1500.0,
		"clearance_mm": 190.0, "tire_radius_m": 0.355,
	},
}
const PAINTS := {
	"factory": {"title": "Factory"},
	"chalk": {"title": "Chalk", "color": Color("e9e3cf")},
	"ember": {"title": "Ember", "color": Color("b74730")},
	"marigold": {"title": "Marigold", "color": Color("e4b54e")},
	"lagoon": {"title": "Lagoon", "color": Color("268d92")},
	"pine": {"title": "Pine", "color": Color("335d4d")},
	"ink": {"title": "Ink", "color": Color("24364e")},
	"lilac": {"title": "Lilac", "color": Color("a391c7")},
}
const WHEELS := {
	"stock": {"title": "Factory alloys", "mass_delta_kg": 0.0},
	"five_spoke": {"title": "Lightweight five-spoke", "mass_delta_kg": -4.8},
	"rally_disc": {"title": "Rally discs", "mass_delta_kg": -3.2},
}
const RIM_FINISHES := {
	"silver": {"title": "Silver", "color": Color("c7cdd1")},
	"graphite": {"title": "Graphite", "color": Color("3c444b")},
	"bronze": {"title": "Bronze", "color": Color("ad7942")},
	"white": {"title": "White", "color": Color("ecece4")},
}
const TIRES := {
	"road": {
		"title": "Road", "radius_scale": 1.0, "width_scale": 1.0,
		"road_grip": 1.0, "loose_grip": 1.0, "mass_delta_kg": 0.0,
	},
	"sport": {
		"title": "Sport - road grip", "radius_scale": 0.98, "width_scale": 1.08,
		"road_grip": 1.18, "loose_grip": 0.85, "mass_delta_kg": 2.0,
	},
	"trail": {
		"title": "Trail - loose-surface grip", "radius_scale": 1.06, "width_scale": 1.12,
		"road_grip": 0.94, "loose_grip": 1.25, "mass_delta_kg": 8.0,
	},
}
const SUSPENSIONS := {
	"stock": {"title": "Factory comfort", "spring_scale": 1.0, "damping_scale": 1.0},
	"street": {"title": "Street - firmer springs", "spring_scale": 1.30, "damping_scale": 1.20},
	"rally": {"title": "Rally - softer springs", "spring_scale": 0.90, "damping_scale": 1.25},
}
const ENGINES := {
	"stock": {"title": "Factory engine", "power_scale": 1.0, "mass_delta_kg": 0.0},
	"intake": {"title": "Intake + tune", "power_scale": 1.10, "mass_delta_kg": 3.0},
	"turbo": {"title": "Turbo kit", "power_scale": 1.32, "mass_delta_kg": 18.0},
}
const PARTS := {
	"paint_id": PAINTS, "wheel_id": WHEELS, "rim_finish_id": RIM_FINISHES,
	"tire_id": TIRES, "suspension_id": SUSPENSIONS, "engine_id": ENGINES,
}
const MIN_RIDE_HEIGHT_MM := -25
const MAX_RIDE_HEIGHT_MM := 60
const RIDE_HEIGHT_STEP_MM := 5


## A factory finish preserves the car's authored coat rather than repainting it.
static func paint_color(car_id: String, paint_id: String) -> Color:
	assert(CARS.has(car_id) and PAINTS.has(paint_id), "Unknown car or paint.")
	return CARS[car_id]["paint"] if paint_id == "factory" else PAINTS[paint_id]["color"]
