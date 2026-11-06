extends Node

const StageGroup = preload("res://scripts/core/stage_group.gd")

## Central application state orchestrator for Stage-Builder.
## Manages selection, tool modes, snapping preferences, project metadata, and scene signals.

signal selection_changed(selected_objects: Array[Node3D])
signal tool_changed(new_tool: String)
signal project_modified
signal project_saved(path: String)
signal project_loaded(path: String)
signal grid_toggled(is_visible: bool)
signal snap_toggled(is_enabled: bool)
signal point_snap_toggled(is_enabled: bool)
signal ground_changed(ground_type: String)
signal status_message(text: String)
signal request_screenshot
signal transform_space_changed(is_local: bool)
signal show_all_rotation_axes_changed(show_all: bool)

enum ToolMode {
	SELECT,
	PLACE,
	MOVE,
	ROTATE,
	SCALE
}

var current_tool: ToolMode = ToolMode.MOVE:
	set(val):
		if current_tool != val:
			current_tool = val
			tool_changed.emit(get_tool_name(current_tool))

var is_local_transform_space: bool = false:
	set(val):
		if is_local_transform_space != val:
			is_local_transform_space = val
			transform_space_changed.emit(val)

var show_all_rotation_axes: bool = false:
	set(val):
		if show_all_rotation_axes != val:
			show_all_rotation_axes = val
			show_all_rotation_axes_changed.emit(val)

var pending_placement_asset_id: String = ""

var selected_objects: Array[Node3D] = []
var stage_container: Node3D = null

# Grid and Snap Settings
var show_grid: bool = true:
	set(val):
		if show_grid != val:
			show_grid = val
			grid_toggled.emit(show_grid)

var snap_to_grid: bool = true:
	set(val):
		if snap_to_grid != val:
			snap_to_grid = val
			snap_toggled.emit(snap_to_grid)

var grid_step: float = 0.5 # 0.25m, 0.5m, 1.0m
var snap_to_points: bool = true:
	set(val):
		if snap_to_points != val:
			snap_to_points = val
			point_snap_toggled.emit(snap_to_points)

var snap_threshold: float = 0.25 # in meters (standard snap radius)

# Rotation Settings
signal rotation_step_changed(new_step: float)
signal auto_rest_toggled(enabled: bool)

var rotation_step: float = 90.0: # 5.0, 15.0, 45.0, 90.0
	set(val):
		if not is_equal_approx(rotation_step, val):
			rotation_step = val
			rotation_step_changed.emit(rotation_step)

var auto_rest_on_rotate: bool = true: # default ON: rests lowest point on surface after rotate
	set(val):
		if auto_rest_on_rotate != val:
			auto_rest_on_rotate = val
			auto_rest_toggled.emit(auto_rest_on_rotate)


# Ground environment
var current_ground: String = "concrete":
	set(val):
		if current_ground != val:
			current_ground = val
			ground_changed.emit(current_ground)

# Project info
var current_project_path: String = ""
var is_modified: bool = false
var project_name: String = "Untitled Stage"

func _ready() -> void:
	project_modified.connect(func(): is_modified = true)

func get_tool_name(mode: ToolMode) -> String:
	match mode:
		ToolMode.SELECT: return "Select"
		ToolMode.PLACE: return "Place"
		ToolMode.MOVE: return "Move"
		ToolMode.ROTATE: return "Rotate"
		ToolMode.SCALE: return "Scale"
	return "Unknown"

# --- Selection Management ---

func set_selection(objects: Array) -> void:
	# Deselect current
	for obj in selected_objects:
		if is_instance_valid(obj):
			if "is_selected" in obj:
				obj.is_selected = false

	selected_objects.clear()
	for obj in objects:
		if is_instance_valid(obj) and obj is Node3D:
			selected_objects.append(obj)
			if "is_selected" in obj:
				obj.is_selected = true

	selection_changed.emit(selected_objects)

func add_to_selection(obj: Node3D) -> void:
	if not is_instance_valid(obj) or selected_objects.has(obj):
		return
	selected_objects.append(obj)
	if "is_selected" in obj:
		obj.is_selected = true
	selection_changed.emit(selected_objects)

func remove_from_selection(obj: Node3D) -> void:
	if not is_instance_valid(obj):
		return
	var idx := selected_objects.find(obj)
	if idx != -1:
		selected_objects.remove_at(idx)
		if "is_selected" in obj:
			obj.is_selected = false
		selection_changed.emit(selected_objects)

func toggle_selection(obj: Node3D) -> void:
	if selected_objects.has(obj):
		remove_from_selection(obj)
	else:
		add_to_selection(obj)

func clear_selection() -> void:
	set_selection([])

func is_selected(obj: Node3D) -> bool:
	return selected_objects.has(obj)

func select_all() -> void:
	if not stage_container:
		return
	var all_items: Array[Node3D] = []
	for child in stage_container.get_children():
		if child is StageObject or child is StageGroup:
			all_items.append(child)
	set_selection(all_items)

# --- Stage Statistics ---

func get_stage_objects() -> Array[StageObject]:
	var list: Array[StageObject] = []
	if stage_container:
		_gather_stage_objects_recursive(stage_container, list)
	return list

func _gather_stage_objects_recursive(parent: Node, out_list: Array[StageObject]) -> void:
	for child in parent.get_children():
		if child is StageObject:
			out_list.append(child)
		elif child is StageGroup:
			out_list.append_array(child.get_all_stage_objects())
		else:
			_gather_stage_objects_recursive(child, out_list)

func get_total_weight() -> float:
	var total := 0.0
	for obj in get_stage_objects():
		total += obj.weight_kg
	return total

func get_total_object_count() -> int:
	return get_stage_objects().size()

# --- Tool Activation ---

func start_placement(catalog_id: String) -> void:
	pending_placement_asset_id = catalog_id
	current_tool = ToolMode.PLACE
	status_message.emit("Placement Mode: Click on stage or equipment to place. Esc to cancel.")

func cancel_placement() -> void:
	pending_placement_asset_id = ""
	current_tool = ToolMode.MOVE
	status_message.emit("Ready")
