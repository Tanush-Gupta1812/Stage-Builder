class_name GizmoVisual
extends Node3D

const GizmoController = preload("res://scripts/viewport/gizmo/gizmo_controller.gd")
const GizmoMath = preload("res://scripts/viewport/gizmo/gizmo_math.gd")

## Renders visual 3D handles for the active tool.
## Constant on-screen size (~110px * UIScale) applied strictly to this visual node's scale,
## never affecting the mathematical controller's axes or positions.
## Drawn on top of the scene (no_depth_test = true, high render priority).

var controller: GizmoController = null
var current_world_size: float = 1.0

# Node handle groups
var _move_group: Node3D = null
var _rotate_group: Node3D = null
var _scale_group: Node3D = null

# Materials
var _mat_x: StandardMaterial3D
var _mat_y: StandardMaterial3D
var _mat_z: StandardMaterial3D
var _mat_plane: StandardMaterial3D
var _mat_scale_center: StandardMaterial3D
var _mat_hover: StandardMaterial3D

# Map HandleId -> Array[MeshInstance3D]
var _handle_meshes: Dictionary = {}
var _handle_areas: Dictionary = {}

func _ready() -> void:
	_init_materials()
	_build_visual_tree()

func _init_materials() -> void:
	_mat_x = _create_unshaded_material(Color(0.95, 0.22, 0.22)) # Red
	_mat_y = _create_unshaded_material(Color(0.22, 0.92, 0.22)) # Green
	_mat_z = _create_unshaded_material(Color(0.25, 0.52, 0.98)) # Blue
	_mat_plane = _create_unshaded_material(Color(0.95, 0.95, 0.3, 0.5), true) # Yellow translucent
	_mat_scale_center = _create_unshaded_material(Color(0.9, 0.9, 0.95))
	_mat_hover = _create_unshaded_material(Color(1.0, 1.0, 0.35)) # Bright yellow highlight

func _create_unshaded_material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 25
	return mat

func _build_visual_tree() -> void:
	_handle_meshes.clear()

	# --- 1. Move Group ---
	_move_group = Node3D.new()
	_move_group.name = "MoveGroup"
	add_child(_move_group)

	_build_arrow(_move_group, Vector3.RIGHT, _mat_x, GizmoController.HandleId.MOVE_X)
	_build_arrow(_move_group, Vector3.UP, _mat_y, GizmoController.HandleId.MOVE_Y)
	_build_arrow(_move_group, Vector3.BACK, _mat_z, GizmoController.HandleId.MOVE_Z)
	_build_xz_plane_square(_move_group)

	# --- 2. Rotate Group ---
	_rotate_group = Node3D.new()
	_rotate_group.name = "RotateGroup"
	add_child(_rotate_group)

	_build_ring(_rotate_group, Vector3.UP, _mat_y, GizmoController.HandleId.ROT_Y)
	_build_ring(_rotate_group, Vector3.RIGHT, _mat_x, GizmoController.HandleId.ROT_X)
	_build_ring(_rotate_group, Vector3.BACK, _mat_z, GizmoController.HandleId.ROT_Z)

	# --- 3. Scale Group ---
	_scale_group = Node3D.new()
	_scale_group.name = "ScaleGroup"
	add_child(_scale_group)

	_build_scale_handle(_scale_group, Vector3.RIGHT, _mat_x, GizmoController.HandleId.SCALE_X)
	_build_scale_handle(_scale_group, Vector3.UP, _mat_y, GizmoController.HandleId.SCALE_Y)
	_build_scale_handle(_scale_group, Vector3.BACK, _mat_z, GizmoController.HandleId.SCALE_Z)
	_build_uniform_scale_cube(_scale_group)

	update_tool_handles()

func _build_arrow(parent: Node3D, dir: Vector3, mat: StandardMaterial3D, id: GizmoController.HandleId) -> void:
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = 0.75
	cyl.material = mat
	stem.mesh = cyl

	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.05
	cone.height = 0.18
	cone.material = mat
	tip.mesh = cone

	if dir == Vector3.RIGHT:
		stem.transform.basis = Basis(Vector3.BACK, PI * 0.5)
		stem.position = Vector3(0.375, 0, 0)
		tip.transform.basis = Basis(Vector3.BACK, -PI * 0.5)
		tip.position = Vector3(0.84, 0, 0)
	elif dir == Vector3.UP:
		stem.position = Vector3(0, 0.375, 0)
		tip.position = Vector3(0, 0.84, 0)
	elif dir == Vector3.BACK:
		stem.transform.basis = Basis(Vector3.RIGHT, PI * 0.5)
		stem.position = Vector3(0, 0, 0.375)
		tip.transform.basis = Basis(Vector3.RIGHT, PI * 0.5)
		tip.position = Vector3(0, 0, 0.84)

	parent.add_child(stem)
	parent.add_child(tip)
	_handle_meshes[id] = [stem, tip]

func _build_xz_plane_square(parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.27, 0.27)
	quad.material = _mat_plane
	mi.mesh = quad
	mi.transform.basis = Basis(Vector3.RIGHT, PI * 0.5)
	mi.position = Vector3(0.315, 0, 0.315)
	parent.add_child(mi)
	_handle_meshes[GizmoController.HandleId.MOVE_XZ] = [mi]

func _build_ring(parent: Node3D, axis: Vector3, mat: StandardMaterial3D, id: GizmoController.HandleId) -> void:
	var area := Area3D.new()
	if id == GizmoController.HandleId.ROT_X: area.name = "Handle_RotX"
	elif id == GizmoController.HandleId.ROT_Y: area.name = "Handle_RotY"
	elif id == GizmoController.HandleId.ROT_Z: area.name = "Handle_RotZ"

	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.985
	torus.outer_radius = 1.015
	torus.rings = 64
	torus.ring_segments = 6
	torus.material = mat
	mi.mesh = torus

	if axis == Vector3.RIGHT:
		mi.transform.basis = Basis(Vector3.BACK, PI * 0.5)
	elif axis == Vector3.BACK:
		mi.transform.basis = Basis(Vector3.RIGHT, PI * 0.5)

	area.add_child(mi)
	parent.add_child(area)
	_handle_meshes[id] = [mi]
	_handle_areas[id] = area

func _build_scale_handle(parent: Node3D, dir: Vector3, mat: StandardMaterial3D, id: GizmoController.HandleId) -> void:
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.75
	cyl.material = mat
	stem.mesh = cyl

	var box := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.12, 0.12, 0.12)
	cube.material = mat
	box.mesh = cube

	if dir == Vector3.RIGHT:
		stem.transform.basis = Basis(Vector3.BACK, PI * 0.5)
		stem.position = Vector3(0.375, 0, 0)
		box.position = Vector3(0.85, 0, 0)
	elif dir == Vector3.UP:
		stem.position = Vector3(0, 0.375, 0)
		box.position = Vector3(0, 0.85, 0)
	elif dir == Vector3.BACK:
		stem.transform.basis = Basis(Vector3.RIGHT, PI * 0.5)
		stem.position = Vector3(0, 0, 0.375)
		box.position = Vector3(0, 0, 0.85)

	parent.add_child(stem)
	parent.add_child(box)
	_handle_meshes[id] = [stem, box]

func _build_uniform_scale_cube(parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.14, 0.14, 0.14)
	cube.material = _mat_scale_center
	mi.mesh = cube
	parent.add_child(mi)
	_handle_meshes[GizmoController.HandleId.SCALE_UNIFORM] = [mi]

func update_tool_handles() -> void:
	if not controller:
		return

	var tool_mode := controller.active_tool
	var is_move := (tool_mode == GizmoController.ToolMode.MOVE)
	var is_rotate := (tool_mode == GizmoController.ToolMode.ROTATE)
	var is_scale := (tool_mode == GizmoController.ToolMode.SCALE)

	if _move_group: _move_group.visible = is_move
	if _rotate_group: _rotate_group.visible = is_rotate
	if _scale_group: _scale_group.visible = is_scale

	if is_rotate and _rotate_group:
		var show_all := controller.show_all_rotation_axes
		if _handle_areas.has(GizmoController.HandleId.ROT_X):
			_handle_areas[GizmoController.HandleId.ROT_X].visible = show_all
		if _handle_areas.has(GizmoController.HandleId.ROT_Z):
			_handle_areas[GizmoController.HandleId.ROT_Z].visible = show_all
		for mesh_inst in _handle_meshes.get(GizmoController.HandleId.ROT_X, []):
			if is_instance_valid(mesh_inst): mesh_inst.visible = show_all
		for mesh_inst in _handle_meshes.get(GizmoController.HandleId.ROT_Z, []):
			if is_instance_valid(mesh_inst): mesh_inst.visible = show_all

	set_hovered_handle(controller.hovered_handle)

func set_hovered_handle(handle: GizmoController.HandleId) -> void:
	for id: GizmoController.HandleId in _handle_meshes:
		var is_hover: bool = (handle == id)
		var default_mat := _get_default_material_for_id(id)
		var mat_to_apply: StandardMaterial3D = _mat_hover if is_hover else default_mat
		for mi: MeshInstance3D in _handle_meshes[id]:
			if is_instance_valid(mi):
				mi.material_override = mat_to_apply

func _get_default_material_for_id(id: GizmoController.HandleId) -> StandardMaterial3D:
	match id:
		GizmoController.HandleId.MOVE_X, GizmoController.HandleId.ROT_X, GizmoController.HandleId.SCALE_X:
			return _mat_x
		GizmoController.HandleId.MOVE_Y, GizmoController.HandleId.ROT_Y, GizmoController.HandleId.SCALE_Y:
			return _mat_y
		GizmoController.HandleId.MOVE_Z, GizmoController.HandleId.ROT_Z, GizmoController.HandleId.SCALE_Z:
			return _mat_z
		GizmoController.HandleId.MOVE_XZ:
			return _mat_plane
		GizmoController.HandleId.SCALE_UNIFORM:
			return _mat_scale_center
	return _mat_x

func update_visual_scale(camera: Camera3D) -> float:
	if not is_instance_valid(camera):
		return 1.0

	var vp_height := float(camera.get_viewport().size.y)
	if vp_height <= 0.0:
		vp_height = 800.0

	var sf := 1.0
	var ui_scale_node := get_node_or_null("/root/UIScale")
	if ui_scale_node and "current_scale" in ui_scale_node:
		sf = ui_scale_node.current_scale
	elif ui_scale_node and "scale_factor" in ui_scale_node:
		sf = ui_scale_node.scale_factor
	var target_px := 110.0 * sf

	var world_size := 1.0
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		world_size = (camera.size / vp_height) * target_px
	else:
		var dist := camera.global_position.distance_to(global_position)
		var fov_rad := deg_to_rad(camera.fov)
		world_size = (2.0 * dist * tan(fov_rad * 0.5) / vp_height) * target_px

	world_size = maxf(0.01, world_size)
	current_world_size = world_size
	scale = Vector3.ONE * world_size
	return world_size
