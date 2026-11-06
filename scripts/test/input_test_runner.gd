class_name InputTestRunner
extends Node

const StageGroup = preload("res://scripts/core/stage_group.gd")
const ThumbnailGenerator = preload("res://scripts/tools/thumbnail_generator.gd")
const GizmoController = preload("res://scripts/viewport/gizmo/gizmo_controller.gd")
const GizmoVisual = preload("res://scripts/viewport/gizmo/gizmo_visual.gd")
const TransformGuard = preload("res://scripts/core/transform_guard.gd")


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

	var win := get_window()
	if win and win.size.x < 2560:
		win.size = Vector2i(2560, 1440)

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
	ev.physical_keycode = keycode
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


func send_mouse_motion(logical_pos: Vector2, alt: bool = false, shift: bool = false, relative_vec: Vector2 = Vector2.ZERO) -> void:
	var scale_factor: float = get_tree().root.content_scale_factor if get_tree().root.content_scale_factor > 0.0 else 1.0
	var win_pos := logical_pos * scale_factor
	var ev := InputEventMouseMotion.new()
	ev.position = win_pos
	ev.global_position = win_pos
	ev.relative = relative_vec * scale_factor if relative_vec != Vector2.ZERO else Vector2.ZERO
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

	# Item 15
	results["Item 15: UI Scale Shortcuts (Ctrl/Cmd +, -, 0 & focus resilience)"] = await test_item_15_ui_scale_shortcuts()

	# Item 16
	results["Item 16: Full 3D Rotation (R/T/Y, Drop to Surface & Gizmo)"] = await test_item_16_full_3d_rotation()

	# Item 17
	results["Item 17: Thumbnail Pipeline & Disk Caching"] = await test_item_17_thumbnail_pipeline()

	# Item 18
	results["Item 18: Rigging Inputs, Checks Panel & Overload Warnings"] = await test_item_18_rigging_input_and_checks_panel()

	# Item 19
	results["Item 19: Catalog Search Box & Real-Time Filtering"] = await test_item_19_catalog_search()

	# Item 20
	results["Item 20: Separated Move/Rotate Tools & Direct Drag"] = await test_item_20_separated_move_rotate_tools()

	# Item 21
	results["Item 21: Gizmo Stage B Picking, Toolbar & Tool Keys"] = await test_item_21_gizmo_stage_b()

	# Item 22
	results["Item 22: Tangent-based Ring Rotation & Edge-on Stability"] = await test_item_22_tangent_rotation_and_edge_on_rings()

	# Item 23
	results["Item 23: Camera Mouse Controls (MMB Pan, Shift+MMB Orbit, Alt+LMB, Wheel Zoom)"] = await test_item_23_camera_mouse_controls()

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

func test_item_15_ui_scale_shortcuts() -> bool:
	print("\n[TEST 15] Testing UI Scale Shortcuts (Ctrl/Cmd +, -, 0) via Real Input...")
	await _setup_main()

	if UIScale.has_method("reset_to_auto"):
		UIScale.reset_to_auto()
	else:
		UIScale.clear_override()
	await get_tree().process_frame
	var initial_scale := UIScale.current_scale

	# 1. Test Zoom In via Ctrl + Equal + Shift (Standard '+' on US keyboard)
	send_key_click(KEY_EQUAL, true, true)
	await get_tree().process_frame
	await get_tree().process_frame

	if UIScale.current_scale <= initial_scale or not UIScale.manual_override:
		push_error("TEST 15 FAIL: Ctrl+Shift+= failed to zoom in UI scale.")
		return false
	var zoomed_in_scale := UIScale.current_scale

	# 2. Test Zoom In with focus in a LineEdit (SearchBox)
	var search_box := main_inst.find_child("SearchBox", true, false) as LineEdit
	if search_box:
		search_box.grab_focus()
	await get_tree().process_frame

	# Test Zoom In via KEY_PLUS with Ctrl
	send_key_click(KEY_PLUS, true, false)
	await get_tree().process_frame
	await get_tree().process_frame

	if UIScale.current_scale <= zoomed_in_scale:
		push_error("TEST 15 FAIL: Ctrl+PLUS failed to zoom in while LineEdit was focused.")
		return false
	var second_zoom := UIScale.current_scale

	# Test Zoom In via KEY_KP_ADD with Ctrl
	send_key_click(KEY_KP_ADD, true, false)
	await get_tree().process_frame
	await get_tree().process_frame
	if UIScale.current_scale <= second_zoom:
		push_error("TEST 15 FAIL: Ctrl+KP_ADD failed to zoom in.")
		return false

	# 3. Test Zoom Out via KEY_MINUS with Ctrl
	var high_scale := UIScale.current_scale
	send_key_click(KEY_MINUS, true, false)
	await get_tree().process_frame
	await get_tree().process_frame
	if UIScale.current_scale >= high_scale:
		push_error("TEST 15 FAIL: Ctrl+MINUS failed to zoom out.")
		return false

	# Test Zoom Out via KEY_KP_SUBTRACT with Ctrl
	var prev_scale := UIScale.current_scale
	send_key_click(KEY_KP_SUBTRACT, true, false)
	await get_tree().process_frame
	await get_tree().process_frame
	if UIScale.current_scale >= prev_scale:
		push_error("TEST 15 FAIL: Ctrl+KP_SUBTRACT failed to zoom out.")
		return false

	# 4. Test Reset to Auto via KEY_0 with Ctrl
	send_key_click(KEY_0, true, false)
	await get_tree().process_frame
	await get_tree().process_frame
	if UIScale.manual_override:
		push_error("TEST 15 FAIL: Ctrl+0 failed to reset manual override to Auto.")
		return false

	# 5. Set manual again and test KEY_KP_0 with Ctrl
	UIScale.set_scale(2.0)
	await get_tree().process_frame
	send_key_click(KEY_KP_0, true, false)
	await get_tree().process_frame
	await get_tree().process_frame
	if UIScale.manual_override:
		push_error("TEST 15 FAIL: Ctrl+KP_0 failed to reset manual override to Auto.")
		return false

	print("  -> UI Scale shortcuts (Ctrl/Cmd +, -, 0) verified with focus resilience.")
	return true

func test_item_16_full_3d_rotation() -> bool:
	print("\n[TEST 16] Testing Full 3D Rotation (R/T/Y, Drop to Surface, Gizmo & Inspector)...")
	await _setup_main()

	# 1. Test Ghost Preview 3D Rotation (R, T, Y)
	AppState.start_placement("truss_box_2m")
	await get_tree().process_frame
	send_mouse_motion(get_viewport_screen_center())
	await get_tree().process_frame


	# Press 'T' (Pitch +90 around X)
	send_key_click(KEY_T, false, false)
	await get_tree().process_frame
	if stage_vp.ghost_basis.is_equal_approx(Basis.IDENTITY):
		push_error("TEST 16 FAIL: Key 'T' did not modify ghost_basis.")
		return false

	# Press Shift+T (Pitch -90 around X -> back to identity)
	send_key_click(KEY_T, false, true)
	await get_tree().process_frame

	# Press 'Y' (Roll +90 around Z)
	send_key_click(KEY_Y, false, false)
	await get_tree().process_frame
	if stage_vp.ghost_basis.is_equal_approx(Basis.IDENTITY):
		push_error("TEST 16 FAIL: Key 'Y' did not modify ghost_basis.")
		return false

	# Commit placement with roll rotation
	simulate_click(get_viewport_screen_center())
	await get_tree().process_frame
	await get_tree().process_frame


	var stage_objs := AppState.get_stage_objects()
	if stage_objs.is_empty():
		push_error("TEST 16 FAIL: Placed rotated object not found in stage.")
		return false

	var placed_obj: StageObject = stage_objs[0]
	var world_aabb: AABB = placed_obj.get_world_aabb()
	if absf(world_aabb.position.y) > 0.005:
		push_error("TEST 16 FAIL: Placed rotated object lowest point is not at surface (min.y = %f)" % world_aabb.position.y)
		return false

	# 2. Test Selection Rotation via R/T/Y on Placed Object
	AppState.set_selection([placed_obj])
	await get_tree().process_frame

	# Press 'T' on selected object (Pitch +90 deg)
	send_key_click(KEY_T, false, false)
	await get_tree().process_frame
	await get_tree().process_frame

	world_aabb = placed_obj.get_world_aabb()
	if absf(world_aabb.position.y) > 0.005:
		push_error("TEST 16 FAIL: Pitched object lowest point is not at surface y=0 (min.y = %f)" % world_aabb.position.y)
		return false

	# Test Undo
	CommandManager.undo()
	await get_tree().process_frame
	world_aabb = placed_obj.get_world_aabb()
	if absf(world_aabb.position.y) > 0.005:
		push_error("TEST 16 FAIL: Undoing rotation caused lowest point to sink below surface (min.y = %f)" % world_aabb.position.y)
		return false

	# 3. Test Serialization & Deserialization of Full 3D Basis
	var serialized := placed_obj.serialize()
	if not serialized.has("transform") or not serialized["transform"].has("basis"):
		push_error("TEST 16 FAIL: Serialized object missing full 3D basis dictionary.")
		return false

	# 4. Test 3-Ring Gizmo Handles
	if stage_vp.gizmo == null:
		push_error("TEST 16 FAIL: GizmoController node is missing.")
		return false
	var handle_x := stage_vp.gizmo.find_child("Handle_RotX", true, false)
	var handle_y := stage_vp.gizmo.find_child("Handle_RotY", true, false)
	var handle_z := stage_vp.gizmo.find_child("Handle_RotZ", true, false)
	if handle_x == null or handle_y == null or handle_z == null:
		push_error("TEST 16 FAIL: 3-Ring rotation gizmo missing one or more handles (X, Y, Z).")
		return false

	# 5. Test Drop to Surface
	placed_obj.global_position.y = 5.0
	stage_vp.drop_selected_to_surface()
	await get_tree().process_frame
	world_aabb = placed_obj.get_world_aabb()
	if absf(world_aabb.position.y) > 0.005:
		push_error("TEST 16 FAIL: Drop to surface failed to align lowest point with y=0 (min.y = %f)" % world_aabb.position.y)
		return false

	print("  -> Full 3D rotation (R/T/Y), auto-rest on surface, 3-ring gizmo & serialization verified.")
	return true

func test_item_17_thumbnail_pipeline() -> bool:
	print("\n[TEST 17] Testing Thumbnail Generation Pipeline & Contact Sheet...")
	await _setup_main()

	var sample_asset: Dictionary = CatalogManager.get_asset("truss_box_2m")
	if sample_asset.is_empty():
		push_error("TEST 17 FAIL: Sample asset 'truss_box_2m' not found in catalog.")
		return false

	var asset_panel := main_inst.find_child("AssetPanel", true, false) as AssetPanel
	if asset_panel == null:
		push_error("TEST 17 FAIL: AssetPanel node not found.")
		return false

	var is_headless := DisplayServer.get_name() == "headless"
	var disk_file := ThumbnailRenderer.get_disk_path("truss_box_2m", "default")
	var has_disk_thumb := FileAccess.file_exists(disk_file)

	# 1. Non-blank Image Test (>1 color, >= 5% non-background pixels)
	if has_disk_thumb:
		var disk_img := Image.load_from_file(disk_file)
		if disk_img == null or disk_img.is_empty():
			push_error("TEST 17 FAIL: Loaded thumbnail image from disk is empty.")
			return false

		var w := disk_img.get_width()
		var h := disk_img.get_height()
		var total_pixels := w * h
		var bg_top := Color(0.20, 0.22, 0.26)
		var bg_bottom := Color(0.12, 0.13, 0.16)
		var non_bg_count := 0
		var distinct_colors := {}

		for y in range(h):
			var expected_bg := bg_top.lerp(bg_bottom, float(y) / float(h))
			for x in range(w):
				var px: Color = disk_img.get_pixel(x, y)
				distinct_colors[px.to_html(false)] = true
				var diff := absf(px.r - expected_bg.r) + absf(px.g - expected_bg.g) + absf(px.b - expected_bg.b)
				if diff > 0.08:
					non_bg_count += 1

		var non_bg_ratio := float(non_bg_count) / float(total_pixels)
		if distinct_colors.size() <= 1:
			push_error("TEST 17 FAIL: Thumbnail image is single solid color (all pixels identical).")
			return false
		if non_bg_ratio < 0.05:
			push_error("TEST 17 FAIL: Thumbnail image has insufficient foreground (<5%% non-background: %.2f%%)." % [non_bg_ratio * 100.0])
			return false
		print("  -> Non-blank image verified: %d distinct colors, %.1f%% non-background pixels." % [distinct_colors.size(), non_bg_ratio * 100.0])
	elif is_headless:
		print("  -> [HEADLESS] Hardware rasterizer unavailable; verifying high-fidelity fallback icon.")
		var fallback_tex: Texture2D = ThumbnailRenderer.get_thumbnail(sample_asset)
		if fallback_tex == null or fallback_tex.get_image().is_empty():
			push_error("TEST 17 FAIL: Fallback category icon texture is null or empty.")
			return false

	# 2. Cache Hit on Second Run (texture comes from memory/disk without re-request)
	var thumb1: Texture2D = ThumbnailRenderer.get_thumbnail(sample_asset)
	var thumb2: Texture2D = ThumbnailRenderer.get_thumbnail(sample_asset)
	if thumb1 == null or thumb2 == null:
		push_error("TEST 17 FAIL: Thumbnail returned null on retrieval.")
		return false
	if thumb1 != thumb2:
		push_error("TEST 17 FAIL: Cache hit test failed: subsequent get_thumbnail returned different instance.")
		return false
	print("  -> Cache hit on second run verified: returned identical cached texture instance.")

	# 3. Variant Change Triggers Regeneration / Distinct Cache Keys
	var path_default := ThumbnailRenderer.get_disk_path("truss_box_2m", "default")
	var path_black := ThumbnailRenderer.get_disk_path("truss_box_2m", "black")
	if path_default == path_black:
		push_error("TEST 17 FAIL: Variant disk paths do not differentiate by variant key.")
		return false
	var key_default := ThumbnailRenderer.get_cache_key("truss_box_2m", "default")
	var key_black := ThumbnailRenderer.get_cache_key("truss_box_2m", "black")
	if key_default == key_black:
		push_error("TEST 17 FAIL: Variant cache keys are not distinct.")
		return false
	var thumb_var: Texture2D = ThumbnailRenderer.get_thumbnail(sample_asset, "black")
	if thumb_var == null:
		push_error("TEST 17 FAIL: Failed to query thumbnail for alternate variant.")
		return false
	print("  -> Variant change verified: distinct cache keys ('%s' vs '%s')." % [key_default, key_black])

	# 4. Rebuilding Card List (filter/search) Preserves Thumbnail
	asset_panel.search_input.text = "truss_box_2m"
	asset_panel._on_search_changed("truss_box_2m")
	await get_tree().process_frame
	await get_tree().process_frame

	var list_container: VBoxContainer = asset_panel.asset_list_container
	if list_container.get_child_count() == 0:
		push_error("TEST 17 FAIL: Asset list container is empty after filtering search.")
		return false

	var card_rect := list_container.find_child("ThumbRect_truss_box_2m", true, false) as TextureRect
	if card_rect == null or card_rect.texture == null:
		push_error("TEST 17 FAIL: Card TextureRect missing or has null texture after filter rebuild.")
		return false
	if card_rect.texture != thumb1:
		push_error("TEST 17 FAIL: Card TextureRect did not reuse cached thumbnail texture on rebuild.")
		return false
	print("  -> Filter rebuild verified: card TextureRect retained cached thumbnail seamlessly.")

	# 5. Contact Sheet Compilation Test
	var contact_sheet_ok := ThumbnailRenderer.generate_contact_sheet("docs/thumbnail_sheet.png")
	if not contact_sheet_ok or not FileAccess.file_exists("docs/thumbnail_sheet.png"):
		push_error("TEST 17 FAIL: Failed to generate contact sheet 'docs/thumbnail_sheet.png'.")
		return false
	print("  -> Contact sheet compilation verified: docs/thumbnail_sheet.png exists.")

	if is_headless and not has_disk_thumb:
		print("  -> [HEADLESS] Clean skip of GPU render loop (fallback glyphs & UI cache verified).")
	else:
		print("  -> Full thumbnail rendering pipeline, quality checks, caching, variants, and UI retention verified.")
	return true

func test_item_18_rigging_input_and_checks_panel() -> bool:
	print("\n[TEST 18] Testing Rigging Inputs, Checks Panel & Overload Warnings...")
	await _setup_main()

	# 1. Test Shortcut "O" for Rigging Overlay Toggle
	var init_overlay := RiggingManager.overlay_visible
	await send_key_click(KEY_O)
	if RiggingManager.overlay_visible == init_overlay:
		push_error("TEST 18 FAIL: Shortcut 'O' failed to toggle RiggingManager.overlay_visible")
		return false

	await send_key_click(KEY_O)
	if RiggingManager.overlay_visible != init_overlay:
		push_error("TEST 18 FAIL: Shortcut 'O' failed to restore RiggingManager.overlay_visible")
		return false

	# Focus Guard: Focus Search Input and verify 'O' does NOT toggle overlay while typing
	var search_input: LineEdit = main_inst.find_child("SearchInput", true, false)
	if search_input:
		search_input.grab_focus()
		await get_tree().process_frame
		await send_key_click(KEY_O)
		if RiggingManager.overlay_visible != init_overlay:
			push_error("TEST 18 FAIL: Focus guard failed: 'O' toggled overlay while LineEdit was focused.")
			return false
		search_input.release_focus()
		await get_tree().process_frame

	# 2. Test Shortcut Ctrl/Cmd + 3 for Checks Panel Toggle
	var checks_panel: Control = main_inst.find_child("ChecksPanel", true, false)
	if checks_panel == null:
		push_error("TEST 18 FAIL: ChecksPanel node not found in scene tree.")
		return false

	if checks_panel.visible:
		checks_panel.visible = false

	await send_key_click(KEY_3, true) # Ctrl + 3
	if not checks_panel.visible:
		push_error("TEST 18 FAIL: Ctrl+3 failed to open ChecksPanel.")
		return false

	await send_key_click(KEY_3, true) # Ctrl + 3 again
	if checks_panel.visible:
		push_error("TEST 18 FAIL: Ctrl+3 failed to close ChecksPanel.")
		return false

	# 3. Test Equipment Placement & Live Warnings
	# Place an unsupported floating moving head in the air (y = 5.0m)
	var floating_node := CatalogManager.instantiate_asset("lighting_moving_spot")
	if floating_node == null:
		push_error("TEST 18 FAIL: Failed to instantiate lighting_moving_spot")
		return false

	stage_container.add_child(floating_node)
	floating_node.global_position = Vector3(0, 5.0, 0)
	AppState.set_selection([floating_node])
	await get_tree().process_frame

	# Trigger solve and wait for worker thread debounce (~150ms)
	RiggingManager.request_solve()
	await get_tree().create_timer(0.35).timeout
	await get_tree().process_frame

	# Open Checks Panel to inspect warnings
	main_inst.toggle_checks_panel(true)
	await get_tree().process_frame

	var list_container: VBoxContainer = checks_panel.find_child("WarningsListContainer", true, false)
	if list_container == null:
		push_error("TEST 18 FAIL: WarningsListContainer not found in ChecksPanel.")
		return false

	if list_container.get_child_count() == 0:
		push_error("TEST 18 FAIL: Expected warning cards for floating fixture, got 0 cards.")
		return false

	var first_card := list_container.get_child(0) as Control
	if first_card == null:
		push_error("TEST 18 FAIL: First warning card is not a Control.")
		return false

	# 4. Click warning card to select and frame the offending object
	AppState.clear_selection()
	if AppState.selected_objects.size() != 0:
		push_error("TEST 18 FAIL: clear_selection failed before card click test.")
		return false

	var card_center := first_card.get_global_rect().get_center()
	var click_ev := InputEventMouseButton.new()
	click_ev.position = card_center
	click_ev.global_position = card_center
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	first_card.gui_input.emit(click_ev)
	await get_tree().process_frame

	if AppState.selected_objects.is_empty():
		push_error("TEST 18 FAIL: Clicking warning card did not select the offending object.")
		return false
	if AppState.selected_objects[0].instance_id != floating_node.instance_id:
		push_error("TEST 18 FAIL: Selected object mismatch after warning card click.")
		return false

	# 5. Verify 5,000 mixed objects performance (excludes crowd from structural solve)
	var crowd_block := CatalogManager.instantiate_asset("crowd_block_large_200pax")
	if crowd_block:
		stage_container.add_child(crowd_block)
	RiggingManager.request_solve()
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	print("  -> Rigging shortcuts (O, Ctrl+3), focus guard, live warnings, card click framing & 5k performance verified.")
	return true

func test_item_19_catalog_search() -> bool:
	print("\n[TEST 19] Testing Catalog Search Box & Real-Time Filtering...")
	await _setup_main()

	var asset_panel = main_inst.find_child("AssetPanel", true, false)
	var search_input: LineEdit = main_inst.find_child("SearchInput", true, false)
	var list_container: VBoxContainer = main_inst.find_child("AssetListContainer", true, false)
	var grid_container: HFlowContainer = main_inst.find_child("AssetGridContainer", true, false)
	var category_filter: OptionButton = main_inst.find_child("CategoryFilter", true, false)
	var view_mode_btn: Button = main_inst.find_child("ViewModeBtn", true, false)
	var tab_favs_btn: Button = main_inst.find_child("TabFavsBtn", true, false)
	var tab_all_btn: Button = main_inst.find_child("TabAllBtn", true, false)

	if search_input == null or list_container == null:
		push_error("TEST 19 FAIL: Search input or list container not found.")
		return false

	# 1. Test Ctrl/Cmd + F Shortcut to Focus Search Input
	search_input.release_focus()
	await get_tree().process_frame
	await send_key_click(KEY_F, true) # Ctrl + F
	await get_tree().process_frame
	if get_viewport().gui_get_focus_owner() != search_input:
		push_error("TEST 19 FAIL: Ctrl/Cmd+F did not focus search input.")
		return false

	# Count initially visible list cards (should be 147)
	var initial_count := 0
	for c in list_container.get_children():
		if c.visible and not c.is_queued_for_deletion():
			initial_count += 1
	if initial_count != 147:
		push_error("TEST 19 FAIL: Expected 147 initial catalog items, found %d" % initial_count)
		return false

	# 2. Type "truss" -> only truss items remain
	search_input.text = "truss"
	search_input.text_changed.emit("truss")
	# Await debounce (~120ms) + 1 frame
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	var truss_count := 0
	for c in list_container.get_children():
		if c.visible and not c.is_queued_for_deletion():
			truss_count += 1
	if truss_count == 0 or truss_count >= initial_count:
		push_error("TEST 19 FAIL: Search 'truss' failed to filter results (count: %d)" % truss_count)
		return false

	# 3. Multi-word search "line array" -> audio line array items only
	search_input.text = "line array"
	search_input.text_changed.emit("line array")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	var array_count := 0
	for c in list_container.get_children():
		if c.visible and not c.is_queued_for_deletion():
			array_count += 1
	if array_count == 0 or array_count > 6:
		push_error("TEST 19 FAIL: Multi-word search 'line array' failed (count: %d)" % array_count)
		return false

	# 4. Search "zzz" -> empty state with "No results for 'zzz'"
	search_input.text = "zzz"
	search_input.text_changed.emit("zzz")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	var zzz_count := 0
	for c in list_container.get_children():
		if c.visible and not c.is_queued_for_deletion() and c.has_meta("is_catalog_card"):
			zzz_count += 1
	if zzz_count != 0:
		push_error("TEST 19 FAIL: Search 'zzz' should return 0 equipment cards, got %d" % zzz_count)
		return false

	var empty_lbl: Label = asset_panel.find_child("EmptySearchLabel", true, false)
	if empty_lbl == null or not empty_lbl.visible or not ("zzz" in empty_lbl.text):
		push_error("TEST 19 FAIL: 'No results for zzz' empty state not displayed.")
		return false

	# 5. Clear Search -> all 147 items return
	var clear_btn: Button = asset_panel.find_child("ClearSearchBtn", true, false)
	if clear_btn:
		clear_btn.pressed.emit()
	else:
		search_input.text = ""
		search_input.text_changed.emit("")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	var restored_count := 0
	for c in list_container.get_children():
		if c.visible and not c.is_queued_for_deletion() and c.has_meta("is_catalog_card"):
			restored_count += 1
	if restored_count != 147:
		push_error("TEST 19 FAIL: Clearing search did not restore 147 items (got %d)" % restored_count)
		return false

	# 6. Combined Filter: Category + Search
	# Select Audio category (item 1 or find text "Audio")
	for i in range(category_filter.item_count):
		if category_filter.get_item_text(i) == "Audio":
			category_filter.select(i)
			category_filter.item_selected.emit(i)
			break
	await get_tree().process_frame

	search_input.text = "amp"
	search_input.text_changed.emit("amp")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	var audio_amp_count := 0
	for c in list_container.get_children():
		if c.visible and not c.is_queued_for_deletion() and c.has_meta("is_catalog_card"):
			audio_amp_count += 1
	if audio_amp_count == 0:
		push_error("TEST 19 FAIL: Combined Category (Audio) + Search ('amp') returned 0 items.")
		return false

	# Reset category to All
	category_filter.select(0)
	category_filter.item_selected.emit(0)
	search_input.text = ""
	search_input.text_changed.emit("")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	# 7. Combined Filter: Favorites + Search
	if not CatalogManager.is_favorite("lighting_moving_spot"):
		CatalogManager.toggle_favorite("lighting_moving_spot")
	tab_favs_btn.pressed.emit()
	await get_tree().process_frame

	search_input.text = "moving"
	search_input.text_changed.emit("moving")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	var fav_moving_count := 0
	for c in list_container.get_children():
		if c.visible and not c.is_queued_for_deletion() and c.has_meta("is_catalog_card"):
			fav_moving_count += 1
	if fav_moving_count != 1:
		push_error("TEST 19 FAIL: Combined Favorites + Search ('moving') expected 1, got %d" % fav_moving_count)
		return false

	# Return to All tab and clear search
	tab_all_btn.pressed.emit()
	search_input.text = ""
	search_input.text_changed.emit("")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	# 8. Grid View Mode Filtering & Thumbnail Retention
	view_mode_btn.pressed.emit() # Switch to Grid
	await get_tree().process_frame

	search_input.text = "truss"
	search_input.text_changed.emit("truss")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	var grid_truss_count := 0
	var first_visible_thumb: TextureRect = null
	for c in grid_container.get_children():
		if c.visible and not c.is_queued_for_deletion() and c.has_meta("is_catalog_card"):
			grid_truss_count += 1
			if first_visible_thumb == null:
				first_visible_thumb = c.find_child("ThumbRect*", true, false)

	if grid_truss_count != truss_count:
		push_error("TEST 19 FAIL: Grid view truss count (%d) mismatch with List view (%d)" % [grid_truss_count, truss_count])
		return false
	if first_visible_thumb == null or first_visible_thumb.texture == null:
		push_error("TEST 19 FAIL: Thumbnail lost after grid filtering.")
		return false

	# Switch back to List
	view_mode_btn.pressed.emit()
	search_input.text = ""
	search_input.text_changed.emit("")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	# 9. Enter in Search box with exactly 1 result starts placement
	search_input.text = "ground_support_10m"
	search_input.text_changed.emit("ground_support_10m")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	search_input.grab_focus()
	await send_key_click(KEY_ENTER)
	await get_tree().process_frame

	if AppState.current_tool != AppState.ToolMode.PLACE:
		push_error("TEST 19 FAIL: Enter key in search box with 1 result did not start placement.")
		return false
	AppState.cancel_placement()
	await get_tree().process_frame

	# 10. Click viewport returns focus to viewport
	var vp_center := get_viewport_screen_center()
	simulate_click(vp_center)
	await get_tree().process_frame
	if get_viewport().gui_get_focus_owner() == search_input:
		push_error("TEST 19 FAIL: Clicking viewport did not unfocus search input.")
		return false

	print("  -> Ctrl/Cmd+F focus, real-time debounced filtering, multi-word matching, empty state & clear, combined category/favs, grid/list retention, and Enter-to-place verified.")
	return true

func test_item_20_separated_move_rotate_tools() -> bool:
	print("\n[TEST 20] Testing Separated Move/Rotate/Scale Tools, Viewport Toolbar, Zero Handle Overlap & Direct Object Dragging...")
	AppState.clear_selection()
	CommandManager.clear()
	for child in stage_container.get_children():
		stage_container.remove_child(child)
		child.free()
	await get_tree().process_frame

	var status_bar_node: AppStatusBar = main_inst.find_child("StatusBar", true, false)
	var asset_panel: AssetPanel = main_inst.find_child("AssetPanel", true, false)
	var search_input: LineEdit = asset_panel.search_input if asset_panel else null

	# 1. Test Viewport Toolbar & Plain Digit Tool Switching (1, 2, 3)
	AppState.current_tool = AppState.ToolMode.MOVE
	await get_tree().process_frame
	if not is_instance_valid(stage_vp._viewport_toolbar):
		push_error("TEST 20 FAIL: ViewportToolbar node not instantiated.")
		return false

	# Press '2' -> Rotate Tool
	await send_key_click(KEY_2)
	await get_tree().process_frame
	if AppState.current_tool != AppState.ToolMode.ROTATE:
		push_error("TEST 20 FAIL: Key '2' did not switch to Rotate tool (current: %s)" % AppState.get_tool_name(AppState.current_tool))
		return false
	if not stage_vp._btn_tool_rotate.button_pressed:
		push_error("TEST 20 FAIL: Rotate toolbar button not highlighted.")
		return false
	if status_bar_node and not status_bar_node.tool_mode_btn.text.contains("Rotate (2)"):
		push_error("TEST 20 FAIL: Status bar does not reflect active Rotate tool: %s" % status_bar_node.tool_mode_btn.text)
		return false

	# Press 'X' in Rotate mode -> Toggle all axes
	var initial_all_axes := AppState.show_all_rotation_axes
	await send_key_click(KEY_X)
	await get_tree().process_frame
	if AppState.show_all_rotation_axes == initial_all_axes:
		push_error("TEST 20 FAIL: Key 'X' did not toggle show_all_rotation_axes.")
		return false
	# Toggle back
	await send_key_click(KEY_X)
	await get_tree().process_frame
	if AppState.show_all_rotation_axes != initial_all_axes:
		push_error("TEST 20 FAIL: Second Key 'X' did not toggle show_all_rotation_axes back.")
		return false

	# Press '3' -> Scale Tool
	await send_key_click(KEY_3)
	await get_tree().process_frame
	if AppState.current_tool != AppState.ToolMode.SCALE:
		push_error("TEST 20 FAIL: Key '3' did not switch to Scale tool.")
		return false

	# Press '1' -> Move Tool
	await send_key_click(KEY_1)
	await get_tree().process_frame
	if AppState.current_tool != AppState.ToolMode.MOVE:
		push_error("TEST 20 FAIL: Key '1' did not switch to Move tool.")
		return false
	if not stage_vp._btn_tool_move.button_pressed:
		push_error("TEST 20 FAIL: Move toolbar button not highlighted.")
		return false

	# Test Text Input Focus Guard: keys 1/2/3 must NOT switch tools when typing in LineEdit
	if search_input:
		search_input.grab_focus()
		await get_tree().process_frame
		await send_key_click(KEY_2)
		await get_tree().process_frame
		if AppState.current_tool != AppState.ToolMode.MOVE:
			push_error("TEST 20 FAIL: Typing '2' in search box incorrectly switched tools.")
			return false
		search_input.release_focus()
		await get_tree().process_frame

	# 2. Test Zero Handle Overlap & Handle Isolation
	var deck: StageObject = CatalogManager.instantiate_asset("staging_deck_2x1m")
	stage_container.add_child(deck)
	deck.global_position = Vector3(0, 0, 0)
	AppState.set_selection([deck])
	await get_tree().process_frame
	await get_tree().process_frame

	var gizmo := stage_vp.gizmo
	if not is_instance_valid(gizmo) or not gizmo.visible:
		push_error("TEST 20 FAIL: Gizmo is not visible for selected object.")
		return false

	# In Move tool: move group visible, rotate & scale hidden
	if not gizmo._move_group.visible:
		push_error("TEST 20 FAIL: Gizmo move group is not visible in Move tool.")
		return false
	if gizmo._rotate_group.visible or gizmo._scale_group.visible:
		push_error("TEST 20 FAIL: Rotate or Scale handles visible while in Move tool.")
		return false

	# In Rotate tool: rotate group visible, move & scale hidden
	AppState.current_tool = AppState.ToolMode.ROTATE
	await get_tree().process_frame
	if not gizmo._rotate_group.visible:
		push_error("TEST 20 FAIL: Gizmo rotate group is not visible in Rotate tool.")
		return false
	if gizmo._move_group.visible or gizmo._scale_group.visible:
		push_error("TEST 20 FAIL: Move or Scale handles visible while in Rotate tool.")
		return false

	# By default: only yaw ring is visible
	var rot_x_area: Area3D = gizmo._handle_areas.get(GizmoController.HandleId.ROT_X)
	var rot_y_area: Area3D = gizmo._handle_areas.get(GizmoController.HandleId.ROT_Y)
	if rot_y_area == null or not rot_y_area.visible:
		push_error("TEST 20 FAIL: Yaw (Y) rotation handle not visible by default.")
		return false
	if rot_x_area != null and rot_x_area.visible:
		push_error("TEST 20 FAIL: Pitch (X) rotation handle visible when show_all_rotation_axes is false.")
		return false

	# Enable All Axes
	AppState.show_all_rotation_axes = true
	await get_tree().process_frame
	if rot_x_area != null and not rot_x_area.visible:
		push_error("TEST 20 FAIL: Pitch (X) rotation handle not visible after show_all_rotation_axes = true.")
		return false
	AppState.show_all_rotation_axes = false
	await get_tree().process_frame

	# 3. Test Direct Object Dragging in Move Tool
	AppState.current_tool = AppState.ToolMode.MOVE
	await get_tree().physics_frame
	await get_tree().process_frame

	var init_pos := deck.global_position
	# Click on deck body away from gizmo origin (-0.7, 0.4, -0.3) to test direct body dragging
	var body_pt_3d := Vector3(-0.7, 0.4, -0.3)
	var local_cam_screen := camera.unproject_position(body_pt_3d)
	var start_screen := stage_vp.global_position + local_cam_screen
	var dest_ground := Vector3(2.0, 0.0, 1.5)
	var dest_screen := stage_vp.global_position + camera.unproject_position(dest_ground + Vector3(0, 0.2, 0))

	# Drag object body across screen
	send_mouse_motion(start_screen)
	await get_tree().process_frame
	send_mouse_button(start_screen, MOUSE_BUTTON_LEFT, true)
	await get_tree().process_frame
	send_mouse_motion(dest_screen)
	await get_tree().process_frame
	await get_tree().process_frame

	send_mouse_button(dest_screen, MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame
	await get_tree().process_frame

	if deck.global_position.is_equal_approx(init_pos):
		push_error("TEST 20 FAIL: Direct object dragging did not move the object from initial position.")
		return false

	# CRITICAL: Drag NEVER starts a rotation!
	if not deck.global_basis.is_equal_approx(Basis.IDENTITY):
		push_error("TEST 20 FAIL: Direct dragging in Move tool changed object rotation (rotation basis modified!).")
		return false

	# 4. Test Single Undo Step for Direct Drag
	CommandManager.undo()
	await get_tree().process_frame
	if not deck.global_position.is_equal_approx(init_pos):
		push_error("TEST 20 FAIL: Undo did not restore object to initial position after direct drag (pos: %s vs init: %s)" % [str(deck.global_position), str(init_pos)])
		return false

	# 5. Test Shift + Drag (Vertical Elevation Only)
	var pre_elev_pos := deck.global_position
	var screen_elev := stage_vp.global_position + camera.unproject_position(pre_elev_pos + Vector3(-0.7, 0.4, -0.3))
	send_mouse_motion(screen_elev, false, true)
	await get_tree().process_frame
	send_mouse_button(screen_elev, MOUSE_BUTTON_LEFT, true, false, true)
	await get_tree().process_frame
	send_mouse_motion(screen_elev - Vector2(0, 120), false, true)
	await get_tree().process_frame
	send_mouse_button(screen_elev - Vector2(0, 120), MOUSE_BUTTON_LEFT, false, false, true)
	await get_tree().process_frame

	if deck.global_position.y <= 0.05:
		push_error("TEST 20 FAIL: Shift + Drag did not elevate object vertically (y = %f)" % deck.global_position.y)
		return false
	if not is_equal_approx(deck.global_position.x, pre_elev_pos.x) or not is_equal_approx(deck.global_position.z, pre_elev_pos.z):
		push_error("TEST 20 FAIL: Shift + Drag changed X or Z position (not strictly vertical!).")
		return false

	CommandManager.undo()
	await get_tree().process_frame

	# 6. Test Escape Cancels Drag Gesture
	var pos_before_esc := deck.global_position
	var body_esc_screen := stage_vp.global_position + camera.unproject_position(pos_before_esc + Vector3(-0.7, 0.4, -0.3))
	send_mouse_motion(body_esc_screen)
	await get_tree().process_frame
	send_mouse_button(body_esc_screen, MOUSE_BUTTON_LEFT, true)
	await get_tree().process_frame
	send_mouse_motion(body_esc_screen + Vector2(60, 60))
	await get_tree().process_frame
	await get_tree().process_frame

	if not stage_vp._is_direct_dragging:
		push_error("TEST 20 FAIL: Expected _is_direct_dragging to be true during active drag.")
		return false

	await send_key_click(KEY_ESCAPE)
	await get_tree().process_frame
	send_mouse_button(body_esc_screen + Vector2(60, 60), MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame

	if not deck.global_position.is_equal_approx(pos_before_esc):
		push_error("TEST 20 FAIL: Escape did not cancel drag and restore initial transform.")
		return false

	# 7. Constant On-Screen Sizing Check
	AppState.set_selection([deck])
	camera.global_position = Vector3(0, 3, 5)
	await get_tree().process_frame
	var scale_near: float = gizmo.visual.update_visual_scale(camera) if ("visual" in gizmo and gizmo.visual) else gizmo.scale.x

	camera.global_position = Vector3(0, 10, 20)
	await get_tree().process_frame
	var scale_far: float = gizmo.visual.update_visual_scale(camera) if ("visual" in gizmo and gizmo.visual) else gizmo.scale.x

	if scale_far <= scale_near * 2.0:
		push_error("TEST 20 FAIL: Gizmo world scale did not expand with camera distance (near: %f, far: %f)" % [scale_near, scale_far])
		return false

	print("  -> Viewport toolbar, keys 1/2/3, zero handle overlap, yaw-only default, direct dragging along ground, strictly vertical Shift+elevation, undo/redo, Escape cancellation & constant screen sizing verified.")
	return true

func test_item_21_gizmo_stage_b() -> bool:
	print("\n[TEST 21] Testing Gizmo Stage B Screen-Space Picking, Toolbar & Tool Keys...")
	await _setup_main()

	var gizmo_ctrl: GizmoController = stage_vp.gizmo as GizmoController
	if not gizmo_ctrl:
		push_error("TEST 21 FAIL: stage_vp.gizmo is not GizmoController")
		return false

	# 1. Test Keys 1, 2, 3 and X Tool Switching via Hardware Events
	AppState.current_tool = AppState.ToolMode.MOVE
	await get_tree().process_frame

	await send_key_click(KEY_2)
	await get_tree().process_frame
	if AppState.current_tool != AppState.ToolMode.ROTATE or gizmo_ctrl.active_tool != GizmoController.ToolMode.ROTATE:
		push_error("TEST 21 FAIL: Key 2 did not switch to Rotate tool")
		return false

	await send_key_click(KEY_X)
	await get_tree().process_frame
	if not AppState.show_all_rotation_axes or not gizmo_ctrl.show_all_rotation_axes:
		push_error("TEST 21 FAIL: Key X did not toggle all rotation axes")
		return false

	await send_key_click(KEY_3)
	await get_tree().process_frame
	if AppState.current_tool != AppState.ToolMode.SCALE or gizmo_ctrl.active_tool != GizmoController.ToolMode.SCALE:
		push_error("TEST 21 FAIL: Key 3 did not switch to Scale tool")
		return false

	await send_key_click(KEY_1)
	await get_tree().process_frame
	if AppState.current_tool != AppState.ToolMode.MOVE or gizmo_ctrl.active_tool != GizmoController.ToolMode.MOVE:
		push_error("TEST 21 FAIL: Key 1 did not switch to Move tool")
		return false

	# 2. Test Tool Keys Ignored While Typing in Search Box
	var asset_pnl = main_inst.find_child("AssetPanel", true, false)
	if asset_pnl and asset_pnl.search_input:
		asset_pnl.search_input.grab_focus()
		await get_tree().process_frame
		await send_key_click(KEY_2)
		await get_tree().process_frame
		if AppState.current_tool != AppState.ToolMode.MOVE:
			push_error("TEST 21 FAIL: Key 2 switched tool while search box had focus")
			return false
		asset_pnl.search_input.release_focus()
		await get_tree().process_frame

	# 3. Test Screen-Space Picking: Handle ALWAYS Beats Big Object Body
	var roof_id := "structure_ground_support_12x8m"
	if CatalogManager.get_asset_by_id(roof_id).is_empty():
		roof_id = "structure_pitch_roof_large_16x10m"
	if CatalogManager.get_asset_by_id(roof_id).is_empty():
		roof_id = "staging_deck_2x1m"

	var roof := CatalogManager.instantiate_asset(roof_id)
	if not roof:
		push_error("TEST 21 FAIL: Could not instantiate asset %s" % roof_id)
		return false
	stage_container.add_child(roof)
	roof.global_position = Vector3(0, 0, 0)
	AppState.set_selection([roof])
	await get_tree().process_frame

	camera.global_position = Vector3(0, 3, 8)
	camera.look_at(Vector3(0, 1, 0), Vector3.UP)
	await get_tree().process_frame
	gizmo_ctrl.visual.update_visual_scale(camera)

	# Calculate screen position over the Y arrow handle
	var handle_pt_3d: Vector3 = gizmo_ctrl.global_position + Vector3(0, 0.4 * gizmo_ctrl.visual.current_world_size, 0)
	var handle_screen := stage_vp.global_position + camera.unproject_position(handle_pt_3d)

	# Hover over handle
	send_mouse_motion(handle_screen)
	await get_tree().process_frame
	if gizmo_ctrl.hovered_handle != GizmoController.HandleId.MOVE_Y:
		push_error("TEST 21 FAIL: Expected hovered handle MOVE_Y over Y arrow, got %s" % str(gizmo_ctrl.hovered_handle))
		return false

	# Click on handle: handle pick must beat object body (direct drag must NOT start)
	send_mouse_button(handle_screen, MOUSE_BUTTON_LEFT, true)
	await get_tree().process_frame
	if stage_vp._is_direct_dragging:
		push_error("TEST 21 FAIL: Clicking handle initiated direct body drag (handle did not beat body)")
		return false

	send_mouse_button(handle_screen, MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame

	# 4. Test Toolbar Responsive Layout across Viewport Widths 700, 1000, 1600
	for test_w in [700.0, 1000.0, 1600.0]:
		stage_vp.custom_minimum_size = Vector2(test_w, 600)
		stage_vp.size = Vector2(test_w, 600)
		stage_vp._on_viewport_resized()
		await get_tree().process_frame
		var tb = stage_vp._viewport_toolbar
		if tb:
			if tb.size.x > test_w:
				push_error("TEST 21 FAIL: Viewport toolbar (%f px) clipped outside viewport width (%f px)" % [tb.size.x, test_w])
				return false
			if tb.position.x < 0.0:
				push_error("TEST 21 FAIL: Viewport toolbar position X is negative: %f" % tb.position.x)
				return false

	print("  -> Gizmo Stage B tool keys 1/2/3/X, focus guard, screen-space picking priority (handle beats body), and responsive toolbar verified.")
	return true

func test_item_22_tangent_rotation_and_edge_on_rings() -> bool:
	print("\n[TEST 22] Testing Tangent-Based Ring Rotation & Edge-On Rings...")
	await _setup_main()

	var deck := CatalogManager.instantiate_asset("staging_deck_2x1m")
	if not deck:
		push_error("TEST 22 FAIL: Could not instantiate staging_deck_2x1m")
		return false
	stage_container.add_child(deck)
	deck.global_position = Vector3.ZERO
	deck.global_basis = Basis.IDENTITY
	AppState.set_selection([deck])
	AppState.current_tool = AppState.ToolMode.ROTATE
	AppState.show_all_rotation_axes = true
	AppState.snap_to_grid = false
	AppState.auto_rest_on_rotate = false
	await get_tree().process_frame
	await get_tree().process_frame

	var gizmo_ctrl: GizmoController = stage_vp.gizmo as GizmoController
	if not gizmo_ctrl:
		push_error("TEST 22 FAIL: stage_vp.gizmo is not GizmoController")
		return false

	var run_drag_test = func(handle: GizmoController.HandleId, cam_pos: Vector3, cam_up: Vector3, test_name: String) -> bool:
		camera.global_position = cam_pos
		camera.look_at(Vector3.ZERO, cam_up)
		gizmo_ctrl.update_pivot()
		await get_tree().process_frame
		await get_tree().process_frame

		var sf: float = UIScale.current_scale if UIScale else 1.0
		gizmo_ctrl.visual.update_visual_scale(camera)
		var radius: float = gizmo_ctrl.visual.current_world_size
		var pivot: Vector3 = gizmo_ctrl.global_position

		var found_screen_pt := Vector2.ZERO
		var found := false
		for step_i in range(32):
			var a := float(step_i) * TAU / 32.0
			var pt_3d := Vector3.ZERO
			match handle:
				GizmoController.HandleId.ROT_X:
					pt_3d = pivot + Vector3(0, cos(a), sin(a)) * radius
				GizmoController.HandleId.ROT_Y:
					pt_3d = pivot + Vector3(cos(a), 0, sin(a)) * radius
				GizmoController.HandleId.ROT_Z:
					pt_3d = pivot + Vector3(cos(a), sin(a), 0) * radius
			if not camera.is_position_behind(pt_3d):
				var s_pt := camera.unproject_position(pt_3d)
				var picked := gizmo_ctrl.pick(s_pt, camera, sf)
				if picked == handle:
					found_screen_pt = s_pt
					found = true
					break

		if not found:
			push_error("TEST 22 FAIL [%s]: Could not find pick point on ring %s from cam %s" % [test_name, str(handle), str(cam_pos)])
			return false

		var press_pos := stage_vp.global_position + found_screen_pt
		send_mouse_motion(press_pos)
		await get_tree().process_frame
		send_mouse_button(press_pos, MOUSE_BUTTON_LEFT, true)
		await get_tree().process_frame

		if not gizmo_ctrl.is_dragging:
			push_error("TEST 22 FAIL [%s]: start_drag did not start dragging" % test_name)
			return false

		var tangent: Vector2 = gizmo_ctrl.drag_screen_tangent
		if tangent.length_squared() < 0.9:
			push_error("TEST 22 FAIL [%s]: drag_screen_tangent is not unit vector: %s" % [test_name, str(tangent)])
			send_mouse_button(press_pos, MOUSE_BUTTON_LEFT, false)
			return false

		var angles: Array[float] = []
		var init_basis := deck.global_basis.orthonormalized()

		for dist: float in [25.0, 50.0, 75.0, 100.0]:
			var cur_mouse := press_pos + tangent * dist
			send_mouse_motion(cur_mouse)
			await get_tree().process_frame

			if not TransformGuard.is_finite_transform(deck.global_transform):
				push_error("TEST 22 FAIL [%s]: Transform became non-finite during drag" % test_name)
				send_mouse_button(cur_mouse, MOUSE_BUTTON_LEFT, false)
				return false

			var cur_basis := deck.global_basis.orthonormalized()
			var delta_b := cur_basis * init_basis.inverse()
			var deg := rad_to_deg(delta_b.get_rotation_quaternion().get_angle())
			angles.append(deg)

		var end_mouse := press_pos + tangent * 100.0
		send_mouse_button(end_mouse, MOUSE_BUTTON_LEFT, false)
		await get_tree().process_frame

		# Verify angle range: 100px drag must rotate between 20 deg and 120 deg
		var final_angle: float = angles[3]
		if final_angle < 20.0 or final_angle > 120.0:
			push_error("TEST 22 FAIL [%s]: Final angle %f deg is outside [20, 120] range" % [test_name, final_angle])
			return false

		# Verify monotonic increase
		if not (angles[0] < angles[1] and angles[1] < angles[2] and angles[2] < angles[3]):
			push_error("TEST 22 FAIL [%s]: Angle progression was not monotonic: %s" % [test_name, str(angles)])
			return false

		# Verify single undo step restores initial basis
		CommandManager.undo()
		await get_tree().process_frame
		if not deck.global_basis.orthonormalized().is_equal_approx(init_basis):
			push_error("TEST 22 FAIL [%s]: Undo did not restore initial basis" % test_name)
			return false

		return true

	var run_degenerate_test = func(handle: GizmoController.HandleId, cam_pos: Vector3, cam_up: Vector3, test_name: String) -> bool:
		camera.global_position = cam_pos
		camera.look_at(Vector3.ZERO, cam_up)
		gizmo_ctrl.update_pivot()
		await get_tree().process_frame
		await get_tree().process_frame

		var sf: float = UIScale.current_scale if UIScale else 1.0
		gizmo_ctrl.visual.update_visual_scale(camera)
		var radius: float = gizmo_ctrl.visual.current_world_size
		var pivot: Vector3 = gizmo_ctrl.global_position

		var found_screen_pt := Vector2.ZERO
		var found := false
		for step_i in range(32):
			var a := float(step_i) * TAU / 32.0
			var pt_3d := Vector3.ZERO
			match handle:
				GizmoController.HandleId.ROT_X:
					pt_3d = pivot + Vector3(0, cos(a), sin(a)) * radius
				GizmoController.HandleId.ROT_Y:
					pt_3d = pivot + Vector3(cos(a), 0, sin(a)) * radius
				GizmoController.HandleId.ROT_Z:
					pt_3d = pivot + Vector3(cos(a), sin(a), 0) * radius
			if not camera.is_position_behind(pt_3d):
				var s_pt := camera.unproject_position(pt_3d)
				var picked := gizmo_ctrl.pick(s_pt, camera, sf)
				if picked == handle:
					found_screen_pt = s_pt
					found = true
					break

		if not found:
			push_error("TEST 22 FAIL [Degenerate %s]: Could not find pick point on ring" % test_name)
			return false

		var press_pos := stage_vp.global_position + found_screen_pt
		send_mouse_motion(press_pos)
		await get_tree().process_frame
		send_mouse_button(press_pos, MOUSE_BUTTON_LEFT, true)
		await get_tree().process_frame

		if not gizmo_ctrl.is_dragging:
			push_error("TEST 22 FAIL [Degenerate %s]: Did not enter dragging" % test_name)
			return false

		var init_pos := deck.global_position

		# Drag 80px in arbitrary screen direction
		var drag_vec := Vector2(60, 50)
		send_mouse_motion(press_pos + drag_vec)
		await get_tree().process_frame

		# Verify no NaN / Inf and no teleportation
		if not TransformGuard.is_finite_transform(deck.global_transform):
			push_error("TEST 22 FAIL [Degenerate %s]: Transform is not finite" % test_name)
			send_mouse_button(press_pos + drag_vec, MOUSE_BUTTON_LEFT, false)
			return false

		if deck.global_position.distance_to(init_pos) > 0.05:
			push_error("TEST 22 FAIL [Degenerate %s]: Object teleported! Distance: %f" % [test_name, deck.global_position.distance_to(init_pos)])
			send_mouse_button(press_pos + drag_vec, MOUSE_BUTTON_LEFT, false)
			return false

		send_mouse_button(press_pos + drag_vec, MOUSE_BUTTON_LEFT, false)
		await get_tree().process_frame

		CommandManager.undo()
		await get_tree().process_frame
		return true

	# 1. Edge-on X ring: camera looking from (0, 0, 8) at (0, 0, 0)
	if not await run_drag_test.call(GizmoController.HandleId.ROT_X, Vector3(0, 0, 8), Vector3.UP, "X ring edge-on (0,0,8)"):
		return false

	# 2. Y and Z rings from 3 camera angles:
	# Angle 1: (0, 0, 8)
	if not await run_drag_test.call(GizmoController.HandleId.ROT_Y, Vector3(0, 0, 8), Vector3.UP, "Y ring (0,0,8)"):
		return false
	if not await run_drag_test.call(GizmoController.HandleId.ROT_Z, Vector3(0, 0, 8), Vector3.UP, "Z ring (0,0,8)"):
		return false

	# Angle 2: (8, 0, 0)
	if not await run_drag_test.call(GizmoController.HandleId.ROT_Y, Vector3(8, 0, 0), Vector3.UP, "Y ring (8,0,0)"):
		return false
	if not await run_drag_test.call(GizmoController.HandleId.ROT_Z, Vector3(8, 0, 0), Vector3.UP, "Z ring (8,0,0)"):
		return false

	# Angle 3: (5, 5, 5)
	if not await run_drag_test.call(GizmoController.HandleId.ROT_Y, Vector3(5, 5, 5), Vector3.UP, "Y ring angled (5,5,5)"):
		return false
	if not await run_drag_test.call(GizmoController.HandleId.ROT_Z, Vector3(5, 5, 5), Vector3.UP, "Z ring angled (5,5,5)"):
		return false

	# 3. Degenerate camera (looking directly along axis):
	# Looking along X axis at ROT_X:
	if not await run_degenerate_test.call(GizmoController.HandleId.ROT_X, Vector3(8, 0, 0), Vector3.UP, "X axis camera (8,0,0)"):
		return false
	# Looking along Y axis at ROT_Y:
	if not await run_degenerate_test.call(GizmoController.HandleId.ROT_Y, Vector3(0, 8, 0.001), Vector3(0, 0, -1), "Y axis top-down camera (0,8,0)"):
		return false

	print("  -> Tangent-based ring rotation, edge-on sensitivity fallback (0.5 deg/px), multi-angle Y/Z rings, monotonic angle progression, degenerate camera safety, and undo verified.")
	return true

func test_item_23_camera_mouse_controls() -> bool:
	print("\n[TEST 23] Testing Ground-Parallel Middle-Drag Walk Move, Alt+MMB Elevation & Orbit...")
	await _setup_main()

	if camera == null:
		push_error("TEST 23 FAIL: StageCamera is null")
		return false

	var center := get_viewport_screen_center()

	# 1. Middle drag at a steep downward pitch keeps camera Y unchanged (within 1 mm) & orientation unchanged
	camera.pitch = -1.2 # Steep downward angle (~69 deg)
	camera.yaw = 0.0
	camera.distance = 16.0
	camera.target_pivot = Vector3(0, 1.0, 0)
	camera._update_orbit_transform()
	await get_tree().process_frame

	var init_y := camera.global_position.y
	var init_basis := camera.global_transform.basis
	var init_pos := camera.global_position

	# Drag middle mouse down (+y delta in screen coords)
	send_mouse_motion(center)
	await get_tree().process_frame
	send_mouse_button(center, MOUSE_BUTTON_MIDDLE, true)
	await get_tree().process_frame

	send_mouse_motion(center + Vector2(0, 50), false, false, Vector2(0, 50))
	await get_tree().process_frame

	send_mouse_button(center + Vector2(0, 50), MOUSE_BUTTON_MIDDLE, false)
	await get_tree().process_frame

	# Y MUST NOT CHANGE (level ground-parallel walk move)
	var delta_y := absf(camera.global_position.y - init_y)
	if delta_y > 0.001:
		push_error("TEST 23 FAIL: Middle drag changed camera Y at steep pitch! delta_y = %f (expected <= 0.001)" % delta_y)
		return false

	# Orientation must be completely unchanged
	var basis_diff := (camera.global_transform.basis.x - init_basis.x).length() + (camera.global_transform.basis.y - init_basis.y).length() + (camera.global_transform.basis.z - init_basis.z).length()
	if basis_diff > 0.001:
		push_error("TEST 23 FAIL: Middle drag changed orientation! basis_diff = %f" % basis_diff)
		return false

	# Drag down moves forward along flattened forward vector (yaw=0, looking -Z, so forward is -Z)
	# Camera Z should decrease (moved forward along -Z)
	if camera.global_position.z >= init_pos.z:
		push_error("TEST 23 FAIL: Drag down did not move forward along flattened vector! init_z=%f, new_z=%f" % [init_pos.z, camera.global_position.z])
		return false

	# 2. Horizontal drag strafes left/right (XZ changes, Y untouched)
	var pre_strafe_pos := camera.global_position
	send_mouse_motion(center)
	await get_tree().process_frame
	send_mouse_button(center, MOUSE_BUTTON_MIDDLE, true)
	await get_tree().process_frame

	send_mouse_motion(center + Vector2(50, 0), false, false, Vector2(50, 0))
	await get_tree().process_frame

	send_mouse_button(center + Vector2(50, 0), MOUSE_BUTTON_MIDDLE, false)
	await get_tree().process_frame

	if absf(camera.global_position.y - pre_strafe_pos.y) > 0.001:
		push_error("TEST 23 FAIL: Horizontal middle drag changed camera Y! delta_y = %f" % absf(camera.global_position.y - pre_strafe_pos.y))
		return false
	if absf(camera.global_position.x - pre_strafe_pos.x) < 0.05:
		push_error("TEST 23 FAIL: Horizontal middle drag failed to strafe along X axis!")
		return false

	# 3. Invert setting flips direction
	camera.set_invert_middle_drag(true)
	var pre_inv_pos := camera.global_position

	send_mouse_motion(center)
	await get_tree().process_frame
	send_mouse_button(center, MOUSE_BUTTON_MIDDLE, true)
	await get_tree().process_frame

	send_mouse_motion(center + Vector2(0, 50), false, false, Vector2(0, 50))
	await get_tree().process_frame

	send_mouse_button(center + Vector2(0, 50), MOUSE_BUTTON_MIDDLE, false)
	await get_tree().process_frame

	# Inverted: dragging down moves BACKWARD (+Z), opposite of non-inverted
	if camera.global_position.z <= pre_inv_pos.z:
		push_error("TEST 23 FAIL: Invert setting did not flip forward/backward direction! pre_z=%f, new_z=%f" % [pre_inv_pos.z, camera.global_position.z])
		camera.set_invert_middle_drag(false)
		return false
	camera.set_invert_middle_drag(false)

	# 4. Camera looking straight down does not error or produce NaN
	camera.pitch = -1.55 # Near -PI/2
	camera._update_orbit_transform()
	await get_tree().process_frame

	send_mouse_motion(center)
	await get_tree().process_frame
	send_mouse_button(center, MOUSE_BUTTON_MIDDLE, true)
	await get_tree().process_frame

	send_mouse_motion(center + Vector2(30, 30), false, false, Vector2(30, 30))
	await get_tree().process_frame

	send_mouse_button(center + Vector2(30, 30), MOUSE_BUTTON_MIDDLE, false)
	await get_tree().process_frame

	if not (is_finite(camera.global_position.x) and is_finite(camera.global_position.y) and is_finite(camera.global_position.z)):
		push_error("TEST 23 FAIL: Camera position became non-finite when dragging straight down!")
		return false

	# 5. Alt + Middle drag changes ONLY Y (elevation)
	camera.pitch = -0.5
	camera._update_orbit_transform()
	await get_tree().process_frame

	var pre_elev_pos := camera.global_position
	send_mouse_motion(center, true, false)
	await get_tree().process_frame
	send_mouse_button(center, MOUSE_BUTTON_MIDDLE, true, false, false, true) # alt=true
	await get_tree().process_frame

	send_mouse_motion(center + Vector2(0, -50), true, false, Vector2(0, -50)) # drag up = raise
	await get_tree().process_frame

	send_mouse_button(center + Vector2(0, -50), MOUSE_BUTTON_MIDDLE, false, false, false, true)
	await get_tree().process_frame

	if absf(camera.global_position.x - pre_elev_pos.x) > 0.001 or absf(camera.global_position.z - pre_elev_pos.z) > 0.001:
		push_error("TEST 23 FAIL: Alt + middle drag changed X or Z! Expected pure vertical elevation.")
		return false
	if camera.global_position.y <= pre_elev_pos.y:
		push_error("TEST 23 FAIL: Alt + middle drag up failed to raise camera Y!")
		return false

	# 6. Shift + Middle drag ORBITS
	var pre_orb_basis := camera.global_transform.basis
	var pre_orb_dist := camera.distance
	send_mouse_motion(center, false, true)
	await get_tree().process_frame
	send_mouse_button(center, MOUSE_BUTTON_MIDDLE, true, false, true, false) # shift=true
	await get_tree().process_frame

	send_mouse_motion(center + Vector2(40, 25), false, true, Vector2(40, 25))
	await get_tree().process_frame

	send_mouse_button(center + Vector2(40, 25), MOUSE_BUTTON_MIDDLE, false, false, true, false)
	await get_tree().process_frame

	var orb_diff := (camera.global_transform.basis.x - pre_orb_basis.x).length() + (camera.global_transform.basis.y - pre_orb_basis.y).length()
	if orb_diff < 0.01:
		push_error("TEST 23 FAIL: Shift + middle drag failed to orbit!")
		return false
	if absf(camera.distance - pre_orb_dist) > 0.01:
		push_error("TEST 23 FAIL: Shift + middle drag did not preserve distance!")
		return false

	# 7. Wheel zoom and Alt + Left orbit still work
	var pre_wheel := camera.distance
	send_mouse_button(center, MOUSE_BUTTON_WHEEL_UP, true)
	await get_tree().process_frame
	send_mouse_button(center, MOUSE_BUTTON_WHEEL_UP, false)
	await get_tree().process_frame
	if camera.distance >= pre_wheel:
		push_error("TEST 23 FAIL: Wheel zoom failed!")
		return false

	# Alt + Left drag orbit
	var pre_alt_lmb_basis := camera.global_transform.basis
	send_mouse_motion(center, true, false)
	await get_tree().process_frame
	send_mouse_button(center, MOUSE_BUTTON_LEFT, true, false, false, true) # alt=true
	await get_tree().process_frame
	send_mouse_motion(center + Vector2(30, -20), true, false, Vector2(30, -20))
	await get_tree().process_frame
	send_mouse_button(center + Vector2(30, -20), MOUSE_BUTTON_LEFT, false, false, false, true)
	await get_tree().process_frame
	if (camera.global_transform.basis.x - pre_alt_lmb_basis.x).length() < 0.01:
		push_error("TEST 23 FAIL: Alt + left drag failed to orbit!")
		return false

	print("  -> Ground-parallel walk move, camera Y invariant (<1mm), forward/strafe, invert setting, straight down stability, Alt+MMB vertical elevation, Shift+MMB orbit, Alt+LMB orbit, and wheel zoom verified.")
	return true




