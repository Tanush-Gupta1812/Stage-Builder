class_name StageViewport
extends SubViewportContainer

## Coordinates 3D raycasting, object placement, gizmo dragging, box selection,
## and viewport input routing for Stage-Builder.

@onready var sub_viewport: SubViewport = $SubViewport
@onready var camera: StageCamera = $SubViewport/StageCamera
@onready var stage_container: Node3D = $SubViewport/StageContainer
@onready var gizmo: TransformGizmo = $SubViewport/TransformGizmo
@onready var grid_plane: GridPlane = $SubViewport/GridPlane
@onready var ground_env: GroundEnvironment = $SubViewport/GroundEnvironment

# Selection Box UI
var is_box_selecting: bool = false
var box_select_start: Vector2 = Vector2.ZERO
var box_select_current: Vector2 = Vector2.ZERO
var selection_rect_node: Control = null

# Placement Preview
var placement_preview_obj: StageObject = null

func _ready() -> void:
	AppState.stage_container = stage_container
	AppState.request_screenshot.connect(_on_request_screenshot)
	_setup_selection_box_ui()

func _setup_selection_box_ui() -> void:
	selection_rect_node = Control.new()
	selection_rect_node.name = "SelectionBox"
	selection_rect_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_rect_node.draw.connect(_draw_selection_box)
	add_child(selection_rect_node)

func _draw_selection_box() -> void:
	if not is_box_selecting:
		return
	var rect := Rect2(box_select_start, box_select_current - box_select_start).abs()
	selection_rect_node.draw_rect(rect, Color(0.3, 0.6, 1.0, 0.18), true)
	selection_rect_node.draw_rect(rect, Color(0.4, 0.7, 1.0, 0.8), false, 1.5)

func _gui_input(event: InputEvent) -> void:
	# 1. Handle Placement Mode
	if AppState.current_tool == AppState.ToolMode.PLACE:
		_handle_placement_input(event)
		return

	# 2. Handle Gizmo Dragging
	if gizmo.is_dragging:
		if event is InputEventMouseMotion:
			gizmo.update_drag(camera, (event as InputEventMouseMotion).position)
			accept_event()
			return
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				gizmo.end_drag()
				accept_event()
				return

	# 3. Handle Mouse Click (Selection or Gizmo Grab)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_handle_left_click_press(mb)
			else:
				_handle_left_click_release(mb)
			accept_event()
			return
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Context / Cancel
			if AppState.current_tool == AppState.ToolMode.PLACE:
				AppState.cancel_placement()
				accept_event()

	# 4. Handle Box Select Drag Motion
	if event is InputEventMouseMotion and is_box_selecting:
		box_select_current = (event as InputEventMouseMotion).position
		selection_rect_node.queue_redraw()
		accept_event()
		return

func _handle_left_click_press(mb: InputEventMouseButton) -> void:
	var mouse_pos := mb.position

	# Check Gizmo handle hit first
	if gizmo.visible:
		var gizmo_hit := _raycast_layer(mouse_pos, 4) # layer 4 is gizmo
		if gizmo_hit.has("collider") and is_instance_valid(gizmo_hit["collider"]):
			var handle_node: Area3D = gizmo_hit["collider"]
			if handle_node.has_meta("axis_mode"):
				var mode: int = handle_node.get_meta("axis_mode")
				gizmo.start_drag(mode, mouse_pos)
				return

	# Check Stage Object hit (layer 1)
	var obj_hit := _raycast_layer(mouse_pos, 1)
	if obj_hit.has("collider") and is_instance_valid(obj_hit["collider"]):
		var collider = obj_hit["collider"]
		var stage_obj := _find_stage_object_ancestor(collider)
		if stage_obj:
			var is_mod := PlatformUtils.is_primary_modifier_pressed(mb) or mb.shift_pressed
			if is_mod:
				AppState.toggle_selection(stage_obj)
			else:
				AppState.set_selection([stage_obj])
			return

	# Clicked empty space -> start Box Selection
	if not mb.shift_pressed and not PlatformUtils.is_primary_modifier_pressed(mb):
		AppState.clear_selection()

	is_box_selecting = true
	box_select_start = mouse_pos
	box_select_current = mouse_pos
	selection_rect_node.queue_redraw()

func _handle_left_click_release(mb: InputEventMouseButton) -> void:
	if is_box_selecting:
		is_box_selecting = false
		selection_rect_node.queue_redraw()
		_finish_box_select(mb.shift_pressed or PlatformUtils.is_primary_modifier_pressed(mb))

func _finish_box_select(is_additive: bool) -> void:
	var rect := Rect2(box_select_start, box_select_current - box_select_start).abs()
	if rect.size.length() < 6.0:
		return # Trivial click

	var newly_selected: Array[StageObject] = []
	for child in stage_container.get_children():
		if child is StageObject:
			var screen_pos := camera.unproject_position(child.global_position)
			if rect.has_point(screen_pos):
				newly_selected.append(child)

	if is_additive:
		for obj in newly_selected:
			AppState.add_to_selection(obj)
	else:
		AppState.set_selection(newly_selected)

# --- Placement Mode Logic ---

func _handle_placement_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_update_placement_preview(mm.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_commit_placement(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			AppState.cancel_placement()
			if placement_preview_obj:
				placement_preview_obj.queue_free()
				placement_preview_obj = null
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE and key.pressed:
			AppState.cancel_placement()
			if placement_preview_obj:
				placement_preview_obj.queue_free()
				placement_preview_obj = null

func _update_placement_preview(mouse_pos: Vector2) -> void:
	if AppState.pending_placement_asset_id == "":
		return

	if placement_preview_obj == null or placement_preview_obj.catalog_id != AppState.pending_placement_asset_id:
		if placement_preview_obj:
			placement_preview_obj.queue_free()
		placement_preview_obj = CatalogManager.instantiate_asset(AppState.pending_placement_asset_id)
		if placement_preview_obj:
			placement_preview_obj.name = "PlacementPreview"
			sub_viewport.add_child(placement_preview_obj)

	if not placement_preview_obj:
		return

	var ground_pos := _get_ground_or_surface_pos(mouse_pos)
	var snap_res := SnapSystem.resolve_position(ground_pos, placement_preview_obj)
	placement_preview_obj.global_position = snap_res.position

func _commit_placement(mouse_pos: Vector2) -> void:
	if AppState.pending_placement_asset_id == "":
		return

	var new_obj := CatalogManager.instantiate_asset(AppState.pending_placement_asset_id)
	if not new_obj:
		return

	var ground_pos := _get_ground_or_surface_pos(mouse_pos)
	var snap_res := SnapSystem.resolve_position(ground_pos, new_obj)
	new_obj.global_position = snap_res.position

	var cmd := BaseCommand.PlaceCommand.new(stage_container, [new_obj], [new_obj.global_transform])
	CommandManager.execute_command(cmd)

	if not Input.is_key_pressed(KEY_SHIFT):
		# If shift is NOT held, return to select mode
		if placement_preview_obj:
			placement_preview_obj.queue_free()
			placement_preview_obj = null
		AppState.cancel_placement()

# --- Raycasting Helpers ---

func _raycast_layer(screen_pos: Vector2, collision_layer: int) -> Dictionary:
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_normal := camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_normal * 1000.0

	var space_state := sub_viewport.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, collision_layer)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)

func _get_ground_or_surface_pos(screen_pos: Vector2) -> Vector3:
	var ray_hit := _raycast_layer(screen_pos, 1)
	if ray_hit.has("position"):
		return ray_hit["position"]

	# Intersect ground plane y = 0
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_normal := camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_normal)
	if hit != null:
		return hit as Vector3
	return Vector3.ZERO

func _find_stage_object_ancestor(node: Node) -> StageObject:
	var cur: Node = node
	while cur != null and cur != sub_viewport:
		if cur is StageObject:
			return cur
		cur = cur.get_parent()
	return null

# --- Keyboard Actions & Shortcuts ---

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed:
		return

	var is_ctrl := PlatformUtils.is_primary_modifier_pressed(key)

	# Undo (Ctrl/Cmd + Z)
	if is_ctrl and key.keycode == KEY_Z and not key.shift_pressed:
		CommandManager.undo()
		get_viewport().set_input_as_handled()
		return

	# Redo (Ctrl/Cmd + Y or Ctrl/Cmd + Shift + Z)
	if (is_ctrl and key.keycode == KEY_Y) or (is_ctrl and key.shift_pressed and key.keycode == KEY_Z):
		CommandManager.redo()
		get_viewport().set_input_as_handled()
		return

	# Duplicate (Ctrl/Cmd + D)
	if is_ctrl and key.keycode == KEY_D:
		_duplicate_selection()
		get_viewport().set_input_as_handled()
		return

	# Delete (Delete or Backspace)
	if key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
		_delete_selection()
		get_viewport().set_input_as_handled()
		return

	# Group (Ctrl/Cmd + G)
	if is_ctrl and key.keycode == KEY_G and not key.shift_pressed:
		_group_selection()
		get_viewport().set_input_as_handled()
		return

	# Ungroup (Ctrl/Cmd + Shift + G)
	if is_ctrl and key.keycode == KEY_G and key.shift_pressed:
		_ungroup_selection()
		get_viewport().set_input_as_handled()
		return

	# Select All (Ctrl/Cmd + A)
	if is_ctrl and key.keycode == KEY_A:
		AppState.select_all()
		get_viewport().set_input_as_handled()
		return

func _duplicate_selection() -> void:
	if AppState.selected_objects.is_empty():
		return

	var duplicates: Array[StageObject] = []
	var transforms: Array[Transform3D] = []
	var offset := Vector3(1.0, 0, 1.0) # slight offset

	for obj in AppState.selected_objects:
		if is_instance_valid(obj):
			var dup := CatalogManager.instantiate_asset(obj.catalog_id)
			if dup:
				dup.asset_name = obj.asset_name + " (Copy)"
				dup.custom_notes = obj.custom_notes
				var new_t := obj.global_transform
				new_t.origin += offset
				dup.global_transform = new_t
				duplicates.append(dup)
				transforms.append(new_t)

	if not duplicates.is_empty():
		var cmd := BaseCommand.PlaceCommand.new(stage_container, duplicates, transforms)
		CommandManager.execute_command(cmd)

func _delete_selection() -> void:
	if AppState.selected_objects.is_empty():
		return
	var cmd := BaseCommand.DeleteCommand.new(stage_container, AppState.selected_objects)
	CommandManager.execute_command(cmd)

func _group_selection() -> void:
	if AppState.selected_objects.size() < 2:
		return
	var gid := "group_" + str(Time.get_ticks_usec())
	var cmd := BaseCommand.GroupCommand.new(AppState.selected_objects, gid)
	CommandManager.execute_command(cmd)
	AppState.status_message.emit("Grouped %d objects." % AppState.selected_objects.size())

func _ungroup_selection() -> void:
	if AppState.selected_objects.is_empty():
		return
	var cmd := BaseCommand.GroupCommand.new(AppState.selected_objects, "")
	CommandManager.execute_command(cmd)
	AppState.status_message.emit("Ungrouped selection.")

func _on_request_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := sub_viewport.get_texture().get_image()
	var filename := "stage_screenshot_" + Time.get_datetime_string_from_system().replace(":", "-") + ".png"
	var export_dir := "user://screenshots"
	DirAccess.make_dir_absolute(export_dir)
	var full_path := export_dir + "/" + filename
	var err := img.save_png(full_path)
	if err == OK:
		var global_path := ProjectSettings.globalize_path(full_path)
		AppState.status_message.emit("Screenshot saved to: " + global_path)
		print("Screenshot exported to: " + global_path)
	else:
		AppState.status_message.emit("Failed to export screenshot.")

