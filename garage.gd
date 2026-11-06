extends Control

## A responsive parts workbench; the gameplay controller owns validation and saves.

signal car_selected(car_id: String)
signal part_changed(field: String, value: Variant)
signal reset_requested
signal import_submitted(text: String)
signal export_requested
signal pause_requested
signal retry_requested
signal modal_opened

const Catalog = preload("res://games/rastro/car_catalog.gd")
const Build = preload("res://games/rastro/car_build.gd")
const View = preload("res://games/rastro/garage_view.gd")

var view: View
var _margins: MarginContainer
var _body: BoxContainer
var _stage_column: VBoxContainer
var _editor: PanelContainer
var _scroll: ScrollContainer
var _parts: VBoxContainer
var _car_picker: OptionButton
var _controls: Dictionary[String, Control] = {}
var _paint_buttons: Dictionary[String, Button] = {}
var _height_value: Label
var _specs: Label
var _status: Label
var _retry: Button
var _reset: Button
var _export: Button
var _import: Button
var _subtitle: Label
var _view_hint: Label
var _pitch_buttons: Array[Button] = []
var _reset_dialog: ConfirmationDialog
var _transfer: ConfirmationDialog
var _transfer_text: TextEdit
var _transfer_error: Label
var _transfer_hint: Label
var _copy_button: Button
var _syncing := false
var _exporting := false
var _locked := false
var _ui_factor := 1.0
var _interface_scale := 1.0
var _current_car := Catalog.CAR_IDS[0]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font := ThemeDB.fallback_font.duplicate() as FontFile
	font.multichannel_signed_distance_field = true
	theme = Theme.new()
	theme.default_font = font
	_build_ui()
	_build_dialogs()
	resized.connect(_layout)
	get_window().size_changed.connect(_layout)
	_layout.call_deferred()


## The selected marker is text plus a pressed state, never only the paint swatch.
func refresh(build: Dictionary, locked: bool) -> void:
	_syncing = true
	_locked = locked
	_current_car = build["car_id"]
	_car_picker.select(Catalog.CAR_IDS.find(_current_car))
	for id: String in _paint_buttons:
		var button := _paint_buttons[id]
		button.set_pressed_no_signal(id == build["paint_id"])
		button.text = str(Catalog.PAINTS[id]["title"]) + (" *" if button.button_pressed else "")
		button.disabled = locked
		_paint_style(button, Catalog.paint_color(_current_car, id))
	for field: String in _controls:
		var control := _controls[field]
		if control is OptionButton:
			var choices: Dictionary = Catalog.PARTS[field]
			control.select(choices.keys().find(build[field]))
			control.disabled = locked
		elif control is HSlider:
			control.value = build[field]
			control.editable = not locked
	_height_value.text = "%+d mm" % int(build["ride_height_mm"])
	var specs := Build.specifications(build)
	_specs.text = (
		"%.0f kW  |  %.0f kW / tonne\n%.0f kg  |  %.0f mm clearance\n"
		+ "Road grip %.2fx  |  Loose grip %.2fx\nSprings %.2fx  |  Damping %.2fx"
	) % [
		specs["power_kw"], specs["power_per_tonne"], specs["mass_kg"],
		specs["clearance_mm"], specs["road_grip"], specs["loose_grip"],
		specs["spring_scale"], specs["damping_scale"],
	]
	_reset.disabled = locked
	_export.disabled = locked
	_import.disabled = locked
	_syncing = false
	view.configure(build)


func set_status(text: String, failed := false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color("ffc4a0") if failed else Color("c6d9d9"))
	_retry.visible = failed


func focus_car() -> void:
	_car_picker.grab_focus()


func set_interface_scale(value: float) -> void:
	_interface_scale = value
	_layout()


func has_modal() -> bool:
	return _transfer.visible or _reset_dialog.visible


## Import confirms replacement of only the named car; export never changes a save.
func show_export(text: String) -> void:
	_exporting = true
	_transfer.title = "Portable car build"
	_transfer_hint.text = (
		"Version 1 car build.\nCopy the JSON below.\nCube Trials: not yet."
	)
	_transfer_text.editable = false
	_transfer_text.text = text
	_transfer_error.text = ""
	_transfer.get_ok_button().text = "Close"
	_transfer.get_cancel_button().hide()
	_copy_button.show()
	_open_transfer()


func finish_import(error: String) -> void:
	if error.is_empty():
		_transfer.hide()
		_car_picker.grab_focus()
	else:
		_transfer_error.text = error


func _build_ui() -> void:
	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	_margins.minimum_size_changed.connect(_fit_content, CONNECT_DEFERRED)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	_margins.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	layout.add_child(header)
	var title := _label("RASTRO", 36)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.add_theme_color_override("font_color", Color("e4b54e"))
	header.add_child(title)
	_subtitle = _label("THE GARAGE  /  Three cars. Your signature.", 22)
	_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_subtitle)
	var pause := _button("Menu", "Open the shared pause menu, settings and main-menu navigation.")
	pause.name = "GarageMenu"
	pause.pressed.connect(func() -> void: pause_requested.emit())
	header.add_child(pause)
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 24)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_body)
	_stage_column = VBoxContainer.new()
	_stage_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_stage_column)
	view = View.new()
	view.name = "GarageView"
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage_column.add_child(view)
	var view_actions := HFlowContainer.new()
	view_actions.add_theme_constant_override("h_separation", 8)
	_stage_column.add_child(view_actions)
	for entry: Dictionary in [
		{"text": "<", "help": "Orbit left", "orbit": Vector2(-0.25, 0)},
		{"text": ">", "help": "Orbit right", "orbit": Vector2(0.25, 0)},
		{"text": "Up", "help": "Raise the camera", "orbit": Vector2(0, 0.15)},
		{"text": "Down", "help": "Lower the camera", "orbit": Vector2(0, -0.15)},
	]:
		var button := _button(entry["text"], entry["help"])
		button.pressed.connect(view.orbit.bind(entry["orbit"]))
		view_actions.add_child(button)
		if entry["text"] in ["Up", "Down"]:
			_pitch_buttons.append(button)
	var closer := _button("+", "Zoom in")
	closer.pressed.connect(view.zoom_by.bind(0.9))
	view_actions.add_child(closer)
	var farther := _button("-", "Zoom out")
	farther.pressed.connect(view.zoom_by.bind(1.1))
	view_actions.add_child(farther)
	var reset_view := _button("Frame car", "Reset the camera, keeping every modification.")
	reset_view.name = "FrameCar"
	reset_view.pressed.connect(view.reset_view)
	view_actions.add_child(reset_view)
	_view_hint = _label("Drag to orbit. Wheel / pinch to zoom. All parts are free.", 20)
	_stage_column.add_child(_view_hint)
	_editor = PanelContainer.new()
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_editor)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("17242b", 0.97)
	panel_style.border_color = Color("506368")
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(24)
	panel_style.set_corner_radius_all(14)
	_editor.add_theme_stylebox_override("panel", panel_style)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_editor.add_child(_scroll)
	_parts = VBoxContainer.new()
	_parts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parts.add_theme_constant_override("separation", 14)
	_scroll.add_child(_parts)
	_parts.add_child(_label("YOUR CAR", 22))
	_car_picker = OptionButton.new()
	_car_picker.name = "CarPicker"
	_car_picker.fit_to_longest_item = false
	_car_picker.custom_minimum_size.y = 66
	for id: String in Catalog.CAR_IDS:
		_car_picker.add_item(Catalog.CARS[id]["title"])
	_car_picker.item_selected.connect(_on_car_selected)
	_car_picker.get_popup().about_to_popup.connect(func() -> void: modal_opened.emit())
	_parts.add_child(_car_picker)
	_parts.add_child(_label("PAINT", 22))
	var palette := HFlowContainer.new()
	palette.add_theme_constant_override("h_separation", 8)
	palette.add_theme_constant_override("v_separation", 8)
	_parts.add_child(palette)
	for id: String in Catalog.PAINTS:
		var button := _button(Catalog.PAINTS[id]["title"], "Paint: " + str(Catalog.PAINTS[id]["title"]))
		button.name = "Paint_" + id
		button.toggle_mode = true
		button.custom_minimum_size.x = 116
		button.pressed.connect(_emit_part.bind("paint_id", id))
		palette.add_child(button)
		_paint_buttons[id] = button
	_parts.add_child(_label("WHEELS & TIRES", 22))
	_add_choice("wheel_id", "Wheel design")
	_add_choice("rim_finish_id", "Rim finish")
	_add_choice("tire_id", "Tires")
	_parts.add_child(_label("SUSPENSION", 22))
	_add_choice("suspension_id", "Spring / damper kit")
	_parts.add_child(_label("Ride height relative to factory", 20))
	var height_row := HBoxContainer.new()
	_parts.add_child(height_row)
	var height := HSlider.new()
	height.name = "RideHeight"
	height.min_value = Catalog.MIN_RIDE_HEIGHT_MM
	height.max_value = Catalog.MAX_RIDE_HEIGHT_MM
	height.step = Catalog.RIDE_HEIGHT_STEP_MM
	height.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	height.custom_minimum_size = Vector2(100, 66)
	height.accessibility_name = "Ride height in millimeters"
	height.value_changed.connect(func(value: float) -> void:
		_emit_part("ride_height_mm", int(value)))
	height_row.add_child(height)
	_controls["ride_height_mm"] = height
	_height_value = _label("+0 mm", 22)
	_height_value.custom_minimum_size.x = 100
	_height_value.size_flags_horizontal = Control.SIZE_SHRINK_END
	height_row.add_child(_height_value)
	_parts.add_child(_label("ENGINE", 22))
	_add_choice("engine_id", "Engine kit")
	_parts.add_child(_label("BUILD ESTIMATES", 22))
	_specs = _label("", 22)
	_specs.name = "BuildSpecifications"
	_parts.add_child(_specs)
	_parts.add_child(_label(
		"Fictional tuning, not factory specifications. No driving or competitions in this version.", 20))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	_parts.add_child(actions)
	_export = _button("Export build", "Show this car's portable JSON. It contains no executable resources.")
	_export.pressed.connect(func() -> void: export_requested.emit())
	actions.add_child(_export)
	_import = _button("Import build", "Paste a version 1 build to replace only its named car.")
	_import.pressed.connect(_show_import)
	actions.add_child(_import)
	_reset = _button("Factory reset", "Ask before resetting only this car. Other cars are kept.")
	_reset.pressed.connect(_ask_reset)
	actions.add_child(_reset)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 14)
	layout.add_child(status_row)
	_status = _label("Factory garage. Changes save automatically.", 20)
	_status.name = "GarageStatus"
	status_row.add_child(_status)
	_retry = _button("Retry", "Retry loading or saving the garage after an error.")
	_retry.hide()
	_retry.pressed.connect(func() -> void: retry_requested.emit())
	status_row.add_child(_retry)


func _add_choice(field: String, title: String) -> void:
	_parts.add_child(_label(title, 20))
	var picker := OptionButton.new()
	picker.name = field.to_pascal_case()
	picker.fit_to_longest_item = false
	picker.custom_minimum_size.y = 66
	var choices: Dictionary = Catalog.PARTS[field]
	for id: String in choices:
		picker.add_item(choices[id]["title"])
	picker.item_selected.connect(func(index: int) -> void:
		_emit_part(field, choices.keys()[index]))
	picker.get_popup().about_to_popup.connect(func() -> void: modal_opened.emit())
	_parts.add_child(picker)
	_controls[field] = picker


func _build_dialogs() -> void:
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.theme = theme
	_reset_dialog.title = "Restore factory build?"
	_reset_dialog.dialog_text = "Only this car returns to factory paint and parts. The other cars are kept."
	_reset_dialog.ok_button_text = "Reset car"
	_reset_dialog.dialog_autowrap = true
	_reset_dialog.wrap_controls = false
	add_child(_reset_dialog)
	_reset_dialog.confirmed.connect(func() -> void: reset_requested.emit())
	_transfer = ConfirmationDialog.new()
	_transfer.theme = theme
	_transfer.title = "Import a car build"
	_transfer.dialog_hide_on_ok = false
	_transfer.wrap_controls = false
	add_child(_transfer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_transfer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	_transfer_hint = _label("", 22)
	_transfer_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_transfer_hint)
	_transfer_text = TextEdit.new()
	_transfer_text.custom_minimum_size = Vector2(260, 200)
	_transfer_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transfer_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_transfer_text.accessibility_name = "Portable car build JSON"
	column.add_child(_transfer_text)
	_transfer_error = _label("", 20)
	_transfer_error.add_theme_color_override("font_color", Color("ffc4a0"))
	column.add_child(_transfer_error)
	_copy_button = _transfer.add_button("Copy", false, "copy")
	_copy_button.name = "CopyBuild"
	_transfer.confirmed.connect(func() -> void:
		if _exporting:
			_transfer.hide()
		else:
			import_submitted.emit(_transfer_text.text))
	_transfer.custom_action.connect(func(action: StringName) -> void:
		if action == &"copy":
			if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
				DisplayServer.clipboard_set(_transfer_text.text)
				_transfer_error.text = "Copy requested. You can also select and copy the text below."
			else:
				_transfer_error.text = "Clipboard unavailable. Select the JSON and copy it manually.")


func _show_import() -> void:
	_exporting = false
	_transfer.title = "Import a car build"
	_transfer_hint.text = "Paste version 1 JSON.\nReplace its named car.\nOther cars are kept."
	_transfer_text.editable = true
	_transfer_text.text = ""
	_transfer_error.text = ""
	_transfer.get_ok_button().text = "Import"
	_transfer.get_cancel_button().show()
	_copy_button.hide()
	_open_transfer()


func _open_transfer() -> void:
	modal_opened.emit()
	_fit_transfer()
	_transfer.popup(Rect2i(_transfer.position, _transfer.size))
	_transfer_text.grab_focus()
	if _exporting:
		_transfer_text.select_all()


func _fit_transfer() -> void:
	_transfer.content_scale_factor = _ui_factor
	var width := float(_transfer_size().x) / _ui_factor - 48.0
	for label: Label in [_transfer_hint, _transfer_error]:
		label.custom_minimum_size.x = width
		label.size.x = width
	_transfer.size = _transfer_size()
	_transfer.position = Vector2i((size - Vector2(_transfer.size)) * 0.5)


func _ask_reset() -> void:
	modal_opened.emit()
	_reset_dialog.dialog_text = "Restore %s to factory paint and parts? The other cars are kept." \
		% str(Catalog.CARS[_current_car]["title"])
	_fit_reset()
	_reset_dialog.popup(Rect2i(_reset_dialog.position, _reset_dialog.size))
	_reset_dialog.get_cancel_button().grab_focus()


func _fit_reset() -> void:
	_reset_dialog.content_scale_factor = _ui_factor
	var popup_size := Vector2i(mini(int(680 * _ui_factor), int(size.x * 0.9)),
		mini(int(300 * _ui_factor), int(size.y * 0.8)))
	_reset_dialog.get_label().custom_minimum_size.x = float(popup_size.x) / _ui_factor - 48
	_reset_dialog.size = popup_size
	_reset_dialog.position = Vector2i((size - Vector2(_reset_dialog.size)) * 0.5)


func _on_car_selected(index: int) -> void:
	if not _syncing:
		car_selected.emit(Catalog.CAR_IDS[index])


func _emit_part(field: String, value: Variant) -> void:
	if not _syncing and not _locked:
		part_changed.emit(field, value)


func _layout() -> void:
	if _body == null:
		return
	_ui_factor = maxf(1.0, size.x / maxf(get_window().size.x, 1.0) / 1.5 * _interface_scale)
	var frame := size / _ui_factor
	_margins.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_margins.scale = Vector2.ONE * _ui_factor
	var portrait := frame.y > frame.x * 0.95
	var compact := frame.y < 600 or (frame.x < 600 and frame.y < 1000)
	_body.vertical = portrait
	for button in _pitch_buttons:
		button.visible = not compact
	_view_hint.text = "Drag / pinch to inspect." if compact \
		else "Drag to orbit. Wheel / pinch to zoom. All parts are free."
	view.custom_minimum_size.y = 135.0 / _interface_scale
	Responsive.apply_margins(_margins, frame, Vector2(0.018, 0.025),
		Vector2(14, 12), Vector2(44, 32))
	_subtitle.text = "THE GARAGE  /  Three cars. Your signature." if frame.x > 900 else ""
	_editor.custom_minimum_size.x = 0 if portrait else clampf(frame.x * 0.33, 440, 640)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	_stage_column.custom_minimum_size.y = maxf(220, frame.y * 0.30) if portrait else 0
	_stage_column.size_flags_stretch_ratio = 0.9 if portrait else 1.0
	_margins.size = frame
	_fit_content.call_deferred()
	if _transfer != null and _transfer.visible:
		_fit_transfer()
	if _reset_dialog != null and _reset_dialog.visible:
		_fit_reset()


func _fit_content() -> void:
	_margins.size = size / _ui_factor


func _transfer_size() -> Vector2i:
	return Vector2i(mini(int(760 * _ui_factor), int(size.x * 0.9)),
		mini(int(650 * _ui_factor), int(size.y * 0.85)))


static func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _button(text: String, description: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = description
	button.accessibility_name = description
	button.custom_minimum_size = Vector2(66, 66)
	button.add_theme_font_size_override("font_size", 22)
	return button


static func _paint_style(button: Button, color: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = Color("e4b54e") if state in ["pressed", "hover_pressed", "focus"] \
			else Color("9faeb0", 0.5)
		style.set_border_width_all(3 if state in ["pressed", "hover_pressed", "focus"] else 1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override(state, style)
	var ink := Color("102028") if color.get_luminance() > 0.40 else Color("fff7e2")
	for key: String in ["font_color", "font_hover_color", "font_pressed_color",
		"font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
