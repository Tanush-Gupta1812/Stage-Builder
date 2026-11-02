class_name PerformanceSettingsDialog
extends AcceptDialog

## Dialog for configuring Frame Rate, VSync, and Unfocused Power Saving.
## Supports presets (30, 60, 90, 120, 144, 240), manual input (15-1000),
## and platform-specific behavior explanations for Windows and macOS.

var vsync_radio: CheckBox
var custom_radio: CheckBox
var unlimited_radio: CheckBox
var radio_group: ButtonGroup

var custom_spinbox: SpinBox
var preset_buttons: Array[Button] = []
var unfocused_checkbox: CheckBox
var platform_note_lbl: Label

func _init() -> void:
	title = "Performance & Frame Rate Settings"
	ok_button_text = "Close"
	min_size = Vector2(460, 380)

func _ready() -> void:
	_build_ui()
	PerformanceSettings.settings_changed.connect(_sync_from_settings)
	visibility_changed.connect(func():
		if visible:
			_sync_from_settings()
	)

func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	add_child(root_vbox)

	var desc := Label.new()
	desc.text = "Configure 3D viewport rendering performance, display synchronization, and background power consumption."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))
	root_vbox.add_child(desc)

	root_vbox.add_child(HSeparator.new())

	# --- Radio Mode Group ---
	radio_group = ButtonGroup.new()

	# 1. VSync
	vsync_radio = CheckBox.new()
	vsync_radio.text = "VSync (Default)"
	vsync_radio.button_group = radio_group
	vsync_radio.tooltip_text = "Synchronize rendering with display refresh rate to eliminate tearing. (On macOS, system compositor always enforces display sync)."
	vsync_radio.pressed.connect(func():
		PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.VSYNC)
	)
	root_vbox.add_child(vsync_radio)

	var vsync_sub := Label.new()
	vsync_sub.text = "   Matches your monitor refresh rate (60Hz, 120Hz, 144Hz, etc.) with zero screen tearing."
	vsync_sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	root_vbox.add_child(vsync_sub)

	# 2. Custom FPS Limit
	custom_radio = CheckBox.new()
	custom_radio.text = "Custom FPS Limit"
	custom_radio.button_group = radio_group
	custom_radio.tooltip_text = "Cap rendering to a specific target frame rate. Disables VSync. (Note: On macOS, system sync may still cap rate to display Hz)."
	custom_radio.pressed.connect(func():
		PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.CUSTOM_LIMIT)
	)
	root_vbox.add_child(custom_radio)

	# Custom controls container
	var custom_box := HBoxContainer.new()
	custom_box.add_theme_constant_override("separation", 8)
	root_vbox.add_child(custom_box)

	var indent_lbl := Label.new()
	indent_lbl.text = "   Target:"
	indent_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	custom_box.add_child(indent_lbl)

	custom_spinbox = SpinBox.new()
	custom_spinbox.min_value = PerformanceSettings.MIN_FPS
	custom_spinbox.max_value = PerformanceSettings.MAX_FPS
	custom_spinbox.step = 1
	custom_spinbox.value = PerformanceSettings.custom_fps_limit
	custom_spinbox.suffix = "FPS"
	custom_spinbox.custom_minimum_size.x = 90
	custom_spinbox.tooltip_text = "Target frame rate limit (15 to 1000 FPS)."
	custom_spinbox.value_changed.connect(func(val: float):
		PerformanceSettings.set_custom_limit(int(val))
		if not custom_radio.button_pressed:
			custom_radio.button_pressed = true
			PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.CUSTOM_LIMIT)
	)
	custom_box.add_child(custom_spinbox)

	# Quick Presets: 30, 60, 90, 120, 144, 240
	var presets_lbl := Label.new()
	presets_lbl.text = "Presets:"
	presets_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	custom_box.add_child(presets_lbl)

	var presets := [30, 60, 90, 120, 144, 240]
	for p in presets:
		var btn := Button.new()
		btn.text = str(p)
		btn.tooltip_text = "Set FPS limit to %d" % p
		btn.pressed.connect(func(target_fps: int = p):
			custom_spinbox.value = target_fps
			PerformanceSettings.set_custom_limit(target_fps)
			custom_radio.button_pressed = true
			PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.CUSTOM_LIMIT)
		)
		preset_buttons.append(btn)
		custom_box.add_child(btn)

	# 3. Unlimited
	unlimited_radio = CheckBox.new()
	unlimited_radio.text = "Unlimited (Uncapped)"
	unlimited_radio.button_group = radio_group
	unlimited_radio.tooltip_text = "Disables VSync and frame caps. Note: on macOS, 'Unlimited' is not meaningful as macOS Metal compositor forces display sync."
	unlimited_radio.pressed.connect(func():
		PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.UNLIMITED)
	)
	root_vbox.add_child(unlimited_radio)

	var unlim_sub := Label.new()
	unlim_sub.text = "   Renders as fast as GPU allows with VSync disabled. May increase GPU temperature and power usage."
	unlim_sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	root_vbox.add_child(unlim_sub)

	root_vbox.add_child(HSeparator.new())

	# --- Unfocused Power Saving Checkbox ---
	unfocused_checkbox = CheckBox.new()
	unfocused_checkbox.text = "Limit to 30 FPS when window is unfocused or minimized"
	unfocused_checkbox.tooltip_text = "Reduces rendering to 30 FPS when switching to other apps or minimizing to save battery and reduce background GPU usage."
	unfocused_checkbox.toggled.connect(func(toggled_on: bool):
		PerformanceSettings.set_limit_fps_unfocused(toggled_on)
	)
	root_vbox.add_child(unfocused_checkbox)

	root_vbox.add_child(HSeparator.new())

	# --- Platform Notes Panel ---
	var note_panel := PanelContainer.new()
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = Color(0.14, 0.16, 0.20, 0.8)
	note_style.border_color = Color(0.25, 0.35, 0.50, 0.6)
	note_style.set_border_width_all(1)
	note_style.set_corner_radius_all(4)
	note_style.set_content_margin_all(8)
	note_panel.add_theme_stylebox_override("panel", note_style)

	platform_note_lbl = Label.new()
	platform_note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	platform_note_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))

	if OS.get_name() == "macOS":
		platform_note_lbl.text = "ℹ macOS Note: The macOS window manager & Metal compositor enforce display synchronization system-wide. 'Unlimited' or caps above your display refresh rate (e.g. 60Hz or 120Hz ProMotion) will be constrained to the active display rate."
	else:
		platform_note_lbl.text = "ℹ Windows Note: VSync eliminates tearing by synchronizing with monitor scanlines. Selecting 'Custom Limit' or 'Unlimited' disables VSync for lowest input latency, but may exhibit visual tearing."

	note_panel.add_child(platform_note_lbl)
	root_vbox.add_child(note_panel)

	_sync_from_settings()

func _sync_from_settings() -> void:
	if not is_instance_valid(vsync_radio):
		return

	match PerformanceSettings.fps_mode:
		PerformanceSettings.FPSMode.VSYNC:
			vsync_radio.button_pressed = true
		PerformanceSettings.FPSMode.CUSTOM_LIMIT:
			custom_radio.button_pressed = true
		PerformanceSettings.FPSMode.UNLIMITED:
			unlimited_radio.button_pressed = true

	if is_instance_valid(custom_spinbox):
		custom_spinbox.set_value_no_signal(PerformanceSettings.custom_fps_limit)

	if is_instance_valid(unfocused_checkbox):
		unfocused_checkbox.set_pressed_no_signal(PerformanceSettings.limit_fps_unfocused)
