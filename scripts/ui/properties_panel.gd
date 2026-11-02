class_name PropertiesPanel
extends PanelContainer

const StageGroup = preload("res://scripts/core/stage_group.gd")

signal collapse_requested

## Right Inspector Panel for Stage-Builder.
## Displays live properties for single selection, multi-selection, or stage overview.

@onready var content_container: VBoxContainer = %ContentContainer

var _active_object: StageObject = null
var _is_updating_ui: bool = false

func _ready() -> void:
	AppState.selection_changed.connect(_on_selection_changed)
	AppState.project_modified.connect(_on_project_modified)
	_show_stage_overview()

func _on_selection_changed(selected: Array) -> void:
	if selected.is_empty():
		_active_object = null
		_show_stage_overview()
	elif selected.size() == 1 and selected[0] is StageObject:
		_active_object = selected[0] as StageObject
		_show_single_object_inspector(_active_object)
	elif selected.size() == 1 and selected[0] is StageGroup:
		_active_object = null
		_show_group_inspector(selected[0] as StageGroup)
	else:
		_active_object = null
		_show_multi_selection_inspector(selected)

func _show_group_inspector(group: StageGroup) -> void:
	_clear_content()
	_create_header("Group: " + group.group_name, Color(0.3, 0.8, 0.6))

	var objs := group.get_all_stage_objects()
	var total_w := 0.0
	for obj in objs:
		if is_instance_valid(obj):
			total_w += obj.weight_kg

	_add_stat_row("Group Name:", group.group_name)
	_add_stat_row("Contained Items:", "%d objects" % objs.size())
	_add_stat_row("Combined Weight:", "%.1f kg" % total_w)

	var btn_ungroup := Button.new()
	btn_ungroup.text = "Ungroup (" + PlatformUtils.get_modifier_name() + "+Shift+G)"
	btn_ungroup.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_ungroup_selection"):
			vp._ungroup_selection()
	)
	content_container.add_child(btn_ungroup)

	var btn_dup := Button.new()
	btn_dup.text = "Duplicate Group"
	btn_dup.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_duplicate_selection"):
			vp._duplicate_selection()
	)
	content_container.add_child(btn_dup)

	var btn_del := Button.new()
	btn_del.text = "Delete Group"
	btn_del.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_del.pressed.connect(func():
		var vp := get_tree().root.find_child("StageViewport", true, false)
		if vp and vp.has_method("_delete_selection"):
			vp._delete_selection()
	)
	content_container.add_child(btn_del)

func _on_project_modified() -> void:
	if AppState.selected_objects.is_empty():
		_show_stage_overview()
	elif AppState.selected_objects.size() == 1 and _active_object:
		_update_single_object_values()

func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()

func _create_header(title_text: String, title_color: Color = Color(0.9, 0.95, 1.0)) -> void:
	var hbox := HBoxContainer.new()
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", title_color)
	hbox.add_child(title)

	var collapse_btn := Button.new()
	collapse_btn.text = "▶"
	collapse_btn.tooltip_text = "Collapse Panel (Ctrl+] / Cmd+])"
	collapse_btn.flat = true
	collapse_btn.add_theme_font_size_override("font_size", 11)
	collapse_btn.pressed.connect(func(): collapse_requested.emit())
	hbox.add_child(collapse_btn)

	content_container.add_child(hbox)
	var sep := HSeparator.new()
	content_container.add_child(sep)

# --- Stage Overview Mode ---

func _show_stage_overview() -> void:
	_clear_content()
	_create_header("Stage Overview", Color(0.9, 0.95, 1.0))

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
	_create_header("Properties: " + obj.asset_name, Color(0.4, 0.75, 1.0))

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

	# Material / Color Variant Picker
	if not obj.available_variants.is_empty():
		var var_lbl := Label.new()
		var_lbl.text = "Material / Color Variant:"
		var_lbl.add_theme_font_size_override("font_size", 12)
		content_container.add_child(var_lbl)

		var var_opt := OptionButton.new()
		var selected_idx := 0
		for i in range(obj.available_variants.size()):
			var v: Dictionary = obj.available_variants[i]
			var_opt.add_item(v.get("name", "Default"), i)
			if v.get("id", "") == obj.current_variant:
				selected_idx = i
		var_opt.select(selected_idx)
		var_opt.item_selected.connect(func(idx: int):
			if not _is_updating_ui and is_instance_valid(obj):
				var target_vid: String = obj.available_variants[idx].get("id", "")
				var cmd := BaseCommand.VariantChangeCommand.new(obj, obj.current_variant, target_vid)
				CommandManager.execute_command(cmd)
		)
		content_container.add_child(var_opt)

	# Base Center Position X, Y, Z
	var pos_lbl := Label.new()
	pos_lbl.text = "Base Center (X, Y, Z meters):"
	pos_lbl.add_theme_font_size_override("font_size", 12)
	content_container.add_child(pos_lbl)

	var pos_hbox := HBoxContainer.new()
	var spin_x := _create_spinbox(-100, 100, obj.global_position.x, 0.1)
	var spin_y := _create_spinbox(-100, 100, obj.global_position.y, 0.1)
	var spin_z := _create_spinbox(-100, 100, obj.global_position.z, 0.1)

	spin_x.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			new_t[0].origin.x = v
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
	)
	spin_y.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			new_t[0].origin.y = v
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
	)
	spin_z.value_changed.connect(func(v: float):
		if not _is_updating_ui and is_instance_valid(obj):
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			new_t[0].origin.z = v
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
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
			var old_t: Array[Transform3D] = [obj.global_transform]
			var new_t: Array[Transform3D] = [obj.global_transform]
			new_t[0].basis = Basis(Vector3.UP, deg_to_rad(v))
			var targets: Array[StageObject] = [obj]
			CommandManager.execute_command(BaseCommand.TransformCommand.new(targets, old_t, new_t))
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

func _show_multi_selection_inspector(selected: Array) -> void:
	_clear_content()
	_create_header("Multiple Objects Selected", Color(0.4, 0.75, 1.0))

	var count := selected.size()
	var total_w := 0.0
	for item in selected:
		if is_instance_valid(item):
			if item is StageObject:
				total_w += item.weight_kg
			elif item is StageGroup:
				for o in item.get_all_stage_objects():
					total_w += o.weight_kg

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
	sb.custom_minimum_size = Vector2(40, 0)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb

