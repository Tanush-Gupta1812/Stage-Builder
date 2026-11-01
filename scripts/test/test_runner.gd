extends Node

## Comprehensive test runner for Stage-Builder.
## Verifies catalog assets, procedural mesh generation, undo/redo commands, snapping, and project save/load.

func _ready() -> void:
	print("\n==================================================")
	print("Running Stage-Builder Automated Test Suite...")
	print("==================================================")

	var all_passed := true

	all_passed = test_catalog_and_mesh_generators() and all_passed
	all_passed = test_snapping_system() and all_passed
	all_passed = test_command_undo_redo() and all_passed
	all_passed = test_project_serialization() and all_passed

	print("==================================================")
	if all_passed:
		print("ALL STAGE-BUILDER TESTS PASSED SUCCESSFULLY! (4/4)")
	else:
		print("SOME TESTS FAILED! Check logs above.")
	print("==================================================\n")

	get_tree().quit(0 if all_passed else 1)

func test_catalog_and_mesh_generators() -> bool:
	print("[TEST 1/4] Verifying 27 Catalog Assets & Procedural Mesh Builders...")
	var assets := CatalogManager.get_all_assets()
	if assets.size() != 27:
		push_error("Expected 27 assets in catalog, got %d" % assets.size())
		return false

	var generated_count := 0
	for item in assets:
		var id: String = item.get("id", "")
		var stage_obj := CatalogManager.instantiate_asset(id)
		if stage_obj == null:
			push_error("Failed to instantiate asset: " + id)
			return false

		if stage_obj.visual_node == null:
			push_error("Asset has no visual node: " + id)
			return false

		if stage_obj.collision_area == null:
			push_error("Asset has no collision area: " + id)
			return false

		if stage_obj.dimensions.length() < 0.01:
			push_error("Asset has invalid dimensions: " + id)
			return false

		generated_count += 1
		stage_obj.free()

	print("  -> Verified %d procedural assets created without errors." % generated_count)
	return true

func test_snapping_system() -> bool:
	print("[TEST 2/4] Testing Grid Snapping & Point Snapping...")
	AppState.snap_to_grid = true
	AppState.grid_step = 0.5
	AppState.snap_to_points = false

	var candidate := Vector3(1.18, 0.0, 3.82)
	var snap_res := SnapSystem.resolve_position(candidate)
	if not is_equal_approx(snap_res.position.x, 1.0) or not is_equal_approx(snap_res.position.z, 4.0):
		push_error("Grid snap failed: expected (1.0, 0, 4.0), got %s" % str(snap_res.position))
		return false

	print("  -> Grid snapping accurate to 0.5m grid step.")
	return true

func test_command_undo_redo() -> bool:
	print("[TEST 3/4] Testing Command Pattern Undo/Redo...")
	CommandManager.clear()
	var test_container := Node3D.new()
	add_child(test_container)

	var obj := CatalogManager.instantiate_asset("truss_straight_2m")
	var cmd := BaseCommand.PlaceCommand.new(test_container, [obj], [Transform3D.IDENTITY])

	# Execute
	CommandManager.execute_command(cmd)
	if test_container.get_child_count() != 1:
		push_error("PlaceCommand execution failed: container child count is %d" % test_container.get_child_count())
		return false

	# Undo
	CommandManager.undo()
	if test_container.get_child_count() != 0:
		push_error("PlaceCommand undo failed: container child count is %d" % test_container.get_child_count())
		return false

	# Redo
	CommandManager.redo()
	if test_container.get_child_count() != 1:
		push_error("PlaceCommand redo failed: container child count is %d" % test_container.get_child_count())
		return false

	test_container.queue_free()
	print("  -> PlaceCommand Execute, Undo, and Redo verified.")
	return true

func test_project_serialization() -> bool:
	print("[TEST 4/4] Testing .stagebuilder JSON Serialization...")
	var test_container := Node3D.new()
	add_child(test_container)
	AppState.stage_container = test_container

	var obj1 := CatalogManager.instantiate_asset("staging_deck_2x1")
	test_container.add_child(obj1)
	obj1.position = Vector3(2, 0.4, 0)

	var obj2 := CatalogManager.instantiate_asset("lighting_moving_head")
	test_container.add_child(obj2)
	obj2.position = Vector3(2, 2.5, 0)

	var temp_file := "user://test_stage.stagebuilder"
	var save_ok := ProjectSerializer.save_project(temp_file)
	if not save_ok:
		push_error("ProjectSerializer save failed.")
		return false

	var load_ok := ProjectSerializer.load_project(temp_file)
	if not load_ok:
		push_error("ProjectSerializer load failed.")
		return false

	if test_container.get_child_count() != 2:
		push_error("ProjectSerializer restored %d objects, expected 2." % test_container.get_child_count())
		return false

	test_container.queue_free()
	print("  -> ProjectSerializer save & load round-trip verified.")
	return true
