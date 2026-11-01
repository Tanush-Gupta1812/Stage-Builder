class_name PropertiesPanel
extends PanelContainer

## Right Inspector Panel for Stage-Builder.
## Displays live properties for single selection, multi-selection, or stage overview.

@onready var content_container: VBoxContainer = %ContentContainer

var _active_object: StageObject = null
var _is_updating_ui: bool = false

func _ready() -> void:
	AppState.selection_changed.connect(_on_selection_changed)
	AppState.project_modified.connect(_on_project_modified)
	_show_stage_overview()

func _on_selection_changed(selected: Array[StageObject]) -> void:
	if selected.is_empty():
		_active_object = null
		_show_stage_overview()
	elif selected.size() == 1:
		_active_object = selected[0]
		_show_single_object_inspector(_active_object)
	else:
		_active_object = null
		_show_multi_selection_inspector(selected)

func _on_project_modified() -> void:
	if AppState.selected_objects.is_empty():
		_show_stage_overview()
	elif AppState.selected_objects.size() == 1 and _active_object:
		_update_single_object_values()

func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()

# --- Stage Overview Mode ---

func _show_stage_overview() -> void:
	_clear_content()

	var title := Label.new()
	title.text = "Stage Overview"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	content_container.add_child(title)

	var sep := HSeparator.new()
	content_container.add_child(sep)

	var obj_count := AppState.get_total_object_count()
	var total_kg := AppState.get_total_weight()

	_add_stat_row("Total Objects:", str(obj_count))
	_add_stat_row("Total Weight:", "%.1f kg (%.2f t)" % [total_kg, total_kg / 1000.0])
	_add_stat_row("Ground Surface:", AppState.current_ground.capitalize())
	_add_stat_row("Active Project:", AppState.project_name)

	var btn_select_all := Button.new()
	btn_select_all.text = "Select All Objects"
	btn_select_all.pressed.connect(AppState.select_all)
	content_container.add_child(btn_select_all)

# --- Single Object Inspector ---

func _show_single_object_inspector(obj: StageObject) -> void:
	_clear_content()

	var title := Label.new()
	title.text = "Properties: " + obj.asset_name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	content_container.add_child(title)

	var sep := HSeparator.new()
	content_container.add_child(sep)

	# Name field
	var lbl_name := Label.new()
	lbl_name.text = "Asset Name:"
	content_container.add_child(lbl_name)
	var input_name := LineEdit.new()
	input_name.text = obj.asset_name
	input_name.text_changed.connect(func(new_text: String):
		if not _is_updating_ui and is_instance_valid(obj):
			var cmd := BaseCommand.PropertyChangeCommand.new(obj, "asset_name", obj.asset_name, new_text)
			CommandManager.execute_command(cmd)
	)
	content_container.add_child(input_name)

	# Category, Dimensions & Weight
	_add_stat_row("Category:", obj.category)
	_add_stat_row("Dimensions:", "%.2fx%.2fx%.2f m" % [obj.dimensions.x, obj.dimensions.y, obj.dimensions.z])
	_add_stat_row("Weight:", "%.1f kg" % obj.weight_kg)

	# Position X, Y, Z
	var pos_lbl := Label.new()
	pos_lbl.text = "Position (X, Y, Z meters):"
	pos_lbl.add_theme_font_size_override("font_size", 12)
	content_container.add_child(pos_lbl)

	var pos_hbox := HBoxContainer.new()
	var spin_x := _create_spinbox(-100, 100, obj.global_position.x, 0.1)
	var spin_y := _create_spinbox(-100, 100, obj.global_position.y, 0.1)
	var spin_z := _create_spinbox(-100, 100, obj.global_position.z, 0.1)

	spin_x.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			var old_t := [obj.global_transform]
			var new_t := [obj.global_transform]
			new_t[0].origin.x = v
			CommandManager.execute_command(BaseCommand.TransformCommand.new([obj], old_t, new_t))
	)
	spin_y.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			var old_t := [obj.global_transform]
			var new_t := [obj.global_transform]
			new_t[0].origin.y = v
			CommandManager.execute_command(BaseCommand.TransformCommand.new([obj], old_t, new_t))
	)
	spin_z.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			var old_t := [obj.global_transform]
			var new_t := [obj.global_transform]
			new_t[0].origin.z = v
			CommandManager.execute_command(BaseCommand.TransformCommand.new([obj], old_t, new_t))
	)

	pos_hbox.add_child(spin_x)
	pos_hbox.add_child(spin_y)
	pos_hbox.add_child(spin_z)
	content_container.add_child(pos_hbox)

	# Rotation Y degrees
	var rot_lbl := Label.new()
	rot_lbl.text = "Rotation Y (Degrees):"
	rot_lbl.add_theme_font_size_override("font_size", 12)
	content_container.add_child(rot_lbl)

	var spin_rot := _create_spinbox(-360, 360, rad_to_deg(obj.rotation.y), 15.0)
	spin_rot.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			var old_t := [obj.global_transform]
			var new_t := [obj.global_transform]
			new_t[0].basis = Basis(Vector3.UP, deg_to_rad(v))
			CommandManager.execute_command(BaseCommand.TransformCommand.new([obj], old_t, new_t))
	)
	content_container.add_child(spin_rot)

	# Notes
	var notes_lbl := Label.new()
	notes_lbl.text = "Equipment Notes:"
	notes_lbl.add_theme_font_size_override("font_size", 12)
	content_container.add_child(notes_lbl)

	var notes_edit := TextEdit.new()
	notes_edit.text = obj.custom_notes
	notes_edit.custom_minimum_size = Vector2(0, 70)
	notes_edit.text_changed.connect(func():
		if not _is_updating_ui and is_instance_valid(obj):
			obj.custom_notes = notes_edit.text
			AppState.is_modified = true
	)
	content_container.add_child(notes_edit)

	# Actions
	var btn_dup := Button.new()
	btn_dup.text = "Duplicate Object"
	btn_dup.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_duplicate_selection"):
			vp._duplicate_selection()
	)
	content_container.add_child(btn_dup)

	var btn_del := Button.new()
	btn_del.text = "Delete Object"
	btn_del.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_del.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_delete_selection"):
			vp._delete_selection()
	)
	content_container.add_child(btn_del)

func _update_single_object_values() -> void:
	# Refreshes the display if transforms changed via gizmo
	if _active_object and is_instance_valid(_active_object):
		_is_updating_ui = true
		_show_single_object_inspector(_active_object)
		_is_updating_ui = false

# --- Multi-Selection Inspector ---

func _show_multi_selection_inspector(selected: Array[StageObject]) -> void:
	_clear_content()

	var title := Label.new()
	title.text = "Multiple Objects Selected"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	content_container.add_child(title)

	var sep := HSeparator.new()
	content_container.add_child(sep)

	var count := selected.size()
	var total_w := 0.0
	for obj in selected:
		if is_instance_valid(obj):
			total_w += obj.weight_kg

	_add_stat_row("Selected Count:", "%d items" % count)
	_add_stat_row("Combined Weight:", "%.1f kg" % total_w)

	var btn_group := Button.new()
	btn_group.text = "Group Selected (" + PlatformUtils.get_modifier_name() + "+G)"
	btn_group.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_group_selection"):
			vp._group_selection()
	)
	content_container.add_child(btn_group)

	var btn_del := Button.new()
	btn_del.text = "Delete Selected Items"
	btn_del.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_del.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_delete_selection"):
			vp._delete_selection()
	)
	content_container.add_child(btn_del)

# --- Helpers ---

func _add_stat_row(label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	val.add_theme_font_size_override("font_size", 12)
	hbox.add_child(val)
	content_container.add_child(hbox)

func _create_spinbox(min_val: float, max_val: float, initial: float, step: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step
	sb.value = initial
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb

