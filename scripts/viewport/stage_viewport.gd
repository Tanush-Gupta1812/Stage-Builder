class_name StageViewport
extends SubViewportContainer

const StageGroup = preload("res://scripts/core/stage_group.gd")
const RiggingOverlay = preload("res://scripts/viewport/rigging_overlay.gd")
const GizmoController = preload("res://scripts/viewport/gizmo/gizmo_controller.gd")
const TransformGuard = preload("res://scripts/core/transform_guard.gd")

## Coordinates 3D raycasting, object placement, gizmo dragging, box selection,
## and viewport input routing for Stage-Builder.

@onready var sub_viewport: SubViewport = $SubViewport
@onready var camera: StageCamera = $SubViewport/StageCamera
@onready var stage_container: Node3D = $SubViewport/StageContainer
@onready var gizmo: GizmoController = $SubViewport/GizmoController
@onready var grid_plane: GridPlane = $SubViewport/GridPlane
@onready var ground_env: GroundEnvironment = $SubViewport/GroundEnvironment

# Selection Box UI
var is_box_selecting: bool = false
var box_select_start: Vector2 = Vector2.ZERO
var box_select_current: Vector2 = Vector2.ZERO
var selection_rect_node: Control = null

# Viewport Toolbar UI
var _viewport_toolbar: PanelContainer = null
var _btn_tool_move: Button = null
var _btn_tool_rotate: Button = null
var _btn_tool_scale: Button = null
var _btn_all_axes: Button = null
var _btn_coord_space: Button = null
var _btn_pivot_mode: Button = null

# Direct Object Dragging (Move Tool)
var _direct_drag_pending: bool = false
var _is_direct_dragging: bool = false
var _direct_drag_start_screen: Vector2 = Vector2.ZERO
var _direct_drag_start_ground: Vector3 = Vector3.ZERO
var _direct_drag_targets: Array[Node3D] = []
var _direct_drag_initial_transforms: Array[Transform3D] = []

# Placement Mode & Ghost Preview
var placement_preview_obj: StageObject = null
var ghost_basis: Basis = Basis.IDENTITY
var last_mouse_pos: Vector2 = Vector2.ZERO
var _ghost_mat_valid: StandardMaterial3D = null
var _ghost_mat_invalid: StandardMaterial3D = null
var snap_indicator: MeshInstance3D = null

## Computes the vertical distance from an object's origin to its lowest transformed point
static func get_lowest_point_y_offset(obj: StageObject, basis: Basis) -> float:
	if not obj:
		return 0.0
	var local_aabb := obj.get_local_aabb()
	var corners := [
		Vector3(local_aabb.position.x, local_aabb.position.y, local_aabb.position.z),
		Vector3(local_aabb.position.x + local_aabb.size.x, local_aabb.position.y, local_aabb.position.z),
		Vector3(local_aabb.position.x, local_aabb.position.y + local_aabb.size.y, local_aabb.position.z),
		Vector3(local_aabb.position.x + local_aabb.size.x, local_aabb.position.y + local_aabb.size.y, local_aabb.position.z),
		Vector3(local_aabb.position.x, local_aabb.position.y, local_aabb.position.z + local_aabb.size.z),
		Vector3(local_aabb.position.x + local_aabb.size.x, local_aabb.position.y, local_aabb.position.z + local_aabb.size.z),
		Vector3(local_aabb.position.x, local_aabb.position.y + local_aabb.size.y, local_aabb.position.z + local_aabb.size.z),
		Vector3(local_aabb.position.x + local_aabb.size.x, local_aabb.position.y + local_aabb.size.y, local_aabb.position.z + local_aabb.size.z)
	]
	var min_y := INF
	for c in corners:
		var tc: Vector3 = basis * c
		if tc.y < min_y:
			min_y = tc.y
	return min_y if min_y != INF else 0.0


func _ready() -> void:
	AppState.stage_container = stage_container
	AppState.request_screenshot.connect(_on_request_screenshot)
	AppState.tool_changed.connect(func(tool_name: String):
		if tool_name != "Place":
			_cleanup_ghost_preview()
	)
	_setup_selection_box_ui()
	_setup_viewport_toolbar()
	_setup_snap_indicator()
	_setup_rigging_overlay()
	_update_3d_viewport_scaling()
	if UIScale:
		UIScale.scale_changed.connect(func(_new_scale: float):
			_update_3d_viewport_scaling()
			_update_toolbar_scaling()
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

func _setup_rigging_overlay() -> void:
	var overlay := RiggingOverlay.new()
	overlay.name = "RiggingOverlay"
	sub_viewport.add_child(overlay)

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

func _setup_viewport_toolbar() -> void:
	if is_instance_valid(_viewport_toolbar):
		return

	_viewport_toolbar = PanelContainer.new()
	_viewport_toolbar.name = "ViewportToolbar"
	_viewport_toolbar.mouse_filter = Control.MOUSE_FILTER_PASS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.15, 0.88)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.24, 0.28, 0.36, 0.8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_viewport_toolbar.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.name = "ToolbarHBox"
	hbox.add_theme_constant_override("separation", 4)
	_viewport_toolbar.add_child(hbox)

	# 1. Move Tool (1)
	_btn_tool_move = Button.new()
	_btn_tool_move.name = "BtnToolMove"
	_btn_tool_move.text = "Move  1"
	_btn_tool_move.custom_minimum_size = Vector2(0, 32)
	_btn_tool_move.toggle_mode = true
	_btn_tool_move.tooltip_text = "Move Tool (1)\nClick and drag objects directly on ground or surface.\nHold Shift for vertical Y-axis elevation.\nHold Alt to disable snapping.\nDrag red/green/blue arrows to constrain to axis."
	_btn_tool_move.pressed.connect(func():
		AppState.current_tool = AppState.ToolMode.MOVE
		AppState.status_message.emit("Tool: Move")
	)
	hbox.add_child(_btn_tool_move)

	# 2. Rotate Tool (2)
	_btn_tool_rotate = Button.new()
	_btn_tool_rotate.name = "BtnToolRotate"
	_btn_tool_rotate.text = "Rotate  2"
	_btn_tool_rotate.custom_minimum_size = Vector2(0, 32)
	_btn_tool_rotate.toggle_mode = true
	_btn_tool_rotate.tooltip_text = "Rotate Tool (2)\nDrag ring to rotate around vertical yaw axis.\nToggle 'All Axes' (X) for pitch and roll.\nSnaps to rotation step."
	_btn_tool_rotate.pressed.connect(func():
		AppState.current_tool = AppState.ToolMode.ROTATE
		AppState.status_message.emit("Tool: Rotate")
	)
	hbox.add_child(_btn_tool_rotate)

	# 3. Scale Tool (3)
	_btn_tool_scale = Button.new()
	_btn_tool_scale.name = "BtnToolScale"
	_btn_tool_scale.text = "Scale  3"
	_btn_tool_scale.custom_minimum_size = Vector2(0, 32)
	_btn_tool_scale.toggle_mode = true
	_btn_tool_scale.tooltip_text = "Scale Tool (3)\nDrag axis handles or center cube to scale."
	_btn_tool_scale.pressed.connect(func():
		AppState.current_tool = AppState.ToolMode.SCALE
		AppState.status_message.emit("Tool: Scale")
	)
	hbox.add_child(_btn_tool_scale)

	var sep1 := VSeparator.new()
	hbox.add_child(sep1)

	# 4. World / Local Toggle
	_btn_coord_space = Button.new()
	_btn_coord_space.name = "BtnCoordSpace"
	_btn_coord_space.text = "World"
	_btn_coord_space.custom_minimum_size = Vector2(0, 32)
	_btn_coord_space.tooltip_text = "Toggle Coordinate Space (World / Local)"
	_btn_coord_space.pressed.connect(func():
		AppState.is_local_transform_space = not AppState.is_local_transform_space
	)
	hbox.add_child(_btn_coord_space)

	# 5. Base / Center Pivot Toggle
	_btn_pivot_mode = Button.new()
	_btn_pivot_mode.name = "BtnPivotMode"
	_btn_pivot_mode.text = "Pivot: Base"
	_btn_pivot_mode.custom_minimum_size = Vector2(0, 32)
	_btn_pivot_mode.tooltip_text = "Toggle Gizmo Pivot (Base Center / Geometric Center)"
	_btn_pivot_mode.pressed.connect(func():
		if gizmo:
			gizmo.pivot_mode = 1 if gizmo.pivot_mode == 0 else 0
			gizmo._update_gizmo_position()
			_update_toolbar_state()
	)
	hbox.add_child(_btn_pivot_mode)

	var sep2 := VSeparator.new()
	hbox.add_child(sep2)

	# 6. All Axes (X) - only in Rotate mode
	_btn_all_axes = Button.new()
	_btn_all_axes.name = "BtnAllAxes"
	_btn_all_axes.text = "All Axes  X"
	_btn_all_axes.custom_minimum_size = Vector2(0, 32)
	_btn_all_axes.toggle_mode = true
	_btn_all_axes.tooltip_text = "Toggle Pitch and Roll rotation rings (X)\nOnly visible in Rotate mode."
	_btn_all_axes.toggled.connect(func(toggled_on: bool):
		AppState.show_all_rotation_axes = toggled_on
		_update_toolbar_state()
	)
	hbox.add_child(_btn_all_axes)

	add_child(_viewport_toolbar)

	AppState.tool_changed.connect(func(_t): _update_toolbar_state())
	AppState.transform_space_changed.connect(func(_l): _update_toolbar_state())
	AppState.show_all_rotation_axes_changed.connect(func(_s): _update_toolbar_state())
	resized.connect(_on_viewport_resized)
	_update_toolbar_state()

func _style_toolbar_button(btn: Button, is_active: bool, is_toggle_on: bool = false) -> void:
	if not is_instance_valid(btn):
		return
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0

	if is_active:
		style.bg_color = Color(0.20, 0.45, 0.85)
		style.border_color = Color(0.40, 0.70, 1.00)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	elif is_toggle_on:
		style.bg_color = Color(0.18, 0.36, 0.60, 0.85)
		style.border_color = Color(0.35, 0.60, 0.90)
		btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		style.bg_color = Color(0.14, 0.16, 0.20, 0.65)
		style.border_color = Color(0.24, 0.28, 0.35, 0.6)
		btn.add_theme_color_override("font_color", Color(0.80, 0.83, 0.88))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)

	btn.add_theme_stylebox_override("normal", style)
	var style_hover := style.duplicate() as StyleBoxFlat
	if not is_active:
		style_hover.bg_color = Color(0.20, 0.24, 0.32, 0.8)
		style_hover.border_color = Color(0.35, 0.45, 0.60)
	btn.add_theme_stylebox_override("hover", style_hover)

func _on_viewport_resized() -> void:
	if not is_instance_valid(_viewport_toolbar):
		return
	var avail_w := size.x - 20.0
	var sf: float = UIScale.current_scale if UIScale else 1.0
	# Adapt labels to fit narrow viewports without truncating
	if avail_w < 560.0 * sf:
		_btn_tool_move.text = "1:Move"
		_btn_tool_rotate.text = "2:Rot"
		_btn_tool_scale.text = "3:Scale"
		_btn_all_axes.text = "Axes X"
		_btn_coord_space.text = "L" if AppState.is_local_transform_space else "W"
		_btn_pivot_mode.text = "Center" if (gizmo and gizmo.pivot_mode == 1) else "Base"
	else:
		_btn_tool_move.text = "Move  1"
		_btn_tool_rotate.text = "Rotate  2"
		_btn_tool_scale.text = "Scale  3"
		_btn_all_axes.text = "All Axes  X"
		_btn_coord_space.text = "Local" if AppState.is_local_transform_space else "World"
		_btn_pivot_mode.text = "Pivot: Center" if (gizmo and gizmo.pivot_mode == 1) else "Pivot: Base"

	_viewport_toolbar.position.x = maxf(8.0, (size.x - _viewport_toolbar.size.x) * 0.5)
	_viewport_toolbar.position.y = 8.0

func _update_toolbar_scaling() -> void:
	_on_viewport_resized()

func _update_toolbar_state() -> void:
	if not is_instance_valid(_viewport_toolbar):
		return
	var is_move := (AppState.current_tool == AppState.ToolMode.MOVE)
	var is_rot := (AppState.current_tool == AppState.ToolMode.ROTATE)
	var is_scale := (AppState.current_tool == AppState.ToolMode.SCALE)

	_btn_tool_move.button_pressed = is_move
	_btn_tool_rotate.button_pressed = is_rot
	_btn_tool_scale.button_pressed = is_scale

	_style_toolbar_button(_btn_tool_move, is_move)
	_style_toolbar_button(_btn_tool_rotate, is_rot)
	_style_toolbar_button(_btn_tool_scale, is_scale)

	# All Axes only in Rotate mode
	_btn_all_axes.visible = is_rot
	_btn_all_axes.button_pressed = AppState.show_all_rotation_axes
	_style_toolbar_button(_btn_all_axes, false, AppState.show_all_rotation_axes)

	var hbox := _viewport_toolbar.find_child("ToolbarHBox", true, false)
	if hbox and hbox.get_child_count() > 5:
		var sep2 = hbox.get_child(5)
		if sep2 is VSeparator:
			sep2.visible = is_rot

	_btn_coord_space.text = "Local" if AppState.is_local_transform_space else "World"
	_style_toolbar_button(_btn_coord_space, false, AppState.is_local_transform_space)

	var is_center := (gizmo and gizmo.pivot_mode == 1)
	_btn_pivot_mode.text = "Pivot: Center" if is_center else "Pivot: Base"
	_style_toolbar_button(_btn_pivot_mode, false, is_center)

	_on_viewport_resized()

func _draw_selection_box() -> void:
	if not is_box_selecting:
		return
	var rect := Rect2(box_select_start, box_select_current - box_select_start).abs()
	selection_rect_node.draw_rect(rect, Color(0.3, 0.6, 1.0, 0.18), true)
	selection_rect_node.draw_rect(rect, Color(0.4, 0.7, 1.0, 0.8), false, 1.5)


func rotate_selected_objects(axis: Vector3, angle_deg: float) -> void:
	if AppState.selected_objects.is_empty():
		return

	var safe_axis := TransformGuard.safe_normalized(axis)
	if safe_axis.is_zero_approx() or not is_finite(angle_deg):
		return

	var targets: Array[Node3D] = []
	var old_transforms: Array[Transform3D] = []
	var new_transforms: Array[Transform3D] = []

	var angle_rad := deg_to_rad(angle_deg)
	var rot_basis := Basis(safe_axis, angle_rad)

	# Calculate shared pivot center
	var center := Vector3.ZERO
	var valid_count := 0
	for obj in AppState.selected_objects:
		if is_instance_valid(obj):
			center += obj.global_position
			valid_count += 1
	if valid_count > 0:
		center /= float(valid_count)

	for obj in AppState.selected_objects:
		if is_instance_valid(obj):
			targets.append(obj)
			old_transforms.append(obj.global_transform)

			var rel_pos := obj.global_position - center
			var new_pos := center + (rot_basis * rel_pos)
			var new_obj_basis := rot_basis * obj.global_basis

			if AppState.auto_rest_on_rotate and obj is StageObject:
				var s_obj := obj as StageObject
				var min_offset: float = get_lowest_point_y_offset(s_obj, new_obj_basis)
				if new_pos.y + min_offset < 0.0:
					new_pos.y = -min_offset

			var cand_t := Transform3D(new_obj_basis, new_pos)
			if TransformGuard.is_finite_transform(cand_t):
				new_transforms.append(cand_t)
			else:
				new_transforms.append(obj.global_transform)

	if not targets.is_empty():
		var cmd := BaseCommand.TransformCommand.new(targets, old_transforms, new_transforms)
		CommandManager.execute_command(cmd)
		if gizmo:
			gizmo._update_gizmo_position()

func drop_selected_to_surface() -> void:
	if AppState.selected_objects.is_empty():
		return

	var targets: Array[Node3D] = []
	var old_transforms: Array[Transform3D] = []
	var new_transforms: Array[Transform3D] = []

	for obj in AppState.selected_objects:
		if is_instance_valid(obj) and obj is StageObject:
			var s_obj := obj as StageObject
			var min_offset: float = get_lowest_point_y_offset(s_obj, s_obj.global_basis)
			targets.append(s_obj)
			old_transforms.append(s_obj.global_transform)

			var new_t := s_obj.global_transform
			new_t.origin.y = -min_offset
			new_transforms.append(TransformGuard.sanitize(new_t, s_obj.global_transform, "drop_selected_to_surface"))

	if not targets.is_empty():
		var cmd := BaseCommand.TransformCommand.new(targets, old_transforms, new_transforms)
		CommandManager.execute_command(cmd)
		if gizmo:
			gizmo._update_gizmo_position()
		AppState.status_message.emit("Dropped %d object(s) to surface." % targets.size())


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

	# 3. Handle Direct Object Dragging (Move tool)
	if _is_direct_dragging:
		if event is InputEventMouseMotion:
			_update_direct_drag(event as InputEventMouseMotion)
			accept_event()
			return
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_end_direct_drag()
				accept_event()
				return
	elif _direct_drag_pending:
		if event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if (mm.position - _direct_drag_start_screen).length() >= 4.0:
				_is_direct_dragging = true
				_direct_drag_pending = false
				_update_direct_drag(mm)
				accept_event()
				return
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_direct_drag_pending = false

	# 4. Handle Mouse Click (Selection or Gizmo Grab or Direct Drag Init)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var focus := get_viewport().gui_get_focus_owner()
			if focus and (focus is LineEdit or focus is TextEdit):
				focus.release_focus()

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.alt_pressed and not (gizmo and gizmo.is_dragging):
				var sf: float = UIScale.current_scale if UIScale else 1.0
				var hit_gizmo := false
				if gizmo and gizmo.visible:
					hit_gizmo = (gizmo.pick(mb.position, camera, sf) != GizmoController.HandleId.NONE)
				if not hit_gizmo:
					# Allow Alt+LMB to pass through to StageCamera for Orbit / Pan
					return

			if mb.pressed:
				_handle_left_click_press(mb)
			else:
				_handle_left_click_release(mb)
			accept_event()
			return
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Context / Cancel
			if _is_direct_dragging or _direct_drag_pending:
				cancel_direct_drag()
				accept_event()
				return
			if gizmo and gizmo.is_dragging:
				gizmo.cancel_drag()
				accept_event()
				return
			if AppState.current_tool == AppState.ToolMode.PLACE:
				AppState.cancel_placement()
				accept_event()
				return

	# 5. Handle Box Select Drag Motion
	if event is InputEventMouseMotion and is_box_selecting:
		box_select_current = (event as InputEventMouseMotion).position
		selection_rect_node.queue_redraw()
		accept_event()
		return

	# 6. Handle Hover Feedback and Cursor (when idle)
	if event is InputEventMouseMotion and not is_box_selecting:
		_update_hover_feedback((event as InputEventMouseMotion).position)

func _update_hover_feedback(mouse_pos: Vector2) -> void:
	if gizmo and gizmo.visible:
		var sf: float = UIScale.current_scale if UIScale else 1.0
		var picked_handle: GizmoController.HandleId = gizmo.pick(mouse_pos, camera, sf)
		if picked_handle != GizmoController.HandleId.NONE:
			gizmo.set_hovered_handle(picked_handle)
			if picked_handle in [GizmoController.HandleId.ROT_X, GizmoController.HandleId.ROT_Y, GizmoController.HandleId.ROT_Z]:
				_set_cursor_shape_safe(Control.CURSOR_POINTING_HAND)
			else:
				_set_cursor_shape_safe(Control.CURSOR_MOVE)
			return

	if gizmo:
		gizmo.set_hovered_handle(GizmoController.HandleId.NONE)

	var obj_hit := _raycast_layer(mouse_pos, 1)
	if obj_hit.has("collider") and is_instance_valid(obj_hit["collider"]):
		if AppState.current_tool == AppState.ToolMode.MOVE:
			_set_cursor_shape_safe(Control.CURSOR_MOVE)
		else:
			_set_cursor_shape_safe(Control.CURSOR_POINTING_HAND)
	else:
		_set_cursor_shape_safe(Control.CURSOR_ARROW)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if is_inside_tree() and is_instance_valid(gizmo):
			gizmo.set_hovered_handle(GizmoController.HandleId.NONE)
		_set_cursor_shape_safe(Control.CURSOR_ARROW)

func _set_cursor_shape_safe(shape: Control.CursorShape) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	if mouse_default_cursor_shape != shape:
		mouse_default_cursor_shape = shape

func _update_direct_drag(event: InputEventMouseMotion) -> void:
	if _direct_drag_targets.is_empty():
		return

	if event.shift_pressed:
		# Vertical Y-axis elevation only
		var dy := - (event.position.y - _direct_drag_start_screen.y) * 0.02
		dy = clampf(dy, -50.0, 50.0)
		for i in range(_direct_drag_targets.size()):
			var target := _direct_drag_targets[i]
			if is_instance_valid(target):
				var init_t := _direct_drag_initial_transforms[i]
				var new_y := maxf(0.0, init_t.origin.y + dy)
				if not event.alt_pressed and AppState.snap_to_grid:
					new_y = maxf(0.0, roundf(new_y / AppState.grid_step) * AppState.grid_step)
				var cand_t := Transform3D(init_t.basis, Vector3(init_t.origin.x, new_y, init_t.origin.z))
				cand_t = TransformGuard.sanitize(cand_t, init_t, "DirectDrag.Elevation")
				target.global_transform = cand_t
		if gizmo:
			gizmo._update_gizmo_position()
		AppState.status_message.emit("Direct Elevation Y: %.2fm" % dy)
		return

	# Ground / surface plane dragging
	var excl := _get_selected_collision_rids()
	var cur_ground := _get_ground_or_surface_pos_excluding(event.position, excl)
	var delta_pos := TransformGuard.clamp_move_delta(cur_ground - _direct_drag_start_ground, 50.0)

	if not event.alt_pressed and AppState.snap_to_grid:
		delta_pos.x = roundf(delta_pos.x / AppState.grid_step) * AppState.grid_step
		delta_pos.z = roundf(delta_pos.z / AppState.grid_step) * AppState.grid_step

	for i in range(_direct_drag_targets.size()):
		var target := _direct_drag_targets[i]
		if is_instance_valid(target):
			var init_t := _direct_drag_initial_transforms[i]
			var new_x := init_t.origin.x + delta_pos.x
			var new_z := init_t.origin.z + delta_pos.z
			var new_y := init_t.origin.y

			# Ensure resting on surface under cursor
			if target is StageObject:
				var min_offset: float = get_lowest_point_y_offset(target as StageObject, init_t.basis)
				var surface_y := cur_ground.y - min_offset
				if init_t.origin.y <= 0.01 or cur_ground.y > 0.0:
					new_y = maxf(surface_y, cur_ground.y - min_offset)

			var cand_t := Transform3D(init_t.basis, Vector3(new_x, new_y, new_z))
			cand_t = TransformGuard.sanitize(cand_t, init_t, "DirectDrag.Ground")
			target.global_transform = cand_t

	if gizmo:
		gizmo._update_gizmo_position()

	if not _direct_drag_targets.is_empty() and is_instance_valid(_direct_drag_targets[0]):
		var p := _direct_drag_targets[0].global_position
		AppState.status_message.emit("Direct Move: (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])

func _end_direct_drag() -> void:
	_is_direct_dragging = false
	_direct_drag_pending = false

	var changed := false
	var final_transforms: Array[Transform3D] = []
	for i in range(_direct_drag_targets.size()):
		var target := _direct_drag_targets[i]
		if is_instance_valid(target):
			final_transforms.append(target.global_transform)
			if not target.global_transform.is_equal_approx(_direct_drag_initial_transforms[i]):
				changed = true

	if changed:
		var cmd := BaseCommand.TransformCommand.new(_direct_drag_targets, _direct_drag_initial_transforms, final_transforms)
		CommandManager.execute_command(cmd)
		AppState.status_message.emit("Moved %d object(s)" % _direct_drag_targets.size())

	if gizmo:
		gizmo._update_gizmo_position()

func cancel_direct_drag() -> void:
	if not _is_direct_dragging and not _direct_drag_pending:
		return
	_is_direct_dragging = false
	_direct_drag_pending = false

	for i in range(_direct_drag_targets.size()):
		var target := _direct_drag_targets[i]
		if is_instance_valid(target) and i < _direct_drag_initial_transforms.size():
			target.global_transform = _direct_drag_initial_transforms[i]

	if gizmo:
		gizmo._update_gizmo_position()
	AppState.status_message.emit("Direct drag cancelled")

func _handle_left_click_press(mb: InputEventMouseButton) -> void:
	var mouse_pos := mb.position
	var sf: float = UIScale.current_scale if UIScale else 1.0

	# If Alt/Option is pressed, allow camera orbit when clicking canvas (unless hitting gizmo)
	if mb.alt_pressed and not (gizmo and gizmo.is_dragging):
		if gizmo and gizmo.visible:
			var handle_check := gizmo.pick(mouse_pos, camera, sf)
			if handle_check == GizmoController.HandleId.NONE:
				return
		else:
			return

	# 1. Screen-space Gizmo handle pick has top priority! (Handles ALWAYS beat bodies)
	if gizmo and gizmo.visible:
		var picked_handle: GizmoController.HandleId = gizmo.pick(mouse_pos, camera, sf)
		if picked_handle != GizmoController.HandleId.NONE:
			gizmo.start_drag(picked_handle, mouse_pos, camera)
			accept_event()
			return

	# 2. Check Stage Object hit (layer 1)
	var obj_hit := _raycast_layer(mouse_pos, 1)
	if obj_hit.has("collider") and is_instance_valid(obj_hit["collider"]):
		var collider = obj_hit["collider"]
		var stage_obj := _find_stage_object_ancestor(collider)
		if stage_obj:
			var target_selectable: Node3D = _find_selectable_unit(stage_obj)
			var is_primary_mod := PlatformUtils.is_primary_modifier_pressed(mb)
			if is_primary_mod:
				AppState.toggle_selection(target_selectable)
			elif mb.shift_pressed:
				# Shift in Move tool is used for vertical elevation dragging, or additive selection
				if not AppState.is_selected(target_selectable):
					AppState.add_to_selection(target_selectable)
			else:
				if not AppState.is_selected(target_selectable):
					AppState.set_selection([target_selectable])

			# In Move tool, initiate direct drag pending
			if AppState.current_tool == AppState.ToolMode.MOVE and not AppState.selected_objects.is_empty():
				_direct_drag_pending = true
				_is_direct_dragging = false
				_direct_drag_start_screen = mouse_pos
				_direct_drag_targets.clear()
				_direct_drag_initial_transforms.clear()
				for obj in AppState.selected_objects:
					if is_instance_valid(obj):
						_direct_drag_targets.append(obj)
						_direct_drag_initial_transforms.append(obj.global_transform)
				var excl := _get_selected_collision_rids()
				_direct_drag_start_ground = _get_ground_or_surface_pos_excluding(mouse_pos, excl)
			return

	# 3. Clicked empty space -> start Box Selection
	if not mb.shift_pressed and not PlatformUtils.is_primary_modifier_pressed(mb):
		AppState.clear_selection()

	is_box_selecting = true
	box_select_start = mouse_pos
	box_select_current = mouse_pos
	selection_rect_node.queue_redraw()

func _handle_left_click_release(mb: InputEventMouseButton) -> void:
	if _is_direct_dragging:
		_end_direct_drag()
		return
	elif _direct_drag_pending:
		_direct_drag_pending = false

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
			var step_deg := AppState.rotation_step
			if key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed):
				step_deg = 5.0 # Fine rotation with Ctrl/Cmd
			var step_rad := deg_to_rad(step_deg)

			if key.keycode == KEY_R:
				var sign_val := -1.0 if key.shift_pressed else 1.0
				ghost_basis = Basis(Vector3.UP, sign_val * step_rad) * ghost_basis
				AppState.status_message.emit("Placement Yaw: %s°" % ("+5" if (step_deg == 5.0 and sign_val > 0) else ("-5" if step_deg == 5.0 else ("+90" if sign_val > 0 else "-90"))))
				_update_placement_preview(last_mouse_pos)
				accept_event()
			elif key.keycode == KEY_T:
				var sign_val := -1.0 if key.shift_pressed else 1.0
				ghost_basis = Basis(Vector3.RIGHT, sign_val * step_rad) * ghost_basis
				AppState.status_message.emit("Placement Pitch: %s°" % ("+5" if (step_deg == 5.0 and sign_val > 0) else ("-5" if step_deg == 5.0 else ("+90" if sign_val > 0 else "-90"))))
				_update_placement_preview(last_mouse_pos)
				accept_event()
			elif key.keycode == KEY_Y and not (key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed)):
				var sign_val := -1.0 if key.shift_pressed else 1.0
				ghost_basis = Basis(Vector3.BACK, sign_val * step_rad) * ghost_basis
				AppState.status_message.emit("Placement Roll: %s°" % ("+5" if (step_deg == 5.0 and sign_val > 0) else ("-5" if step_deg == 5.0 else ("+90" if sign_val > 0 else "-90"))))
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
	var rot_basis := ghost_basis
	var snap_res := SnapSystem.resolve_position(ground_pos, placement_preview_obj, rot_basis)
	var final_pos := snap_res.position
	if not snap_res.snapped_to_point:
		var min_offset: float = get_lowest_point_y_offset(placement_preview_obj, rot_basis)
		# Surface hit Y is ground_pos.y; ensure lowest point touches ground_pos.y
		final_pos.y = maxf(ground_pos.y - min_offset, final_pos.y)
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
	var rot_basis := ghost_basis
	var snap_res := SnapSystem.resolve_position(ground_pos, new_obj, rot_basis)
	var final_pos := snap_res.position
	if not snap_res.snapped_to_point:
		var min_offset: float = get_lowest_point_y_offset(new_obj, rot_basis)
		final_pos.y = maxf(ground_pos.y - min_offset, final_pos.y)

	var final_transform := Transform3D(rot_basis, final_pos)
	final_transform = TransformGuard.sanitize(final_transform, Transform3D.IDENTITY, "Placement.commit")


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
		ghost_basis = Basis.IDENTITY


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
	return _get_ground_or_surface_pos_excluding(screen_pos, [])

func _get_selected_collision_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for obj in AppState.selected_objects:
		if is_instance_valid(obj):
			if obj is StageObject and obj.collision_area:
				rids.append(obj.collision_area.get_rid())
			elif obj is StageGroup:
				_collect_group_rids(obj, rids)
	return rids

func _collect_group_rids(group: StageGroup, rids: Array[RID]) -> void:
	for child in group.get_children():
		if child is StageObject and child.collision_area:
			rids.append(child.collision_area.get_rid())
		elif child is StageGroup:
			_collect_group_rids(child, rids)

func _get_ground_or_surface_pos_excluding(screen_pos: Vector2, exclude_rids: Array[RID] = []) -> Vector3:
	var vp_rect := Rect2(Vector2.ZERO, size)
	if not vp_rect.has_point(screen_pos):
		return Vector3.ZERO

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_normal := camera.project_ray_normal(screen_pos)

	if not (is_finite(ray_origin.x) and is_finite(ray_origin.y) and is_finite(ray_origin.z)):
		return Vector3.ZERO
	if not (is_finite(ray_normal.x) and is_finite(ray_normal.y) and is_finite(ray_normal.z)):
		return Vector3.ZERO

	# 1. Physics raycast hit on layer 1 (placed objects/decks/risers) excluding specified RIDs
	var world_3d := sub_viewport.find_world_3d()
	if world_3d and world_3d.direct_space_state:
		var space_state := world_3d.direct_space_state
		var ray_end := ray_origin + ray_normal * 1000.0
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = exclude_rids
		var ray_hit := space_state.intersect_ray(query)
		if ray_hit.has("position"):
			var pos_hit: Vector3 = ray_hit["position"]
			if is_finite(pos_hit.x) and is_finite(pos_hit.y) and is_finite(pos_hit.z):
				if pos_hit.length_squared() < TransformGuard.MAX_COORD_SQ:
					return pos_hit

	# 2. Intersect ground plane y = 0 (guarding near-parallel grazing angles)
	var dot_up := ray_normal.dot(Vector3.UP)
	if absf(dot_up) < 1e-4:
		return Vector3.ZERO # Skip frame on grazing / parallel angle

	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_normal)
	if hit != null:
		var hit_pos := hit as Vector3
		if is_finite(hit_pos.x) and is_finite(hit_pos.y) and is_finite(hit_pos.z):
			if hit_pos.length_squared() < TransformGuard.MAX_COORD_SQ:
				return hit_pos

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
	if not key.pressed or key.echo:
		return

	# Never fire tool shortcuts while typing in a text field
	var focus := get_viewport().gui_get_focus_owner()
	if focus and (focus is LineEdit or focus is TextEdit):
		return

	# Escape key: cancel direct drag, gizmo drag, or placement
	if key.keycode == KEY_ESCAPE:
		if _is_direct_dragging or _direct_drag_pending:
			cancel_direct_drag()
			get_viewport().set_input_as_handled()
			return
		if gizmo and gizmo.is_dragging:
			gizmo.cancel_drag()
			get_viewport().set_input_as_handled()
			return
		if AppState.current_tool == AppState.ToolMode.PLACE:
			AppState.cancel_placement()
			_cleanup_ghost_preview()
			get_viewport().set_input_as_handled()
			return

	# Plain digit tool shortcuts 1, 2, 3 (no Ctrl, no Cmd, no Alt, no Shift)
	if not (key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed) or key.alt_pressed or key.shift_pressed):
		if key.keycode == KEY_1 or key.physical_keycode == KEY_1:
			AppState.current_tool = AppState.ToolMode.MOVE
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_2 or key.physical_keycode == KEY_2:
			AppState.current_tool = AppState.ToolMode.ROTATE
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_3 or key.physical_keycode == KEY_3:
			AppState.current_tool = AppState.ToolMode.SCALE
			get_viewport().set_input_as_handled()
			return

	# Key X in Rotate mode: toggle all axes
	if (key.keycode == KEY_X or key.physical_keycode == KEY_X) and not (key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed) or key.alt_pressed):
		if AppState.current_tool == AppState.ToolMode.ROTATE:
			AppState.show_all_rotation_axes = not AppState.show_all_rotation_axes
			AppState.status_message.emit("Rotate axes: " + ("Pitch, Yaw, Roll" if AppState.show_all_rotation_axes else "Yaw Only"))
			get_viewport().set_input_as_handled()
			return

	# Placement Mode Keybinds (R to rotate, Shift+R for -90, etc.)
	if AppState.current_tool == AppState.ToolMode.PLACE:
		var step_deg := AppState.rotation_step
		if key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed):
			step_deg = 5.0
		var step_rad := deg_to_rad(step_deg)

		if key.keycode == KEY_R:
			var sign_val := -1.0 if key.shift_pressed else 1.0
			ghost_basis = Basis(Vector3.UP, sign_val * step_rad) * ghost_basis
			_update_placement_preview(last_mouse_pos)
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_T:
			var sign_val := -1.0 if key.shift_pressed else 1.0
			ghost_basis = Basis(Vector3.RIGHT, sign_val * step_rad) * ghost_basis
			_update_placement_preview(last_mouse_pos)
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_Y and not (key.ctrl_pressed or (OS.get_name() == "macOS" and key.meta_pressed)):
			var sign_val := -1.0 if key.shift_pressed else 1.0
			ghost_basis = Basis(Vector3.BACK, sign_val * step_rad) * ghost_basis
			_update_placement_preview(last_mouse_pos)
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
				new_t = TransformGuard.sanitize(new_t, item.global_transform, "Duplicate.object")
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
	new_grp.global_transform = TransformGuard.sanitize(new_grp.global_transform, group.global_transform, "Duplicate.group")

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

