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

func _ready() -> void:
	status_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stats_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	AppState.status_message.connect(set_status)
	AppState.selection_changed.connect(func(_s): _update_stats())
	AppState.project_modified.connect(_update_stats)
	AppState.snap_toggled.connect(func(_e): _update_buttons())
	AppState.point_snap_toggled.connect(func(_e): _update_buttons())
	PerformanceSettings.settings_changed.connect(_update_stats)

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

	_setup_grid_steps()
	_update_buttons()
	_update_stats()

func _process(_delta: float) -> void:
	_update_stats()
	_update_responsive_visibility()

func _update_responsive_visibility() -> void:
	var w := size.x
	# Keep stats_lbl permanently visible across all UI scales
	stats_lbl.visible = true
	grid_step_btn.visible = (w >= 540.0)

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
	var count := AppState.get_total_object_count()
	var weight := AppState.get_total_weight()
	var fps := Engine.get_frames_per_second()
	var mode_str := PerformanceSettings.get_fps_mode_string()
	var w := size.x
	if w > 0.0 and w < 650.0:
		# Compact stats for narrow window widths or high UI scaling tiers
		stats_lbl.text = "FPS: %d (%s)" % [fps, mode_str]
	else:
		stats_lbl.text = "Items: %d  |  Weight: %.1f kg  |  FPS: %d (%s)" % [count, weight, fps, mode_str]

func set_status(msg: String) -> void:
	status_lbl.text = msg
