extends SceneTree

## Real Compatibility rendering, physical phone-sized controls and scrollable workbenches.

const Catalog = preload("res://games/rastro/car_catalog.gd")
const Build = preload("res://games/rastro/car_build.gd")
const Garage = preload("res://games/rastro/garage_state.gd")

var _failures := PackedStringArray()
var _path := "user://rastro_view_test_%d.cfg" % Time.get_ticks_usec()
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("garage_view_test.gd requires a real Compatibility graphics window.")
		quit(1)
		return
	GameCatalog.select("rastro")
	var game := (load("res://games/rastro/gameplay.tscn") as PackedScene).instantiate()
	game.set("garage_save_path", _path)
	get_root().add_child(game)
	await process_frame
	var ui: Control = game.get("_garage")
	var view: Control = ui.get("view")
	var viewport: SubViewport = view.get("viewport")
	var camera: Camera3D = view.get("camera")
	var rig: Node3D = view.get("rig")
	var settings := get_root().get_node("Settings")
	var reduced: Variant = settings.call("get_value", "accessibility/reduced_motion")
	var original_scale: Variant = settings.call("get_value", "ui/scale")
	settings.call("set_value", "accessibility/reduced_motion", true)
	var artifact_dir := _artifact_directory()
	for layout: Dictionary in [
		{"window": Vector2i(1280, 720), "scale": 1.0},
		{"window": Vector2i(390, 844), "scale": 1.0},
		{"window": Vector2i(844, 390), "scale": 1.0},
		{"window": Vector2i(320, 568), "scale": 1.0},
		{"window": Vector2i(2560, 1080), "scale": 1.0},
		{"window": Vector2i(390, 844), "scale": 1.35},
		{"window": Vector2i(844, 390), "scale": 1.35},
		{"window": Vector2i(320, 568), "scale": 1.35},
	]:
		var window_size: Vector2i = layout["window"]
		settings.call("set_value", "ui/scale", layout["scale"])
		get_root().size = window_size
		await process_frame
		await process_frame
		await process_frame
		var bounds := get_root().get_visible_rect()
		var editor := ui.get("_editor") as Control
		var scroll := ui.get("_scroll") as ScrollContainer
		_expect(bounds.grow(1).encloses(view.get_global_rect())
			and bounds.grow(1).encloses(editor.get_global_rect()),
			"Preview and workbench must fit %s: %s / %s inside %s." % [
				window_size, view.get_global_rect(), editor.get_global_rect(), bounds,
			])
		_expect(not view.get_global_rect().intersects(editor.get_global_rect()),
			"The parts panel must not cover the car at %s." % window_size)
		var picker := ui.get("_car_picker") as Control
		var physical_scale := float(window_size.x) / bounds.size.x
		_expect(view.get_global_rect().size.y * physical_scale >= 89.5,
			"Car inspection must keep usable height at %s / UI scale %s, got %.1f px." % [
				window_size, layout["scale"], view.get_global_rect().size.y * physical_scale,
			])
		_expect(picker.get_global_rect().size.y * physical_scale >= 43.0,
			"The car picker must remain a physical touch target at %s." % window_size)
		for id: String in Catalog.CAR_IDS:
			var build := Build.factory(id)
			build["paint_id"] = "lagoon"
			build["wheel_id"] = "five_spoke"
			build["tire_id"] = "trail"
			build["ride_height_mm"] = 60
			view.call("configure", build)
			view.call("reset_view")
			await process_frame
			await RenderingServer.frame_post_draw
			_expect(viewport.own_world_3d and viewport.world_3d != get_root().world_3d,
				"Rastro must render its own isolated 3D workshop.")
			var car_bounds: AABB = rig.call("local_bounds")
			for corner in 8:
				var world := rig.global_transform * car_bounds.get_endpoint(corner)
				var point := camera.unproject_position(world)
				_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(2).has_point(point),
					"The entire %s must fit the reset camera at %s." % [id, window_size])
			var image := viewport.get_texture().get_image()
			_expect(_has_geometry(image), "The real %s garage must render geometry." % id)
			if not artifact_dir.is_empty() and window_size == Vector2i(1280, 720):
				_expect(image.save_png(artifact_dir.path_join(id + ".png")) == OK,
					"Save requested car review captures.")
		view.call("configure", (game.get("_state") as RefCounted).call("current_build"))
		await process_frame
		var before: Transform3D = camera.transform
		await create_timer(0.05).timeout
		_expect(camera.transform.is_equal_approx(before),
			"Idle garage inspection must be static under Reduced motion.")
		if not artifact_dir.is_empty():
			await RenderingServer.frame_post_draw
			var suffix := "" if layout["scale"] == 1.0 else "-large"
			_expect(get_root().get_texture().get_image().save_png(artifact_dir.path_join(
				"garage-%dx%d%s.png" % [window_size.x, window_size.y, suffix])) == OK,
				"Save requested full-layout review captures.")
		scroll.scroll_vertical = ceili(scroll.get_v_scroll_bar().max_value)
		await process_frame
		await process_frame
		var reset := ui.get("_reset") as Control
		_expect(scroll.get_global_rect().grow(1).encloses(reset.get_global_rect()),
			"The last action must scroll fully into view at %s: %s inside %s." % [
				window_size, reset.get_global_rect(), scroll.get_global_rect(),
			])
		scroll.scroll_vertical = 0
		await process_frame
		(ui.get("_export") as Button).pressed.emit()
		await process_frame
		var dialog := ui.get("_transfer") as ConfirmationDialog
		var dialog_bounds := Rect2(Vector2(dialog.position), Vector2(dialog.size))
		_expect(bounds.grow(2).encloses(dialog_bounds),
			"The portable build dialog must fit %s: %s inside %s." % [
				window_size, dialog_bounds, bounds,
			])
		var content_bounds := dialog.get_visible_rect().grow(1)
		_expect(content_bounds.encloses(dialog.get_ok_button().get_global_rect())
			and content_bounds.encloses((ui.get("_copy_button") as Button).get_global_rect()),
			"Portable build actions must stay visible at %s / UI scale %s." % [
				window_size, layout["scale"],
			])
		var text_rect := (ui.get("_transfer_text") as TextEdit).get_global_rect()
		_expect(text_rect.position.x >= 0 and text_rect.end.x <= content_bounds.end.x,
			"Portable JSON must not be clipped horizontally at %s." % window_size)
		if not artifact_dir.is_empty() and window_size == Vector2i(390, 844):
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(artifact_dir.path_join("portable-build.png"))
		if window_size == Vector2i(320, 568):
			await _rotate_modal(dialog)
		dialog.hide()
		(ui.get("_reset") as Button).pressed.emit()
		await process_frame
		var reset_dialog := ui.get("_reset_dialog") as ConfirmationDialog
		var reset_bounds := Rect2(Vector2(reset_dialog.position), Vector2(reset_dialog.size))
		_expect(bounds.grow(2).encloses(reset_bounds),
			"Factory confirmation must fit %s at UI scale %s." % [window_size, layout["scale"]])
		var reset_content := reset_dialog.get_visible_rect().grow(1)
		_expect(reset_content.encloses(reset_dialog.get_ok_button().get_global_rect())
			and reset_content.encloses(reset_dialog.get_cancel_button().get_global_rect()),
			"Factory confirmation actions must stay visible at %s." % window_size)
		_expect(reset_dialog.get_label().size.y >= reset_dialog.get_label().get_minimum_size().y,
			"Factory confirmation text must not be clipped at %s." % window_size)
		if window_size == Vector2i(320, 568):
			await _rotate_modal(reset_dialog)
		reset_dialog.hide()
	settings.call("set_value", "accessibility/reduced_motion", reduced)
	settings.call("set_value", "ui/scale", original_scale)
	game.free()
	await process_frame
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	await create_timer(0.2, true, false, true).timeout
	for failure in _failures:
		printerr(failure)
	print("Rastro rendering: %d checks, %d failures." % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _rotate_modal(dialog: Window) -> void:
	get_root().size = Vector2i(568, 320)
	await process_frame
	await process_frame
	await process_frame
	_expect(get_root().get_visible_rect().grow(2).encloses(
		Rect2(Vector2(dialog.position), Vector2(dialog.size))),
		"An open garage dialog must stay onscreen after phone rotation.")
	get_root().size = Vector2i(320, 568)
	await process_frame
	await process_frame
	await process_frame
	_expect(get_root().get_visible_rect().grow(2).encloses(
		Rect2(Vector2(dialog.position), Vector2(dialog.size))),
		"An open garage dialog must fit when returning to portrait.")


func _has_geometry(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var colors := {}
	for y in range(0, image.get_height(), maxi(1, image.get_height() / 20)):
		for x in range(0, image.get_width(), maxi(1, image.get_width() / 20)):
			colors[image.get_pixel(x, y).to_html()] = true
	return colors.size() > 25


func _artifact_directory() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rastro-artifacts="):
			var directory := argument.trim_prefix("--rastro-artifacts=")
			if DirAccess.make_dir_recursive_absolute(directory) != OK:
				_failures.append("Could not create the requested capture directory.")
				return ""
			return directory
	return ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
