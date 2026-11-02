class_name MainUI
extends Control

const AssetImportDialog = preload("res://scripts/ui/asset_import_dialog.gd")
const PerformanceSettingsDialog = preload("res://scripts/ui/performance_settings_dialog.gd")

## Top-level UI controller for Stage-Builder.
## Manages dock layouts, theme styling, file dialogs, keyboard shortcuts, and dialog popups.

@onready var menu_bar: AppMenuBar = %AppMenuBar
@onready var asset_panel: AssetPanel = %AssetPanel
@onready var properties_panel: PropertiesPanel = %PropertiesPanel
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
	_setup_autosave()
	_connect_menu_signals()

	resized.connect(_update_layout_proportions)
	if UIScale:
		UIScale.scale_changed.connect(func(_s): _update_layout_proportions())

	_update_layout_proportions()

func _setup_theme() -> void:
	if theme == null:
		theme = Theme.new()
	theme.default_font_size = 14
	theme.set_font_size("font_size", "Label", 14)
	theme.set_font_size("font_size", "Button", 13)
	theme.set_font_size("font_size", "OptionButton", 13)
	theme.set_font_size("font_size", "PopupMenu", 13)
	theme.set_font_size("font_size", "LineEdit", 13)
	theme.set_font_size("font_size", "TabBar", 13)
	theme.set_font_size("font_size", "Tree", 13)

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
- Orbit View: Middle Mouse Button OR Alt + Left Mouse Button
- Pan View: Shift + Middle Mouse Button OR Mac Trackpad Two-Finger Pan
- Zoom: Mouse Wheel OR Mac Trackpad Pinch
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
""" % [mod, mod, mod, mod, mod, mod, mod, mod, mod, mod]
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
	asset_panel.collapse_requested.connect(func(): toggle_catalog(false))
	properties_panel.collapse_requested.connect(func(): toggle_properties(false))
	expand_left_btn.pressed.connect(func(): toggle_catalog(true))
	expand_right_btn.pressed.connect(func(): toggle_properties(true))

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	# If user is editing in a text field, do not consume shortcuts (allow typing/backspace/delete)
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	var is_ctrl := key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed)

	# 1. Panel Toggles: Ctrl/Cmd + [ and Ctrl/Cmd + ]
	if is_ctrl and key.keycode == KEY_BRACKETLEFT:
		toggle_catalog()
		get_viewport().set_input_as_handled()
		return
	elif is_ctrl and key.keycode == KEY_BRACKETRIGHT:
		toggle_properties()
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

	# 10. Escape: Cancel placement or deselect
	if key.keycode == KEY_ESCAPE:
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

