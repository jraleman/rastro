extends RefCounted

## The garage's actual configurable car, photographed like a workshop print.
const Helpers = preload("res://tools/cover_art_helpers.gd")
const Rig = preload("res://games/rastro/car_rig.gd")
const Build = preload("res://games/rastro/car_build.gd")


## Technical graph paper is intentionally different from Cube Trials' rally art.
static func design() -> Dictionary:
	return {
		"paper": Color("193c47"), "ink": Color("f4ddb1"), "accent": Color("64bcb6"),
		"motif": "blueprint", "camera": Vector3(51, 18, 0),
		"photo": Rect2(-10, 367, 1044, 500),
		"lettering": [
			{"text": "RASTRO", "at": Vector2(53, 260), "size": 238},
			{"text": "YOUR NEXT PROJECT.", "at": Vector2(59, 340), "size": 43, "font": "mono"},
			{"text": "BUILD IT YOUR WAY.", "at": Vector2(58, 976), "size": 42, "font": "mono"},
		],
	}


## A valid local build selects real catalogue parts; no saved car is read or edited.
static func build(parent: Node) -> Node:
	var root := Helpers.group(parent)
	var car := Rig.new()
	root.add_child(car)
	var configuration := Build.factory("nissan_cube")
	configuration["paint_id"] = "lagoon"
	configuration["wheel_id"] = "five_spoke"
	configuration["rim_finish_id"] = "bronze"
	car.configure(configuration)
	return root
