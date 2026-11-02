class_name BaseCommand
extends RefCounted

const StageGroup = preload("res://scripts/core/stage_group.gd")

## Base class for all undoable commands in Stage-Builder.

func execute() -> void:
	pass

func undo() -> void:
	pass

func redo() -> void:
	execute()

func get_description() -> String:
	return "Command"

# --- Place Command ---
class PlaceCommand extends BaseCommand:
	var stage_container: Node3D
	var placed_objects: Array[StageObject] = []
	var transforms: Array[Transform3D] = []

	func _init(container: Node3D, objects: Array, tforms: Array = []) -> void:
		stage_container = container
		for obj in objects:
			if obj is StageObject:
				placed_objects.append(obj)
		if tforms.is_empty():
			for obj in placed_objects:
				transforms.append(obj.global_transform)
		else:
			for t in tforms:
				if t is Transform3D:
					transforms.append(t)

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
	var deleted_nodes: Array[Node3D] = []
	var parents: Array[Node] = []
	var transforms: Array[Transform3D] = []

	func _init(container: Node3D, objects: Array) -> void:
		stage_container = container
		for obj in objects:
			if obj is Node3D and is_instance_valid(obj):
				deleted_nodes.append(obj)
				parents.append(obj.get_parent() if obj.get_parent() else container)
				transforms.append(obj.global_transform)

	func execute() -> void:
		AppState.clear_selection()
		for i in range(deleted_nodes.size()):
			var node := deleted_nodes[i]
			var parent := parents[i]
			if is_instance_valid(node) and is_instance_valid(parent) and parent.is_ancestor_of(node):
				parent.remove_child(node)
		AppState.project_modified.emit()

	func undo() -> void:
		for i in range(deleted_nodes.size()):
			var node := deleted_nodes[i]
			var parent := parents[i]
			if is_instance_valid(node) and is_instance_valid(parent):
				if not parent.is_ancestor_of(node):
					parent.add_child(node)
				node.global_transform = transforms[i]
		AppState.set_selection(deleted_nodes)
		AppState.project_modified.emit()

	func get_description() -> String:
		if deleted_nodes.size() == 1:
			var name_str: String = deleted_nodes[0].name
			if "asset_name" in deleted_nodes[0]:
				name_str = deleted_nodes[0].asset_name
			return "Delete %s" % name_str
		return "Delete %d items" % deleted_nodes.size()

# --- Transform Command ---
class TransformCommand extends BaseCommand:
	var target_nodes: Array[Node3D] = []
	var old_transforms: Array[Transform3D] = []
	var new_transforms: Array[Transform3D] = []

	func _init(objects: Array, old_t: Array, new_t: Array) -> void:
		for obj in objects:
			if obj is Node3D and is_instance_valid(obj):
				target_nodes.append(obj)
		for t in old_t:
			if t is Transform3D:
				old_transforms.append(t)
		for t in new_t:
			if t is Transform3D:
				new_transforms.append(t)

	func execute() -> void:
		for i in range(target_nodes.size()):
			if is_instance_valid(target_nodes[i]) and i < new_transforms.size():
				target_nodes[i].global_transform = new_transforms[i]
		AppState.project_modified.emit()

	func undo() -> void:
		for i in range(target_nodes.size()):
			if is_instance_valid(target_nodes[i]) and i < old_transforms.size():
				target_nodes[i].global_transform = old_transforms[i]
		AppState.project_modified.emit()

	func get_description() -> String:
		return "Move/Rotate %d object(s)" % target_nodes.size()

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
	var stage_container: Node3D
	var group_node: StageGroup
	var member_nodes: Array[Node3D] = []
	var previous_parents: Array[Node] = []
	var original_transforms: Array[Transform3D] = []

	func _init(container: Node3D, objects: Array, group_name: String = "Group") -> void:
		stage_container = container
		group_node = StageGroup.new()
		group_node.group_name = group_name
		for obj in objects:
			if obj is Node3D and is_instance_valid(obj):
				member_nodes.append(obj)
				previous_parents.append(obj.get_parent() if obj.get_parent() else container)
				original_transforms.append(obj.global_transform)

	func execute() -> void:
		if member_nodes.is_empty():
			return

		# Compute group center
		var center := Vector3.ZERO
		for t in original_transforms:
			center += t.origin
		center /= float(original_transforms.size())

		if not stage_container.is_ancestor_of(group_node):
			stage_container.add_child(group_node)
		group_node.global_position = center

		for i in range(member_nodes.size()):
			var node := member_nodes[i]
			if is_instance_valid(node):
				node.reparent(group_node, true)
				node.global_transform = original_transforms[i]

		AppState.set_selection([group_node])
		AppState.project_modified.emit()

	func undo() -> void:
		for i in range(member_nodes.size()):
			var node := member_nodes[i]
			var parent := previous_parents[i]
			if is_instance_valid(node) and is_instance_valid(parent):
				node.reparent(parent, true)
				node.global_transform = original_transforms[i]

		if stage_container.is_ancestor_of(group_node):
			stage_container.remove_child(group_node)

		AppState.set_selection(member_nodes)
		AppState.project_modified.emit()

	func get_description() -> String:
		return "Group %d items" % member_nodes.size()

# --- Ungroup Command ---
class UngroupCommand extends BaseCommand:
	var stage_container: Node3D
	var groups_to_ungroup: Array[StageGroup] = []
	var group_parents: Array[Node] = []
	var group_transforms: Array[Transform3D] = []
	var grouped_children: Array[Array] = []
	var children_transforms: Array[Array] = []
	var all_ungrouped_nodes: Array[Node3D] = []

	func _init(container: Node3D, groups: Array) -> void:
		stage_container = container
		for g in groups:
			if g is StageGroup and is_instance_valid(g):
				groups_to_ungroup.append(g)
				group_parents.append(g.get_parent() if g.get_parent() else container)
				group_transforms.append(g.global_transform)

				var ch_list: Array[Node3D] = []
				var t_list: Array[Transform3D] = []
				for child in g.get_children():
					if child is Node3D:
						ch_list.append(child)
						t_list.append(child.global_transform)
				grouped_children.append(ch_list)
				children_transforms.append(t_list)

	func execute() -> void:
		all_ungrouped_nodes.clear()
		for i in range(groups_to_ungroup.size()):
			var grp := groups_to_ungroup[i]
			var parent := group_parents[i]
			var children: Array = grouped_children[i]
			var tforms: Array = children_transforms[i]

			for j in range(children.size()):
				var ch: Node3D = children[j]
				if is_instance_valid(ch):
					ch.reparent(parent, true)
					ch.global_transform = tforms[j]
					all_ungrouped_nodes.append(ch)

			if is_instance_valid(grp) and parent.is_ancestor_of(grp):
				parent.remove_child(grp)

		AppState.set_selection(all_ungrouped_nodes)
		AppState.project_modified.emit()

	func undo() -> void:
		for i in range(groups_to_ungroup.size()):
			var grp := groups_to_ungroup[i]
			var parent := group_parents[i]
			var children: Array = grouped_children[i]
			var tforms: Array = children_transforms[i]

			if not parent.is_ancestor_of(grp):
				parent.add_child(grp)
			grp.global_transform = group_transforms[i]

			for j in range(children.size()):
				var ch: Node3D = children[j]
				if is_instance_valid(ch):
					ch.reparent(grp, true)
					ch.global_transform = tforms[j]

		AppState.set_selection(groups_to_ungroup)
		AppState.project_modified.emit()

	func get_description() -> String:
		return "Ungroup %d group(s)" % groups_to_ungroup.size()

# --- Variant Change Command ---
class VariantChangeCommand extends BaseCommand:
	var target_object: StageObject
	var old_variant: String
	var new_variant: String

	func _init(obj: StageObject, old_v: String, new_v: String) -> void:
		target_object = obj
		old_variant = old_v
		new_variant = new_v

	func execute() -> void:
		if is_instance_valid(target_object):
			target_object.apply_variant(new_variant)

	func undo() -> void:
		if is_instance_valid(target_object):
			target_object.apply_variant(old_variant)

	func get_description() -> String:
		return "Change Variant to %s" % new_variant

