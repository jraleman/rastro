extends "res://games/rastro/gameplay.gd"

## Synthetic events use the real adapter with a virtual assigned device, never hardware.


func _camera_device() -> int:
	return 41
