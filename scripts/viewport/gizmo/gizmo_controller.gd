class_name GizmoController
extends Node3D

const GizmoMath = preload("res://scripts/viewport/gizmo/gizmo_math.gd")
const GizmoPicker = preload("res://scripts/viewport/gizmo/gizmo_picker.gd")
const GizmoVisual = preload("res://scripts/viewport/gizmo/gizmo_visual.gd")
const TransformGuard = preload("res://scripts/core/transform_guard.gd")
const BaseCommand = preload("res://scripts/core/commands.gd")

## High-level controller for 3D Viewport Transform Gizmo.
## Holds tool state (MOVE, ROTATE, SCALE), coordinate space (WORLD / LOCAL),
## rotation axes visibility, target objects, and hover handle state.
## All logical axes are strictly normalized unit vectors. Visual scaling is
## completely decoupled and applied only to the visual child node.

enum ToolMode { MOVE, ROTATE, SCALE }
enum AxisSpace { WORLD, LOCAL }
enum HandleId {
	NONE,
	MOVE_X, MOVE_Y, MOVE_Z, MOVE_XZ,
	ROT_Y, ROT_X, ROT_Z,
	SCALE_X, SCALE_Y, SCALE_Z, SCALE_UNIFORM
}

# Compatibility alias
const AxisMode = HandleId

signal tool_changed(tool: ToolMode)
signal hover_changed(handle: HandleId)
signal space_changed(space: AxisSpace)

var active_tool: ToolMode = ToolMode.MOVE:
	set(val):
		if active_tool != val:
			active_tool = val
			tool_changed.emit(active_tool)
			if visual:
				visual.update_tool_handles()

var axis_space: AxisSpace = AxisSpace.WORLD:
	set(val):
		if axis_space != val:
			axis_space = val
			space_changed.emit(axis_space)
			_update_orientation()

var show_all_rotation_axes: bool = false:
	set(val):
		if show_all_rotation_axes != val:
			show_all_rotation_axes = val
			if visual:
				visual.update_tool_handles()

var hovered_handle: HandleId = HandleId.NONE:
	set(val):
		if hovered_handle != val:
			hovered_handle = val
			hover_changed.emit(hovered_handle)
			if visual:
				visual.set_hovered_handle(hovered_handle)

var selected_objects: Array[Node3D] = []
var visual: GizmoVisual = null
var is_dragging: bool = false
var pivot_mode: int = 0 # 0: Base Center, 1: Geo Center

# Drag tracking state
var active_drag_handle: HandleId = HandleId.NONE
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_targets: Array[Node3D] = []
var drag_initial_transforms: Array[Transform3D] = []
var drag_pivot: Vector3 = Vector3.ZERO
var drag_axis: Vector3 = Vector3.UP
var drag_plane_normal: Vector3 = Vector3.UP
var drag_start_ring_vec: Vector3 = Vector3.ZERO
var drag_start_axis_t: float = 0.0
var drag_start_plane_pos: Vector3 = Vector3.ZERO
var drag_grab_point: Vector3 = Vector3.ZERO
var drag_screen_tangent: Vector2 = Vector2.ZERO
var drag_pixels_per_radian: float = 100.0
var drag_is_edge_on: bool = false

# Backward compatibility accessors for existing tests
var _move_group: Node3D:
	get: return visual._move_group if visual else null
var _rotate_group: Node3D:
	get: return visual._rotate_group if visual else null
var _scale_group: Node3D:
	get: return visual._scale_group if visual else null
var _handle_areas: Dictionary:
	get:
		var d := {}
		if visual:
			var ax_x = visual._handle_areas.get(HandleId.ROT_X)
			var ax_y = visual._handle_areas.get(HandleId.ROT_Y)
			var ax_z = visual._handle_areas.get(HandleId.ROT_Z)
			if ax_x:
				d[HandleId.ROT_X] = ax_x
				d[int(HandleId.ROT_X)] = ax_x
			if ax_y:
				d[HandleId.ROT_Y] = ax_y
				d[int(HandleId.ROT_Y)] = ax_y
			if ax_z:
				d[HandleId.ROT_Z] = ax_z
				d[int(HandleId.ROT_Z)] = ax_z
		return d

func _init() -> void:
	self.scale = Vector3.ONE
	visual = GizmoVisual.new()
	visual.name = "GizmoVisual"
	visual.controller = self
	add_child(visual)

func _ready() -> void:
	visible = false

	# Bind to AppState
	AppState.selection_changed.connect(_on_selection_changed)
	AppState.tool_changed.connect(_on_app_tool_changed)
	AppState.transform_space_changed.connect(_on_app_transform_space_changed)
	AppState.show_all_rotation_axes_changed.connect(_on_app_show_all_rotation_axes_changed)

	_sync_from_app_state()

func _process(_delta: float) -> void:
	if not visible or selected_objects.is_empty():
		return

	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if not cam and is_inside_tree():
		cam = get_parent().find_child("StageCamera", true, false) as Camera3D
		if not cam and vp:
			cam = vp.find_child("StageCamera", true, false) as Camera3D

	if cam and visual:
		visual.update_visual_scale(cam)
		_update_orientation()

func _sync_from_app_state() -> void:
	_on_app_tool_changed("")
	_on_app_transform_space_changed(AppState.is_local_transform_space)
	_on_app_show_all_rotation_axes_changed(AppState.show_all_rotation_axes)
	_on_selection_changed(AppState.selected_objects)

func _on_app_tool_changed(_tool_name: String) -> void:
	match AppState.current_tool:
		AppState.ToolMode.MOVE, AppState.ToolMode.SELECT:
			active_tool = ToolMode.MOVE
		AppState.ToolMode.ROTATE:
			active_tool = ToolMode.ROTATE
		AppState.ToolMode.SCALE:
			active_tool = ToolMode.SCALE
	_update_visibility()

func _on_app_transform_space_changed(is_local: bool) -> void:
	axis_space = AxisSpace.LOCAL if is_local else AxisSpace.WORLD

func _on_app_show_all_rotation_axes_changed(show_all: bool) -> void:
	show_all_rotation_axes = show_all

func _on_selection_changed(new_selection: Array) -> void:
	selected_objects.clear()
	for item in new_selection:
		if is_instance_valid(item) and item is Node3D:
			selected_objects.append(item)

	update_pivot()
	_update_orientation()
	_update_visibility()

func _update_visibility() -> void:
	if selected_objects.is_empty() or AppState.current_tool == AppState.ToolMode.PLACE:
		visible = false
		hovered_handle = HandleId.NONE
	else:
		visible = true

func update_pivot() -> void:
	if selected_objects.is_empty():
		visible = false
		return

	var center := Vector3.ZERO
	var valid_count := 0
	for obj in selected_objects:
		if is_instance_valid(obj):
			var pos := obj.global_position if obj.is_inside_tree() else obj.position
			center += pos
			valid_count += 1

	if valid_count > 0:
		var target_pos := center / float(valid_count)
		if is_inside_tree():
			global_position = target_pos
		else:
			position = target_pos

func _get_target_basis() -> Basis:
	if selected_objects.is_empty() or not is_instance_valid(selected_objects[0]):
		return Basis.IDENTITY
	var obj := selected_objects[0]
	return obj.global_basis.orthonormalized() if obj.is_inside_tree() else obj.basis.orthonormalized()

func get_axis_x() -> Vector3:
	if axis_space == AxisSpace.LOCAL and not selected_objects.is_empty():
		var ob := _get_target_basis()
		var ax := GizmoMath.safe_normalized(ob.x)
		return ax if not ax.is_zero_approx() else Vector3.RIGHT
	return Vector3.RIGHT

func get_axis_y() -> Vector3:
	if axis_space == AxisSpace.LOCAL and not selected_objects.is_empty():
		var ob := _get_target_basis()
		var ay := GizmoMath.safe_normalized(ob.y)
		return ay if not ay.is_zero_approx() else Vector3.UP
	return Vector3.UP

func get_axis_z() -> Vector3:
	if axis_space == AxisSpace.LOCAL and not selected_objects.is_empty():
		var ob := _get_target_basis()
		var az := GizmoMath.safe_normalized(ob.z)
		return az if not az.is_zero_approx() else Vector3.BACK
	return Vector3.BACK

func get_orientation_basis() -> Basis:
	return Basis(get_axis_x(), get_axis_y(), get_axis_z())

func _update_orientation() -> void:
	if visual:
		visual.transform.basis = get_orientation_basis()

func _update_gizmo_position() -> void:
	update_pivot()

static func get_lowest_point_y_offset(obj: Node3D, basis: Basis) -> float:
	if not obj or not ("get_local_aabb" in obj):
		return 0.0
	var local_aabb: AABB = obj.call("get_local_aabb")
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

func start_drag(handle: HandleId, mouse_pos: Vector2, cam: Camera3D = null) -> void:
	if handle == HandleId.NONE or selected_objects.is_empty():
		return

	if cam == null:
		var vp := get_viewport()
		cam = vp.get_camera_3d() if vp else null
		if not cam and is_inside_tree():
			cam = get_tree().root.find_child("StageCamera", true, false) as Camera3D

	drag_targets.clear()
	drag_initial_transforms.clear()
	for obj in selected_objects:
		if is_instance_valid(obj):
			drag_targets.append(obj)
			drag_initial_transforms.append(obj.global_transform)

	if drag_targets.is_empty():
		return

	is_dragging = true
	active_drag_handle = handle
	drag_start_mouse_pos = mouse_pos
	drag_pivot = global_position

	match handle:
		HandleId.ROT_X, HandleId.ROT_Y, HandleId.ROT_Z:
			if handle == HandleId.ROT_X:
				drag_axis = get_axis_x()
			elif handle == HandleId.ROT_Y:
				drag_axis = get_axis_y()
			else:
				drag_axis = get_axis_z()
			drag_axis = TransformGuard.safe_normalized(drag_axis, Vector3.UP)
			drag_plane_normal = drag_axis

			var radius := 1.0
			if visual and "current_world_size" in visual:
				radius = visual.current_world_size
			elif cam:
				var vp_h := float(cam.get_viewport().size.y) if cam.get_viewport() else 800.0
				if vp_h <= 0.0: vp_h = 800.0
				var dist := cam.global_position.distance_to(drag_pivot)
				var sf: float = UIScale.current_scale if UIScale else 1.0
				radius = (2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / vp_h) * 110.0 * sf
			radius = maxf(0.01, radius)

			# 1. Record the grabbed point on the ring in 3D (closest point on ring to mouse)
			var sf: float = UIScale.current_scale if UIScale else 1.0
			if cam:
				drag_grab_point = GizmoPicker.pick_ring_point(mouse_pos, self, cam, handle, sf)
			else:
				var ref := Vector3.UP if absf(drag_axis.y) < 0.9 else Vector3.RIGHT
				drag_grab_point = drag_pivot + (drag_axis.cross(ref)).normalized() * radius

			# 2. Compute 3D tangent at that point = normalize(cross(axis, grab_point - pivot))
			var radial := drag_grab_point - drag_pivot
			radial = radial - drag_axis * drag_axis.dot(radial)
			var radial_dir := TransformGuard.safe_normalized(radial)
			if radial_dir.is_zero_approx():
				var ref := Vector3.UP if absf(drag_axis.y) < 0.9 else Vector3.RIGHT
				radial_dir = TransformGuard.safe_normalized(drag_axis.cross(ref))
			var tangent_3d := TransformGuard.safe_normalized(drag_axis.cross(radial_dir))

			# Project grab_point and grab_point + tangent * small_step to screen
			var small_step := radius * 0.05
			var p_grab_2d := cam.unproject_position(drag_grab_point) if cam else mouse_pos
			var p_step_2d := cam.unproject_position(drag_grab_point + tangent_3d * small_step) if cam else (mouse_pos + Vector2(1, 0))
			var screen_tan_vec := p_step_2d - p_grab_2d
			var screen_tan_len := screen_tan_vec.length()
			var angle_step := small_step / radius
			var px_per_rad := (screen_tan_len / angle_step) if angle_step > 1e-6 else 0.0

			# 4. If the ring is nearly edge-on (screen tangent length or pixels_per_radian very small),
			# fall back to stable rule perpendicular to ring's projected major axis with 0.5 deg/pixel sensitivity
			if screen_tan_len < 1.5 or px_per_rad < 15.0:
				drag_is_edge_on = true
				var cam_fwd := -cam.global_transform.basis.z.normalized() if cam else Vector3.FORWARD
				var major_3d := drag_axis.cross(cam_fwd)
				if major_3d.length_squared() < 1e-6:
					major_3d = cam.global_transform.basis.x.normalized() if cam else Vector3.RIGHT
				else:
					major_3d = major_3d.normalized()

				var p_center_2d := cam.unproject_position(drag_pivot) if cam else mouse_pos
				var p_maj_2d := cam.unproject_position(drag_pivot + major_3d * radius) if cam else (mouse_pos + Vector2(100, 0))
				var s_major := (p_maj_2d - p_center_2d).normalized()
				if s_major.is_zero_approx():
					s_major = Vector2.RIGHT

				var s_perp := Vector2(-s_major.y, s_major.x)
				# Sign check: align with positive rotation around drag_axis
				var test_rot := Basis(drag_axis, 0.05)
				var test_pt_2d := cam.unproject_position(drag_pivot + test_rot * (drag_grab_point - drag_pivot)) if cam else p_grab_2d
				if (test_pt_2d - p_grab_2d).dot(s_perp) < 0.0:
					s_perp = -s_perp

				drag_screen_tangent = s_perp
				drag_pixels_per_radian = 1.0 / deg_to_rad(0.5) # 0.5 deg per pixel (~114.59 px/rad)
			else:
				drag_is_edge_on = false
				drag_screen_tangent = screen_tan_vec / screen_tan_len
				drag_pixels_per_radian = maxf(15.0, px_per_rad)

		HandleId.MOVE_X, HandleId.MOVE_Y, HandleId.MOVE_Z:
			if handle == HandleId.MOVE_X:
				drag_axis = get_axis_x()
			elif handle == HandleId.MOVE_Y:
				drag_axis = get_axis_y()
			else:
				drag_axis = get_axis_z()
			drag_axis = TransformGuard.safe_normalized(drag_axis, Vector3.RIGHT)
			if cam:
				var ray_orig := cam.project_ray_origin(mouse_pos)
				var ray_norm := cam.project_ray_normal(mouse_pos)
				drag_start_axis_t = GizmoMath.ray_closest_point_on_axis(ray_orig, ray_norm, drag_pivot, drag_axis)
			else:
				drag_start_axis_t = 0.0

		HandleId.MOVE_XZ:
			drag_plane_normal = get_axis_y()
			if cam:
				var ray_orig := cam.project_ray_origin(mouse_pos)
				var ray_norm := cam.project_ray_normal(mouse_pos)
				var hit = GizmoMath.ray_plane_intersection(ray_orig, ray_norm, drag_pivot, drag_plane_normal)
				drag_start_plane_pos = hit if hit != null else drag_pivot
			else:
				drag_start_plane_pos = drag_pivot

func update_drag(cam: Camera3D, mouse_pos: Vector2) -> void:
	if not is_dragging or drag_targets.is_empty() or cam == null:
		return

	match active_drag_handle:
		HandleId.ROT_X, HandleId.ROT_Y, HandleId.ROT_Z:
			# 3. Tangent-based screen-space angle calculation
			var mouse_delta := mouse_pos - drag_start_mouse_pos
			var drag_dist_px := mouse_delta.dot(drag_screen_tangent)
			var raw_angle := drag_dist_px / drag_pixels_per_radian

			if drag_is_edge_on:
				raw_angle = clampf(raw_angle, -PI * 4.0, PI * 4.0)

			var final_angle := raw_angle
			if not Input.is_key_pressed(KEY_ALT) and AppState.snap_to_grid:
				var step_deg := 15.0 # Default 15° snapping for gizmo rotation rings
				if Input.is_key_pressed(KEY_CTRL) or (OS.get_name() == "macOS" and Input.is_key_pressed(KEY_META)):
					step_deg = 5.0 # Fine 5° snapping
				elif AppState.rotation_step < 15.0:
					step_deg = AppState.rotation_step

				var step_rad := deg_to_rad(step_deg)
				final_angle = GizmoMath.snap_angle(raw_angle, step_rad)

			var rot_basis := Basis(drag_axis, final_angle)

			for i in range(drag_targets.size()):
				var obj := drag_targets[i]
				if is_instance_valid(obj):
					var init_t := drag_initial_transforms[i]
					var rel_pos := init_t.origin - drag_pivot
					var new_pos := drag_pivot + (rot_basis * rel_pos)
					var new_basis := rot_basis * init_t.basis

					if AppState.auto_rest_on_rotate and "get_local_aabb" in obj:
						var min_offset: float = get_lowest_point_y_offset(obj, new_basis)
						if new_pos.y + min_offset < 0.0:
							new_pos.y = -min_offset

					var cand_t := Transform3D(new_basis, new_pos)
					cand_t = TransformGuard.sanitize(cand_t, init_t, "Gizmo.rotate")
					obj.global_transform = cand_t

			_update_orientation()
			var ax_name := "Yaw Y" if active_drag_handle == HandleId.ROT_Y else ("Pitch X" if active_drag_handle == HandleId.ROT_X else "Roll Z")
			AppState.status_message.emit("Rotate %s: %.1f°" % [ax_name, rad_to_deg(final_angle)])

		HandleId.MOVE_X, HandleId.MOVE_Y, HandleId.MOVE_Z:
			var ray_orig := cam.project_ray_origin(mouse_pos)
			var ray_norm := cam.project_ray_normal(mouse_pos)
			var cur_t := GizmoMath.ray_closest_point_on_axis(ray_orig, ray_norm, drag_pivot, drag_axis)
			var delta_t := cur_t - drag_start_axis_t
			if not Input.is_key_pressed(KEY_ALT) and AppState.snap_to_grid:
				delta_t = GizmoMath.snap_value(delta_t, AppState.grid_step)
			var delta_vec := drag_axis * delta_t
			delta_vec = TransformGuard.clamp_move_delta(delta_vec, 50.0)

			for i in range(drag_targets.size()):
				var obj := drag_targets[i]
				if is_instance_valid(obj):
					var init_t := drag_initial_transforms[i]
					var new_origin := init_t.origin + delta_vec
					if AppState.auto_rest_on_rotate and "get_local_aabb" in obj:
						var min_offset: float = get_lowest_point_y_offset(obj, init_t.basis)
						if new_origin.y + min_offset < 0.0:
							new_origin.y = -min_offset
					var cand_t := Transform3D(init_t.basis, new_origin)
					cand_t = TransformGuard.sanitize(cand_t, init_t, "Gizmo.move")
					obj.global_transform = cand_t

			global_position = drag_pivot + delta_vec
			AppState.status_message.emit("Move: (%.2f, %.2f, %.2f)" % [global_position.x, global_position.y, global_position.z])

		HandleId.MOVE_XZ:
			var ray_orig := cam.project_ray_origin(mouse_pos)
			var ray_norm := cam.project_ray_normal(mouse_pos)
			var hit = GizmoMath.ray_plane_intersection(ray_orig, ray_norm, drag_pivot, drag_plane_normal)
			if hit != null:
				var delta_vec: Vector3 = (hit as Vector3) - drag_start_plane_pos
				if not Input.is_key_pressed(KEY_ALT) and AppState.snap_to_grid:
					delta_vec.x = GizmoMath.snap_value(delta_vec.x, AppState.grid_step)
					delta_vec.z = GizmoMath.snap_value(delta_vec.z, AppState.grid_step)
				delta_vec = TransformGuard.clamp_move_delta(delta_vec, 50.0)

				for i in range(drag_targets.size()):
					var obj := drag_targets[i]
					if is_instance_valid(obj):
						var init_t := drag_initial_transforms[i]
						var new_origin := init_t.origin + delta_vec
						if AppState.auto_rest_on_rotate and "get_local_aabb" in obj:
							var min_offset: float = get_lowest_point_y_offset(obj, init_t.basis)
							if new_origin.y + min_offset < 0.0:
								new_origin.y = -min_offset
						var cand_t := Transform3D(init_t.basis, new_origin)
						cand_t = TransformGuard.sanitize(cand_t, init_t, "Gizmo.move_xz")
						obj.global_transform = cand_t

				global_position = drag_pivot + delta_vec
				AppState.status_message.emit("Move XZ: (%.2f, %.2f, %.2f)" % [global_position.x, global_position.y, global_position.z])

		HandleId.SCALE_X, HandleId.SCALE_Y, HandleId.SCALE_Z, HandleId.SCALE_UNIFORM:
			var dy := - (mouse_pos.y - drag_start_mouse_pos.y) * 0.01
			var scale_factor: float = clampf(1.0 + dy, 0.1, 10.0)
			if not Input.is_key_pressed(KEY_ALT) and AppState.snap_to_grid:
				scale_factor = roundf(scale_factor * 10.0) / 10.0

			for i in range(drag_targets.size()):
				var obj := drag_targets[i]
				if is_instance_valid(obj):
					var init_t := drag_initial_transforms[i]
					var scale_vec := Vector3.ONE * scale_factor
					if active_drag_handle == HandleId.SCALE_X:
						scale_vec = Vector3(scale_factor, 1.0, 1.0)
					elif active_drag_handle == HandleId.SCALE_Y:
						scale_vec = Vector3(1.0, scale_factor, 1.0)
					elif active_drag_handle == HandleId.SCALE_Z:
						scale_vec = Vector3(1.0, 1.0, scale_factor)

					var new_basis := init_t.basis.scaled(scale_vec)
					var cand_t := Transform3D(new_basis, init_t.origin)
					cand_t = TransformGuard.sanitize(cand_t, init_t, "Gizmo.scale")
					obj.global_transform = cand_t

			AppState.status_message.emit("Scale: %.2fx" % scale_factor)

func end_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false

	var changed := false
	var final_transforms: Array[Transform3D] = []
	for i in range(drag_targets.size()):
		var obj := drag_targets[i]
		if is_instance_valid(obj):
			final_transforms.append(obj.global_transform)
			if not obj.global_transform.is_equal_approx(drag_initial_transforms[i]):
				changed = true
		else:
			final_transforms.append(drag_initial_transforms[i])

	if changed and not drag_targets.is_empty():
		var cmd := BaseCommand.TransformCommand.new(drag_targets, drag_initial_transforms, final_transforms)
		CommandManager.execute_command(cmd)

	update_pivot()
	_update_orientation()
	active_drag_handle = HandleId.NONE
	drag_targets.clear()
	drag_initial_transforms.clear()

func cancel_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false

	for i in range(drag_targets.size()):
		var obj := drag_targets[i]
		if is_instance_valid(obj) and i < drag_initial_transforms.size():
			obj.global_transform = drag_initial_transforms[i]

	update_pivot()
	_update_orientation()
	active_drag_handle = HandleId.NONE
	drag_targets.clear()
	drag_initial_transforms.clear()
	AppState.status_message.emit("Gizmo drag cancelled")

func set_hovered_handle(handle: Variant) -> void:
	hovered_handle = handle as HandleId

func pick(mouse_pos: Vector2, camera: Camera3D, ui_scale: float = 1.0) -> HandleId:
	if not visible:
		return HandleId.NONE
	return GizmoPicker.pick(mouse_pos, self, camera, ui_scale)

