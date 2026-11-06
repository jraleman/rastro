extends RefCounted

## Rebindable inspection keys; ordinary UI focus stays on arrows, Tab and Accept.

const GAME_ID := "rastro"
const ORBIT_LEFT := &"rastro_orbit_left"
const ORBIT_RIGHT := &"rastro_orbit_right"
const ORBIT_UP := &"rastro_orbit_up"
const ORBIT_DOWN := &"rastro_orbit_down"
const ZOOM_IN := &"rastro_zoom_in"
const ZOOM_OUT := &"rastro_zoom_out"
const RESET_VIEW := &"rastro_reset_view"
const HELD_ACTIONS: Array[StringName] = [
	ORBIT_LEFT, ORBIT_RIGHT, ORBIT_UP, ORBIT_DOWN, ZOOM_IN, ZOOM_OUT,
]
const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": "controls/rastro_orbit_left", "action": ORBIT_LEFT, "default": KEY_A,
		"title": "Orbit left", "description": "Inspect the car from the left.",
		"heading": "Garage camera", "player": 0,
	},
	{
		"key": "controls/rastro_orbit_right", "action": ORBIT_RIGHT, "default": KEY_D,
		"title": "Orbit right", "description": "Inspect the car from the right.",
		"heading": "Garage camera", "player": 0,
	},
	{
		"key": "controls/rastro_orbit_up", "action": ORBIT_UP, "default": KEY_W,
		"title": "Raise view", "description": "Look down on the roof and bodywork.",
		"heading": "Garage camera", "player": 0,
	},
	{
		"key": "controls/rastro_orbit_down", "action": ORBIT_DOWN, "default": KEY_S,
		"title": "Lower view", "description": "Inspect the wheels and suspension.",
		"heading": "Garage camera", "player": 0,
	},
	{
		"key": "controls/rastro_zoom_in", "action": ZOOM_IN, "default": KEY_Q,
		"title": "Zoom in", "description": "Move closer to the car.",
		"heading": "Garage camera", "player": 0,
	},
	{
		"key": "controls/rastro_zoom_out", "action": ZOOM_OUT, "default": KEY_E,
		"title": "Zoom out", "description": "Move farther from the car.",
		"heading": "Garage camera", "player": 0,
	},
	{
		"key": "controls/rastro_reset_view", "action": RESET_VIEW, "default": KEY_R,
		"title": "Reset view", "description": "Frame the whole car. This does not reset its parts.",
		"heading": "Garage camera", "player": 0,
	},
]
