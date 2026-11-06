extends Node3D

## Rastro owns its imported meshes; customization never mutates shared GLB resources.

const Catalog = preload("res://games/rastro/car_catalog.gd")
const Build = preload("res://games/rastro/car_build.gd")
const MODELS := {
	"nissan_cube": preload("res://games/rastro/assets/models/nissan_cube.glb"),
	"hyundai_sonata": preload("res://games/rastro/assets/models/hyundai_sonata.glb"),
	"honda_crv": preload("res://games/rastro/assets/models/honda_crv.glb"),
}
const WHEEL_NAMES := [
	"FrontLeftWheel", "FrontRightWheel", "RearLeftWheel", "RearRightWheel",
]
const PREFIXES := ["LF", "RF", "LR", "RR"]
const BODY_MATERIALS := ["Cube Bronze metallic", "Cube Bronze edge", "Cube Body paint"]
const RIM_MATERIALS := [
	"Cube Silver alloy", "Cube Polished chrome", "Cube Alloy", "Cube Chrome",
]

var car_id := ""
var chassis: Node3D
var wheels: Array[Node3D] = []
var _imported: Node3D
var _body: MeshInstance3D
var _wheel_origins: Array[Vector3] = []
var _suspension: Node3D


## Meter-scale chassis and tire contacts stay separate when ride height changes.
func configure(build: Dictionary) -> void:
	assert(Build.problem(build).is_empty(), "Invalid garage rig build.")
	if car_id != build["car_id"]:
		_load_car(build["car_id"])
	var car: Dictionary = Catalog.CARS[car_id]
	var tire: Dictionary = Catalog.TIRES[build["tire_id"]]
	var radius_scale: float = tire["radius_scale"]
	var tire_rise: float = car["tire_radius_m"] * (radius_scale - 1.0)
	chassis.position.y = float(build["ride_height_mm"]) / 1000.0 + tire_rise
	_paint(build["paint_id"])
	for index in wheels.size():
		var wheel := wheels[index]
		wheel.position = _wheel_origins[index] + Vector3.UP * tire_rise
		wheel.scale = Vector3(radius_scale, radius_scale, float(tire["width_scale"]))
		_dress_wheel(wheel, index, build)
	_build_suspension(build)


## The camera frames actual visible geometry, including the selected wheels.
func local_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for node in find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if not part.is_visible_in_tree() or part.mesh == null:
			continue
		var transform := global_transform.affine_inverse() * part.global_transform
		var box := transform * part.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _load_car(id: String) -> void:
	if _imported != null:
		_imported.free()
	if _suspension != null:
		_suspension.free()
	wheels.clear()
	_wheel_origins.clear()
	car_id = id
	_imported = (MODELS[id] as PackedScene).instantiate() as Node3D
	add_child(_imported)
	var assembly := _imported.get_node(str(Catalog.CARS[id]["root"])) as Node3D
	chassis = assembly.get_node("Chassis") as Node3D
	_body = chassis.get_node(str(Catalog.CARS[id]["body"])) as MeshInstance3D
	for wheel_name: String in WHEEL_NAMES:
		var wheel := assembly.get_node(wheel_name) as Node3D
		wheels.append(wheel)
		_wheel_origins.append(wheel.position)
	_suspension = Node3D.new()
	_suspension.name = "Suspension"
	add_child(_suspension)


func _paint(id: String) -> void:
	for surface in _body.mesh.get_surface_count():
		var source := _body.mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null or source.resource_name not in BODY_MATERIALS:
			continue
		if id == "factory":
			_body.set_surface_override_material(surface, null)
			continue
		var paint := source.duplicate() as StandardMaterial3D
		var color := Catalog.paint_color(car_id, id)
		paint.albedo_color = color.darkened(0.10) \
			if source.resource_name == "Cube Bronze edge" else color
		_body.set_surface_override_material(surface, paint)


func _dress_wheel(wheel: Node3D, index: int, build: Dictionary) -> void:
	var stock := wheel.get_node(PREFIXES[index] + "AlloyRims") as MeshInstance3D
	stock.visible = build["wheel_id"] == "stock"
	for surface in stock.mesh.get_surface_count():
		var source := stock.mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null or source.resource_name not in RIM_MATERIALS:
			continue
		var finish: StandardMaterial3D
		if build["rim_finish_id"] != "silver":
			finish = source.duplicate() as StandardMaterial3D
			finish.albedo_color = Catalog.RIM_FINISHES[build["rim_finish_id"]]["color"]
		stock.set_surface_override_material(surface, finish)
	var old := wheel.get_node_or_null("RastroWheel")
	if old != null:
		old.free()
	if build["wheel_id"] == "stock":
		return
	var custom := Node3D.new()
	custom.name = "RastroWheel"
	wheel.add_child(custom)
	var side := signf(wheel.position.z)
	var color: Color = Catalog.RIM_FINISHES[build["rim_finish_id"]]["color"]
	var metal := _material(color, 0.8)
	var radius: float = Catalog.CARS[car_id]["tire_radius_m"] * 0.64
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.86
	disc.bottom_radius = disc.top_radius
	disc.height = 0.035
	disc.radial_segments = 24
	var brake := _mesh(custom, disc, _material(Color("43474c"), 0.65))
	brake.rotation.x = PI * 0.5
	var lip := TorusMesh.new()
	lip.inner_radius = radius * 0.88
	lip.outer_radius = radius
	lip.rings = 32
	lip.ring_segments = 8
	var rim := _mesh(custom, lip, metal)
	rim.rotation.x = PI * 0.5
	rim.position.z = side * 0.10
	var hub := CylinderMesh.new()
	hub.top_radius = radius * (0.90 if build["wheel_id"] == "rally_disc" else 0.20)
	hub.bottom_radius = hub.top_radius
	hub.height = 0.04
	hub.radial_segments = 24
	var center := _mesh(custom, hub, metal)
	center.rotation.x = PI * 0.5
	center.position.z = side * 0.105
	if build["wheel_id"] == "five_spoke":
		for spoke in 5:
			var angle := TAU * float(spoke) / 5.0
			var box := BoxMesh.new()
			box.size = Vector3(radius * 0.82, radius * 0.17, 0.04)
			var arm := _mesh(custom, box, metal)
			arm.position = Vector3(cos(angle) * radius * 0.52,
				sin(angle) * radius * 0.52, side * 0.105)
			arm.rotation.z = angle


func _build_suspension(build: Dictionary) -> void:
	for child in _suspension.get_children():
		child.free()
	var length := 0.20 + float(build["ride_height_mm"]) / 1000.0
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.017
	cylinder.bottom_radius = 0.017
	cylinder.height = length
	cylinder.radial_segments = 8
	var spring := _spring_mesh(length)
	var spring_color := Color("a9b5b9")
	if build["suspension_id"] == "street":
		spring_color = Color("e4b54e")
	elif build["suspension_id"] == "rally":
		spring_color = Color("56bcb3")
	var steel := _material(Color("9ba5ac"), 0.8)
	var enamel := _material(spring_color, 0.4)
	for wheel in wheels:
		var origin := Vector3(wheel.position.x, wheel.position.y + length * 0.5,
			wheel.position.z * 0.83)
		_mesh(_suspension, cylinder, steel).position = origin
		_mesh(_suspension, spring, enamel).position = origin - Vector3.UP * length * 0.5


func _spring_mesh(length: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 65:
		var t := float(step) / 64.0
		var angle := t * TAU * 4.0
		var outward := Vector3(cos(angle), 0, sin(angle))
		var center := outward * 0.035 + Vector3.UP * length * t
		for segment in 7:
			var phi := float(segment) / 6.0 * TAU
			var normal := outward * cos(phi) + Vector3.UP * sin(phi)
			tool.set_normal(normal)
			tool.add_vertex(center + normal * 0.005)
	for step in 64:
		for segment in 6:
			var start := step * 7 + segment
			for index: int in [start, start + 7, start + 1,
				start + 1, start + 7, start + 8]:
				tool.add_index(index)
	return tool.commit()


static func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.30
	return result


static func _mesh(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
