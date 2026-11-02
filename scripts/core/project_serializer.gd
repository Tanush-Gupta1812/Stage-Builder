class_name ProjectSerializer
extends RefCounted

const StageGroup = preload("res://scripts/core/stage_group.gd")

## Serializes and deserializes Stage-Builder projects to/from .stagebuilder JSON files.
## Supports autosave, recent files history, and full stage state persistence.

const RECENT_FILES_PATH = "user://recent_projects.json"
const AUTOSAVE_PATH = "user://autosave.stagebuilder"
const MAX_RECENT_FILES = 8

static func save_project(path: String, camera_node: Camera3D = null) -> bool:
	if AppState.stage_container == null:
		push_error("Cannot save: stage container is null.")
		return false

	var data := {
		"version": "2.1.0",
		"project_name": AppState.project_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"ground": AppState.current_ground,
		"camera": {},
		"objects": []
	}

	if camera_node:
		data["camera"] = {
			"position": [camera_node.global_position.x, camera_node.global_position.y, camera_node.global_position.z],
			"rotation": [camera_node.rotation.x, camera_node.rotation.y, camera_node.rotation.z]
		}

	var objs: Array = []
	for child in AppState.stage_container.get_children():
		if child is StageObject:
			objs.append(child.serialize())
		elif child is StageGroup:
			objs.append(child.serialize())
	data["objects"] = objs

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: " + path)
		return false

	file.store_string(JSON.stringify(data, "  "))
	AppState.current_project_path = path
	AppState.is_modified = false
	AppState.project_saved.emit(path)

	add_recent_file(path)
	print("Project saved to: %s with %d top-level items." % [path, objs.size()])
	return true

static func load_project(path: String, camera_node: Camera3D = null) -> bool:
	if AppState.stage_container == null:
		push_error("Cannot load: stage container is null.")
		return false

	if not FileAccess.file_exists(path):
		push_error("File does not exist: " + path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	var json := JSON.new()
	if json.parse(content) != OK:
		push_error("Invalid .stagebuilder file: " + json.get_error_message())
		return false

	var data: Dictionary = json.data

	# Clear current scene
	AppState.clear_selection()
	for child in AppState.stage_container.get_children():
		if child is StageObject or child is StageGroup:
			AppState.stage_container.remove_child(child)
			child.queue_free()

	CommandManager.clear()

	# Restore project settings
	AppState.project_name = data.get("project_name", "Stage Project")
	AppState.current_ground = data.get("ground", "concrete")

	# Restore camera
	var cam_data: Dictionary = data.get("camera", {})
	if camera_node and not cam_data.is_empty():
		var pos_arr: Array = cam_data.get("position", [0, 8, 12])
		camera_node.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		var rot_arr: Array = cam_data.get("rotation", [-0.5, 0, 0])
		camera_node.rotation = Vector3(rot_arr[0], rot_arr[1], rot_arr[2])

	var file_version: String = str(data.get("version", "1.0.0"))
	var is_legacy := _is_legacy_version(file_version)

	# Reconstruct stage items (objects and nested groups)
	var objects_data: Array = data.get("objects", [])
	for item_dict in objects_data:
		_deserialize_item(item_dict, AppState.stage_container, is_legacy)

	AppState.current_project_path = path
	AppState.is_modified = false
	AppState.project_loaded.emit(path)

	add_recent_file(path)
	print("Project loaded: %s (%d top-level items restored)" % [path, objects_data.size()])
	return true

static func _is_legacy_version(ver: String) -> bool:
	var parts := ver.split(".")
	if parts.size() >= 2:
		var major := parts[0].to_int()
		var minor := parts[1].to_int()
		if major < 2:
			return true
		if major == 2 and minor < 1:
			return true
		return false
	return true

static func _deserialize_item(item_dict: Dictionary, parent_node: Node, is_legacy: bool = false) -> Node3D:
	if item_dict.get("type", "") == "group":
		var grp := StageGroup.new()
		grp.group_id = item_dict.get("group_id", "")
		grp.group_name = item_dict.get("group_name", "Group")
		parent_node.add_child(grp)

		var t_val = item_dict.get("transform", null)
		if t_val is Dictionary:
			var basis_arr: Array = t_val.get("basis", [[1,0,0],[0,1,0],[0,0,1]])
			var orig_arr: Array = t_val.get("origin", [0,0,0])
			var basis := Basis(
				Vector3(basis_arr[0][0], basis_arr[0][1], basis_arr[0][2]),
				Vector3(basis_arr[1][0], basis_arr[1][1], basis_arr[1][2]),
				Vector3(basis_arr[2][0], basis_arr[2][1], basis_arr[2][2])
			)
			grp.global_transform = Transform3D(basis, Vector3(orig_arr[0], orig_arr[1], orig_arr[2]))

		var children_data: Array = item_dict.get("children", [])
		for ch_dict in children_data:
			_deserialize_item(ch_dict, grp, is_legacy)
		return grp

	# Single StageObject (or legacy item)
	var cat_id: String = item_dict.get("catalog_id", "")
	if cat_id == "":
		cat_id = item_dict.get("asset_id", "")

	var stage_obj := CatalogManager.instantiate_asset(cat_id)
	if stage_obj:
		stage_obj.instance_id = item_dict.get("instance_id", "")
		stage_obj.asset_name = item_dict.get("name", stage_obj.asset_name)
		stage_obj.custom_notes = item_dict.get("custom_notes", "")
		stage_obj.group_id = item_dict.get("group_id", "")

		if item_dict.has("variant") and str(item_dict["variant"]) != "":
			stage_obj.apply_variant(str(item_dict["variant"]))

		var t_val = item_dict.get("transform", null)
		if t_val is Dictionary:
			var basis_arr: Array = t_val.get("basis", [[1,0,0],[0,1,0],[0,0,1]])
			var orig_arr: Array = t_val.get("origin", [0,0,0])
			var basis := Basis(
				Vector3(basis_arr[0][0], basis_arr[0][1], basis_arr[0][2]),
				Vector3(basis_arr[1][0], basis_arr[1][1], basis_arr[1][2]),
				Vector3(basis_arr[2][0], basis_arr[2][1], basis_arr[2][2])
			)
			var origin := Vector3(orig_arr[0], orig_arr[1], orig_arr[2])
			if is_legacy:
				origin -= basis * Vector3(0, stage_obj.pivot_offset_y, 0)
				if origin.y < 0.0 and origin.y >= -stage_obj.pivot_offset_y - 0.05:
					origin.y = 0.0
			stage_obj.global_transform = Transform3D(basis, origin)
		elif t_val is Array and t_val.size() == 12:
			var basis := Basis(
				Vector3(t_val[0], t_val[1], t_val[2]),
				Vector3(t_val[3], t_val[4], t_val[5]),
				Vector3(t_val[6], t_val[7], t_val[8])
			)
			var origin := Vector3(t_val[9], t_val[10], t_val[11])
			if is_legacy:
				origin -= basis * Vector3(0, stage_obj.pivot_offset_y, 0)
				if origin.y < 0.0 and origin.y >= -stage_obj.pivot_offset_y - 0.05:
					origin.y = 0.0
			stage_obj.global_transform = Transform3D(basis, origin)

		parent_node.add_child(stage_obj)
		return stage_obj

	return null

static func autosave() -> void:
	if AppState.stage_container and AppState.is_modified:
		save_project(AUTOSAVE_PATH)

static func get_recent_files() -> Array[String]:
	if not FileAccess.file_exists(RECENT_FILES_PATH):
		return []
	var file := FileAccess.open(RECENT_FILES_PATH, FileAccess.READ)
	var content := file.get_as_text()
	var json := JSON.new()
	if json.parse(content) == OK and json.data is Array:
		var result: Array[String] = []
		for item in json.data:
			if item is String:
				result.append(item)
		return result
	return []

static func add_recent_file(path: String) -> void:
	var recents := get_recent_files()
	recents.erase(path)
	recents.push_front(path)
	if recents.size() > MAX_RECENT_FILES:
		recents.resize(MAX_RECENT_FILES)

	var file := FileAccess.open(RECENT_FILES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(recents))

