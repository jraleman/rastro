extends Control

## An isolated Compatibility workshop; gestures only own contacts begun on this view.

const Rig = preload("res://games/rastro/car_rig.gd")
const Catalog = preload("res://games/rastro/car_catalog.gd")
const DEFAULT_YAW := 0.68
const DEFAULT_PITCH := 0.28

var yaw := DEFAULT_YAW
var pitch := DEFAULT_PITCH
var zoom := 1.0
var rig: Rig
var camera: Camera3D
var viewport: SubViewport
var _world: Node3D
var _sample_paint: StandardMaterial3D
var _focus := Vector3(0, 0.9, 0)
var _radius := 2.8
var _dragging := false
var _touches: Dictionary[int, Vector2] = {}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = (
		"Drag to orbit; mouse wheel or pinch to zoom. "
		+ "Keyboard orbit/zoom keys work alongside normal menu navigation. "
		+ "On a gamepad, use the right stick and shoulder buttons."
	)
	accessibility_name = "3D garage car preview"
	accessibility_description = tooltip_text
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_world = Node3D.new()
	viewport.add_child(_world)
	_build_workshop()
	rig = Rig.new()
	rig.name = "Car"
	rig.position.y = 0.095
	_world.add_child(rig)
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.05
	camera.far = 80.0
	camera.current = true
	_world.add_child(camera)
	resized.connect(_aim)
	visibility_changed.connect(_on_visibility_changed)
	gui_input.connect(_on_gui_input)


## Restyling a car keeps the inspection angle instead of resetting every edit.
func configure(build: Dictionary) -> void:
	rig.configure(build)
	_sample_paint.albedo_color = Catalog.paint_color(build["car_id"], build["paint_id"])
	var bounds := rig.local_bounds()
	_focus = rig.position + bounds.get_center()
	_radius = bounds.size.length() * 0.5
	_aim()


## Manual camera movement remains essential even under Reduced motion.
func orbit(amount: Vector2) -> void:
	yaw = wrapf(yaw + amount.x, -PI, PI)
	pitch = clampf(pitch + amount.y, 0.08, 1.12)
	_aim()


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, 0.65, 1.65)
	_aim()


func reset_view() -> void:
	yaw = DEFAULT_YAW
	pitch = DEFAULT_PITCH
	zoom = 1.0
	_aim()


func release_contacts() -> void:
	_dragging = false
	_touches.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_contacts()


func _aim() -> void:
	if camera == null or size.y <= 0.0:
		return
	var half_fov := deg_to_rad(camera.fov) * 0.5
	var aspect := maxf(size.x / size.y, 0.25)
	var limiting_fov := minf(half_fov, atan(tan(half_fov) * aspect))
	var distance := _radius / sin(limiting_fov) * 1.05 * zoom
	var direction := Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
	camera.position = _focus + direction * distance
	camera.look_at(_focus)


func _on_visibility_changed() -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS \
			if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if not is_visible_in_tree():
		release_contacts()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				grab_focus()
			if event.double_click:
				reset_view()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(0.90 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.10)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		orbit(-event.relative * Vector2(0.008, 0.006))
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			grab_focus()
		else:
			_touches.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		if _touches.size() == 1:
			orbit(-event.relative * Vector2(0.008, 0.006))
			_touches[event.index] = event.position
		else:
			var keys := _touches.keys()
			var previous := _touches[keys[0]].distance_to(_touches[keys[1]])
			_touches[event.index] = event.position
			var current := _touches[keys[0]].distance_to(_touches[keys[1]])
			if previous > 1.0 and current > 1.0:
				zoom_by(previous / current)
		accept_event()
	elif event is InputEventMagnifyGesture:
		if event.factor > 0.0:
			zoom_by(1.0 / event.factor)
		accept_event()


func _build_workshop() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("18252b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d2e0e3")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	_world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff0d3")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35.0
	_world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 4.5, 5)
	fill.omni_range = 18.0
	fill.light_color = Color("9bd8e1")
	fill.light_energy = 2.0
	_world.add_child(fill)
	var floor_material := _material(Color("343f44"))
	var dark := _material(Color("202c32"))
	var pale := _material(Color("9faeb0"))
	var wall := _material(Color("43545a"))
	_box(Vector3(38, 0.12, 38), Vector3(0, -0.07, 0), floor_material)
	_box(Vector3(30, 5.5, 0.18), Vector3(0, 2.6, -14), wall)
	_box(Vector3(0.18, 5.5, 30), Vector3(-14, 2.6, 0), wall)
	for line in range(-8, 9):
		_box(Vector3(0.015, 0.003, 24), Vector3(line * 1.5, 0, 0), dark)
		_box(Vector3(24, 0.003, 0.015), Vector3(0, 0.002, line * 1.5), dark)
	var turntable := CylinderMesh.new()
	turntable.top_radius = 3.65
	turntable.bottom_radius = 3.65
	turntable.height = 0.08
	turntable.radial_segments = 96
	var platform := MeshInstance3D.new()
	platform.mesh = turntable
	var dial := ShaderMaterial.new()
	dial.shader = preload("res://games/rastro/assets/alignment_dial.gdshader")
	platform.material_override = dial
	platform.position.y = 0.04
	_world.add_child(platform)
	for side: float in [-1, 1]:
		_box(Vector3(0.15, 3.6, 0.15), Vector3(side * 5, 1.8, -4.8), dark)
		_box(Vector3(2.5, 0.08, 0.35), Vector3(side * 3.5, 4.3, -1.5), pale)
	_box(Vector3(5.5, 0.15, 0.85), Vector3(-1.5, 1.1, -6.0), pale)
	for x: float in [-3.6, 0.6]:
		_box(Vector3(0.12, 1.1, 0.65), Vector3(x, 0.55, -6), dark)
	_box(Vector3(1.3, 1.25, 0.85), Vector3(3.5, 0.625, -5.7),
		_material(Color("2e7777"), 0.2))
	for drawer in 5:
		_box(Vector3(1.1, 0.035, 0.04),
			Vector3(3.5, 0.20 + drawer * 0.22, -5.25), pale)
	var sign := Label3D.new()
	sign.text = "R A S T R O\nTHE GARAGE"
	sign.font_size = 76
	sign.pixel_size = 0.0045
	sign.position = Vector3(-4.6, 3.04, -6.02)
	sign.modulate = Color("f0dfb0")
	sign.no_depth_test = false
	_world.add_child(sign)
	var detail := preload("res://scripts/miniature_detail.gd").new()
	var ink := Color("23383f")
	var cream := Color("9c9d89")
	detail.box(sign.position - Vector3(0, 0, 0.08), Vector3(2.52, 0.96, 0.09), ink)
	detail.box(Vector3(-1.54, 1.96, -6.18), Vector3(4.9, 1.50, 0.10), ink)
	for tool in 7:
		var x := -3.45 + tool * 0.58
		var length := 0.47 + float(tool % 3) * 0.13
		var base := Vector3(x, 1.50, -6.1)
		detail.rod(base, base + Vector3.UP * length, 0.039, cream)
		for side: float in [-1, 1]:
			detail.rod(base + Vector3.UP * length,
				base + Vector3(side * 0.09, length + 0.10, 0), 0.035, cream)
	for side: float in [-1, 1]:
		var bay := Vector3(side * 6.3, 2.49, -13.82)
		detail.box(bay, Vector3(8.7, 3.6, 0.18), ink)
		for pane in 4:
			detail.box(bay + Vector3(-3.15 + pane * 2.10, 0.1, 0.12),
				Vector3(1.99, 2.91, 0.075), Color("3a5259").darkened(0.08 * (pane % 2)))
		detail.box(bay + Vector3(0, -0.35, 0.19), Vector3(8.50, 0.10, 0.07), ink)
		detail.box(bay + Vector3(0, -1.82, 0.18), Vector3(8.94, 0.19, 0.26), Color("c98959"))
	detail.attach(_world, "WorkshopGlazingAndToolBoard")
	_paint_station()


func _paint_station() -> void:
	# The left wall is seen obliquely behind the turntable; its sample faces the car.
	var rack := preload("res://scripts/miniature_detail.gd").new()
	var at := Vector3(-7.2, 0, -1.05)
	var slate := Color("344c52")
	var nickel := Color("94a7a3")
	rack.box(at + Vector3.UP * 1.35, Vector3(0.88, 2.70, 2.56), slate)
	rack.box(at + Vector3(0.49, 2.35, 0), Vector3(0.28, 0.19, 2.78), nickel)
	for shelf in 2:
		var y := 0.43 + shelf * 0.69
		rack.box(at + Vector3(0.47, y, 0), Vector3(0.61, 0.11, 2.31), nickel)
		for pot in 3:
			var foot := at + Vector3(0.50, y + 0.07, (pot - 1) * 0.64)
			rack.rod(foot, foot + Vector3.UP * 0.38, 0.205,
				[Color("9b6655"), Color("789894"), Color("c5aa78")][(pot + shelf) % 3])
			rack.rod(foot + Vector3.UP * 0.38, foot + Vector3.UP * 0.43, 0.218, nickel)
	rack.attach(_world, "PaintMixingBench")
	_sample_paint = _material(Color.WHITE, 0.26)
	_box(Vector3(0.14, 0.45, 1.91), at + Vector3(0.47, 1.97, 0), _sample_paint).name = "LivePaintSwatch"


func _box(size_m: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_m
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	_world.add_child(instance)
	return instance


static func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.6
	result.metallic = metallic
	return result
