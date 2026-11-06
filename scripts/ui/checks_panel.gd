class_name ChecksPanel
extends PanelContainer

## Dockable Warnings and Structural Checks Panel for Stage-Builder (Phase 3A).
## Displays live structural load checks, beam statics, hoist capacities, and safety warnings.
## Clicking an issue selects and frames the offending equipment in the 3D viewport.

signal close_requested

@onready var close_btn: Button = %CloseBtn
@onready var unit_opt: OptionButton = %UnitOpt
@onready var static_sf_spin: SpinBox = %StaticSfSpin
@onready var motor_sf_spin: SpinBox = %MotorSfSpin
@onready var list_container: VBoxContainer = %WarningsListContainer
@onready var badge_summary_lbl: Label = %BadgeSummaryLabel

func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(func(): close_requested.emit())

	_setup_units()
	_setup_safety_factors()

	RiggingManager.rigging_solved.connect(_on_rigging_solved)
	RiggingManager.unit_changed.connect(func(_u): _update_unit_ui())

	_populate_warnings(RiggingManager.warnings)

func _setup_units() -> void:
	if unit_opt:
		unit_opt.clear()
		unit_opt.add_item("kg", 0)
		unit_opt.add_item("kN", 1)
		unit_opt.add_item("lb", 2)
		_update_unit_ui()
		unit_opt.item_selected.connect(func(idx: int):
			match idx:
				0: RiggingManager.set_unit("kg")
				1: RiggingManager.set_unit("kN")
				2: RiggingManager.set_unit("lb")
		)

func _update_unit_ui() -> void:
	if unit_opt:
		match RiggingManager.active_unit:
			"kg": unit_opt.select(0)
			"kN": unit_opt.select(1)
			"lb": unit_opt.select(2)

func _setup_safety_factors() -> void:
	if static_sf_spin:
		static_sf_spin.min_value = 1.0
		static_sf_spin.max_value = 10.0
		static_sf_spin.step = 0.1
		static_sf_spin.value = RiggingManager.static_safety_factor
		static_sf_spin.value_changed.connect(func(val: float):
			RiggingManager.set_safety_factors(val, RiggingManager.motor_safety_factor)
		)

	if motor_sf_spin:
		motor_sf_spin.min_value = 1.0
		motor_sf_spin.max_value = 20.0
		motor_sf_spin.step = 0.5
		motor_sf_spin.value = RiggingManager.motor_safety_factor
		motor_sf_spin.value_changed.connect(func(val: float):
			RiggingManager.set_safety_factors(RiggingManager.static_safety_factor, val)
		)

func _on_rigging_solved(results: Dictionary) -> void:
	_populate_warnings(results.get("warnings", []))

func _populate_warnings(warnings_list: Array) -> void:
	if list_container == null:
		return

	for child in list_container.get_children():
		child.queue_free()

	var crit_cnt := RiggingManager.critical_count
	var warn_cnt := RiggingManager.warning_count
	if badge_summary_lbl:
		if crit_cnt == 0 and warn_cnt == 0:
			badge_summary_lbl.text = "✓ All structural checks pass"
			badge_summary_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		else:
			badge_summary_lbl.text = "%d Critical  •  %d Warning(s)" % [crit_cnt, warn_cnt]
			badge_summary_lbl.add_theme_color_override(
				"font_color",
				Color(1.0, 0.3, 0.3) if crit_cnt > 0 else Color(1.0, 0.8, 0.2)
			)

	if warnings_list.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No structural or load risks detected.\nAll truss spans and supports are within rated limits."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		list_container.add_child(empty_lbl)
		return

	for w in warnings_list:
		var card := _create_warning_card(w)
		list_container.add_child(card)

func _create_warning_card(w: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var sev: int = int(w.get("severity", RiggingManager.Severity.WARNING))

	var border_col := Color(1.0, 0.75, 0.2) # Yellow/Orange warning
	var bg_col := Color(0.18, 0.16, 0.14)
	if sev == RiggingManager.Severity.CRITICAL:
		border_col = Color(1.0, 0.25, 0.25) # Red critical
		bg_col = Color(0.22, 0.14, 0.14)
	elif sev == RiggingManager.Severity.INFO:
		border_col = Color(0.3, 0.7, 1.0)
		bg_col = Color(0.14, 0.16, 0.2)

	style.bg_color = bg_col
	style.border_color = border_col
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	var header_hbox := HBoxContainer.new()
	var icon_lbl := Label.new()
	icon_lbl.text = "🔴 CRITICAL" if sev == RiggingManager.Severity.CRITICAL else "⚠️ WARNING"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", border_col)
	header_hbox.add_child(icon_lbl)

	var rule_lbl := Label.new()
	rule_lbl.text = " • " + w.get("rule_id", "Check").capitalize()
	rule_lbl.add_theme_font_size_override("font_size", 11)
	rule_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	rule_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(rule_lbl)
	vbox.add_child(header_hbox)

	var msg_lbl := Label.new()
	msg_lbl.text = w.get("message", "")
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_size_override("font_size", 12)
	msg_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	vbox.add_child(msg_lbl)

	var fix_text: String = w.get("suggested_fix", "")
	if fix_text != "":
		var fix_lbl := Label.new()
		fix_lbl.text = "Fix: " + fix_text
		fix_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fix_lbl.add_theme_font_size_override("font_size", 11)
		fix_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
		vbox.add_child(fix_lbl)

	card.add_child(vbox)

	# Click warning to select and frame object
	var obj_id: String = w.get("object_id", "")
	if obj_id != "":
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.tooltip_text = "Click to select and frame offending equipment in 3D"
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				_frame_offending_object(obj_id)
		)

	return card

func _frame_offending_object(obj_id: String) -> void:
	if AppState.stage_container == null:
		return

	var target_obj: StageObject = null
	for child in AppState.stage_container.get_children():
		if child is StageObject and child.instance_id == obj_id:
			target_obj = child
			break

	if target_obj:
		AppState.set_selection([target_obj])
		var cam := get_tree().root.find_child("StageCamera", true, false)
		if cam and cam.has_method("frame_target"):
			cam.frame_target(target_obj.global_position, target_obj.get_world_aabb().size.length())
		AppState.status_message.emit("Selected: " + target_obj.asset_name)
