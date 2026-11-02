class_name StageObject
extends Node3D

## A placed piece of production equipment in the 3D scene.
## Contains catalog metadata, collision area for raycasting, snap points, variants, and selection visualization.

signal selection_toggled(is_selected: bool)
signal variant_changed(variant_id: String)

@export var catalog_id: String = ""
@export var instance_id: String = ""
@export var asset_name: String = ""
@export var category: String = ""
@export var subcategory: String = ""
@export var dimensions: Vector3 = Vector3.ONE
@export var weight_kg: float = 0.0
@export var custom_notes: String = ""
@export var group_id: String = ""
@export var current_variant: String = ""

var available_variants: Array = []
var snap_points: Array = []
var raw_catalog_data: Dictionary = {}
var is_selected: bool = false:
	set(val):
		if is_selected != val:
			is_selected = val
			_update_selection_highlight()
			selection_toggled.emit(is_selected)

var content_pivot: Node3D = null
var visual_node: Node3D = null
var collision_area: Area3D = null
var highlight_mesh: MeshInstance3D = null
var pivot_offset_y: float = 0.0

func setup_from_catalog(data: Dictionary, initial_variant: String = "") -> void:
	raw_catalog_data = data
	catalog_id = data.get("id", "")
	asset_name = data.get("name", "Unnamed Asset")
	category = data.get("category", "General")
	subcategory = data.get("subcategory", "General")
	weight_kg = float(data.get("weight_kg", 0.0))

	var dims: Dictionary = data.get("dimensions", {})
	dimensions = Vector3(
		float(dims.get("x", 1.0)),
		float(dims.get("y", 1.0)),
		float(dims.get("z", 1.0))
	)

	# Central Pivot Convention: Base Center (bottom sits at y = 0)
	pivot_offset_y = dimensions.y * 0.5
	if data.has("pivot_offset_y"):
		pivot_offset_y = float(data["pivot_offset_y"])

	snap_points = data.get("snap_points", []).duplicate(true)
	# Shift snap points in Y by pivot_offset_y so snapping lines up with the bottom origin
	for sp in snap_points:
		if sp.has("pos") and sp["pos"] is Array and sp["pos"].size() == 3:
			sp["pos"][1] = float(sp["pos"][1]) + pivot_offset_y

	available_variants = data.get("variants", []).duplicate(true)

	if initial_variant != "":
		current_variant = initial_variant
	elif not available_variants.is_empty():
		current_variant = available_variants[0].get("id", "")

	if instance_id == "":
		instance_id = "obj_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 10000)

	_ensure_content_pivot()
	_build_visuals()
	_build_collision()
	_build_highlight()

func _ensure_content_pivot() -> void:
	if content_pivot == null:
		content_pivot = Node3D.new()
		content_pivot.name = "ContentPivot"
		add_child(content_pivot)
	content_pivot.position = Vector3(0, pivot_offset_y, 0)

func apply_variant(variant_id: String) -> void:
	if current_variant == variant_id and visual_node != null:
		return

	current_variant = variant_id
	_build_visuals()
	variant_changed.emit(current_variant)
	AppState.project_modified.emit()

func _get_variant_material_id() -> String:
	for v in available_variants:
		if v.get("id", "") == current_variant:
			return v.get("material", "")
	return ""

func _build_visuals() -> void:
	if visual_node:
		visual_node.queue_free()

	_ensure_content_pivot()
	var generator_id: String = raw_catalog_data.get("mesh_generator", "")
	var model_path: String = raw_catalog_data.get("model_path", "")
	var var_mat := _get_variant_material_id()

	if model_path != "":
		# Check internal res:// or user:// imported models
		if ResourceLoader.exists(model_path) or FileAccess.file_exists(model_path):
			var res = load(model_path)
			if res is PackedScene:
				visual_node = res.instantiate()
				content_pivot.add_child(visual_node)
				return

	if generator_id != "":
		visual_node = MeshGenerators.create_mesh(generator_id, raw_catalog_data.get("dimensions", {}), var_mat)
	else:
		visual_node = MeshGenerators.create_mesh("", raw_catalog_data.get("dimensions", {}), var_mat)

	content_pivot.add_child(visual_node)

func _build_collision() -> void:
	if collision_area:
		collision_area.queue_free()

	_ensure_content_pivot()
	collision_area = Area3D.new()
	collision_area.name = "CollisionArea"
	collision_area.collision_layer = 1
	collision_area.collision_mask = 0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	collision_area.add_child(shape)
	content_pivot.add_child(collision_area)

func _build_highlight() -> void:
	if highlight_mesh:
		highlight_mesh.queue_free()

	_ensure_content_pivot()
	highlight_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions + Vector3(0.04, 0.04, 0.04)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.6, 1.0, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.material = mat

	highlight_mesh.mesh = box
	highlight_mesh.position = Vector3(0, 0.02, 0)
	highlight_mesh.visible = false
	content_pivot.add_child(highlight_mesh)

func get_local_aabb() -> AABB:
	return AABB(
		Vector3(-dimensions.x * 0.5, 0.0, -dimensions.z * 0.5),
		dimensions
	)

func get_world_aabb() -> AABB:
	return global_transform * get_local_aabb()

func _update_selection_highlight() -> void:
	if highlight_mesh:
		highlight_mesh.visible = is_selected

func get_global_snap_points() -> Array:
	var result: Array = []
	for sp in snap_points:
		var local_pos_arr: Array = sp.get("pos", [0, 0, 0])
		var local_norm_arr: Array = sp.get("normal", [0, 1, 0])
		var local_pos := Vector3(local_pos_arr[0], local_pos_arr[1], local_pos_arr[2])
		var local_norm := Vector3(local_norm_arr[0], local_norm_arr[1], local_norm_arr[2])

		result.append({
			"global_pos": global_transform * local_pos,
			"global_normal": (global_transform.basis * local_norm).normalized(),
			"tag": sp.get("tag", ""),
			"owner": self
		})
	return result

func serialize() -> Dictionary:
	return {
		"catalog_id": catalog_id,
		"instance_id": instance_id,
		"name": asset_name,
		"category": category,
		"subcategory": subcategory,
		"variant": current_variant,
		"dimensions": { "x": dimensions.x, "y": dimensions.y, "z": dimensions.z },
		"weight_kg": weight_kg,
		"custom_notes": custom_notes,
		"group_id": group_id,
		"transform": {
			"basis": [
				[global_transform.basis.x.x, global_transform.basis.x.y, global_transform.basis.x.z],
				[global_transform.basis.y.x, global_transform.basis.y.y, global_transform.basis.y.z],
				[global_transform.basis.z.x, global_transform.basis.z.y, global_transform.basis.z.z]
			],
			"origin": [global_transform.origin.x, global_transform.origin.y, global_transform.origin.z]
		}
	}
