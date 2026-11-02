class_name StageViewport
extends SubViewportContainer

const StageGroup = preload("res://scripts/core/stage_group.gd")

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

# Placement Mode & Ghost Preview
var placement_preview_obj: StageObject = null
var ghost_yaw: float = 0.0
var last_mouse_pos: Vector2 = Vector2.ZERO
var _ghost_mat_valid: StandardMaterial3D = null
var _ghost_mat_invalid: StandardMaterial3D = null
var snap_indicator: MeshInstance3D = null

func _ready() -> void:
	AppState.stage_container = stage_container
	AppState.request_screenshot.connect(_on_request_screenshot)
	AppState.tool_changed.connect(func(tool_name: String):
		if tool_name != "Place":
			_cleanup_ghost_preview()
	)
	_setup_selection_box_ui()
	_setup_snap_indicator()
	_update_3d_viewport_scaling()
	if UIScale:
		UIScale.scale_changed.connect(func(_new_scale: float):
			_update_3d_viewport_scaling()
		)

func _setup_snap_indicator() -> void:
	snap_indicator = MeshInstance3D.new()
	snap_indicator.name = "SnapIndicator"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.06
	torus.outer_radius = 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.1, 1.0, 0.8, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	snap_indicator.mesh = torus
	snap_indicator.visible = false
	sub_viewport.add_child(snap_indicator)

func _update_snap_indicator(snap_res: SnapSystem.SnapResult) -> void:
	if snap_indicator == null:
		return
	if snap_res != null and snap_res.snapped_to_point:
		snap_indicator.global_position = snap_res.snap_world_pos
		snap_indicator.visible = true
	else:
		snap_indicator.visible = false

func _update_3d_viewport_scaling() -> void:
	if sub_viewport:
		var scale_factor := get_window().content_scale_factor if get_window() else 1.0
		sub_viewport.scaling_3d_scale = maxf(1.0, scale_factor)

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

	# If Alt/Option is pressed, allow camera orbit when clicking canvas (unless hitting gizmo)
	if mb.alt_pressed and not gizmo.is_dragging:
		var gizmo_check := _raycast_layer(mouse_pos, 4)
		if not (gizmo_check.has("collider") and is_instance_valid(gizmo_check["collider"])):
			return

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
			var target_selectable: Node3D = _find_selectable_unit(stage_obj)
			var is_mod := PlatformUtils.is_primary_modifier_pressed(mb) or mb.shift_pressed
			if is_mod:
				AppState.toggle_selection(target_selectable)
			else:
				AppState.set_selection([target_selectable])
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

	var newly_selected: Array[Node3D] = []
	for child in stage_container.get_children():
		if child is StageObject or child is StageGroup:
			var screen_pos := camera.unproject_position(child.global_position)
			if rect.has_point(screen_pos):
				newly_selected.append(child)

	if is_additive:
		for obj in newly_selected:
			AppState.add_to_selection(obj)
	else:
		AppState.set_selection(newly_selected)

func _find_selectable_unit(node: Node) -> Node3D:
	var stage_obj := _find_stage_object_ancestor(node)
	if stage_obj == null:
		return null
	var cur: Node = stage_obj
	while cur.get_parent() != null and cur.get_parent() != stage_container:
		if cur.get_parent() is StageGroup:
			cur = cur.get_parent()
		else:
			break
	return cur as Node3D

# --- Placement Mode Logic ---

func _handle_placement_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_update_placement_preview(mm.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_commit_placement(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			AppState.cancel_placement()
			_cleanup_ghost_preview(true)
			accept_event()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_R:
				if key.shift_pressed:
					ghost_yaw = fmod(ghost_yaw - PI * 0.5, TAU)
				else:
					ghost_yaw = fmod(ghost_yaw + PI * 0.5, TAU)
				_update_placement_preview(last_mouse_pos)
				accept_event()
			elif key.keycode == KEY_ESCAPE:
				AppState.cancel_placement()
				_cleanup_ghost_preview(true)
				accept_event()

func _update_placement_preview(mouse_pos: Vector2) -> void:
	last_mouse_pos = mouse_pos
	if AppState.pending_placement_asset_id == "":
		return

	if placement_preview_obj == null or placement_preview_obj.catalog_id != AppState.pending_placement_asset_id:
		_cleanup_ghost_preview(false)
		placement_preview_obj = CatalogManager.instantiate_asset(AppState.pending_placement_asset_id)
		if placement_preview_obj:
			placement_preview_obj.name = "PlacementPreview"
			# Disable collision so preview never blocks rays or gizmos
			if placement_preview_obj.collision_area:
				placement_preview_obj.collision_area.monitoring = false
				placement_preview_obj.collision_area.monitorable = false
				placement_preview_obj.collision_area.collision_layer = 0
				placement_preview_obj.collision_area.collision_mask = 0
			sub_viewport.add_child(placement_preview_obj)

	if not placement_preview_obj:
		return

	var ground_pos := _get_ground_or_surface_pos(mouse_pos)
	var rot_basis := Basis(Vector3.UP, ghost_yaw)
	var snap_res := SnapSystem.resolve_position(ground_pos, placement_preview_obj, rot_basis)
	var final_pos := snap_res.position
	if not snap_res.snapped_to_point:
		final_pos.y = maxf(ground_pos.y, final_pos.y)
	placement_preview_obj.global_transform = Transform3D(rot_basis, final_pos)

	var is_valid := _check_ghost_validity(placement_preview_obj, snap_res)
	_apply_ghost_material(placement_preview_obj, is_valid)
	_update_snap_indicator(snap_res)

func _commit_placement(mouse_pos: Vector2) -> void:
	if AppState.pending_placement_asset_id == "":
		return

	var new_obj := CatalogManager.instantiate_asset(AppState.pending_placement_asset_id)
	if not new_obj:
		return

	var ground_pos := _get_ground_or_surface_pos(mouse_pos)
	var rot_basis := Basis(Vector3.UP, ghost_yaw)
	var snap_res := SnapSystem.resolve_position(ground_pos, new_obj, rot_basis)
	var final_pos := snap_res.position
	if not snap_res.snapped_to_point:
		final_pos.y = maxf(ground_pos.y, final_pos.y)

	var final_transform := Transform3D(rot_basis, final_pos)

	var cmd := BaseCommand.PlaceCommand.new(stage_container, [new_obj], [final_transform])
	CommandManager.execute_command(cmd)

	if not Input.is_key_pressed(KEY_SHIFT):
		# If shift is NOT held, return to select mode
		_cleanup_ghost_preview(true)
		AppState.cancel_placement()
	else:
		# Shift held: update preview for next copy
		_update_placement_preview(mouse_pos)

func _cleanup_ghost_preview(reset_yaw: bool = false) -> void:
	if placement_preview_obj:
		placement_preview_obj.queue_free()
		placement_preview_obj = null
	_update_snap_indicator(null)
	if reset_yaw:
		ghost_yaw = 0.0

# --- Drag and Drop Support ---

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type", "") == "stage_asset":
		var asset_id: String = data.get("asset_id", "")
		if AppState.pending_placement_asset_id != asset_id:
			AppState.start_placement(asset_id)
		_update_placement_preview(at_position)
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("type", "") == "stage_asset":
		var asset_id: String = data.get("asset_id", "")
		AppState.pending_placement_asset_id = asset_id
		_commit_placement(at_position)
		_cleanup_ghost_preview(true)
		AppState.cancel_placement()

# --- Ghost Visuals & Collision Check ---

func _check_ghost_validity(obj: StageObject, snap_res: SnapSystem.SnapResult) -> bool:
	if snap_res != null and snap_res.snapped_to_point:
		return true

	var world_3d := sub_viewport.find_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return true

	var space_state := world_3d.direct_space_state
	var shape := BoxShape3D.new()
	var dims := obj.dimensions
	# Use 2mm epsilon (0.002m margin on each side = 0.004m shrink)
	# so touching face-to-face or flush sitting items never report false collision
	var sx := maxf(0.005, dims.x - 0.004)
	var sy := maxf(0.005, dims.y - 0.004)
	var sz := maxf(0.005, dims.z - 0.004)
	shape.size = Vector3(sx, sy, sz)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = obj.global_transform * Transform3D(Basis(), Vector3(0, obj.pivot_offset_y, 0))
	query.collision_mask = 1
	query.collide_with_areas = true
	# Crucial: collide_with_bodies = false so it ignores GroundEnvironment floor
	query.collide_with_bodies = false
	if obj.collision_area:
		query.exclude = [obj.collision_area.get_rid()]

	var hits := space_state.intersect_shape(query, 1)
	return hits.is_empty()

func _get_ghost_mat(is_valid: bool) -> StandardMaterial3D:
	if _ghost_mat_valid == null:
		_ghost_mat_valid = StandardMaterial3D.new()
		_ghost_mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_mat_valid.albedo_color = Color(0.2, 0.9, 0.4, 0.5)
		_ghost_mat_valid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_mat_valid.cull_mode = BaseMaterial3D.CULL_DISABLED

		_ghost_mat_invalid = StandardMaterial3D.new()
		_ghost_mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_mat_invalid.albedo_color = Color(0.95, 0.2, 0.2, 0.5)
		_ghost_mat_invalid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_mat_invalid.cull_mode = BaseMaterial3D.CULL_DISABLED

	return _ghost_mat_valid if is_valid else _ghost_mat_invalid

func _apply_ghost_material(root_node: Node, is_valid: bool) -> void:
	var mat := _get_ghost_mat(is_valid)
	_apply_material_recursive(root_node, mat)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is GeometryInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

# --- Raycasting Helpers ---

func _raycast_layer(screen_pos: Vector2, collision_layer: int) -> Dictionary:
	var world_3d := sub_viewport.find_world_3d()
	if world_3d == null:
		return {}
	var space_state := world_3d.direct_space_state
	if space_state == null:
		return {}

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_normal := camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_normal * 1000.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, collision_layer)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	if is_instance_valid(placement_preview_obj) and placement_preview_obj.collision_area:
		query.exclude = [placement_preview_obj.collision_area.get_rid()]

	return space_state.intersect_ray(query)

func _get_ground_or_surface_pos(screen_pos: Vector2) -> Vector3:
	var vp_rect := Rect2(Vector2.ZERO, size)
	if not vp_rect.has_point(screen_pos):
		return Vector3.ZERO

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_normal := camera.project_ray_normal(screen_pos)

	# 1. Physics raycast hit on layer 1 (placed objects/decks/risers)
	var ray_hit := _raycast_layer(screen_pos, 1)
	if ray_hit.has("position"):
		return ray_hit["position"]

	# 2. Intersect ground plane y = 0
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

	# Placement Mode Keybinds (R to rotate, Shift+R for -90, Esc to cancel)
	if AppState.current_tool == AppState.ToolMode.PLACE:
		if key.keycode == KEY_R:
			if key.shift_pressed:
				ghost_yaw = fmod(ghost_yaw - PI * 0.5, TAU)
			else:
				ghost_yaw = fmod(ghost_yaw + PI * 0.5, TAU)
			_update_placement_preview(last_mouse_pos)
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_ESCAPE:
			AppState.cancel_placement()
			_cleanup_ghost_preview()
			get_viewport().set_input_as_handled()
			return

func _duplicate_selection() -> void:
	if AppState.selected_objects.is_empty():
		return

	var duplicates: Array[Node3D] = []
	var transforms: Array[Transform3D] = []
	var offset := Vector3(0.5, 0, 0.5) # small offset

	for item in AppState.selected_objects:
		if not is_instance_valid(item):
			continue
		if item is StageGroup:
			var dup_group := _duplicate_group_recursive(item, offset)
			if dup_group:
				duplicates.append(dup_group)
				transforms.append(dup_group.global_transform)
		elif item is StageObject:
			var dup := CatalogManager.instantiate_asset(item.catalog_id)
			if dup:
				dup.asset_name = item.asset_name + " (Copy)"
				dup.custom_notes = item.custom_notes
				dup.current_variant = item.current_variant
				dup.apply_variant(item.current_variant)
				var new_t := item.global_transform
				new_t.origin += offset
				dup.global_transform = new_t
				duplicates.append(dup)
				transforms.append(new_t)

	if not duplicates.is_empty():
		var cmd := BaseCommand.PlaceCommand.new(stage_container, duplicates, transforms)
		CommandManager.execute_command(cmd)

func _duplicate_group_recursive(group: StageGroup, offset: Vector3) -> StageGroup:
	var new_grp := StageGroup.new()
	new_grp.group_name = group.group_name + " (Copy)"
	new_grp.global_transform = group.global_transform
	new_grp.global_position += offset

	for child in group.get_children():
		if child is StageObject:
			var dup := CatalogManager.instantiate_asset(child.catalog_id)
			if dup:
				dup.asset_name = child.asset_name + " (Copy)"
				dup.custom_notes = child.custom_notes
				dup.current_variant = child.current_variant
				dup.apply_variant(child.current_variant)
				new_grp.add_child(dup)
				dup.global_transform = child.global_transform
				dup.global_position += offset
		elif child is StageGroup:
			var nested := _duplicate_group_recursive(child, offset)
			new_grp.add_child(nested)

	return new_grp

func _delete_selection() -> void:
	if AppState.selected_objects.is_empty():
		return
	var cmd := BaseCommand.DeleteCommand.new(stage_container, AppState.selected_objects)
	CommandManager.execute_command(cmd)

func _group_selection() -> void:
	if AppState.selected_objects.size() < 2:
		return
	var cmd := BaseCommand.GroupCommand.new(stage_container, AppState.selected_objects)
	CommandManager.execute_command(cmd)
	AppState.status_message.emit("Grouped %d items." % AppState.selected_objects.size())

func _ungroup_selection() -> void:
	var groups: Array[StageGroup] = []
	for item in AppState.selected_objects:
		if item is StageGroup:
			groups.append(item)
	if groups.is_empty():
		return
	var cmd := BaseCommand.UngroupCommand.new(stage_container, groups)
	CommandManager.execute_command(cmd)
	AppState.status_message.emit("Ungrouped %d group(s)." % groups.size())

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

