class_name BaseCommand
extends RefCounted

## Base class for all undoable commands in Stage-Builder.

func execute() -> void:
	pass

func undo() -> void:
	pass

func get_description() -> String:
	return "Command"

# --- Place Command ---
class PlaceCommand extends BaseCommand:
	var stage_container: Node3D
	var placed_objects: Array[StageObject] = []
	var transforms: Array[Transform3D] = []

	func _init(container: Node3D, objects: Array[StageObject], tforms: Array[Transform3D] = []) -> void:
		stage_container = container
		placed_objects = objects
		if tforms.is_empty():
			for obj in objects:
				transforms.append(obj.global_transform)
		else:
			transforms = tforms

	func execute() -> void:
		for i in range(placed_objects.size()):
			var obj := placed_objects[i]
			if not stage_container.is_ancestor_of(obj):
				stage_container.add_child(obj)
			obj.global_transform = transforms[i]
			obj.visible = true
		AppState.set_selection(placed_objects)
		AppState.project_modified.emit()

	func undo() -> void:
		for obj in placed_objects:
			if stage_container.is_ancestor_of(obj):
				stage_container.remove_child(obj)
		AppState.clear_selection()
		AppState.project_modified.emit()

	func get_description() -> String:
		if placed_objects.size() == 1:
			return "Place %s" % placed_objects[0].asset_name
		return "Place %d objects" % placed_objects.size()

# --- Delete Command ---
class DeleteCommand extends BaseCommand:
	var stage_container: Node3D
	var deleted_objects: Array[StageObject] = []
	var transforms: Array[Transform3D] = []

	func _init(container: Node3D, objects: Array[StageObject]) -> void:
		stage_container = container
		deleted_objects = objects.duplicate()
		for obj in deleted_objects:
			transforms.append(obj.global_transform)

	func execute() -> void:
		AppState.clear_selection()
		for obj in deleted_objects:
			if stage_container.is_ancestor_of(obj):
				stage_container.remove_child(obj)
		AppState.project_modified.emit()

	func undo() -> void:
		for i in range(deleted_objects.size()):
			var obj := deleted_objects[i]
			if not stage_container.is_ancestor_of(obj):
				stage_container.add_child(obj)
			obj.global_transform = transforms[i]
		AppState.set_selection(deleted_objects)
		AppState.project_modified.emit()

	func get_description() -> String:
		if deleted_objects.size() == 1:
			return "Delete %s" % deleted_objects[0].asset_name
		return "Delete %d objects" % deleted_objects.size()

# --- Transform Command ---
class TransformCommand extends BaseCommand:
	var target_objects: Array[StageObject] = []
	var old_transforms: Array[Transform3D] = []
	var new_transforms: Array[Transform3D] = []

	func _init(objects: Array[StageObject], old_t: Array[Transform3D], new_t: Array[Transform3D]) -> void:
		target_objects = objects.duplicate()
		old_transforms = old_t.duplicate()
		new_transforms = new_t.duplicate()

	func execute() -> void:
		for i in range(target_objects.size()):
			if is_instance_valid(target_objects[i]):
				target_objects[i].global_transform = new_transforms[i]
		AppState.project_modified.emit()

	func undo() -> void:
		for i in range(target_objects.size()):
			if is_instance_valid(target_objects[i]):
				target_objects[i].global_transform = old_transforms[i]
		AppState.project_modified.emit()

	func get_description() -> String:
		return "Move/Rotate %d object(s)" % target_objects.size()

# --- Property Change Command ---
class PropertyChangeCommand extends BaseCommand:
	var target_object: StageObject
	var property_name: String
	var old_value: Variant
	var new_value: Variant

	func _init(obj: StageObject, prop: String, old_v: Variant, new_v: Variant) -> void:
		target_object = obj
		property_name = prop
		old_value = old_v
		new_value = new_v

	func execute() -> void:
		if is_instance_valid(target_object):
			target_object.set(property_name, new_value)
			AppState.project_modified.emit()

	func undo() -> void:
		if is_instance_valid(target_object):
			target_object.set(property_name, old_value)
			AppState.project_modified.emit()

	func get_description() -> String:
		return "Change %s" % property_name

# --- Group Command ---
class GroupCommand extends BaseCommand:
	var grouped_objects: Array[StageObject] = []
	var new_group_id: String = ""
	var old_group_ids: Array[String] = []

	func _init(objects: Array[StageObject], gid: String) -> void:
		grouped_objects = objects.duplicate()
		new_group_id = gid
		for obj in grouped_objects:
			old_group_ids.append(obj.group_id)

	func execute() -> void:
		for obj in grouped_objects:
			if is_instance_valid(obj):
				obj.group_id = new_group_id
		AppState.project_modified.emit()

	func undo() -> void:
		for i in range(grouped_objects.size()):
			if is_instance_valid(grouped_objects[i]):
				grouped_objects[i].group_id = old_group_ids[i]
		AppState.project_modified.emit()

	func get_description() -> String:
		return "Group %d objects" % grouped_objects.size()

