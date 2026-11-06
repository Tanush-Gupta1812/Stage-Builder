class_name AppStatusBar
extends PanelContainer

## Bottom status bar for Stage-Builder.
## Displays real-time operational messages, snapping toggles, total load weight, and viewport FPS with mode.

signal request_show_performance_settings

@onready var status_lbl: Label = %StatusLabel
@onready var grid_snap_btn: Button = %GridSnapButton
@onready var point_snap_btn: Button = %PointSnapButton
@onready var grid_step_btn: OptionButton = %GridStepButton
@onready var stats_lbl: Label = %StatsLabel
var tool_mode_btn: Button = null
var rot_step_btn: OptionButton = null
var checks_badge_btn: Button = null
var _thumbnail_progress_msg: String = ""


func _ready() -> void:
	status_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stats_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_lbl.tooltip_text = "Navigation: MMB Drag = Walk Move | Alt+MMB = Elevate | Shift+MMB or Alt+LMB = Orbit | Ctrl/Cmd+MMB = Smooth Zoom | Wheel = Zoom | RMB+WASD = Fly"

	AppState.status_message.connect(set_status)
	AppState.selection_changed.connect(func(_s): _update_stats())
	AppState.project_modified.connect(_update_stats)
	AppState.snap_toggled.connect(func(_e): _update_buttons())
	AppState.point_snap_toggled.connect(func(_e): _update_buttons())
	PerformanceSettings.settings_changed.connect(_update_stats)

	if is_instance_valid(ThumbnailRenderer.instance):
		ThumbnailRenderer.instance.progress_changed.connect(_on_thumbnail_progress)

	RiggingManager.rigging_solved.connect(func(_res): _update_checks_badge())

	grid_snap_btn.pressed.connect(_on_toggle_grid_snap)
	point_snap_btn.pressed.connect(_on_toggle_point_snap)
	grid_step_btn.item_selected.connect(_on_grid_step_selected)

	# Click stats label to open Performance Settings
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stats_lbl.tooltip_text = "Click to configure Frame Rate & Performance Settings"
	stats_lbl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			request_show_performance_settings.emit()
	)

	_setup_tool_mode_button()
	_setup_grid_steps()
	_setup_rot_steps()
	_setup_checks_badge()
	_update_buttons()
	_update_stats()


func _process(_delta: float) -> void:
	_update_stats()

func _update_responsive_visibility() -> void:
	var w := size.x
	stats_lbl.visible = true
	if tool_mode_btn:
		tool_mode_btn.visible = (w >= 480.0)
	if checks_badge_btn:
		checks_badge_btn.visible = (w >= 520.0)
	grid_snap_btn.visible = (w >= 640.0)
	point_snap_btn.visible = (w >= 700.0)
	grid_step_btn.visible = (w >= 760.0)
	if rot_step_btn:
		rot_step_btn.visible = (w >= 840.0)

func _setup_tool_mode_button() -> void:
	if not is_instance_valid(tool_mode_btn):
		tool_mode_btn = Button.new()
		tool_mode_btn.name = "ToolModeButton"
		tool_mode_btn.flat = true
		tool_mode_btn.tooltip_text = "Active Viewport Tool (1: Move, 2: Rotate, 3: Scale). Click to cycle."
		tool_mode_btn.pressed.connect(func():
			match AppState.current_tool:
				AppState.ToolMode.MOVE: AppState.current_tool = AppState.ToolMode.ROTATE
				AppState.ToolMode.ROTATE: AppState.current_tool = AppState.ToolMode.SCALE
				AppState.ToolMode.SCALE: AppState.current_tool = AppState.ToolMode.MOVE
				_: AppState.current_tool = AppState.ToolMode.MOVE
		)
		var parent := grid_snap_btn.get_parent()
		if parent:
			parent.add_child(tool_mode_btn)
			parent.move_child(tool_mode_btn, grid_snap_btn.get_index())
	AppState.tool_changed.connect(func(_t): _update_tool_mode_button())
	_update_tool_mode_button()

func _update_tool_mode_button() -> void:
	if not is_instance_valid(tool_mode_btn):
		return
	match AppState.current_tool:
		AppState.ToolMode.MOVE:
			tool_mode_btn.text = "Tool: Move (1)"
			tool_mode_btn.add_theme_color_override("font_color", Color(0.35, 0.70, 1.00))
		AppState.ToolMode.ROTATE:
			tool_mode_btn.text = "Tool: Rotate (2)"
			tool_mode_btn.add_theme_color_override("font_color", Color(0.35, 0.70, 1.00))
		AppState.ToolMode.SCALE:
			tool_mode_btn.text = "Tool: Scale (3)"
			tool_mode_btn.add_theme_color_override("font_color", Color(0.35, 0.70, 1.00))
		AppState.ToolMode.PLACE:
			tool_mode_btn.text = "Tool: Place"
			tool_mode_btn.add_theme_color_override("font_color", Color(1.0, 0.50, 0.40))
		_:
			tool_mode_btn.text = "Tool: Select"
			tool_mode_btn.remove_theme_color_override("font_color")

func _setup_checks_badge() -> void:
	if not is_instance_valid(checks_badge_btn):
		checks_badge_btn = Button.new()
		checks_badge_btn.name = "ChecksBadgeBtn"
		checks_badge_btn.flat = true
		checks_badge_btn.tooltip_text = "Toggle Structural Checks & Warnings Panel (Ctrl+3 / Cmd+3)"
		checks_badge_btn.pressed.connect(func():
			var main_ui = get_tree().root.find_child("Main", true, false)
			if main_ui and main_ui.has_method("toggle_checks_panel"):
				main_ui.toggle_checks_panel()
		)
		var parent := grid_step_btn.get_parent()
		if parent:
			parent.add_child(checks_badge_btn)
			parent.move_child(checks_badge_btn, stats_lbl.get_index())
	_update_checks_badge()

func _update_checks_badge() -> void:
	if not is_instance_valid(checks_badge_btn):
		return
	var crit := RiggingManager.critical_count
	var warn := RiggingManager.warning_count
	if crit == 0 and warn == 0:
		checks_badge_btn.text = "✓ Rigging OK"
		checks_badge_btn.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
	elif crit > 0:
		checks_badge_btn.text = "🔴 %d Critical | ⚠️ %d" % [crit, warn]
		checks_badge_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		checks_badge_btn.text = "⚠️ %d Warnings" % warn
		checks_badge_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))

func _setup_rot_steps() -> void:
	if not is_instance_valid(rot_step_btn):
		rot_step_btn = OptionButton.new()
		rot_step_btn.name = "RotStepButton"
		# Insert next to grid_step_btn
		var parent := grid_step_btn.get_parent()
		if parent:
			parent.add_child(rot_step_btn)
			parent.move_child(rot_step_btn, grid_step_btn.get_index() + 1)

	rot_step_btn.clear()
	rot_step_btn.add_item("Rot: 5°", 0)
	rot_step_btn.add_item("Rot: 15°", 1)
	rot_step_btn.add_item("Rot: 45°", 2)
	rot_step_btn.add_item("Rot: 90°", 3)
	rot_step_btn.select(3) # Default 90°
	rot_step_btn.item_selected.connect(_on_rot_step_selected)

func _on_rot_step_selected(idx: int) -> void:
	match idx:
		0: AppState.rotation_step = 5.0
		1: AppState.rotation_step = 15.0
		2: AppState.rotation_step = 45.0
		3: AppState.rotation_step = 90.0
	AppState.status_message.emit("Rotation step: %d°" % int(AppState.rotation_step))


func _setup_grid_steps() -> void:
	grid_step_btn.clear()
	grid_step_btn.add_item("Grid: 0.25m", 0)
	grid_step_btn.add_item("Grid: 0.50m", 1)
	grid_step_btn.add_item("Grid: 1.00m", 2)
	grid_step_btn.select(1) # Default 0.5m

func _on_grid_step_selected(idx: int) -> void:
	match idx:
		0: AppState.grid_step = 0.25
		1: AppState.grid_step = 0.50
		2: AppState.grid_step = 1.00
	AppState.status_message.emit("Grid snap step: %.2fm" % AppState.grid_step)

func _on_toggle_grid_snap() -> void:
	AppState.snap_to_grid = not AppState.snap_to_grid
	_update_buttons()
	AppState.status_message.emit("Grid snap: " + ("ON" if AppState.snap_to_grid else "OFF"))

func _on_toggle_point_snap() -> void:
	AppState.snap_to_points = not AppState.snap_to_points
	_update_buttons()
	AppState.status_message.emit("Point snap: " + ("ON" if AppState.snap_to_points else "OFF"))

func _update_buttons() -> void:
	grid_snap_btn.text = "Grid Snap: " + ("ON" if AppState.snap_to_grid else "OFF")
	point_snap_btn.text = "Point Snap: " + ("ON" if AppState.snap_to_points else "OFF")

func _update_stats() -> void:
	_update_responsive_visibility()
	var count := AppState.get_total_object_count()
	var weight := AppState.get_total_weight()
	var fps := Engine.get_frames_per_second()
	var mode_str := PerformanceSettings.get_fps_mode_string()
	var w := size.x
	if w > 0.0 and w < 840.0:
		stats_lbl.text = "FPS: %d (%s)" % [fps, mode_str]
	else:
		stats_lbl.text = "Items: %d  |  Weight: %.1f kg  |  FPS: %d (%s)" % [count, weight, fps, mode_str]

func _on_thumbnail_progress(completed: int, total: int) -> void:
	if total > 0 and completed < total:
		_thumbnail_progress_msg = "Thumbnails %d/%d" % [completed, total]
		status_lbl.text = _thumbnail_progress_msg
	elif total > 0 and completed >= total:
		_thumbnail_progress_msg = ""
		status_lbl.text = "Thumbnails %d/%d (Complete)" % [completed, total]
	else:
		_thumbnail_progress_msg = ""

func set_status(msg: String) -> void:
	if _thumbnail_progress_msg != "" and msg == "Ready":
		status_lbl.text = _thumbnail_progress_msg
	else:
		status_lbl.text = msg
