class_name GizmoPicker
extends RefCounted

const GizmoMath = preload("res://scripts/viewport/gizmo/gizmo_math.gd")
const GizmoController = preload("res://scripts/viewport/gizmo/gizmo_controller.gd")

## Screen-space picking for Transform Gizmo handles.
## Projects handle geometry to 2D viewport coordinates and tests mouse distance
## against screen-space pixel tolerance (~12px scaled with UI scale).
## Closest handle wins. Handles ALWAYS beat object bodies.

static func pick(
	mouse_pos: Vector2,
	controller: GizmoController,
	camera: Camera3D,
	ui_scale: float = 1.0
) -> GizmoController.HandleId:
	if not controller or not controller.visible or not is_instance_valid(camera):
		return GizmoController.HandleId.NONE

	var tolerance := 12.0 * maxf(0.5, ui_scale)
	var origin := controller.global_position

	if camera.is_position_behind(origin):
		return GizmoController.HandleId.NONE

	var visual_scale := 1.0
	if controller.visual and "current_world_size" in controller.visual:
		visual_scale = controller.visual.current_world_size
	else:
		# Estimate constant size
		var vp_h := float(camera.get_viewport().size.y)
		if vp_h <= 0.0: vp_h = 800.0
		var dist := camera.global_position.distance_to(origin)
		visual_scale = (2.0 * dist * tan(deg_to_rad(camera.fov) * 0.5) / vp_h) * 110.0 * ui_scale
	visual_scale = maxf(0.01, visual_scale)

	var ux := controller.get_axis_x()
	var uy := controller.get_axis_y()
	var uz := controller.get_axis_z()

	var best_handle := GizmoController.HandleId.NONE
	var min_distance := tolerance

	var tool_mode := controller.active_tool

	# --- 1. MOVE TOOL ---
	if tool_mode == GizmoController.ToolMode.MOVE:
		# Check XZ ground plane handle first (if mouse is inside square, dist is 0)
		var c0 := origin + (ux * 0.18 + uz * 0.18) * visual_scale
		var c1 := origin + (ux * 0.45 + uz * 0.18) * visual_scale
		var c2 := origin + (ux * 0.45 + uz * 0.45) * visual_scale
		var c3 := origin + (ux * 0.18 + uz * 0.45) * visual_scale

		if not (camera.is_position_behind(c0) or camera.is_position_behind(c1) or camera.is_position_behind(c2) or camera.is_position_behind(c3)):
			var p0_2d := camera.unproject_position(c0)
			var p1_2d := camera.unproject_position(c1)
			var p2_2d := camera.unproject_position(c2)
			var p3_2d := camera.unproject_position(c3)
			var poly := PackedVector2Array([p0_2d, p1_2d, p2_2d, p3_2d])

			if Geometry2D.is_point_in_polygon(mouse_pos, poly):
				best_handle = GizmoController.HandleId.MOVE_XZ
				min_distance = 0.0
			else:
				var closed_poly := PackedVector2Array([p0_2d, p1_2d, p2_2d, p3_2d, p0_2d])
				var d_poly := GizmoMath.dist_point_to_polyline_2d(mouse_pos, closed_poly)
				if d_poly < min_distance:
					min_distance = d_poly
					best_handle = GizmoController.HandleId.MOVE_XZ

		# Check Axis Arrows (X, Y, Z)
		var axes := [
			{"id": GizmoController.HandleId.MOVE_X, "dir": ux},
			{"id": GizmoController.HandleId.MOVE_Y, "dir": uy},
			{"id": GizmoController.HandleId.MOVE_Z, "dir": uz}
		]
		for a in axes:
			var tip: Vector3 = origin + a["dir"] * visual_scale
			if not camera.is_position_behind(tip):
				var s_start := camera.unproject_position(origin)
				var s_end := camera.unproject_position(tip)
				var d_seg := GizmoMath.dist_point_to_segment_2d(mouse_pos, s_start, s_end)
				if d_seg < min_distance:
					min_distance = d_seg
					best_handle = a["id"]

	# --- 2. ROTATE TOOL ---
	elif tool_mode == GizmoController.ToolMode.ROTATE:
		var rings := [
			{"id": GizmoController.HandleId.ROT_Y, "axis": uy}
		]
		if controller.show_all_rotation_axes:
			rings.append({"id": GizmoController.HandleId.ROT_X, "axis": ux})
			rings.append({"id": GizmoController.HandleId.ROT_Z, "axis": uz})

		for r in rings:
			var ring_3d := GizmoMath.ring_polyline(origin, r["axis"], visual_scale, 64)
			var seg_count := ring_3d.size() - 1
			for i in range(seg_count):
				var p0_3d := ring_3d[i]
				var p1_3d := ring_3d[i + 1]
				if camera.is_position_behind(p0_3d) or camera.is_position_behind(p1_3d):
					continue
				var p0_2d := camera.unproject_position(p0_3d)
				var p1_2d := camera.unproject_position(p1_3d)
				var d_seg := GizmoMath.dist_point_to_segment_2d(mouse_pos, p0_2d, p1_2d)
				if d_seg < min_distance:
					min_distance = d_seg
					best_handle = r["id"]

	# --- 3. SCALE TOOL ---
	elif tool_mode == GizmoController.ToolMode.SCALE:
		# Center Uniform Box
		var s_center := camera.unproject_position(origin)
		var d_center := mouse_pos.distance_to(s_center)
		var center_hit_rad := 12.0 * maxf(0.5, ui_scale)
		if d_center <= center_hit_rad:
			best_handle = GizmoController.HandleId.SCALE_UNIFORM
			min_distance = 0.0

		# Scale Box Handles (X, Y, Z)
		var scale_axes := [
			{"id": GizmoController.HandleId.SCALE_X, "dir": ux},
			{"id": GizmoController.HandleId.SCALE_Y, "dir": uy},
			{"id": GizmoController.HandleId.SCALE_Z, "dir": uz}
		]
		for a in scale_axes:
			var box_center: Vector3 = origin + a["dir"] * (0.85 * visual_scale)
			if not camera.is_position_behind(box_center):
				var s_box := camera.unproject_position(box_center)
				var d_box := mouse_pos.distance_to(s_box)
				if d_box < min_distance:
					min_distance = d_box
					best_handle = a["id"]

	return best_handle

## Returns the exact 3D point on the specified rotation ring closest to the mouse in screen space.
## Works reliably for edge-on, tilted, and full-face rings.
static func pick_ring_point(
	mouse_pos: Vector2,
	controller: GizmoController,
	camera: Camera3D,
	handle: GizmoController.HandleId,
	ui_scale: float = 1.0
) -> Vector3:
	if not controller or not is_instance_valid(camera):
		return Vector3.ZERO

	var origin := controller.global_position
	var visual_scale := 1.0
	if controller.visual and "current_world_size" in controller.visual:
		visual_scale = controller.visual.current_world_size
	else:
		var vp_h := float(camera.get_viewport().size.y) if camera.get_viewport() else 800.0
		if vp_h <= 0.0: vp_h = 800.0
		var dist := camera.global_position.distance_to(origin)
		visual_scale = (2.0 * dist * tan(deg_to_rad(camera.fov) * 0.5) / vp_h) * 110.0 * ui_scale
	visual_scale = maxf(0.01, visual_scale)

	var axis := Vector3.UP
	if handle == GizmoController.HandleId.ROT_X:
		axis = controller.get_axis_x()
	elif handle == GizmoController.HandleId.ROT_Y:
		axis = controller.get_axis_y()
	elif handle == GizmoController.HandleId.ROT_Z:
		axis = controller.get_axis_z()
	axis = GizmoMath.safe_normalized(axis)
	if axis.is_zero_approx():
		axis = Vector3.UP

	var ring_3d := GizmoMath.ring_polyline(origin, axis, visual_scale, 64)
	var seg_count := ring_3d.size() - 1
	var best_dist := INF
	var fallback_ref := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var best_pt_3d := origin + (axis.cross(fallback_ref)).normalized() * visual_scale

	for i in range(seg_count):
		var p0_3d := ring_3d[i]
		var p1_3d := ring_3d[i + 1]
		if camera.is_position_behind(p0_3d) or camera.is_position_behind(p1_3d):
			continue
		var p0_2d := camera.unproject_position(p0_3d)
		var p1_2d := camera.unproject_position(p1_3d)
		var ab := p1_2d - p0_2d
		var ab_len_sq := ab.length_squared()
		var t := 0.0
		if ab_len_sq > 1e-8:
			t = clampf((mouse_pos - p0_2d).dot(ab) / ab_len_sq, 0.0, 1.0)
		var proj_2d := p0_2d + ab * t
		var d := mouse_pos.distance_to(proj_2d)
		if d < best_dist:
			best_dist = d
			best_pt_3d = p0_3d.lerp(p1_3d, t)

	# Project exactly onto the ring circle radius
	var rad := best_pt_3d - origin
	rad = rad - axis * axis.dot(rad)
	if rad.length_squared() > 1e-6:
		best_pt_3d = origin + rad.normalized() * visual_scale

	return best_pt_3d

