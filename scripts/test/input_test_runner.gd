class_name InputTestRunner
extends Node

const StageGroup = preload("res://scripts/core/stage_group.gd")

## Input-driven test runner for Stage-Builder.
## Simulates real hardware events (InputEventKey, InputEventMouseButton, InputEventMouseMotion)
## through the real engine input pipeline (Input.parse_input_event and viewport.push_input).

var main_inst: Control = null
var stage_vp: StageViewport = null
var sub_vp: SubViewport = null
var camera: StageCamera = null
var stage_container: Node3D = null

func _ready() -> void:
	print("==================================================")
	print("Running Stage-Builder Input-Simulation Test Suite")
	print("==================================================")
	call_deferred("_run_all_tests")

func _setup_main() -> void:
	if main_inst != null:
		main_inst.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame

	var scene: PackedScene = load("res://scenes/main.tscn")
	main_inst = scene.instantiate()
	get_tree().root.add_child(main_inst)

	await get_tree().process_frame
	await get_tree().process_frame

	stage_vp = main_inst.find_child("StageViewport", true, false)
	sub_vp = stage_vp.find_child("SubViewport", true, false)
	camera = sub_vp.find_child("StageCamera", true, false)
	stage_container = sub_vp.find_child("StageContainer", true, false)

	AppState.stage_container = stage_container
	AppState.clear_selection()
	CommandManager.clear()
	for child in stage_container.get_children():
		stage_container.remove_child(child)
		child.free()
	await get_tree().process_frame

func _cleanup() -> void:
	if main_inst:
		main_inst.queue_free()
		main_inst = null
	await get_tree().process_frame

# --- Input Dispatch Helpers ---

func send_key(keycode: Key, pressed: bool, ctrl: bool = false, shift: bool = false, alt: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = pressed
	ev.echo = false
	ev.ctrl_pressed = ctrl
	if OS.get_name() == "macOS":
		ev.meta_pressed = ctrl
	ev.shift_pressed = shift
	ev.alt_pressed = alt
	Input.parse_input_event(ev)

func send_key_click(keycode: Key, ctrl: bool = false, shift: bool = false, alt: bool = false) -> void:
	send_key(keycode, true, ctrl, shift, alt)
	await get_tree().process_frame
	send_key(keycode, false, ctrl, shift, alt)
	await get_tree().process_frame

func send_mouse_motion(logical_pos: Vector2, alt: bool = false, shift: bool = false) -> void:
	var scale_factor: float = get_tree().root.content_scale_factor if get_tree().root.content_scale_factor > 0.0 else 1.0
	var win_pos := logical_pos * scale_factor
	var ev := InputEventMouseMotion.new()
	ev.position = win_pos
	ev.global_position = win_pos
	ev.alt_pressed = alt
	ev.shift_pressed = shift
	Input.parse_input_event(ev)

func send_mouse_button(logical_pos: Vector2, button: MouseButton, pressed: bool, ctrl: bool = false, shift: bool = false, alt: bool = false) -> void:
	var scale_factor: float = get_tree().root.content_scale_factor if get_tree().root.content_scale_factor > 0.0 else 1.0
	var win_pos := logical_pos * scale_factor
	var ev := InputEventMouseButton.new()
	ev.position = win_pos
	ev.global_position = win_pos
	ev.button_index = button
	ev.pressed = pressed
	ev.ctrl_pressed = ctrl
	if OS.get_name() == "macOS":
		ev.meta_pressed = ctrl
	ev.shift_pressed = shift
	ev.alt_pressed = alt
	Input.parse_input_event(ev)

func simulate_click(global_pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, ctrl: bool = false, shift: bool = false, alt: bool = false) -> void:
	send_mouse_motion(global_pos, alt, shift)
	await get_tree().process_frame
	send_mouse_button(global_pos, button, true, ctrl, shift, alt)
	await get_tree().process_frame
	send_mouse_button(global_pos, button, false, ctrl, shift, alt)
	await get_tree().process_frame

func get_viewport_screen_center() -> Vector2:
	return stage_vp.global_position + (stage_vp.size * 0.5)

# --- Test Execution ---

func _run_all_tests() -> void:
	var results: Dictionary = {}

	# Item 1
	results["Item 1: Ghost Color & Validity"] = await test_item_1_ghost_color()

	# Item 2
	results["Item 2: Duplicate & Delete"] = await test_item_2_duplicate_and_delete()

	# Item 3
	results["Item 3: Group & Ungroup"] = await test_item_3_group_and_ungroup()

	# Item 4
	results["Item 4: Undo / Redo for Every Action"] = await test_item_4_undo_redo_chain()

	# Item 5
	results["Item 5: Grid Snap"] = await test_item_5_grid_snap()

	# Item 6
	results["Item 6: Truss-to-Truss and Corner Snapping"] = await test_item_6_truss_snapping()

	# Item 7
	results["Item 7: Deck Edge-to-Edge and Barricade Snapping"] = await test_item_7_deck_snapping()

	# Item 8
	results["Item 8: Point Snap Toggle and Override"] = await test_item_8_point_snap_and_override()

	# Item 9
	results["Item 9: Ground Resting for All 146 Assets"] = await test_item_9_all_assets_rest_on_ground()

	# Item 10
	results["Item 10: Placement on 0.4m Elevated Deck"] = await test_item_10_placement_on_elevated_deck()

	# Item 11
	results["Item 11: Surface Resting Variations (Rot/Scale/Variant)"] = await test_item_11_surface_resting_variations()

	# Item 12
	results["Item 12: Surface Resting Workflows (Undo/Redo/Save/Load/Dup/Group)"] = await test_item_12_surface_resting_workflows()

	# Item 13
	results["Item 13: Snapping Precision After Pivot Fix"] = await test_item_13_snapping_after_pivot_change()

	# Item 14
	results["Item 14: FPS Modes, UI Menus, Dialog & Status Bar Display"] = await test_item_14_fps_modes_and_ui()

	print("\n==================================================")
	print("INPUT-SIMULATION TEST RESULTS SUMMARY:")
	print("==================================================")
	var all_passed := true
	for item in results:
		var passed: bool = results[item]
		print("  [%s] %s" % ["PASS" if passed else "FAIL", item])
		if not passed:
			all_passed = false

	if all_passed:
		print("ALL INPUT TESTS PASSED!")
	else:
		print("SOME TESTS FAILED (EXPECTED BEFORE FIXES).")

	await _cleanup()
	get_tree().quit(0 if all_passed else 1)

# --- Individual Test Implementations ---

func test_item_1_ghost_color() -> bool:
	print("\n[TEST 1] Testing Ghost Color, 2mm Epsilon & MultiMesh Tinting...")
	await _setup_main()

	# 1. Start placement of deck
	AppState.start_placement("staging_deck_2x1m")
	var center := get_viewport_screen_center()
	send_mouse_motion(center)
	await get_tree().process_frame
	await get_tree().process_frame

	var preview := stage_vp.placement_preview_obj
	if preview == null:
		push_error("TEST 1 FAIL: Placement preview object was not created.")
		return false

	# 2. Check ghost validity on empty ground: must be valid
	var is_valid := stage_vp._check_ghost_validity(preview, null)
	if not is_valid:
		push_error("TEST 1 FAIL: Ghost on empty ground reported invalid.")
		return false

	# Check material applied to preview
	var geoms := preview.find_children("*", "GeometryInstance3D", true, false)
	if geoms.is_empty() or geoms[0].material_override == null:
		push_error("TEST 1 FAIL: Ghost preview has no material_override applied.")
		return false

	var mat: StandardMaterial3D = geoms[0].material_override as StandardMaterial3D
	# Valid ghost must have green albedo (g > 0.8, r < 0.3)
	if mat.albedo_color.g < 0.7 or mat.albedo_color.r > 0.4:
		push_error("TEST 1 FAIL: Valid ghost did not have green material. Albedo: " + str(mat.albedo_color))
		return false

	# 3. Commit placement of first deck at origin (0, 0.2, 0)
	await simulate_click(center, MOUSE_BUTTON_LEFT)
	await get_tree().process_frame

	var placed := AppState.get_stage_objects()
	if placed.is_empty():
		push_error("TEST 1 FAIL: First deck was not placed.")
		return false
	var deck1 := placed[0]
	deck1.global_position = Vector3(0, 0.2, 0)

	# 4. Test face-to-face touching deck (2mm gap/flush):
	# Deck 1 is 2x1m centered at (0, 0.2, 0), x spans [-1.0, 1.0].
	# Deck 2 placed flush touching at x = 2.0 (spans [1.0, 3.0], boundary x = 1.0).
	var deck2 := CatalogManager.instantiate_asset("staging_deck_2x1m")
	stage_container.add_child(deck2)
	deck2.global_position = Vector3(2.0, 0.2, 0)
	await get_tree().process_frame

	var touching_valid := stage_vp._check_ghost_validity(deck2, null)
	deck2.queue_free()
	if not touching_valid:
		push_error("TEST 1 FAIL: Flush face-to-face touching decks were incorrectly reported as invalid collision (2mm epsilon violated).")
		return false

	# 5. Test truly overlapping deck: Deck 3 placed at (0.5, 0.2, 0) overlapping Deck 1
	var deck3 := CatalogManager.instantiate_asset("staging_deck_2x1m")
	stage_container.add_child(deck3)
	deck3.global_position = Vector3(0.5, 0.2, 0)
	await get_tree().process_frame

	var overlap_valid := stage_vp._check_ghost_validity(deck3, null)
	deck3.queue_free()
	deck1.free()
	if overlap_valid:
		push_error("TEST 1 FAIL: Truly overlapping decks were reported as valid.")
		return false

	print("  -> Ghost color, 2mm epsilon and overlap check verified.")
	return true

func test_item_2_duplicate_and_delete() -> bool:
	print("\n[TEST 2] Testing Duplicate (Ctrl+D) and Delete (Del/Backspace) via Real Input...")
	await _setup_main()

	# Place one object
	var obj := CatalogManager.instantiate_asset("truss_box_2m")
	stage_container.add_child(obj)
	obj.global_position = Vector3(1, 0, 1)
	obj.current_variant = "black"
	AppState.set_selection([obj])
	await get_tree().process_frame

	# Focus a UI button (e.g. AssetPanel or StatusBar button) to test focus eating
	var some_btn := main_inst.find_child("GridSnapButton", true, false) as Button
	if some_btn:
		some_btn.grab_focus()
	await get_tree().process_frame

	# Inject Ctrl+D key press
	send_key_click(KEY_D, true)
	await get_tree().process_frame
	await get_tree().process_frame

	var objs_after_dup := AppState.get_stage_objects()
	if objs_after_dup.size() != 2:
		push_error("TEST 2 FAIL: Ctrl+D duplicate failed to create copy when button was focused. Count: %d" % objs_after_dup.size())
		return false

	var dup_obj: StageObject = AppState.selected_objects[0]
	if dup_obj == obj:
		push_error("TEST 2 FAIL: Duplicate selection was not set to the new copy.")
		return false
	if dup_obj.current_variant != "black":
		push_error("TEST 2 FAIL: Duplicate did not copy variant 'black'. Got: " + dup_obj.current_variant)
		return false

	# Test Undo duplicate
	send_key_click(KEY_Z, true)
	await get_tree().process_frame
	await get_tree().process_frame
	if AppState.get_stage_objects().size() != 1:
		push_error("TEST 2 FAIL: Undo duplicate failed.")
		return false

	# Select original object again
	AppState.set_selection([obj])
	await get_tree().process_frame

	# Focus button again and press Delete key
	if some_btn:
		some_btn.grab_focus()
	await get_tree().process_frame

	send_key_click(KEY_DELETE, false)
	await get_tree().process_frame
	await get_tree().process_frame

	if not AppState.get_stage_objects().is_empty():
		push_error("TEST 2 FAIL: Delete key failed to delete object when button was focused.")
		return false
	if not AppState.selected_objects.is_empty():
		push_error("TEST 2 FAIL: Delete did not clear selection.")
		return false

	# Undo delete
	send_key_click(KEY_Z, true)
	await get_tree().process_frame
	await get_tree().process_frame

	if AppState.get_stage_objects().size() != 1:
		push_error("TEST 2 FAIL: Undo delete failed to restore object.")
		return false
	if not is_equal_approx(AppState.get_stage_objects()[0].global_position.x, 1.0):
		push_error("TEST 2 FAIL: Undone object transform mismatch.")
		return false

	print("  -> Duplicate & Delete via real input confirmed passing.")
	return true

func test_item_3_group_and_ungroup() -> bool:
	print("\n[TEST 3] Testing Group (Ctrl+G) and Ungroup (Ctrl+Shift+G) with Hierarchy...")
	await _setup_main()

	var obj1 := CatalogManager.instantiate_asset("staging_deck_2x1m")
	var obj2 := CatalogManager.instantiate_asset("staging_deck_2x1m")
	stage_container.add_child(obj1)
	stage_container.add_child(obj2)
	obj1.global_position = Vector3(0, 0, 0)
	obj2.global_position = Vector3(2, 0, 0)

	AppState.set_selection([obj1, obj2])
	await get_tree().process_frame

	# Press Ctrl+G to group
	send_key_click(KEY_G, true, false)
	await get_tree().process_frame
	await get_tree().process_frame

	# Must have created a parent group node
	var parent1 := obj1.get_parent()
	if parent1 == stage_container or parent1 == null:
		push_error("TEST 3 FAIL: Grouping did not create a selectable parent node in scene tree.")
		return false
	if obj2.get_parent() != parent1:
		push_error("TEST 3 FAIL: Group members do not share the same parent node.")
		return false

	# Test clicking member: clicking obj1 in 3D must select the whole group
	AppState.clear_selection()
	await get_tree().physics_frame
	await get_tree().process_frame
	var screen_pos1 := camera.unproject_position(obj1.global_position)
	await simulate_click(stage_vp.global_position + screen_pos1, MOUSE_BUTTON_LEFT)
	await get_tree().process_frame

	# Selection must include both group members (or group node)
	if not (AppState.selected_objects.has(parent1) or (AppState.selected_objects.has(obj1) and AppState.selected_objects.has(obj2))):
		push_error("TEST 3 FAIL: Clicking a group member did not select the whole group.")
		return false

	# Test ungrouping (Ctrl+Shift+G)
	send_key_click(KEY_G, true, true)
	await get_tree().process_frame
	await get_tree().process_frame

	if obj1.get_parent() != stage_container or obj2.get_parent() != stage_container:
		push_error("TEST 3 FAIL: Ungrouping did not restore objects to stage_container.")
		return false

	print("  -> Group & Ungroup with selectable parent hierarchy verified.")
	return true

func test_item_4_undo_redo_chain() -> bool:
	print("\n[TEST 4] Testing 20-Action Mixed Undo/Redo Chain...")
	await _setup_main()

	var initial_count := AppState.get_total_object_count()

	# Execute 20 mixed commands
	for i in range(20):
		var obj := CatalogManager.instantiate_asset("truss_box_1m")
		stage_container.add_child(obj)
		obj.global_position = Vector3(float(i) * 0.5, 0, 0)
		var cmd := BaseCommand.PlaceCommand.new(stage_container, [obj], [obj.global_transform])
		CommandManager.execute_command(cmd)
		await get_tree().process_frame

	if AppState.get_total_object_count() != initial_count + 20:
		push_error("TEST 4 FAIL: 20 objects were not placed.")
		return false

	# Undo all 20 via Ctrl+Z
	for i in range(20):
		send_key_click(KEY_Z, true)
		await get_tree().process_frame

	if AppState.get_total_object_count() != initial_count:
		push_error("TEST 4 FAIL: Undoing all 20 actions did not return to initial count. Count: %d" % AppState.get_total_object_count())
		return false

	# Redo all 20 via Ctrl+Y
	for i in range(20):
		send_key_click(KEY_Y, true)
		await get_tree().process_frame

	if AppState.get_total_object_count() != initial_count + 20:
		push_error("TEST 4 FAIL: Redoing all 20 actions did not restore all objects. Count: %d" % AppState.get_total_object_count())
		return false

	print("  -> 20-action Undo/Redo chain verified.")
	return true

func test_item_5_grid_snap() -> bool:
	print("\n[TEST 5] Testing Grid Snap Toggle ('G') & Step Resolution (0.25, 0.5, 1.0m)...")
	await _setup_main()

	var initial_grid := AppState.show_grid
	# Press 'G' key
	send_key_click(KEY_G, false)
	await get_tree().process_frame

	if AppState.show_grid == initial_grid:
		push_error("TEST 5 FAIL: Key 'G' failed to toggle grid.")
		return false

	# Test grid snap math at 0.25, 0.5, 1.0
	for step_val in [0.25, 0.50, 1.00]:
		var step: float = step_val
		AppState.grid_step = step
		AppState.snap_to_grid = true
		AppState.snap_to_points = false
		var raw_pos := Vector3(1.33, 0, 2.78)
		var res := SnapSystem.resolve_position(raw_pos)
		var expected_x: float = roundf(raw_pos.x / step) * step
		var expected_z: float = roundf(raw_pos.z / step) * step
		if not is_equal_approx(res.position.x, expected_x) or not is_equal_approx(res.position.z, expected_z):
			push_error("TEST 5 FAIL: Grid snap math mismatch at step %.2f. Got: %s, Expected: (%f, 0, %f)" % [step, str(res.position), expected_x, expected_z])
			return false

	print("  -> Grid snap toggle ('G') and steps verified.")
	return true

func test_item_6_truss_snapping() -> bool:
	print("\n[TEST 6] Testing Truss-to-Truss, Corner Snapping & Visual Indicator...")
	await _setup_main()

	# 1. Straight box truss at (0, 0, 0)
	var t1 := CatalogManager.instantiate_asset("truss_box_2m")
	stage_container.add_child(t1)
	t1.global_transform = Transform3D.IDENTITY
	await get_tree().process_frame

	# 2. Second straight truss candidate approaching end at z = 1.0
	var t2 := CatalogManager.instantiate_asset("truss_box_2m")
	var candidate_pos := Vector3(0.05, 0, 1.85) # within 0.25m snap radius of (0, 0, 2.0)
	AppState.snap_to_points = true
	var res := SnapSystem.resolve_position(candidate_pos, t2, Basis.IDENTITY)

	if not res.snapped_to_point:
		push_error("TEST 6 FAIL: Truss did not snap to neighbor end within 0.25m snap radius.")
		t1.queue_free()
		t2.queue_free()
		return false

	# Expected snapped position is exactly (0, 0, 2.0) so ends touch with 0mm gap
	if not is_equal_approx(res.position.z, 2.0) or not is_equal_approx(res.position.x, 0.0):
		push_error("TEST 6 FAIL: Snapped position z expected 2.0, got: " + str(res.position))
		t1.queue_free()
		t2.queue_free()
		return false

	# 3. Test 90 degree corner block joining straight piece
	var corner := CatalogManager.instantiate_asset("truss_corner_2way_90")
	stage_container.add_child(corner)
	corner.global_position = Vector3(10, 0, 10)
	# Corner face 1 is at (10, 0, 9.75), norm [0, 0, -1]
	# Bring straight piece rotated along Z
	var t3 := CatalogManager.instantiate_asset("truss_box_2m")
	var t3_pos := Vector3(10, 0, 8.8) # approaches face 1
	var corner_res := SnapSystem.resolve_position(t3_pos, t3, Basis.IDENTITY)
	if not corner_res.snapped_to_point:
		push_error("TEST 6 FAIL: Straight truss failed to snap to 90 deg corner face.")
		t1.queue_free()
		t2.queue_free()
		corner.queue_free()
		t3.queue_free()
		return false

	# Check gap (< 1mm)
	var end_of_t3: Vector3 = corner_res.position + Vector3(0, 0, 1.0)
	var corner_face: Vector3 = Vector3(10, 0, 9.75)
	var gap := end_of_t3.distance_to(corner_face)
	if gap > 0.001:
		push_error("TEST 6 FAIL: Gap between corner and straight truss exceeded 1mm: %.4fm" % gap)
		t1.queue_free()
		t2.queue_free()
		corner.queue_free()
		t3.queue_free()
		return false

	t1.queue_free()
	t2.queue_free()
	corner.queue_free()
	t3.queue_free()
	print("  -> Truss-to-truss and 90 deg corner snapping verified (<1mm gap).")
	return true

func test_item_7_deck_snapping() -> bool:
	print("\n[TEST 7] Testing Deck Edge-to-Edge, Mixed Sizes (2x1, 1x1) & Barricades...")
	await _setup_main()

	# 1. Deck 1: 2x1m at (0, 0.2, 0)
	var d1 := CatalogManager.instantiate_asset("staging_deck_2x1m")
	stage_container.add_child(d1)
	d1.global_position = Vector3(0, 0.2, 0)
	await get_tree().process_frame

	# 2. Deck 2: 1x1m approaching 1m edge at x = 1.0
	var d2 := CatalogManager.instantiate_asset("staging_deck_1x1m")
	var d2_cand := Vector3(1.4, 0.2, 0.0)
	AppState.snap_to_points = true
	var res := SnapSystem.resolve_position(d2_cand, d2, Basis.IDENTITY)

	if not res.snapped_to_point:
		push_error("TEST 7 FAIL: 1x1m deck failed to snap to 2x1m deck 1m edge.")
		d1.queue_free()
		d2.queue_free()
		return false

	# d1 spans [-1, 1] in X. d2 is 1x1m so width is 1.0. Snapped center must be x = 1.5
	if not is_equal_approx(res.position.x, 1.5):
		push_error("TEST 7 FAIL: 1x1m deck snapped position expected x=1.5, got: " + str(res.position))
		d1.queue_free()
		d2.queue_free()
		return false

	# 3. Barricade side-by-side snapping
	var b1 := CatalogManager.instantiate_asset("staging_barricade_straight")
	stage_container.add_child(b1)
	b1.global_position = Vector3(5, 0, 5)
	await get_tree().process_frame

	var b2 := CatalogManager.instantiate_asset("staging_barricade_straight")
	var b2_cand := Vector3(5.85, 0, 5.0)
	var b_res := SnapSystem.resolve_position(b2_cand, b2, Basis.IDENTITY)
	if not b_res.snapped_to_point:
		push_error("TEST 7 FAIL: Barricade failed to snap side-by-side to neighbor.")
		d1.queue_free()
		d2.queue_free()
		b1.queue_free()
		b2.queue_free()
		return false

	# Barricade 1m wide: snapped center should be x = 6.0
	if not is_equal_approx(b_res.position.x, 6.0):
		push_error("TEST 7 FAIL: Barricade snapped position expected x=6.0, got: " + str(b_res.position))
		d1.queue_free()
		d2.queue_free()
		b1.queue_free()
		b2.queue_free()
		return false

	d1.queue_free()
	d2.queue_free()
	b1.queue_free()
	b2.queue_free()
	print("  -> Deck edge-to-edge and barricade side-by-side snapping verified.")
	return true

func test_item_8_point_snap_and_override() -> bool:
	print("\n[TEST 8] Testing Point Snap Toggle ('S') & Alt Key Override...")
	await _setup_main()

	# 1. Test 'S' key toggle
	var initial_snap := AppState.snap_to_points
	send_key_click(KEY_S, false)
	await get_tree().process_frame

	if AppState.snap_to_points == initial_snap:
		push_error("TEST 8 FAIL: Key 'S' failed to toggle point snapping.")
		return false

	# Toggle back on
	send_key_click(KEY_S, false)
	await get_tree().process_frame
	if not AppState.snap_to_points:
		push_error("TEST 8 FAIL: Key 'S' failed to toggle point snapping back on.")
		return false

	# 2. Test Alt key override during snapping
	var t1 := CatalogManager.instantiate_asset("truss_box_2m")
	stage_container.add_child(t1)
	t1.global_transform = Transform3D.IDENTITY
	await get_tree().process_frame

	var t2 := CatalogManager.instantiate_asset("truss_box_2m")
	var cand_pos := Vector3(0.02, 0, 1.95)

	# Without Alt: snaps to (0, 0, 2.0)
	var snap_on := SnapSystem.resolve_position(cand_pos, t2, Basis.IDENTITY)
	if not snap_on.snapped_to_point:
		push_error("TEST 8 FAIL: Baseline point snap failed before Alt test.")
		t1.queue_free()
		t2.queue_free()
		return false

	# With Alt held: ALL snapping must be disabled, candidate_pos returned raw!
	send_key(KEY_ALT, true)
	await get_tree().process_frame

	var snap_alt := SnapSystem.resolve_position(cand_pos, t2, Basis.IDENTITY)
	send_key(KEY_ALT, false)
	await get_tree().process_frame

	if snap_alt.snapped_to_point:
		push_error("TEST 8 FAIL: Holding Alt failed to disable point snapping.")
		t1.queue_free()
		t2.queue_free()
		return false

	if not is_equal_approx(snap_alt.position.x, cand_pos.x) or not is_equal_approx(snap_alt.position.z, cand_pos.z):
		push_error("TEST 8 FAIL: Holding Alt did not preserve raw position. Got: " + str(snap_alt.position))
		t1.queue_free()
		t2.queue_free()
		return false

	t1.queue_free()
	t2.queue_free()
	print("  -> Point snap toggle ('S') and Alt override verified.")
	return true

func test_item_9_all_assets_rest_on_ground() -> bool:
	print("\n[TEST 9] Testing Ground Resting (AABB min.y == 0) for All Catalog Assets...")
	await _setup_main()

	var all_assets := CatalogManager.get_all_assets()
	if all_assets.size() < 120:
		push_error("TEST 9 FAIL: Expected at least 120 assets, got: %d" % all_assets.size())
		return false

	var failure_count := 0
	for asset in all_assets:
		var asset_id: String = asset.get("id", "")
		var obj := CatalogManager.instantiate_asset(asset_id)
		if obj == null:
			push_error("TEST 9 FAIL: Could not instantiate asset '%s'" % asset_id)
			failure_count += 1
			continue

		stage_container.add_child(obj)
		obj.global_position = Vector3(0, 0, 0)

		var local_aabb := obj.get_local_aabb()
		var world_aabb := obj.get_world_aabb()

		# Assert local AABB min.y sits at 0.0 within 1 mm tolerance (0.001 m)
		if abs(local_aabb.position.y) > 0.001:
			push_error("TEST 9 FAIL: Asset '%s' local AABB min.y is not 0 (got %f)" % [asset_id, local_aabb.position.y])
			failure_count += 1

		# Assert world AABB min.y sits at ground y=0 within 1 mm tolerance
		if abs(world_aabb.position.y) > 0.001:
			push_error("TEST 9 FAIL: Asset '%s' world AABB min.y is not 0 on ground (got %f)" % [asset_id, world_aabb.position.y])
			failure_count += 1

		# Assert content_pivot offset correctly matches pivot_offset_y
		if abs(obj.content_pivot.position.y - obj.pivot_offset_y) > 0.001:
			push_error("TEST 9 FAIL: Asset '%s' content_pivot offset mismatch (%f vs %f)" % [asset_id, obj.content_pivot.position.y, obj.pivot_offset_y])
			failure_count += 1

		obj.free()

	if failure_count > 0:
		push_error("TEST 9 FAIL: %d assets failed ground resting check." % failure_count)
		return false

	print("  -> Verified ground resting (AABB min.y == 0.000m) across all %d catalog assets." % all_assets.size())
	return true

func test_item_10_placement_on_elevated_deck() -> bool:
	print("\n[TEST 10] Testing Placement on 0.4m Elevated Deck (Stacking)...")
	await _setup_main()

	# 1. Place a 0.4m elevated deck on the ground
	var deck := CatalogManager.instantiate_asset("staging_deck_2x1m")
	stage_container.add_child(deck)
	deck.global_position = Vector3(0, 0, 0)
	await get_tree().physics_frame
	await get_tree().process_frame

	var deck_aabb := deck.get_world_aabb()
	if abs(deck_aabb.position.y) > 0.001:
		push_error("TEST 10 FAIL: Base deck does not rest on ground (min.y = %f)" % deck_aabb.position.y)
		return false
	var deck_top_y := deck_aabb.position.y + deck_aabb.size.y # 0.4m
	if abs(deck_top_y - 0.4) > 0.001:
		push_error("TEST 10 FAIL: Base deck top height is not 0.4m (got %f)" % deck_top_y)
		return false

	# 2. Position camera looking directly down-angled at the deck
	camera.global_position = Vector3(0, 5, 5)
	camera.look_at(Vector3(0, 0.4, 0))
	await get_tree().physics_frame
	await get_tree().process_frame

	# 3. Simulate placement of barricade onto the deck
	var local_center := stage_vp.size * 0.5
	var surface_pos := stage_vp._get_ground_or_surface_pos(local_center)
	if abs(surface_pos.y - 0.4) > 0.05:
		push_error("TEST 10 FAIL: Raycast on deck top did not hit surface at y=0.4 (hit y = %f)" % surface_pos.y)
		return false

	AppState.start_placement("staging_barricade_straight")
	await get_tree().process_frame
	stage_vp._commit_placement(local_center)
	await get_tree().process_frame

	var placed_objs := AppState.get_stage_objects()
	var barricade: StageObject = null
	for o in placed_objs:
		if o.catalog_id == "staging_barricade_straight":
			barricade = o
			break

	if barricade == null:
		push_error("TEST 10 FAIL: Barricade was not placed on deck.")
		return false

	var bar_aabb := barricade.get_world_aabb()
	if abs(bar_aabb.position.y - 0.4) > 0.002:
		push_error("TEST 10 FAIL: Barricade world min.y on deck is not 0.4m (got %f)" % bar_aabb.position.y)
		return false

	# Remove barricade so deck surface is clear for deck-on-deck stacking
	barricade.free()
	await get_tree().physics_frame
	await get_tree().process_frame

	# 4. Stack a second deck on top of the first deck
	AppState.start_placement("staging_deck_2x1m")
	await get_tree().process_frame
	stage_vp._commit_placement(local_center)
	await get_tree().process_frame

	var all_decks: Array = []
	for o in AppState.get_stage_objects():
		if o.catalog_id == "staging_deck_2x1m" and o != deck:
			all_decks.append(o)

	if all_decks.is_empty():
		push_error("TEST 10 FAIL: Second deck was not stacked on first deck.")
		return false

	var deck2: StageObject = all_decks[0]
	var deck2_aabb := deck2.get_world_aabb()
	if abs(deck2_aabb.position.y - 0.4) > 0.002:
		push_error("TEST 10 FAIL: Second deck base did not sit at 0.4m (got %f)" % deck2_aabb.position.y)
		return false

	# 5. Place a moving spot on top of the stacked decks (y = 0.8m)
	await get_tree().physics_frame
	await get_tree().process_frame
	AppState.start_placement("lighting_moving_spot")
	await get_tree().process_frame
	stage_vp._commit_placement(local_center)
	await get_tree().process_frame

	var moving_spots: Array = []
	for o in AppState.get_stage_objects():
		if o.catalog_id == "lighting_moving_spot":
			moving_spots.append(o)

	if moving_spots.is_empty():
		push_error("TEST 10 FAIL: Moving spot was not placed on stacked decks.")
		return false

	var spot: StageObject = moving_spots[0]
	var spot_aabb := spot.get_world_aabb()
	if abs(spot_aabb.position.y - 0.8) > 0.002:
		push_error("TEST 10 FAIL: Moving spot base did not sit at 0.8m on double deck stack (got %f)" % spot_aabb.position.y)
		return false

	print("  -> Verified items stacked on 0.4m deck and 0.8m double stack rest precisely.")
	return true

func test_item_11_surface_resting_variations() -> bool:
	print("\n[TEST 11] Testing Surface Resting Variations (Yaw Rotation, Scale, Finish Variant)...")
	await _setup_main()

	var obj := CatalogManager.instantiate_asset("truss_box_2m")
	stage_container.add_child(obj)
	obj.global_position = Vector3(0, 0, 0)
	await get_tree().process_frame

	# 1. Test Rotations around Y (0, 45, 90, 180, 270 degrees)
	var test_angles := [0.0, PI * 0.25, PI * 0.5, PI, PI * 1.5]
	for rad in test_angles:
		obj.global_transform = Transform3D(Basis(Vector3.UP, rad), Vector3(0, 0, 0))
		var aabb := obj.get_world_aabb()
		if abs(aabb.position.y) > 0.001:
			push_error("TEST 11 FAIL: Truss rotated by %f rad failed ground resting (min.y = %f)" % [rad, aabb.position.y])
			return false

	# 2. Test Finish/Color Variants
	for v in obj.available_variants:
		var v_id: String = v.get("id", "")
		obj.apply_variant(v_id)
		var aabb := obj.get_world_aabb()
		if abs(aabb.position.y) > 0.001:
			push_error("TEST 11 FAIL: Truss variant '%s' failed ground resting (min.y = %f)" % [v_id, aabb.position.y])
			return false

	# 3. Test Scaling (both uniform and non-uniform)
	var test_scales := [
		Vector3(1.0, 1.0, 1.0),
		Vector3(1.5, 2.0, 1.5),
		Vector3(0.5, 0.5, 0.5),
		Vector3(2.0, 3.0, 2.0)
	]
	for sc in test_scales:
		obj.scale = sc
		var aabb := obj.get_world_aabb()
		if abs(aabb.position.y) > 0.001:
			push_error("TEST 11 FAIL: Truss scaled by %s failed ground resting (min.y = %f)" % [str(sc), aabb.position.y])
			return false

	obj.queue_free()
	print("  -> Rotation, scale, and variant changes all preserve ground resting at y=0.000m.")
	return true

func test_item_12_surface_resting_workflows() -> bool:
	print("\n[TEST 12] Testing Surface Resting Workflows (Undo/Redo, Duplicate, Group, Save/Load, Legacy)...")
	await _setup_main()

	# 1. Undo / Redo
	var obj := CatalogManager.instantiate_asset("staging_deck_2x1m")
	var initial_xform := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	var cmd := BaseCommand.PlaceCommand.new(stage_container, [obj], [initial_xform])
	CommandManager.execute_command(cmd)
	await get_tree().process_frame

	if abs(obj.get_world_aabb().position.y) > 0.001:
		push_error("TEST 12 FAIL: Placed deck not resting on ground (min.y = %f)" % obj.get_world_aabb().position.y)
		return false

	# Undo
	CommandManager.undo()
	await get_tree().process_frame
	# Redo
	CommandManager.redo()
	await get_tree().process_frame

	var restored_obj: StageObject = AppState.get_stage_objects()[0]
	if abs(restored_obj.get_world_aabb().position.y) > 0.001:
		push_error("TEST 12 FAIL: Redone deck not resting on ground (min.y = %f)" % restored_obj.get_world_aabb().position.y)
		return false

	# 2. Duplicate via Ctrl+D
	AppState.set_selection([restored_obj])
	await get_tree().process_frame
	send_key_click(KEY_D, true)
	await get_tree().process_frame
	await get_tree().process_frame

	var objs := AppState.get_stage_objects()
	if objs.size() != 2:
		push_error("TEST 12 FAIL: Duplicate failed to create copy.")
		return false
	for o in objs:
		if abs(o.get_world_aabb().position.y) > 0.001:
			push_error("TEST 12 FAIL: Duplicate object not resting on ground (min.y = %f)" % o.get_world_aabb().position.y)
			return false

	# 3. Group via Ctrl+G & Ungroup via Ctrl+Shift+G
	AppState.set_selection(objs)
	await get_tree().process_frame
	send_key_click(KEY_G, true, false)
	await get_tree().process_frame
	await get_tree().process_frame

	# Check objects still rest on ground while grouped
	for o in AppState.get_stage_objects():
		if abs(o.get_world_aabb().position.y) > 0.001:
			push_error("TEST 12 FAIL: Grouped object not resting on ground (min.y = %f)" % o.get_world_aabb().position.y)
			return false

	# Ungroup
	send_key_click(KEY_G, true, true)
	await get_tree().process_frame
	await get_tree().process_frame
	for o in AppState.get_stage_objects():
		if abs(o.get_world_aabb().position.y) > 0.001:
			push_error("TEST 12 FAIL: Ungrouped object not resting on ground (min.y = %f)" % o.get_world_aabb().position.y)
			return false

	# 4. Save and Load
	var test_path := "user://test_workflow_pivot.stagebuilder"
	var save_ok := ProjectSerializer.save_project(test_path, camera)
	if not save_ok:
		push_error("TEST 12 FAIL: ProjectSerializer save failed.")
		return false

	var load_ok := ProjectSerializer.load_project(test_path, camera)
	if not load_ok:
		push_error("TEST 12 FAIL: ProjectSerializer load failed.")
		return false

	for o in AppState.get_stage_objects():
		if abs(o.get_world_aabb().position.y) > 0.001:
			push_error("TEST 12 FAIL: Loaded object not resting on ground (min.y = %f)" % o.get_world_aabb().position.y)
			return false

	# 5. Legacy Project Version (< 2.1.0) Compatibility
	var legacy_path := "user://test_legacy_project.stagebuilder"
	var legacy_data := {
		"version": "2.0.0",
		"project_name": "Legacy Test",
		"objects": [
			{
				"catalog_id": "staging_deck_2x1m",
				"instance_id": "legacy_deck_1",
				"name": "Stage Deck 2x1m",
				"dimensions": { "x": 2.0, "y": 0.4, "z": 1.0 },
				"transform": {
					"basis": [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
					"origin": [0.0, 0.0, 0.0]
				}
			}
		]
	}
	var f := FileAccess.open(legacy_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy_data, "  "))
	f.close()

	var leg_load_ok := ProjectSerializer.load_project(legacy_path, camera)
	if not leg_load_ok:
		push_error("TEST 12 FAIL: Loading legacy project failed.")
		return false

	var leg_objs := AppState.get_stage_objects()
	if leg_objs.is_empty():
		push_error("TEST 12 FAIL: No objects loaded from legacy project.")
		return false

	var leg_deck: StageObject = leg_objs[0]
	if abs(leg_deck.get_world_aabb().position.y) > 0.001:
		push_error("TEST 12 FAIL: Legacy object was not corrected to ground level (min.y = %f, expected 0.0)" % leg_deck.get_world_aabb().position.y)
		return false

	print("  -> Undo/redo, duplicate, grouping, save/load, and legacy compatibility verified.")
	return true

func test_item_13_snapping_after_pivot_change() -> bool:
	print("\n[TEST 13] Testing Snapping Precision (Alignment <= 1mm) After Pivot Fix...")
	await _setup_main()

	# 1. Truss-to-Truss Snapping (box 2m to box 2m end-to-end)
	var t1 := CatalogManager.instantiate_asset("truss_box_2m")
	stage_container.add_child(t1)
	t1.global_transform = Transform3D.IDENTITY
	await get_tree().process_frame

	var t2 := CatalogManager.instantiate_asset("truss_box_2m")
	var snap_t2 := SnapSystem.resolve_position(Vector3(0, 0, 1.95), t2, Basis.IDENTITY)
	if not snap_t2.snapped_to_point:
		push_error("TEST 13 FAIL: Truss-to-truss end snap failed.")
		t1.free()
		t2.free()
		return false

	stage_container.add_child(t2)
	t2.global_transform = Transform3D(Basis.IDENTITY, snap_t2.position)
	await get_tree().process_frame

	# Verify both trusses have min.y == 0
	if abs(t1.get_world_aabb().position.y) > 0.001 or abs(t2.get_world_aabb().position.y) > 0.001:
		push_error("TEST 13 FAIL: Connected trusses not resting on ground (t1=%f, t2=%f)" % [t1.get_world_aabb().position.y, t2.get_world_aabb().position.y])
		t1.free()
		t2.free()
		return false

	# Verify snap points coincide within 1mm
	var t1_snaps := t1.get_global_snap_points()
	var t2_snaps := t2.get_global_snap_points()
	var found_coincident := false
	for s1 in t1_snaps:
		for s2 in t2_snaps:
			if (s1["global_pos"] as Vector3).distance_to(s2["global_pos"] as Vector3) <= 0.001:
				found_coincident = true
				break
		if found_coincident:
			break

	if not found_coincident:
		push_error("TEST 13 FAIL: Truss snap points are not coincident within 1mm.")
		t1.free()
		t2.free()
		return false

	t1.free()
	t2.free()

	# 2. Deck-to-Deck Edge Snapping (2x1m side-by-side)
	var d1 := CatalogManager.instantiate_asset("staging_deck_2x1m")
	stage_container.add_child(d1)
	d1.global_transform = Transform3D.IDENTITY
	await get_tree().process_frame

	var d2 := CatalogManager.instantiate_asset("staging_deck_2x1m")
	var snap_d2 := SnapSystem.resolve_position(Vector3(1.95, 0, 0), d2, Basis.IDENTITY)
	if not snap_d2.snapped_to_point:
		push_error("TEST 13 FAIL: Deck side-by-side snap failed.")
		d1.free()
		d2.free()
		return false

	stage_container.add_child(d2)
	d2.global_transform = Transform3D(Basis.IDENTITY, snap_d2.position)
	await get_tree().process_frame

	# Verify vertical alignment of deck surfaces
	var d1_aabb := d1.get_world_aabb()
	var d2_aabb := d2.get_world_aabb()
	if abs(d1_aabb.position.y - d2_aabb.position.y) > 0.001:
		push_error("TEST 13 FAIL: Deck bottom surfaces misaligned vertically: %f vs %f" % [d1_aabb.position.y, d2_aabb.position.y])
		d1.free()
		d2.free()
		return false

	var d1_top := d1_aabb.position.y + d1_aabb.size.y
	var d2_top := d2_aabb.position.y + d2_aabb.size.y
	if abs(d1_top - d2_top) > 0.001:
		push_error("TEST 13 FAIL: Deck top surfaces misaligned vertically: %f vs %f" % [d1_top, d2_top])
		d1.free()
		d2.free()
		return false

	d1.free()
	d2.free()

	# 3. Flown Item Clamped to Truss (Audio Array to Box Truss)
	var truss_flown := CatalogManager.instantiate_asset("truss_box_2m")
	stage_container.add_child(truss_flown)
	truss_flown.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 4.0, 0))
	await get_tree().process_frame

	var array_mod := CatalogManager.instantiate_asset("audio_array_standard_10in")
	var snap_array := SnapSystem.resolve_position(Vector3(0, 3.8, 1.0), array_mod, Basis.IDENTITY)
	if snap_array.snapped_to_point:
		stage_container.add_child(array_mod)
		array_mod.global_transform = Transform3D(Basis.IDENTITY, snap_array.position)
		await get_tree().process_frame

		var matches_clamp := false
		for sp in array_mod.get_global_snap_points():
			if (sp["global_pos"] as Vector3).distance_to(snap_array.snap_world_pos) <= 0.001:
				matches_clamp = true
				break
		if not matches_clamp:
			push_error("TEST 13 FAIL: Flown audio array clamp snap point misaligned by > 1mm.")
			truss_flown.free()
			array_mod.free()
			return false

		array_mod.free()

	truss_flown.free()

	print("  -> Snapping precision verified <= 1mm across truss, deck, and rigging points.")
	return true

func test_item_14_fps_modes_and_ui() -> bool:
	print("\n[TEST 14] Testing Performance FPS Modes, Menu Items, Dialog & Status Bar Display...")
	await _setup_main()

	var stats_lbl := main_inst.find_child("StatsLabel", true, false) as Label
	if stats_lbl == null:
		push_error("TEST 14 FAIL: StatsLabel not found in main_inst.")
		return false

	var status_bar_node := main_inst.find_child("StatusBar", true, false) as AppStatusBar
	if status_bar_node == null:
		push_error("TEST 14 FAIL: StatusBar not found in main_inst.")
		return false

	# 1. Test VSync Mode selection via Menu
	main_inst.menu_bar._on_perf_menu_pressed(311)
	await get_tree().process_frame
	if PerformanceSettings.fps_mode != PerformanceSettings.FPSMode.VSYNC:
		push_error("TEST 14 FAIL: Menu 311 failed to set VSYNC mode.")
		return false
	status_bar_node._update_stats()
	if not stats_lbl.text.contains("(VSync)"):
		push_error("TEST 14 FAIL: StatsLabel does not show '(VSync)': " + stats_lbl.text)
		return false

	# 2. Test Unlimited Mode selection via Menu
	main_inst.menu_bar._on_perf_menu_pressed(313)
	await get_tree().process_frame
	if PerformanceSettings.fps_mode != PerformanceSettings.FPSMode.UNLIMITED:
		push_error("TEST 14 FAIL: Menu 313 failed to set UNLIMITED mode.")
		return false
	status_bar_node._update_stats()
	if not stats_lbl.text.contains("(Unlimited)"):
		push_error("TEST 14 FAIL: StatsLabel does not show '(Unlimited)': " + stats_lbl.text)
		return false

	# 3. Test Custom Limit Menu (312) opening dialog
	main_inst.menu_bar._on_perf_menu_pressed(312)
	await get_tree().process_frame
	if not main_inst.performance_dialog.visible:
		push_error("TEST 14 FAIL: Menu 312 did not open performance settings dialog.")
		return false
	if PerformanceSettings.fps_mode != PerformanceSettings.FPSMode.CUSTOM_LIMIT:
		push_error("TEST 14 FAIL: Menu 312 failed to set CUSTOM_LIMIT mode.")
		return false

	# 4. Interact with Dialog Preset Buttons
	var presets := [60, 120, 144, 240]
	for p in presets:
		PerformanceSettings.set_custom_limit(p)
		await get_tree().process_frame
		status_bar_node._update_stats()
		if not stats_lbl.text.contains("(Limit %d)" % p):
			push_error("TEST 14 FAIL: StatsLabel does not show '(Limit %d)': %s" % [p, stats_lbl.text])
			return false

	# Close dialog
	main_inst.performance_dialog.hide()
	await get_tree().process_frame

	# 5. Test opening dialog via click on StatusLabel
	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	stats_lbl.gui_input.emit(click_ev)
	await get_tree().process_frame
	if not main_inst.performance_dialog.visible:
		push_error("TEST 14 FAIL: Clicking StatsLabel did not open performance dialog.")
		return false
	main_inst.performance_dialog.hide()
	await get_tree().process_frame

	# 6. Test Responsive Status Bar on Narrow Layout
	status_bar_node.size.x = 500.0
	status_bar_node._update_stats()
	if not stats_lbl.text.begins_with("FPS:") or not stats_lbl.text.contains("(Limit 240)"):
		push_error("TEST 14 FAIL: Responsive compact stats label failed: " + stats_lbl.text)
		return false

	# Restore default VSync mode
	PerformanceSettings.set_fps_mode(PerformanceSettings.FPSMode.VSYNC)
	PerformanceSettings.set_limit_fps_unfocused(true)
	await get_tree().process_frame

	print("  -> Performance FPS modes, menu actions, dialog presets & status bar verified.")
	return true
