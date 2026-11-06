class_name MainUI
extends Control

const AssetImportDialog = preload("res://scripts/ui/asset_import_dialog.gd")
const PerformanceSettingsDialog = preload("res://scripts/ui/performance_settings_dialog.gd")
const ThumbnailGenerator = preload("res://scripts/tools/thumbnail_generator.gd")
const ChecksPanelScene = preload("res://scenes/ui/checks_panel.tscn")


## Top-level UI controller for Stage-Builder.
## Manages dock layouts, theme styling, file dialogs, keyboard shortcuts, and dialog popups.

@onready var menu_bar: AppMenuBar = %AppMenuBar
@onready var asset_panel: AssetPanel = %AssetPanel
@onready var properties_panel: PropertiesPanel = %PropertiesPanel
var checks_panel: Control = null
@onready var status_bar: AppStatusBar = %StatusBar
@onready var stage_viewport: Control = %StageViewport
@onready var expand_left_btn: Button = %ExpandLeftBtn
@onready var expand_right_btn: Button = %ExpandRightBtn

var save_file_dialog: FileDialog
var open_file_dialog: FileDialog
var import_file_dialog: FileDialog
var asset_import_dialog: AssetImportDialog
var performance_dialog: PerformanceSettingsDialog
var shortcuts_dialog: AcceptDialog
var about_dialog: AcceptDialog
var autosave_timer: Timer

func _ready() -> void:
	_setup_theme()
	_setup_dialogs()
	_setup_checks_panel()
	_setup_autosave()
	_setup_tool_actions()
	_connect_menu_signals()



	resized.connect(_update_layout_proportions)
	if UIScale:
		UIScale.scale_changed.connect(func(_s): _update_layout_proportions())

	_update_layout_proportions()

func _setup_theme() -> void:
	if theme == null:
		theme = Theme.new()

	# Fixed typography scale at UI scale 1.0 (ContentScaleFactor scales automatically)
	# Body: 13-14 px, Small: 12 px, Panel headings: 16 px, Toolbar labels: 13 px
	theme.default_font_size = 13
	theme.set_font_size("font_size", "Label", 13)
	theme.set_font_size("font_size", "Button", 13)
	theme.set_font_size("font_size", "OptionButton", 13)
	theme.set_font_size("font_size", "PopupMenu", 13)
	theme.set_font_size("font_size", "LineEdit", 13)
	theme.set_font_size("font_size", "TextEdit", 13)
	theme.set_font_size("font_size", "SpinBox", 13)
	theme.set_font_size("font_size", "TabBar", 13)
	theme.set_font_size("font_size", "Tree", 13)
	theme.set_font_size("font_size", "RichTextLabel", 13)

	# Colors
	theme.set_color("font_color", "Label", Color(0.90, 0.92, 0.96))
	theme.set_color("font_color", "Button", Color(0.88, 0.90, 0.94))
	theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	theme.set_color("font_pressed_color", "Button", Color(1.0, 1.0, 1.0))
	theme.set_color("font_disabled_color", "Button", Color(0.50, 0.53, 0.58))

	# Button styles: 4px corner radius, 1px border, 4/8px padding
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.16, 0.18, 0.22)
	btn_normal.border_color = Color(0.24, 0.27, 0.33)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(4)
	btn_normal.content_margin_left = 8
	btn_normal.content_margin_right = 8
	btn_normal.content_margin_top = 4
	btn_normal.content_margin_bottom = 4
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.20, 0.24, 0.30)
	btn_hover.border_color = Color(0.35, 0.45, 0.60)
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.18, 0.38, 0.75)
	btn_pressed.border_color = Color(0.35, 0.65, 1.00)
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := btn_normal.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.12, 0.13, 0.16, 0.5)
	btn_disabled.border_color = Color(0.18, 0.20, 0.24, 0.5)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# LineEdit styles
	var le_normal := StyleBoxFlat.new()
	le_normal.bg_color = Color(0.11, 0.12, 0.15)
	le_normal.border_color = Color(0.24, 0.27, 0.33)
	le_normal.set_border_width_all(1)
	le_normal.set_corner_radius_all(4)
	le_normal.content_margin_left = 8
	le_normal.content_margin_right = 8
	le_normal.content_margin_top = 4
	le_normal.content_margin_bottom = 4
	theme.set_stylebox("normal", "LineEdit", le_normal)

	var le_focus := le_normal.duplicate() as StyleBoxFlat
	le_focus.border_color = Color(0.30, 0.60, 1.00)
	theme.set_stylebox("focus", "LineEdit", le_focus)

	# Thin Separator
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.22, 0.25, 0.30)
	sep_style.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep_style)

	var vsep_style := StyleBoxLine.new()
	vsep_style.color = Color(0.22, 0.25, 0.30)
	vsep_style.thickness = 1
	vsep_style.vertical = true
	theme.set_stylebox("separator", "VSeparator", vsep_style)

func _update_layout_proportions() -> void:
	var total_w := size.x
	if total_w <= 0:
		return

	if asset_panel and asset_panel.visible:
		var target_left := clampf(total_w * 0.22, 260.0, 420.0)
		asset_panel.custom_minimum_size.x = target_left

	if properties_panel and properties_panel.visible:
		var target_right := clampf(total_w * 0.18, 240.0, 360.0)
		properties_panel.custom_minimum_size.x = target_right

	if checks_panel and checks_panel.visible:
		var target_checks := clampf(total_w * 0.22, 260.0, 380.0)
		checks_panel.custom_minimum_size.x = target_checks

	if stage_viewport:
		stage_viewport.custom_minimum_size = Vector2(400, 300)

func toggle_catalog(force_state: Variant = null) -> void:
	var target: bool = not asset_panel.visible if force_state == null else bool(force_state)
	asset_panel.visible = target
	expand_left_btn.visible = not target
	menu_bar.set_catalog_checked(target)
	_update_layout_proportions()

func toggle_properties(force_state: Variant = null) -> void:
	var target: bool = not properties_panel.visible if force_state == null else bool(force_state)
	properties_panel.visible = target
	expand_right_btn.visible = not target
	menu_bar.set_properties_checked(target)
	_update_layout_proportions()

func _setup_checks_panel() -> void:
	if checks_panel == null:
		var panel_inst: Control = ChecksPanelScene.instantiate()
		panel_inst.name = "ChecksPanel"
		panel_inst.visible = false
		var split := properties_panel.get_parent()
		if split:
			split.add_child(panel_inst)
			split.move_child(panel_inst, properties_panel.get_index())
		checks_panel = panel_inst
		if checks_panel.has_signal("close_requested"):
			checks_panel.close_requested.connect(func(): toggle_checks_panel(false))

func toggle_checks_panel(force_state: Variant = null) -> void:
	if checks_panel == null:
		_setup_checks_panel()
	if checks_panel == null:
		return
	var target: bool = not checks_panel.visible if force_state == null else bool(force_state)
	checks_panel.visible = target
	menu_bar.set_checks_checked(target)
	_update_layout_proportions()

func _setup_dialogs() -> void:
	# Save File Dialog
	save_file_dialog = FileDialog.new()
	save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_file_dialog.add_filter("*.stagebuilder", "Stage-Builder Project Files")
	save_file_dialog.title = "Save Stage Project"
	save_file_dialog.file_selected.connect(_on_save_file_selected)
	add_child(save_file_dialog)

	# Open File Dialog
	open_file_dialog = FileDialog.new()
	open_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_file_dialog.add_filter("*.stagebuilder", "Stage-Builder Project Files")
	open_file_dialog.title = "Open Stage Project"
	open_file_dialog.file_selected.connect(_on_open_file_selected)
	add_child(open_file_dialog)

	# Import GLTF/GLB File Dialog
	import_file_dialog = FileDialog.new()
	import_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_file_dialog.add_filter("*.gltf, *.glb", "3D Models (GLTF / GLB)")
	import_file_dialog.title = "Select 3D Model to Import"
	import_file_dialog.file_selected.connect(_on_import_file_selected)
	add_child(import_file_dialog)

	# Asset Import Wizard Dialog
	asset_import_dialog = AssetImportDialog.new()
	add_child(asset_import_dialog)

	# Performance & Frame Rate Settings Dialog
	performance_dialog = PerformanceSettingsDialog.new()
	add_child(performance_dialog)

	# Shortcuts Dialog
	shortcuts_dialog = AcceptDialog.new()
	shortcuts_dialog.title = "Keyboard & Mouse Controls"
	var mod := PlatformUtils.get_modifier_name()
	shortcuts_dialog.dialog_text = """STAGE-BUILDER CONTROLS

VIEWPORT NAVIGATION:
- Walk Move (Ground-Parallel): Middle Mouse Drag (level W/S/A/D equivalent)
- Elevate View: Alt + Middle Mouse Drag (raise/lower height)
- Orbit View: Shift + Middle Mouse Drag OR Alt + Left Mouse Drag OR Option + Two-Finger Drag
- Pan View: Alt + Shift + Left Mouse Drag OR Trackpad Two-Finger Scroll
- Smooth Zoom: %s + Middle Mouse Drag
- Zoom Viewport: Mouse Wheel Up / Down OR Mac Trackpad Pinch
- WASD Fly Mode: Hold Right Mouse Button + W/A/S/D/Q/E
- Quick Views: Numpad 7 (Top), 1 (Front), 3 (Side), 0 (Perspective)
- Frame Selection: F

EQUIPMENT EDITING:
- Select: Left Click on object
- Multi-Select: Shift + Left Click OR %s + Left Click
- Box Select: Drag box on empty canvas
- Move/Rotate: Click and drag 3D Gizmo handles
- Duplicate: %s + D
- Delete: Delete OR Backspace
- Group / Ungroup: %s + G / %s + Shift + G
- Undo / Redo: %s + Z / %s + Y (or Shift+%s+Z)

VIEW & ENVIRONMENT:
- Toggle Grid: G
- Toggle Snap: S
- Toggle Catalog Panel: %s + [
- Toggle Properties Panel: %s + ]
- Screenshot: %s + E (Exports PNG to user://screenshots)
""" % [mod, mod, mod, mod, mod, mod, mod, mod, mod, mod, mod]
	add_child(shortcuts_dialog)

	# About Dialog
	about_dialog = AcceptDialog.new()
	about_dialog.title = "About Stage-Builder"
	about_dialog.dialog_text = """Stage-Builder v1.0.0
Native Desktop 3D Simulator for Event & Stage Design.

Built with Godot 4.x & GDScript.
Real-world physical scale: 1 unit = 1 meter.
Targets: Windows 10/11 (x86_64) & macOS (Apple Silicon + Intel Universal).

Features:
- 27 Standard Production Equipment Assets
- Real-world physics scale, weight calculation & snap points
- Interactive 3D Gizmo and Command-Pattern Undo/Redo
- Dynamic 1m/5m Grid & Dusk Sky Environment
- .stagebuilder Project File Format with Autosave
"""
	add_child(about_dialog)

func _setup_autosave() -> void:
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 120.0 # 2 minutes
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(func():
		ProjectSerializer.autosave()
	)
	add_child(autosave_timer)

func _connect_menu_signals() -> void:
	menu_bar.request_new_file.connect(_on_new_file)
	menu_bar.request_save_file.connect(_on_request_save)
	menu_bar.request_open_file.connect(_on_request_open)
	menu_bar.request_import_file.connect(func(): import_file_dialog.popup_file_dialog())
	menu_bar.request_show_shortcuts.connect(func(): shortcuts_dialog.popup_centered(Vector2i(540, 480)))
	menu_bar.request_show_about.connect(func(): about_dialog.popup_centered(Vector2i(480, 320)))
	menu_bar.request_show_performance_settings.connect(func(): performance_dialog.popup_centered(Vector2i(480, 420)))
	status_bar.request_show_performance_settings.connect(func(): performance_dialog.popup_centered(Vector2i(480, 420)))

	menu_bar.request_toggle_catalog.connect(toggle_catalog)
	menu_bar.request_toggle_properties.connect(toggle_properties)
	menu_bar.request_toggle_checks.connect(func(): toggle_checks_panel())
	if checks_panel and checks_panel.has_signal("close_requested"):
		checks_panel.close_requested.connect(func(): toggle_checks_panel(false))
	asset_panel.collapse_requested.connect(func(): toggle_catalog(false))
	properties_panel.collapse_requested.connect(func(): toggle_properties(false))
	expand_left_btn.pressed.connect(func(): toggle_catalog(true))
	expand_right_btn.pressed.connect(func(): toggle_properties(true))

func _setup_tool_actions() -> void:
	_register_action("tool_move", KEY_1)
	_register_action("tool_rotate", KEY_2)
	_register_action("tool_scale", KEY_3)
	_register_action("tool_toggle_all_axes", KEY_X)

func _register_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)

func _input(event: InputEvent) -> void:
	# Global UI Scale Shortcuts (accessible from anywhere, even with focus inside LineEdit / SearchBox)
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			var is_ctrl := key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed)
			if is_ctrl:
				var is_plus := (key.keycode == KEY_PLUS or key.physical_keycode == KEY_PLUS
					or key.keycode == KEY_KP_ADD or key.physical_keycode == KEY_KP_ADD
					or ((key.keycode == KEY_EQUAL or key.physical_keycode == KEY_EQUAL) and key.shift_pressed))
				var is_minus := (key.keycode == KEY_MINUS or key.physical_keycode == KEY_MINUS
					or key.keycode == KEY_KP_SUBTRACT or key.physical_keycode == KEY_KP_SUBTRACT)
				var is_zero := (key.keycode == KEY_0 or key.physical_keycode == KEY_0
					or key.keycode == KEY_KP_0 or key.physical_keycode == KEY_KP_0)

				if is_plus:
					UIScale.zoom_in()
					get_viewport().set_input_as_handled()
					return
				elif is_minus:
					UIScale.zoom_out()
					get_viewport().set_input_as_handled()
					return
				elif is_zero:
					UIScale.reset_to_auto()
					get_viewport().set_input_as_handled()
					return

	# Ctrl/Cmd + Mouse Wheel over UI panels (not over the 3D viewport)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var is_ctrl := mb.ctrl_pressed or (OS.get_name() == "macOS" and mb.meta_pressed)
		if is_ctrl and mb.pressed:
			var vp_rect := stage_viewport.get_global_rect() if stage_viewport else Rect2()
			if not vp_rect.has_point(mb.global_position):
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					UIScale.zoom_in()
					get_viewport().set_input_as_handled()
					return
				elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					UIScale.zoom_out()
					get_viewport().set_input_as_handled()
					return

	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	var is_ctrl := key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed)

	# Ctrl/Cmd + F: Focus Catalog Search Box
	if is_ctrl and (key.keycode == KEY_F or key.physical_keycode == KEY_F) and not key.shift_pressed:
		if asset_panel and not asset_panel.visible:
			toggle_catalog(true)
		if asset_panel and asset_panel.search_input:
			asset_panel.search_input.grab_focus()
			asset_panel.search_input.select_all()
		get_viewport().set_input_as_handled()
		return

	# If user is editing in a text field, do not consume shortcuts (allow typing/backspace/delete)
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	# 1. Panel Toggles: Ctrl/Cmd + [, Ctrl/Cmd + ], Ctrl/Cmd + 3
	if is_ctrl and key.keycode == KEY_BRACKETLEFT:
		toggle_catalog()
		get_viewport().set_input_as_handled()
		return
	elif is_ctrl and key.keycode == KEY_BRACKETRIGHT:
		toggle_properties()
		get_viewport().set_input_as_handled()
		return
	elif is_ctrl and (key.keycode == KEY_3 or key.physical_keycode == KEY_3):
		toggle_checks_panel()
		get_viewport().set_input_as_handled()
		return

	# 2. Undo / Redo: Ctrl/Cmd + Z, Ctrl/Cmd + Y, Ctrl/Cmd + Shift + Z
	if is_ctrl and key.keycode == KEY_Z and not key.shift_pressed:
		CommandManager.undo()
		get_viewport().set_input_as_handled()
		return
	elif (is_ctrl and key.keycode == KEY_Y) or (is_ctrl and key.shift_pressed and key.keycode == KEY_Z):
		CommandManager.redo()
		get_viewport().set_input_as_handled()
		return

	# 3. Duplicate: Ctrl/Cmd + D
	if is_ctrl and key.keycode == KEY_D:
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_duplicate_selection"):
			vp._duplicate_selection()
		get_viewport().set_input_as_handled()
		return

	# 4. Delete: Delete or Backspace
	if (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE) and not is_ctrl:
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_delete_selection"):
			vp._delete_selection()
		get_viewport().set_input_as_handled()
		return

	# 5. Group: Ctrl/Cmd + G
	if is_ctrl and key.keycode == KEY_G and not key.shift_pressed:
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_group_selection"):
			vp._group_selection()
		get_viewport().set_input_as_handled()
		return

	# 6. Ungroup: Ctrl/Cmd + Shift + G
	if is_ctrl and key.keycode == KEY_G and key.shift_pressed:
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_ungroup_selection"):
			vp._ungroup_selection()
		get_viewport().set_input_as_handled()
		return

	# 7. Select All: Ctrl/Cmd + A
	if is_ctrl and key.keycode == KEY_A:
		AppState.select_all()
		get_viewport().set_input_as_handled()
		return

	# 8. Grid Snap Toggle: 'G' (without Ctrl)
	if key.keycode == KEY_G and not is_ctrl and not key.alt_pressed:
		AppState.show_grid = not AppState.show_grid
		AppState.status_message.emit("3D Grid: " + ("ON" if AppState.show_grid else "OFF"))
		get_viewport().set_input_as_handled()
		return

	# 9. Point Snap Toggle: 'S' (without Ctrl)
	if key.keycode == KEY_S and not is_ctrl and not key.alt_pressed:
		AppState.snap_to_points = not AppState.snap_to_points
		AppState.status_message.emit("Point Snap: " + ("ON" if AppState.snap_to_points else "OFF"))
		get_viewport().set_input_as_handled()
		return

	# 10. Rigging Overlay Toggle: 'O' (without Ctrl)
	if (key.keycode == KEY_O or key.physical_keycode == KEY_O) and not is_ctrl and not key.alt_pressed:
		RiggingManager.toggle_overlay()
		get_viewport().set_input_as_handled()
		return

	# Selection Rotation Keys: R/Shift+R (Yaw), T/Shift+T (Pitch), Y/Shift+Y (Roll)
	if not AppState.selected_objects.is_empty() and AppState.current_tool != AppState.ToolMode.PLACE:
		var step_deg := AppState.rotation_step
		if is_ctrl:
			step_deg = 5.0 # Fine rotation
		var sign_val := -1.0 if key.shift_pressed else 1.0

		var vp := get_tree().root.find_child("StageViewport", true, false)
		if key.keycode == KEY_R and not is_ctrl and not key.alt_pressed:
			if vp and vp.has_method("rotate_selected_objects"):
				vp.rotate_selected_objects(Vector3.UP, sign_val * step_deg)
				var sign_str := "+" if sign_val > 0 else "-"
				AppState.status_message.emit("Rotated Yaw %s%d deg" % [sign_str, int(step_deg)])

			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_T and not is_ctrl and not key.alt_pressed:
			if vp and vp.has_method("rotate_selected_objects"):
				vp.rotate_selected_objects(Vector3.RIGHT, sign_val * step_deg)
				var sign_str := "+" if sign_val > 0 else "-"
				AppState.status_message.emit("Rotated Pitch %s%d deg" % [sign_str, int(step_deg)])
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_Y and not is_ctrl and not key.alt_pressed:
			if vp and vp.has_method("rotate_selected_objects"):
				vp.rotate_selected_objects(Vector3.BACK, sign_val * step_deg)
				var sign_str := "+" if sign_val > 0 else "-"
				AppState.status_message.emit("Rotated Roll %s%d deg" % [sign_str, int(step_deg)])
			get_viewport().set_input_as_handled()
			return



	# 11. Tool Mode Shortcuts: 1 = Move, 2 = Rotate, 3 = Scale (plain digits, no modifiers)
	if not is_ctrl and not key.alt_pressed and not key.shift_pressed:
		if event.is_action_pressed("tool_move") or key.keycode == KEY_1 or key.physical_keycode == KEY_1:
			AppState.current_tool = AppState.ToolMode.MOVE
			AppState.status_message.emit("Tool: Move")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("tool_rotate") or key.keycode == KEY_2 or key.physical_keycode == KEY_2:
			AppState.current_tool = AppState.ToolMode.ROTATE
			AppState.status_message.emit("Tool: Rotate")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("tool_scale") or key.keycode == KEY_3 or key.physical_keycode == KEY_3:
			AppState.current_tool = AppState.ToolMode.SCALE
			AppState.status_message.emit("Tool: Scale")
			get_viewport().set_input_as_handled()
			return

	# 12. Key X in Rotate mode: toggle all axes
	if (event.is_action_pressed("tool_toggle_all_axes") or key.keycode == KEY_X or key.physical_keycode == KEY_X) and not is_ctrl and not key.alt_pressed:
		if AppState.current_tool == AppState.ToolMode.ROTATE:
			AppState.show_all_rotation_axes = not AppState.show_all_rotation_axes
			AppState.status_message.emit("Rotate axes: " + ("Pitch, Yaw, Roll" if AppState.show_all_rotation_axes else "Yaw Only"))
			get_viewport().set_input_as_handled()
			return

	# 13. Escape: Cancel drag, placement, or deselect
	if key.keycode == KEY_ESCAPE:
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp:
			if vp.get("_is_direct_dragging") or vp.get("_direct_drag_pending"):
				vp.cancel_direct_drag()
				get_viewport().set_input_as_handled()
				return
			if vp.gizmo and vp.gizmo.is_dragging:
				vp.gizmo.cancel_drag()
				get_viewport().set_input_as_handled()
				return
		if AppState.current_tool == AppState.ToolMode.PLACE:
			AppState.cancel_placement()
		else:
			AppState.clear_selection()
		get_viewport().set_input_as_handled()
		return

func _on_new_file() -> void:
	if AppState.stage_container:
		AppState.clear_selection()
		for child in AppState.stage_container.get_children():
			if child is StageObject:
				AppState.stage_container.remove_child(child)
				child.queue_free()
		CommandManager.clear()
		AppState.project_name = "Untitled Stage"
		AppState.current_project_path = ""
		AppState.is_modified = false
		AppState.status_message.emit("New project created.")

func _on_request_save(save_as: bool) -> void:
	if save_as or AppState.current_project_path == "":
		save_file_dialog.popup_file_dialog()
	else:
		var camera: Camera3D = get_tree().root.find_child("StageCamera", true, false)
		ProjectSerializer.save_project(AppState.current_project_path, camera)

func _on_save_file_selected(path: String) -> void:
	var camera: Camera3D = get_tree().root.find_child("StageCamera", true, false)
	ProjectSerializer.save_project(path, camera)

func _on_request_open() -> void:
	open_file_dialog.popup_file_dialog()

func _on_open_file_selected(path: String) -> void:
	var camera: Camera3D = get_tree().root.find_child("StageCamera", true, false)
	ProjectSerializer.load_project(path, camera)

func _on_import_file_selected(path: String) -> void:
	asset_import_dialog.inspect_and_open(path)

