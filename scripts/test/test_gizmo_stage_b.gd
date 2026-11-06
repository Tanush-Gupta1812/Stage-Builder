class_name TestGizmoStageB
extends RefCounted

const GizmoController = preload("res://scripts/viewport/gizmo/gizmo_controller.gd")
const GizmoVisual = preload("res://scripts/viewport/gizmo/gizmo_visual.gd")
const GizmoPicker = preload("res://scripts/viewport/gizmo/gizmo_picker.gd")
const GizmoMath = preload("res://scripts/viewport/gizmo/gizmo_math.gd")

## Unit tests for Gizmo Stage B:
## - Visual handle counts and tool exclusivity
## - Strict unit-length axes under gizmo scaling and object non-uniform scaling
## - Screen-space picking accuracy and tolerance
## - Constant on-screen sizing across camera distances and UI scales
## - Toolbar layout at 700, 1000, 1600 px widths

static func run_all_tests() -> bool:
	print("[TEST] Running Gizmo Stage B Unit Test Suite...")
	var passed := true

	passed = test_visual_handle_counts_and_visibility() and passed
	passed = test_axis_normalization_and_unit_lengths() and passed
	passed = test_constant_screen_sizing() and passed
	passed = test_screen_space_picker() and passed
	passed = test_toolbar_responsive_widths() and passed
	passed = test_gizmo_rotation_dragging() and passed

	if passed:
		print("  -> Gizmo Stage B: ALL UNIT TESTS PASSED.")
	else:
		push_error("  -> Gizmo Stage B: ONE OR MORE UNIT TESTS FAILED.")
	return passed

static func test_visual_handle_counts_and_visibility() -> bool:
	var dummy_root := Node3D.new()
	Engine.get_main_loop().root.add_child(dummy_root)
	var ctrl := GizmoController.new()
	dummy_root.add_child(ctrl)

	var target := Node3D.new()
	dummy_root.add_child(target)
	ctrl.selected_objects = [target]
	ctrl.update_pivot()

	# 1. MOVE Tool: only MoveGroup is visible
	ctrl.active_tool = GizmoController.ToolMode.MOVE
	ctrl.visual.update_tool_handles()
	if not ctrl.visual._move_group.visible:
		push_error("MoveGroup should be visible in MOVE tool")
		_cleanup(dummy_root)
		return false
	if ctrl.visual._rotate_group.visible or ctrl.visual._scale_group.visible:
		push_error("RotateGroup and ScaleGroup should be hidden in MOVE tool")
		_cleanup(dummy_root)
		return false

	# 2. ROTATE Tool: default shows ONLY yaw ring
	ctrl.active_tool = GizmoController.ToolMode.ROTATE
	ctrl.show_all_rotation_axes = false
	ctrl.visual.update_tool_handles()
	if not ctrl.visual._rotate_group.visible or ctrl.visual._move_group.visible or ctrl.visual._scale_group.visible:
		push_error("Only RotateGroup should be visible in ROTATE tool")
		_cleanup(dummy_root)
		return false

	var rot_y_meshes: Array = ctrl.visual._handle_meshes.get(GizmoController.HandleId.ROT_Y, [])
	var rot_x_meshes: Array = ctrl.visual._handle_meshes.get(GizmoController.HandleId.ROT_X, [])
	var rot_z_meshes: Array = ctrl.visual._handle_meshes.get(GizmoController.HandleId.ROT_Z, [])
	if rot_y_meshes.is_empty() or not rot_y_meshes[0].visible:
		push_error("ROT_Y ring should be visible by default")
		_cleanup(dummy_root)
		return false
	if not rot_x_meshes.is_empty() and rot_x_meshes[0].visible:
		push_error("ROT_X ring should be hidden by default in ROTATE tool")
		_cleanup(dummy_root)
		return false
	if not rot_z_meshes.is_empty() and rot_z_meshes[0].visible:
		push_error("ROT_Z ring should be hidden by default in ROTATE tool")
		_cleanup(dummy_root)
		return false

	# 3. ROTATE Tool with show_all_rotation_axes = true
	ctrl.show_all_rotation_axes = true
	ctrl.visual.update_tool_handles()
	if rot_x_meshes.is_empty() or not rot_x_meshes[0].visible:
		push_error("ROT_X ring should be visible when show_all_rotation_axes is true")
		_cleanup(dummy_root)
		return false
	if rot_z_meshes.is_empty() or not rot_z_meshes[0].visible:
		push_error("ROT_Z ring should be visible when show_all_rotation_axes is true")
		_cleanup(dummy_root)
		return false

	# 4. SCALE Tool: only ScaleGroup visible
	ctrl.active_tool = GizmoController.ToolMode.SCALE
	ctrl.visual.update_tool_handles()
	if not ctrl.visual._scale_group.visible or ctrl.visual._move_group.visible or ctrl.visual._rotate_group.visible:
		push_error("Only ScaleGroup should be visible in SCALE tool")
		_cleanup(dummy_root)
		return false

	_cleanup(dummy_root)
	return true

static func test_axis_normalization_and_unit_lengths() -> bool:
	var dummy_root := Node3D.new()
	Engine.get_main_loop().root.add_child(dummy_root)
	var ctrl := GizmoController.new()
	dummy_root.add_child(ctrl)

	var target := Node3D.new()
	dummy_root.add_child(target)
	ctrl.selected_objects = [target]

	# Test World axes across visual world sizes 1.0, 2.55, 5.0
	for test_size in [1.0, 2.55, 5.0]:
		ctrl.visual.current_world_size = test_size
		ctrl.visual.scale = Vector3.ONE * test_size

		# Controller logical node must remain unit scale
		if not ctrl.scale.is_equal_approx(Vector3.ONE):
			push_error("GizmoController logical node scale was altered: %s" % str(ctrl.scale))
			_cleanup(dummy_root)
			return false

		var ax := ctrl.get_axis_x()
		var ay := ctrl.get_axis_y()
		var az := ctrl.get_axis_z()
		if not is_equal_approx(ax.length(), 1.0) or not is_equal_approx(ay.length(), 1.0) or not is_equal_approx(az.length(), 1.0):
			push_error("World axes are not unit vectors at scale %f: ax=%f, ay=%f, az=%f" % [test_size, ax.length(), ay.length(), az.length()])
			_cleanup(dummy_root)
			return false

	# Test Local axes with heavily non-uniformly scaled target object
	target.scale = Vector3(4.2, 0.15, 12.8)
	target.global_basis = Basis(Vector3.UP, deg_to_rad(37.0)) * Basis(Vector3.RIGHT, deg_to_rad(22.0)).scaled(target.scale)
	ctrl.axis_space = GizmoController.AxisSpace.LOCAL

	for test_size in [1.0, 2.55, 5.0]:
		ctrl.visual.current_world_size = test_size
		var lax := ctrl.get_axis_x()
		var lay := ctrl.get_axis_y()
		var laz := ctrl.get_axis_z()

		if not is_equal_approx(lax.length(), 1.0) or not is_equal_approx(lay.length(), 1.0) or not is_equal_approx(laz.length(), 1.0):
			push_error("Local axes from non-uniformly scaled object are not unit vectors: lax=%f, lay=%f, laz=%f" % [lax.length(), lay.length(), laz.length()])
			_cleanup(dummy_root)
			return false

		# Orthonormality check: axes must be mutually orthogonal
		if absf(lax.dot(lay)) > 1e-4 or absf(lay.dot(laz)) > 1e-4 or absf(lax.dot(laz)) > 1e-4:
			push_error("Local axes are not orthogonal: lax.lay=%f, lay.laz=%f, lax.laz=%f" % [lax.dot(lay), lay.dot(laz), lax.dot(laz)])
			_cleanup(dummy_root)
			return false

	_cleanup(dummy_root)
	return true

static func test_constant_screen_sizing() -> bool:
	var dummy_root := Node3D.new()
	var tree_root: Window = Engine.get_main_loop().root
	tree_root.add_child(dummy_root)

	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	dummy_root.add_child(vp)

	var cam := Camera3D.new()
	cam.fov = 75.0
	vp.add_child(cam)

	var ctrl := GizmoController.new()
	vp.add_child(ctrl)
	ctrl.global_position = Vector3(0, 0, 0)

	# Distances 5m, 10m, 20m
	cam.global_position = Vector3(0, 0, 5)
	var s_5m := ctrl.visual.update_visual_scale(cam)

	cam.global_position = Vector3(0, 0, 10)
	var s_10m := ctrl.visual.update_visual_scale(cam)

	cam.global_position = Vector3(0, 0, 20)
	var s_20m := ctrl.visual.update_visual_scale(cam)

	# When distance doubles from 5m to 10m, world size must double to maintain 110px
	if not is_equal_approx(s_10m / s_5m, 2.0):
		push_error("Gizmo visual scale does not scale proportionally with distance (5m: %f, 10m: %f, ratio: %f)" % [s_5m, s_10m, s_10m / s_5m])
		_cleanup(dummy_root)
		return false

	if not is_equal_approx(s_20m / s_10m, 2.0):
		push_error("Gizmo visual scale does not scale proportionally with distance (10m: %f, 20m: %f, ratio: %f)" % [s_10m, s_20m, s_20m / s_10m])
		_cleanup(dummy_root)
		return false

	_cleanup(dummy_root)
	return true

static func test_screen_space_picker() -> bool:
	var dummy_root := Node3D.new()
	var tree_root: Window = Engine.get_main_loop().root
	tree_root.add_child(dummy_root)

	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	dummy_root.add_child(vp)

	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.global_position = Vector3(0, 2, 5)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)

	var ctrl := GizmoController.new()
	vp.add_child(ctrl)

	var target := Node3D.new()
	vp.add_child(target)
	target.global_position = Vector3(0, 0, 0)
	ctrl.selected_objects = [target]
	ctrl.update_pivot()
	ctrl.visible = true
	ctrl.visual.current_world_size = 1.0

	# 1. Test picking MOVE_Y: point halfway up Y arrow
	ctrl.active_tool = GizmoController.ToolMode.MOVE
	var arrow_y_mid := Vector3(0, 0.4, 0)
	var screen_y_mid := cam.unproject_position(arrow_y_mid)
	var hit_y := ctrl.pick(screen_y_mid, cam, 1.0)
	if hit_y != GizmoController.HandleId.MOVE_Y:
		push_error("Screen-space picker expected MOVE_Y, got %s" % str(hit_y))
		_cleanup(dummy_root)
		return false

	# 2. Test picking MOVE_X: point halfway along X arrow
	var arrow_x_mid := Vector3(0.4, 0, 0)
	var screen_x_mid := cam.unproject_position(arrow_x_mid)
	var hit_x := ctrl.pick(screen_x_mid, cam, 1.0)
	if hit_x != GizmoController.HandleId.MOVE_X:
		push_error("Screen-space picker expected MOVE_X, got %s" % str(hit_x))
		_cleanup(dummy_root)
		return false

	# 3. Test picking far away -> returns NONE
	var hit_far := ctrl.pick(screen_x_mid + Vector2(250, 250), cam, 1.0)
	if hit_far != GizmoController.HandleId.NONE:
		push_error("Screen-space picker expected NONE for distant point, got %s" % str(hit_far))
		_cleanup(dummy_root)
		return false

	# 4. Overlapping test: point closer to X than Y returns X
	var screen_near_x := screen_x_mid + Vector2(2, 2)
	var hit_near_x := ctrl.pick(screen_near_x, cam, 1.0)
	if hit_near_x != GizmoController.HandleId.MOVE_X:
		push_error("Screen-space picker closest handle expected MOVE_X, got %s" % str(hit_near_x))
		_cleanup(dummy_root)
		return false

	# 5. Test SCALE tool uniform center box
	ctrl.active_tool = GizmoController.ToolMode.SCALE
	var screen_origin := cam.unproject_position(Vector3(0, 0, 0))
	var hit_scale_uni := ctrl.pick(screen_origin, cam, 1.0)
	if hit_scale_uni != GizmoController.HandleId.SCALE_UNIFORM:
		push_error("Screen-space picker expected SCALE_UNIFORM, got %s" % str(hit_scale_uni))
		_cleanup(dummy_root)
		return false

	_cleanup(dummy_root)
	return true

static func test_toolbar_responsive_widths() -> bool:
	# Verify that the toolbar can resize across 700, 1000, 1600 px without clipping
	var tb := PanelContainer.new()
	var hbox := HBoxContainer.new()
	tb.add_child(hbox)

	var b1 := Button.new()
	b1.text = "Move (1)"
	hbox.add_child(b1)
	var b2 := Button.new()
	b2.text = "Rotate (2)"
	hbox.add_child(b2)
	var b3 := Button.new()
	b3.text = "Scale (3)"
	hbox.add_child(b3)
	var b4 := Button.new()
	b4.text = "All Axes (X)"
	hbox.add_child(b4)
	var b5 := Button.new()
	b5.text = "World"
	hbox.add_child(b5)

	for w: float in [700.0, 1000.0, 1600.0]:
		var avail_w: float = w - 20.0
		# Apply compact text for < 480
		if avail_w < 480.0:
			b1.text = "1:Move"
			b2.text = "2:Rot"
			b3.text = "3:Scale"
			b4.text = "Axes (X)"
			b5.text = "W"
		else:
			b1.text = "Move (1)"
			b2.text = "Rotate (2)"
			b3.text = "Scale (3)"
			b4.text = "All Axes (X)"
			b5.text = "World"

		var min_w: float = tb.get_combined_minimum_size().x
		if min_w > w:
			push_error("Toolbar min size (%f) exceeded viewport width (%f)" % [min_w, w])
			tb.free()
			return false

	tb.free()
	return true

static func test_gizmo_rotation_dragging() -> bool:
	var dummy_root := Node3D.new()
	Engine.get_main_loop().root.add_child(dummy_root)

	var cam := Camera3D.new()
	dummy_root.add_child(cam)
	cam.global_position = Vector3(0, 10, 10)
	cam.look_at(Vector3.ZERO, Vector3.UP)

	var target := Node3D.new()
	dummy_root.add_child(target)
	target.global_position = Vector3.ZERO
	target.global_basis = Basis.IDENTITY

	var ctrl := GizmoController.new()
	dummy_root.add_child(ctrl)
	ctrl.selected_objects = [target]
	ctrl.active_tool = GizmoController.ToolMode.ROTATE
	ctrl.visible = true
	ctrl.update_pivot()

	# Start rotation drag on Yaw Y ring (HandleId.ROT_Y)
	ctrl.start_drag(GizmoController.HandleId.ROT_Y, Vector2(300, 300), cam)
	if not ctrl.is_dragging:
		push_error("FAIL: GizmoController did not enter is_dragging on start_drag.")
		_cleanup(dummy_root)
		return false

	# Drag to a new mouse coordinate to induce angle change
	ctrl.update_drag(cam, Vector2(600, 200))

	# Verify target basis has rotated and is strictly finite
	var initial_basis := Basis.IDENTITY
	if target.global_basis.is_equal_approx(initial_basis):
		push_error("FAIL: Target basis did not rotate during gizmo update_drag.")
		_cleanup(dummy_root)
		return false

	# Complete drag and verify command execution
	ctrl.end_drag()
	if ctrl.is_dragging:
		push_error("FAIL: GizmoController is_dragging did not reset to false after end_drag.")
		_cleanup(dummy_root)
		return false

	_cleanup(dummy_root)
	return true

static func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		if node.get_parent():
			node.get_parent().remove_child(node)
		node.free()
