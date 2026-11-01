class_name MainUI
extends Control

## Top-level UI controller for Stage-Builder.
## Manages dock layouts, theme styling, file dialogs, keyboard shortcuts, and dialog popups.

@onready var menu_bar: AppMenuBar = %AppMenuBar
@onready var asset_panel: AssetPanel = %AssetPanel
@onready var properties_panel: PropertiesPanel = %PropertiesPanel
@onready var status_bar: AppStatusBar = %StatusBar

var save_file_dialog: FileDialog
var open_file_dialog: FileDialog
var shortcuts_dialog: AcceptDialog
var about_dialog: AcceptDialog
var autosave_timer: Timer

func _ready() -> void:
	_setup_dialogs()
	_setup_autosave()
	_connect_menu_signals()

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
- Screenshot: %s + E (Exports PNG to user://screenshots)
""" % [mod, mod, mod, mod, mod, mod, mod, mod]
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
	menu_bar.request_show_shortcuts.connect(func(): shortcuts_dialog.popup_centered(Vector2i(540, 480)))
	menu_bar.request_show_about.connect(func(): about_dialog.popup_centered(Vector2i(480, 320)))

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

