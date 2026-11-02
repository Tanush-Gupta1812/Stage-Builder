class_name TransformGizmo
extends Node3D

## Interactive 3D Transform Gizmo for Stage-Builder.
## Provides visual handles for 3-axis translation and Y-axis rotation with undo/redo support.

enum AxisMode { NONE, AXIS_X, AXIS_Y, AXIS_Z, PLANE_XZ, ROT_Y }
enum PivotDisplayMode { BASE_CENTER, GEOMETRIC_CENTER }

var active_handle: AxisMode = AxisMode.NONE
var pivot_mode: PivotDisplayMode = PivotDisplayMode.BASE_CENTER
var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_gizmo_pos: Vector3 = Vector3.ZERO
var initial_transforms: Array[Transform3D] = []
var target_objects: Array[Node3D] = []

var _mat_x: StandardMaterial3D
var _mat_y: StandardMaterial3D
var _mat_z: StandardMaterial3D
var _mat_plane: StandardMaterial3D
var _mat_rot: StandardMaterial3D
var _mat_active: StandardMaterial3D

func _ready() -> void:
	_init_materials()
	_build_gizmo_handles()
	visible = false

	AppState.selection_changed.connect(_on_selection_changed)

func _init_materials() -> void:
	_mat_x = _create_unshaded_material(Color(0.95, 0.2, 0.2)) # Red
	_mat_y = _create_unshaded_material(Color(0.2, 0.9, 0.2)) # Green
	_mat_z = _create_unshaded_material(Color(0.25, 0.5, 0.98)) # Blue
	_mat_plane = _create_unshaded_material(Color(0.9, 0.9, 0.2, 0.4), true) # Yellow
	_mat_rot = _create_unshaded_material(Color(0.2, 0.85, 0.85)) # Cyan
	_mat_active = _create_unshaded_material(Color(1.0, 1.0, 0.3)) # Highlight

func _create_unshaded_material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10
	return mat

func _build_gizmo_handles() -> void:
	# X-Axis Arrow (Red)
	_build_axis_arrow(Vector3.RIGHT, _mat_x, AxisMode.AXIS_X)
	# Y-Axis Arrow (Green)
	_build_axis_arrow(Vector3.UP, _mat_y, AxisMode.AXIS_Y)
	# Z-Axis Arrow (Blue)
	_build_axis_arrow(Vector3.BACK, _mat_z, AxisMode.AXIS_Z)
	# XZ Plane Quad Handle (Yellow)
	_build_plane_handle()
	# Y-Rotation Ring (Cyan)
	_build_rotation_ring()

func _build_axis_arrow(dir: Vector3, mat: StandardMaterial3D, mode: AxisMode) -> void:
	var handle_node := Area3D.new()
	handle_node.name = "Handle_" + str(mode)
	handle_node.collision_layer = 4 # Gizmo layer
	handle_node.collision_mask = 0

	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 1.2
	cyl.material = mat
	stem.mesh = cyl

	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.001
	cone.bottom_radius = 0.06
	cone.height = 0.25
	cone.material = mat
	head.mesh = cone

	if dir == Vector3.RIGHT:
		stem.position = Vector3(0.6, 0, 0)
		stem.rotation = Vector3(0, 0, -PI * 0.5)
		head.position = Vector3(1.25, 0, 0)
		head.rotation = Vector3(0, 0, -PI * 0.5)
	elif dir == Vector3.UP:
		stem.position = Vector3(0, 0.6, 0)
		head.position = Vector3(0, 1.25, 0)
	elif dir == Vector3.BACK:
		stem.position = Vector3(0, 0, 0.6)
		stem.rotation = Vector3(PI * 0.5, 0, 0)
		head.position = Vector3(0, 0, 1.25)
		head.rotation = Vector3(PI * 0.5, 0, 0)

	handle_node.add_child(stem)
	handle_node.add_child(head)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 1.4) if dir == Vector3.BACK else (Vector3(1.4, 0.3, 0.3) if dir == Vector3.RIGHT else Vector3(0.3, 1.4, 0.3))
	col.shape = box
	col.position = dir * 0.7
	handle_node.add_child(col)

	handle_node.set_meta("axis_mode", mode)
	add_child(handle_node)

func _build_plane_handle() -> void:
	var handle_node := Area3D.new()
	handle_node.name = "Handle_PlaneXZ"
	handle_node.collision_layer = 4
	handle_node.collision_mask = 0

	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = _mat_plane
	mi.mesh = quad
	mi.position = Vector3(0.3, 0.01, 0.3)
	mi.rotation = Vector3(-PI * 0.5, 0, 0)
	handle_node.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.1, 0.4)
	col.shape = box
	col.position = Vector3(0.3, 0, 0.3)
	handle_node.add_child(col)

	handle_node.set_meta("axis_mode", AxisMode.PLANE_XZ)
	add_child(handle_node)

func _build_rotation_ring() -> void:
	var handle_node := Area3D.new()
	handle_node.name = "Handle_RotY"
	handle_node.collision_layer = 4
	handle_node.collision_mask = 0

	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.45
	torus.outer_radius = 1.55
	torus.material = _mat_rot
	mi.mesh = torus
	handle_node.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 0.2, 3.2)
	col.shape = box
	handle_node.add_child(col)

	handle_node.set_meta("axis_mode", AxisMode.ROT_Y)
	add_child(handle_node)

func _on_selection_changed(selected: Array) -> void:
	if selected.is_empty():
		visible = false
		target_objects.clear()
		return

	visible = true
	target_objects = selected.duplicate()
	_update_gizmo_position()

func toggle_pivot_mode() -> void:
	if pivot_mode == PivotDisplayMode.BASE_CENTER:
		pivot_mode = PivotDisplayMode.GEOMETRIC_CENTER
	else:
		pivot_mode = PivotDisplayMode.BASE_CENTER
	_update_gizmo_position()

func _update_gizmo_position() -> void:
	if target_objects.is_empty():
		return
	var center := Vector3.ZERO
	var valid_count := 0
	for obj in target_objects:
		if is_instance_valid(obj):
			var pos := obj.global_position
			if pivot_mode == PivotDisplayMode.GEOMETRIC_CENTER and obj is StageObject:
				pos += obj.global_basis * Vector3(0, (obj as StageObject).pivot_offset_y, 0)
			center += pos
			valid_count += 1

	if valid_count > 0:
		global_position = center / float(valid_count)

func start_drag(handle: AxisMode, mouse_pos: Vector2) -> void:
	active_handle = handle
	is_dragging = true
	drag_start_mouse = mouse_pos
	drag_start_gizmo_pos = global_position

	initial_transforms.clear()
	for obj in target_objects:
		if is_instance_valid(obj):
			initial_transforms.append(obj.global_transform)

func update_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if not is_dragging or target_objects.is_empty() or not camera:
		return

	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	if active_handle == AxisMode.ROT_Y:
		# Rotation around Y axis
		var ground_plane := Plane(Vector3.UP, drag_start_gizmo_pos.y)
		var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			var hit_vec: Vector3 = (hit as Vector3) - drag_start_gizmo_pos
			var angle := atan2(hit_vec.x, hit_vec.z)
			if AppState.snap_to_grid and not SnapSystem.is_snap_disabled_by_modifier():
				var step_rad := deg_to_rad(15.0)
				angle = roundf(angle / step_rad) * step_rad

			var rot_basis := Basis(Vector3.UP, angle)
			for i in range(target_objects.size()):
				if is_instance_valid(target_objects[i]):
					var init_t := initial_transforms[i]
					var rel_pos := init_t.origin - drag_start_gizmo_pos
					target_objects[i].global_position = drag_start_gizmo_pos + rot_basis * rel_pos
					target_objects[i].global_basis = rot_basis * init_t.basis
		return

	# Translation
	var new_center := drag_start_gizmo_pos

	if active_handle == AxisMode.PLANE_XZ:
		var ground_plane := Plane(Vector3.UP, drag_start_gizmo_pos.y)
		var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			new_center = hit as Vector3
	elif active_handle == AxisMode.AXIS_X:
		var cam_norm := camera.global_transform.basis.z
		var plane := Plane(Vector3(0, cam_norm.y, cam_norm.z).normalized(), drag_start_gizmo_pos)
		var hit: Variant = plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			new_center.x = (hit as Vector3).x
	elif active_handle == AxisMode.AXIS_Y:
		var cam_norm := camera.global_transform.basis.z
		var plane := Plane(Vector3(cam_norm.x, 0, cam_norm.z).normalized(), drag_start_gizmo_pos)
		var hit: Variant = plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			new_center.y = (hit as Vector3).y
	elif active_handle == AxisMode.AXIS_Z:
		var cam_norm := camera.global_transform.basis.z
		var plane := Plane(Vector3(cam_norm.x, cam_norm.y, 0).normalized(), drag_start_gizmo_pos)
		var hit: Variant = plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			new_center.z = (hit as Vector3).z

	# Snapping
	var moving_obj: StageObject = target_objects[0] as StageObject if (target_objects.size() == 1 and target_objects[0] is StageObject) else null
	var rot_basis := target_objects[0].global_basis if (target_objects.size() == 1) else Basis.IDENTITY
	var snap_res := SnapSystem.resolve_position(new_center, moving_obj, rot_basis)
	new_center = snap_res.position

	if target_objects.size() == 1:
		target_objects[0].global_position = new_center
	else:
		var delta_pos := new_center - drag_start_gizmo_pos
		for i in range(target_objects.size()):
			if is_instance_valid(target_objects[i]):
				target_objects[i].global_position = initial_transforms[i].origin + delta_pos

	global_position = new_center

func end_drag() -> void:
	if not is_dragging:
		return

	is_dragging = false
	active_handle = AxisMode.NONE

	var changed := false
	var final_transforms: Array[Transform3D] = []
	for i in range(target_objects.size()):
		var obj := target_objects[i]
		if is_instance_valid(obj):
			final_transforms.append(obj.global_transform)
			if not obj.global_transform.is_equal_approx(initial_transforms[i]):
				changed = true

	# Execute exactly ONE Undoable Transform Command on release if moved
	if changed:
		var cmd := BaseCommand.TransformCommand.new(target_objects, initial_transforms, final_transforms)
		CommandManager.execute_command(cmd)

	_update_gizmo_position()

