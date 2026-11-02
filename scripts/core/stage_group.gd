class_name StageGroup
extends Node3D

## Hierarchical group of stage objects in Stage-Builder.
## Acts as a selectable parent in the 3D scene, transforming, duplicating,
## deleting, and serializing its member objects as a unified unit.

signal selection_toggled(is_selected: bool)

@export var group_id: String = ""
@export var group_name: String = "Group"

var is_selected: bool = false:
	set(val):
		if is_selected != val:
			is_selected = val
			_update_selection_highlight()
			selection_toggled.emit(is_selected)

func _ready() -> void:
	if group_id == "":
		group_id = "group_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)

func _update_selection_highlight() -> void:
	for child in get_children():
		if child is StageObject:
			child.is_selected = is_selected
		elif child is StageGroup:
			child.is_selected = is_selected

func get_all_stage_objects() -> Array[StageObject]:
	var list: Array[StageObject] = []
	for child in get_children():
		if child is StageObject:
			list.append(child)
		elif child is StageGroup:
			list.append_array(child.get_all_stage_objects())
	return list

func get_global_snap_points() -> Array:
	var result: Array = []
	for obj in get_all_stage_objects():
		result.append_array(obj.get_global_snap_points())
	return result

func serialize() -> Dictionary:
	var children_data: Array = []
	for child in get_children():
		if child is StageObject:
			children_data.append(child.serialize())
		elif child is StageGroup:
			children_data.append(child.serialize())

	return {
		"type": "group",
		"group_id": group_id,
		"group_name": group_name,
		"transform": {
			"basis": [
				[global_transform.basis.x.x, global_transform.basis.x.y, global_transform.basis.x.z],
				[global_transform.basis.y.x, global_transform.basis.y.y, global_transform.basis.y.z],
				[global_transform.basis.z.x, global_transform.basis.z.y, global_transform.basis.z.z]
			],
			"origin": [global_transform.origin.x, global_transform.origin.y, global_transform.origin.z]
		},
		"children": children_data
	}

