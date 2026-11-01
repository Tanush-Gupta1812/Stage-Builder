class_name AppStatusBar
extends PanelContainer

## Bottom status bar for Stage-Builder.
## Displays real-time operational messages, snapping toggles, total load weight, and viewport FPS.

@onready var status_lbl: Label = %StatusLabel
@onready var grid_snap_btn: Button = %GridSnapButton
@onready var point_snap_btn: Button = %PointSnapButton
@onready var grid_step_btn: OptionButton = %GridStepButton
@onready var stats_lbl: Label = %StatsLabel

func _ready() -> void:
	AppState.status_message.connect(set_status)
	AppState.selection_changed.connect(func(_s): _update_stats())
	AppState.project_modified.connect(_update_stats)
	AppState.snap_toggled.connect(func(_e): _update_buttons())

	grid_snap_btn.pressed.connect(_on_toggle_grid_snap)
	point_snap_btn.pressed.connect(_on_toggle_point_snap)
	grid_step_btn.item_selected.connect(_on_grid_step_selected)

	_setup_grid_steps()
	_update_buttons()
	_update_stats()

func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var count := AppState.get_total_object_count()
	var weight := AppState.get_total_weight()
	stats_lbl.text = "Items: %d  |  Weight: %.1f kg  |  FPS: %d" % [count, weight, fps]

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
	stats_lbl.text = "Items: %d  |  Weight: %.1f kg  |  FPS: %d" % [count, weight, Engine.get_frames_per_second()]

func set_status(msg: String) -> void:
	status_lbl.text = msg

