class_name TransformGizmo
extends Node3D

## Interactive 3D Transform Gizmo for Stage-Builder.
## Supports separated Move (default), Rotate, and Scale tool modes with:
## - Constant on-screen size (~110px regardless of camera zoom)
## - Generous ~12px invisible hit areas
## - Zero collision overlap between Move, Rotate, and Scale handles
## - Hover highlighting and cursor styling
## - Single yaw ring by default in Rotate mode, expandable to all axes
## - World vs Local transform space support
## - Single-step undo/redo via TransformCommand and Escape-to-cancel

enum AxisMode {
	NONE,
	AXIS_X, AXIS_Y, AXIS_Z, PLANE_XZ,
	ROT_X, ROT_Y, ROT_Z,
	SCALE_X, SCALE_Y, SCALE_Z, SCALE_UNIFORM
}

enum PivotDisplayMode { BASE_CENTER, GEOMETRIC_CENTER }

var active_handle: AxisMode = AxisMode.NONE
var hovered_handle: AxisMode = AxisMode.NONE
var pivot_mode: PivotDisplayMode = PivotDisplayMode.BASE_CENTER
var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_gizmo_pos: Vector3 = Vector3.ZERO
var initial_transforms: Array[Transform3D] = []
var target_objects: Array[Node3D] = []

# Node Groups
var _move_group: Node3D = null
var _rotate_group: Node3D = null
var _scale_group: Node3D = null

# Materials
var _mat_x: StandardMaterial3D
var _mat_y: StandardMaterial3D
var _mat_z: StandardMaterial3D
var _mat_plane: StandardMaterial3D
var _mat_rot_x: StandardMaterial3D
var _mat_rot_y: StandardMaterial3D
var _mat_rot_z: StandardMaterial3D
var _mat_scale_center: StandardMaterial3D
var _mat_hover: StandardMaterial3D

var _handle_mesh_instances: Dictionary = {} # AxisMode -> Array[MeshInstance3D]
var _handle_areas: Dictionary = {} # AxisMode -> Area3D

func _ready() -> void:
	_init_materials()
	_build_groups_and_handles()
	visible = false

	AppState.selection_changed.connect(_on_selection_changed)
	AppState.tool_changed.connect(func(_t): _update_tool_visibility())
	AppState.transform_space_changed.connect(func(_l): _update_gizmo_orientation())
	AppState.show_all_rotation_axes_changed.connect(func(_s): _update_tool_visibility())

func _process(_delta: float) -> void:
	if not visible or target_objects.is_empty():
		return
	var vp := get_viewport()
	if not vp:
		return
	var cam := vp.get_camera_3d()
	if cam:
		_update_gizmo_scale(cam)

func _init_materials() -> void:
	_mat_x = _create_unshaded_material(Color(0.95, 0.22, 0.22)) # Red
	_mat_y = _create_unshaded_material(Color(0.22, 0.92, 0.22)) # Green
	_mat_z = _create_unshaded_material(Color(0.25, 0.52, 0.98)) # Blue
	_mat_plane = _create_unshaded_material(Color(0.95, 0.95, 0.3, 0.45), true) # Yellow translucent
	_mat_rot_x = _create_unshaded_material(Color(0.95, 0.25, 0.25))
	_mat_rot_y = _create_unshaded_material(Color(0.25, 0.95, 0.25))
	_mat_rot_z = _create_unshaded_material(Color(0.25, 0.5, 0.98))
	_mat_scale_center = _create_unshaded_material(Color(0.9, 0.9, 0.95))
	_mat_hover = _create_unshaded_material(Color(1.0, 1.0, 0.35))

func _create_unshaded_material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 20
	return mat

# --- Building Handles ---

func _build_groups_and_handles() -> void:
	_handle_mesh_instances.clear()
	_handle_areas.clear()

	# 1. Move Group
	_move_group = Node3D.new()
	_move_group.name = "MoveGroup"
	add_child(_move_group)

	_build_axis_arrow(_move_group, Vector3.RIGHT, _mat_x, AxisMode.AXIS_X)
	_build_axis_arrow(_move_group, Vector3.UP, _mat_y, AxisMode.AXIS_Y)
	_build_axis_arrow(_move_group, Vector3.BACK, _mat_z, AxisMode.AXIS_Z)
	_build_plane_handle(_move_group)

	# 2. Rotate Group
	_rotate_group = Node3D.new()
	_rotate_group.name = "RotateGroup"
	add_child(_rotate_group)

	_build_rotation_ring(_rotate_group, Vector3.UP, _mat_rot_y, AxisMode.ROT_Y, "Handle_RotY")
	_build_rotation_ring(_rotate_group, Vector3.RIGHT, _mat_rot_x, AxisMode.ROT_X, "Handle_RotX")
	_build_rotation_ring(_rotate_group, Vector3.BACK, _mat_rot_z, AxisMode.ROT_Z, "Handle_RotZ")

	# 3. Scale Group
	_scale_group = Node3D.new()
	_scale_group.name = "ScaleGroup"
	add_child(_scale_group)

	_build_scale_handle(_scale_group, Vector3.RIGHT, _mat_x, AxisMode.SCALE_X)
	_build_scale_handle(_scale_group, Vector3.UP, _mat_y, AxisMode.SCALE_Y)
	_build_scale_handle(_scale_group, Vector3.BACK, _mat_z, AxisMode.SCALE_Z)
	_build_scale_uniform_handle(_scale_group)

	_update_tool_visibility()

func _build_axis_arrow(parent: Node3D, dir: Vector3, mat: StandardMaterial3D, mode: AxisMode) -> void:
	var handle_node := Area3D.new()
	handle_node.name = "Handle_" + str(mode)
	handle_node.collision_layer = 4
	handle_node.collision_mask = 0

	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = 0.75
	cyl.material = mat
	stem.mesh = cyl

	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.001
	cone.bottom_radius = 0.05
	cone.height = 0.22
	cone.material = mat
	head.mesh = cone

	if dir == Vector3.RIGHT:
		stem.position = Vector3(0.40, 0, 0)
		stem.rotation = Vector3(0, 0, -PI * 0.5)
		head.position = Vector3(0.88, 0, 0)
		head.rotation = Vector3(0, 0, -PI * 0.5)
	elif dir == Vector3.UP:
		stem.position = Vector3(0, 0.40, 0)
		head.position = Vector3(0, 0.88, 0)
	elif dir == Vector3.BACK:
		stem.position = Vector3(0, 0, 0.40)
		stem.rotation = Vector3(PI * 0.5, 0, 0)
		head.position = Vector3(0, 0, 0.88)
		head.rotation = Vector3(PI * 0.5, 0, 0)

	handle_node.add_child(stem)
	handle_node.add_child(head)

	# Invisible generous hit area (~12px on screen)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if dir == Vector3.RIGHT:
		box.size = Vector3(1.0, 0.22, 0.22)
	elif dir == Vector3.UP:
		box.size = Vector3(0.22, 1.0, 0.22)
	else:
		box.size = Vector3(0.22, 0.22, 1.0)
	col.shape = box
	col.position = dir * 0.5
	handle_node.add_child(col)

	handle_node.set_meta("axis_mode", mode)
	parent.add_child(handle_node)

	_handle_areas[mode] = handle_node
	_handle_mesh_instances[mode] = [stem, head]

func _build_plane_handle(parent: Node3D) -> void:
	var handle_node := Area3D.new()
	handle_node.name = "Handle_PlaneXZ"
	handle_node.collision_layer = 4
	handle_node.collision_mask = 0

	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.26, 0.26)
	quad.material = _mat_plane
	mi.mesh = quad
	mi.position = Vector3(0.22, 0.01, 0.22)
	mi.rotation = Vector3(-PI * 0.5, 0, 0)
	handle_node.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.32, 0.08, 0.32)
	col.shape = box
	col.position = Vector3(0.22, 0, 0.22)
	handle_node.add_child(col)

	handle_node.set_meta("axis_mode", AxisMode.PLANE_XZ)
	parent.add_child(handle_node)

	_handle_areas[AxisMode.PLANE_XZ] = handle_node
	_handle_mesh_instances[AxisMode.PLANE_XZ] = [mi]

func _build_rotation_ring(parent: Node3D, normal: Vector3, mat: StandardMaterial3D, mode: AxisMode, handle_name: String) -> void:
	var handle_node := Area3D.new()
	handle_node.name = handle_name
	handle_node.collision_layer = 4
	handle_node.collision_mask = 0

	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 0.92
	torus.material = mat
	mi.mesh = torus

	if normal == Vector3.RIGHT:
		mi.rotation = Vector3(0, 0, PI * 0.5)
	elif normal == Vector3.BACK:
		mi.rotation = Vector3(PI * 0.5, 0, 0)
	handle_node.add_child(mi)

	# Segmented 8-box collider ring: generous hit area without blocking center
	var ring_radius := 0.90
	for i in range(8):
		var theta := i * (PI * 0.25)
		var c_col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.72, 0.18, 0.18)
		c_col.shape = box

		var pos_circle := Vector3(cos(theta) * ring_radius, 0, sin(theta) * ring_radius)
		var tangent_rot := -theta

		if normal == Vector3.UP:
			c_col.position = pos_circle
			c_col.rotation = Vector3(0, tangent_rot, 0)
		elif normal == Vector3.RIGHT:
			c_col.position = Vector3(0, cos(theta) * ring_radius, sin(theta) * ring_radius)
			c_col.rotation = Vector3(tangent_rot, 0, PI * 0.5)
		elif normal == Vector3.BACK:
			c_col.position = Vector3(cos(theta) * ring_radius, sin(theta) * ring_radius, 0)
			c_col.rotation = Vector3(0, 0, tangent_rot)

		handle_node.add_child(c_col)

	handle_node.set_meta("axis_mode", mode)
	parent.add_child(handle_node)

	_handle_areas[mode] = handle_node
	_handle_mesh_instances[mode] = [mi]

func _build_scale_handle(parent: Node3D, dir: Vector3, mat: StandardMaterial3D, mode: AxisMode) -> void:
	var handle_node := Area3D.new()
	handle_node.name = "Handle_" + str(mode)
	handle_node.collision_layer = 4
	handle_node.collision_mask = 0

	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.75
	cyl.material = mat
	stem.mesh = cyl

	var tip_box := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.1, 0.1, 0.1)
	cube.material = mat
	tip_box.mesh = cube

	if dir == Vector3.RIGHT:
		stem.position = Vector3(0.40, 0, 0)
		stem.rotation = Vector3(0, 0, -PI * 0.5)
		tip_box.position = Vector3(0.85, 0, 0)
	elif dir == Vector3.UP:
		stem.position = Vector3(0, 0.40, 0)
		tip_box.position = Vector3(0, 0.85, 0)
	elif dir == Vector3.BACK:
		stem.position = Vector3(0, 0, 0.40)
		stem.rotation = Vector3(PI * 0.5, 0, 0)
		tip_box.position = Vector3(0, 0, 0.85)

	handle_node.add_child(stem)
	handle_node.add_child(tip_box)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.24, 0.24, 0.24)
	col.shape = box
	col.position = dir * 0.85
	handle_node.add_child(col)

	handle_node.set_meta("axis_mode", mode)
	parent.add_child(handle_node)

	_handle_areas[mode] = handle_node
	_handle_mesh_instances[mode] = [stem, tip_box]

func _build_scale_uniform_handle(parent: Node3D) -> void:
	var handle_node := Area3D.new()
	handle_node.name = "Handle_ScaleUniform"
	handle_node.collision_layer = 4
	handle_node.collision_mask = 0

	var mi := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.12, 0.12, 0.12)
	cube.material = _mat_scale_center
	mi.mesh = cube
	handle_node.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.24, 0.24, 0.24)
	col.shape = box
	handle_node.add_child(col)

	handle_node.set_meta("axis_mode", AxisMode.SCALE_UNIFORM)
	parent.add_child(handle_node)

	_handle_areas[AxisMode.SCALE_UNIFORM] = handle_node
	_handle_mesh_instances[AxisMode.SCALE_UNIFORM] = [mi]

# --- Dynamic Tool Visibility & Collision ---

func _update_tool_visibility() -> void:
	if not _move_group or not _rotate_group or not _scale_group:
		return

	var tool_mode: AppState.ToolMode = AppState.current_tool

	# Move handles
	var is_move := (tool_mode == AppState.ToolMode.MOVE or tool_mode == AppState.ToolMode.SELECT)
	_move_group.visible = is_move
	_set_group_collision(_move_group, is_move)

	# Rotate handles
	var is_rotate := (tool_mode == AppState.ToolMode.ROTATE)
	_rotate_group.visible = is_rotate
	_set_group_collision(_rotate_group, is_rotate)

	if is_rotate:
		var show_all: bool = AppState.show_all_rotation_axes
		if _handle_areas.has(AxisMode.ROT_X):
			_handle_areas[AxisMode.ROT_X].visible = show_all
			_set_area_collision(_handle_areas[AxisMode.ROT_X], show_all)
		if _handle_areas.has(AxisMode.ROT_Z):
			_handle_areas[AxisMode.ROT_Z].visible = show_all
			_set_area_collision(_handle_areas[AxisMode.ROT_Z], show_all)

	# Scale handles
	var is_scale := (tool_mode == AppState.ToolMode.SCALE)
	_scale_group.visible = is_scale
	_set_group_collision(_scale_group, is_scale)

func _set_group_collision(group: Node, enabled: bool) -> void:
	for child in group.get_children():
		if child is Area3D:
			_set_area_collision(child, enabled)

func _set_area_collision(area: Area3D, enabled: bool) -> void:
	area.monitoring = enabled
	area.monitorable = enabled
	for c in area.get_children():
		if c is CollisionShape3D:
			c.disabled = not enabled

# --- Highlight and Hover Feedback ---

func set_hovered_handle(handle: AxisMode) -> void:
	if hovered_handle == handle:
		return
	hovered_handle = handle
	_refresh_handle_materials()

func _refresh_handle_materials() -> void:
	for mode: AxisMode in _handle_mesh_instances:
		var is_hover: bool = (hovered_handle == mode or active_handle == mode)
		var target_mat: StandardMaterial3D = _mat_hover if is_hover else _get_default_material_for_mode(mode)
		for mi: MeshInstance3D in _handle_mesh_instances[mode]:
			if is_instance_valid(mi):
				mi.material_override = target_mat

func _get_default_material_for_mode(mode: AxisMode) -> StandardMaterial3D:
	match mode:
		AxisMode.AXIS_X, AxisMode.SCALE_X: return _mat_x
		AxisMode.AXIS_Y, AxisMode.SCALE_Y: return _mat_y
		AxisMode.AXIS_Z, AxisMode.SCALE_Z: return _mat_z
		AxisMode.PLANE_XZ: return _mat_plane
		AxisMode.ROT_X: return _mat_rot_x
		AxisMode.ROT_Y: return _mat_rot_y
		AxisMode.ROT_Z: return _mat_rot_z
		AxisMode.SCALE_UNIFORM: return _mat_scale_center
	return _mat_x

# --- Constant On-Screen Sizing (~110px) ---

func _update_gizmo_scale(camera: Camera3D) -> void:
	if not is_instance_valid(camera):
		return
	var vp_height := float(camera.get_viewport().size.y)
	if vp_height <= 0.0:
		vp_height = 800.0

	var scale_multiplier := 1.0
	var ui_scale_node := get_node_or_null("/root/UIScale")
	if ui_scale_node and "current_scale" in ui_scale_node:
		scale_multiplier = ui_scale_node.current_scale
	elif ui_scale_node and "scale_factor" in ui_scale_node:
		scale_multiplier = ui_scale_node.scale_factor
	var target_px := 110.0 * scale_multiplier

	var world_size := 1.0
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		world_size = (camera.size / vp_height) * target_px
	else:
		var dist := camera.global_position.distance_to(global_position)
		var fov_rad := deg_to_rad(camera.fov)
		world_size = (2.0 * dist * tan(fov_rad * 0.5) / vp_height) * target_px

	scale = Vector3.ONE * maxf(0.01, world_size)

# --- Selection & Orientation ---

func _on_selection_changed(selected: Array) -> void:
	if selected.is_empty():
		visible = false
		target_objects.clear()
		return

	visible = (AppState.current_tool != AppState.ToolMode.PLACE)
	target_objects = selected.duplicate()
	_update_gizmo_position()
	_update_gizmo_orientation()
	_update_tool_visibility()

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

func _update_gizmo_orientation() -> void:
	if AppState.is_local_transform_space and target_objects.size() > 0 and is_instance_valid(target_objects[0]):
		global_basis = target_objects[0].global_basis.orthonormalized()
	else:
		global_basis = Basis.IDENTITY

# --- Interaction Drag Cycle ---

func start_drag(handle: AxisMode, mouse_pos: Vector2) -> void:
	active_handle = handle
	is_dragging = true
	drag_start_mouse = mouse_pos
	drag_start_gizmo_pos = global_position
	_refresh_handle_materials()

	initial_transforms.clear()
	for obj in target_objects:
		if is_instance_valid(obj):
			initial_transforms.append(obj.global_transform)

func update_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if not is_dragging or target_objects.is_empty() or not camera:
		return

	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	# 1. Rotation Handles
	if active_handle == AxisMode.ROT_Y or active_handle == AxisMode.ROT_X or active_handle == AxisMode.ROT_Z:
		var rot_axis := Vector3.UP
		var rot_plane_norm := Vector3.UP
		if active_handle == AxisMode.ROT_X:
			rot_axis = global_basis.x
			rot_plane_norm = global_basis.x
		elif active_handle == AxisMode.ROT_Z:
			rot_axis = global_basis.z
			rot_plane_norm = global_basis.z
		else:
			rot_axis = global_basis.y
			rot_plane_norm = global_basis.y

		var plane := Plane(rot_plane_norm, drag_start_gizmo_pos)
		var hit: Variant = plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			var hit_vec: Vector3 = (hit as Vector3) - drag_start_gizmo_pos
			var angle := 0.0
			if active_handle == AxisMode.ROT_Y:
				angle = atan2(hit_vec.x, hit_vec.z)
			elif active_handle == AxisMode.ROT_X:
				angle = atan2(hit_vec.y, hit_vec.z)
			elif active_handle == AxisMode.ROT_Z:
				angle = atan2(hit_vec.y, hit_vec.x)

			# Snap to rotation_step
			var step_deg := AppState.rotation_step
			if Input.is_key_pressed(KEY_CTRL) or (OS.get_name() == "macOS" and Input.is_key_pressed(KEY_META)):
				step_deg = 5.0 # Fine rotation
			var step_rad := deg_to_rad(step_deg)
			angle = roundf(angle / step_rad) * step_rad

			var live_deg := int(roundf(rad_to_deg(angle)))
			var axis_name := "Yaw (Y)" if active_handle == AxisMode.ROT_Y else ("Pitch (X)" if active_handle == AxisMode.ROT_X else "Roll (Z)")
			AppState.status_message.emit("Rotating %s: %d° (Step: %d°)" % [axis_name, live_deg, int(step_deg)])

			var rot_basis := Basis(rot_axis, angle)
			for i in range(target_objects.size()):
				if is_instance_valid(target_objects[i]):
					var init_t := initial_transforms[i]
					var rel_pos := init_t.origin - drag_start_gizmo_pos
					target_objects[i].global_position = drag_start_gizmo_pos + rot_basis * rel_pos
					target_objects[i].global_basis = rot_basis * init_t.basis

					if AppState.auto_rest_on_rotate and target_objects[i] is StageObject:
						var s_obj := target_objects[i] as StageObject
						var min_offset: float = StageViewport.get_lowest_point_y_offset(s_obj, target_objects[i].global_basis)
						if target_objects[i].global_position.y + min_offset < 0.0:
							target_objects[i].global_position.y = -min_offset
		return

	# 2. Scale Handles
	if active_handle == AxisMode.SCALE_X or active_handle == AxisMode.SCALE_Y or active_handle == AxisMode.SCALE_Z or active_handle == AxisMode.SCALE_UNIFORM:
		var mouse_delta := mouse_pos - drag_start_mouse
		var factor := 1.0 + (-mouse_delta.y + mouse_delta.x) * 0.005
		factor = maxf(0.1, factor)
		factor = roundf(factor * 10.0) / 10.0 # Snap 0.1 step
		for i in range(target_objects.size()):
			if is_instance_valid(target_objects[i]):
				var init_t := initial_transforms[i]
				var s_vec := Vector3.ONE * factor
				if active_handle == AxisMode.SCALE_X: s_vec = Vector3(factor, 1, 1)
				elif active_handle == AxisMode.SCALE_Y: s_vec = Vector3(1, factor, 1)
				elif active_handle == AxisMode.SCALE_Z: s_vec = Vector3(1, 1, factor)
				target_objects[i].scale = init_t.basis.get_scale() * s_vec
		AppState.status_message.emit("Scaling: %.1fx" % factor)
		return

	# 3. Translation Handles
	var new_center := drag_start_gizmo_pos

	if active_handle == AxisMode.PLANE_XZ:
		var plane_normal := global_basis.y if AppState.is_local_transform_space else Vector3.UP
		var ground_plane := Plane(plane_normal, drag_start_gizmo_pos)
		var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			var hit_pos: Vector3 = hit as Vector3
			if AppState.is_local_transform_space:
				var local_delta := global_basis.inverse() * (hit_pos - drag_start_gizmo_pos)
				if AppState.snap_to_grid and not SnapSystem.is_snap_disabled_by_modifier():
					local_delta.x = roundf(local_delta.x / AppState.grid_step) * AppState.grid_step
					local_delta.z = roundf(local_delta.z / AppState.grid_step) * AppState.grid_step
				new_center = drag_start_gizmo_pos + (global_basis * Vector3(local_delta.x, 0, local_delta.z))
			else:
				var moving_obj: StageObject = target_objects[0] as StageObject if (target_objects.size() == 1 and target_objects[0] is StageObject) else null
				var rot_basis := target_objects[0].global_basis if (target_objects.size() == 1) else Basis.IDENTITY
				var snap_res := SnapSystem.resolve_position(hit_pos, moving_obj, rot_basis)
				new_center = snap_res.position
	elif active_handle == AxisMode.AXIS_X or active_handle == AxisMode.AXIS_Y or active_handle == AxisMode.AXIS_Z:
		var axis_dir := Vector3.RIGHT
		if active_handle == AxisMode.AXIS_X:
			axis_dir = global_basis.x if AppState.is_local_transform_space else Vector3.RIGHT
		elif active_handle == AxisMode.AXIS_Y:
			axis_dir = global_basis.y if AppState.is_local_transform_space else Vector3.UP
		elif active_handle == AxisMode.AXIS_Z:
			axis_dir = global_basis.z if AppState.is_local_transform_space else Vector3.BACK

		var cam_forward := -camera.global_transform.basis.z
		var plane_normal := (axis_dir.cross(cam_forward)).cross(axis_dir).normalized()
		if plane_normal.length_squared() < 0.001:
			plane_normal = (axis_dir.cross(camera.global_transform.basis.y)).cross(axis_dir).normalized()

		var plane := Plane(plane_normal, drag_start_gizmo_pos)
		var hit: Variant = plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			var offset: float = ((hit as Vector3) - drag_start_gizmo_pos).dot(axis_dir)
			if AppState.snap_to_grid and not SnapSystem.is_snap_disabled_by_modifier():
				offset = roundf(offset / AppState.grid_step) * AppState.grid_step
			new_center = drag_start_gizmo_pos + axis_dir * offset
			if active_handle == AxisMode.AXIS_Y and not AppState.is_local_transform_space:
				new_center.y = maxf(0.0, new_center.y)

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
	_refresh_handle_materials()

	var changed := false
	var final_transforms: Array[Transform3D] = []
	for i in range(target_objects.size()):
		var obj := target_objects[i]
		if is_instance_valid(obj):
			final_transforms.append(obj.global_transform)
			if not obj.global_transform.is_equal_approx(initial_transforms[i]):
				changed = true

	if changed:
		var cmd := BaseCommand.TransformCommand.new(target_objects, initial_transforms, final_transforms)
		CommandManager.execute_command(cmd)

	_update_gizmo_position()

func cancel_drag() -> void:
	if not is_dragging:
		return

	is_dragging = false
	active_handle = AxisMode.NONE
	_refresh_handle_materials()

	for i in range(target_objects.size()):
		if is_instance_valid(target_objects[i]) and i < initial_transforms.size():
			target_objects[i].global_transform = initial_transforms[i]

	_update_gizmo_position()
	AppState.status_message.emit("Transform cancelled")
