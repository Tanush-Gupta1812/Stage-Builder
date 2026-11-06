class_name TestTransformGuard
extends RefCounted

const TransformGuard = preload("res://scripts/core/transform_guard.gd")
const BaseCommand = preload("res://scripts/core/commands.gd")
const ProjectSerializer = preload("res://scripts/core/project_serializer.gd")

static func run_all_tests() -> bool:
	print("[TEST] Running TransformGuard Safety & Resiliency Unit Test Suite...")
	var all_passed := true

	all_passed = test_is_finite_transform() and all_passed
	all_passed = test_sanitize() and all_passed
	all_passed = test_clamp_move_delta() and all_passed
	all_passed = test_safe_normalized() and all_passed
	all_passed = test_commands_reject_invalid_transform() and all_passed
	all_passed = test_corrupt_project_repair_and_autosave() and all_passed
	all_passed = test_degenerate_inputs() and all_passed

	if all_passed:
		print("  -> TransformGuard: ALL TESTS PASSED.")
	else:
		push_error("  -> TransformGuard: TESTS FAILED.")
	return all_passed

static func test_is_finite_transform() -> bool:
	# 1. Valid Transform
	var valid_t := Transform3D(Basis.IDENTITY, Vector3(10.0, 5.0, -2.0))
	if not TransformGuard.is_finite_transform(valid_t):
		push_error("FAIL: Valid transform rejected by is_finite_transform.")
		return false

	# 2. NaN Origin
	var nan_origin_t := Transform3D(Basis.IDENTITY, Vector3(NAN, 0.0, 0.0))
	if TransformGuard.is_finite_transform(nan_origin_t):
		push_error("FAIL: NaN origin accepted by is_finite_transform.")
		return false

	# 3. Inf Origin
	var inf_origin_t := Transform3D(Basis.IDENTITY, Vector3(0.0, INF, 0.0))
	if TransformGuard.is_finite_transform(inf_origin_t):
		push_error("FAIL: Inf origin accepted by is_finite_transform.")
		return false

	# 4. Out of bounds Origin (> 100,000m)
	var oob_origin_t := Transform3D(Basis.IDENTITY, Vector3(150000.0, 0.0, 0.0))
	if TransformGuard.is_finite_transform(oob_origin_t):
		push_error("FAIL: Out-of-bounds (>100km) origin accepted.")
		return false

	# 5. NaN in Basis
	var nan_basis := Basis.IDENTITY
	nan_basis.x.x = NAN
	var nan_basis_t := Transform3D(nan_basis, Vector3.ZERO)
	if TransformGuard.is_finite_transform(nan_basis_t):
		push_error("FAIL: NaN in basis accepted by is_finite_transform.")
		return false

	# 6. Singular/Zero Determinant Basis (Collapsed matrix)
	var zero_basis := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	var zero_basis_t := Transform3D(zero_basis, Vector3.ZERO)
	if TransformGuard.is_finite_transform(zero_basis_t):
		push_error("FAIL: Zero determinant basis accepted.")
		return false

	# 7. Extremely Small Column Length (< 1e-4)
	var tiny_basis := Basis(Vector3(1e-5, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var tiny_basis_t := Transform3D(tiny_basis, Vector3.ZERO)
	if TransformGuard.is_finite_transform(tiny_basis_t):
		push_error("FAIL: Tiny degenerate basis accepted.")
		return false

	# 8. Outrageous Column Scale (> 1e4)
	var huge_basis := Basis(Vector3(20000.0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var huge_basis_t := Transform3D(huge_basis, Vector3.ZERO)
	if TransformGuard.is_finite_transform(huge_basis_t):
		push_error("FAIL: Huge column basis accepted.")
		return false

	return true

static func test_sanitize() -> bool:
	var valid_t := Transform3D(Basis.IDENTITY, Vector3(5, 2, 3))
	var result := TransformGuard.sanitize(valid_t, Transform3D.IDENTITY, "test")
	if result != valid_t:
		push_error("FAIL: Valid transform altered by sanitize.")
		return false

	var corrupt_t := Transform3D(Basis.IDENTITY, Vector3(NAN, 0, 0))
	var fallback := Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))
	result = TransformGuard.sanitize(corrupt_t, fallback, "test")
	if result != fallback:
		push_error("FAIL: sanitize did not return fallback for corrupt transform.")
		return false

	# Invalid fallback safely defaults to IDENTITY
	var bad_fallback := Transform3D(Basis.IDENTITY, Vector3(INF, 0, 0))
	result = TransformGuard.sanitize(corrupt_t, bad_fallback, "test")
	if result != Transform3D.IDENTITY:
		push_error("FAIL: sanitize did not return IDENTITY when fallback is invalid.")
		return false

	return true

static func test_clamp_move_delta() -> bool:
	# Within limit
	var d1 := Vector3(10.0, 0.0, 20.0)
	var res1 := TransformGuard.clamp_move_delta(d1, 50.0)
	if not res1.is_equal_approx(d1):
		push_error("FAIL: Delta within limit was altered.")
		return false

	# Exceeds limit (e.g. 100m)
	var d2 := Vector3(100.0, 0.0, 0.0)
	var res2 := TransformGuard.clamp_move_delta(d2, 50.0)
	if not is_equal_approx(res2.length(), 50.0) or not res2.is_equal_approx(Vector3(50.0, 0.0, 0.0)):
		push_error("FAIL: Delta exceeding 50m was not clamped to 50m: " + str(res2))
		return false

	# NaN delta
	var d_nan := Vector3(NAN, 0.0, 0.0)
	var res_nan := TransformGuard.clamp_move_delta(d_nan, 50.0)
	if res_nan != Vector3.ZERO:
		push_error("FAIL: NaN delta did not clamp to Vector3.ZERO.")
		return false

	return true

static func test_safe_normalized() -> bool:
	var v := Vector3(0.0, 10.0, 0.0)
	var n := TransformGuard.safe_normalized(v)
	if not n.is_equal_approx(Vector3.UP):
		push_error("FAIL: safe_normalized did not return Vector3.UP.")
		return false

	var zero_v := Vector3.ZERO
	var n_zero := TransformGuard.safe_normalized(zero_v, Vector3.FORWARD)
	if n_zero != Vector3.FORWARD:
		push_error("FAIL: safe_normalized did not return fallback for zero vector.")
		return false

	var nan_v := Vector3(NAN, 0, 0)
	var n_nan := TransformGuard.safe_normalized(nan_v, Vector3.RIGHT)
	if n_nan != Vector3.RIGHT:
		push_error("FAIL: safe_normalized did not return fallback for NaN vector.")
		return false

	return true

static func test_commands_reject_invalid_transform() -> bool:
	var root: Window = (Engine.get_main_loop() as SceneTree).root if Engine.get_main_loop() is SceneTree else null
	var node := Node3D.new()
	if root:
		root.add_child(node)
	var original_t := Transform3D(Basis.IDENTITY, Vector3(2, 0, 2))
	node.global_transform = original_t

	var bad_t := Transform3D(Basis.IDENTITY, Vector3(NAN, 1e20, INF))

	# Test TransformCommand with invalid new transform
	var cmd := BaseCommand.TransformCommand.new([node], [original_t], [bad_t])
	cmd.execute()

	# Assert transform remains unchanged and finite
	if not node.global_transform.is_equal_approx(original_t):
		push_error("FAIL: TransformCommand executed NaN transform on node.")
		node.queue_free()
		return false

	# Test TransformCommand undo with invalid old transform
	var bad_cmd := BaseCommand.TransformCommand.new([node], [bad_t], [original_t])
	bad_cmd.undo()
	if not node.global_transform.is_equal_approx(original_t):
		push_error("FAIL: TransformCommand undo applied NaN transform on node.")
		node.queue_free()
		return false

	node.queue_free()
	return true

static func test_corrupt_project_repair_and_autosave() -> bool:
	var corrupt_json := {
		"version": "2.1.0",
		"project_name": "Corrupt Test",
		"ground": "concrete",
		"objects": [
			{
				"catalog_id": "truss_box_2m",
				"name": "Corrupt Truss",
				"transform": {
					"basis": [
						[1.0, 0.0, 0.0],
						[0.0, 1.0, 0.0],
						[0.0, 0.0, 1.0]
					],
					"origin": [1e25, 0.0, 0.0] # Absurd coordinate > 100km
				}
			}
		]
	}

	var test_path := "user://test_corrupt_recovery.stagebuilder"
	var f := FileAccess.open(test_path, FileAccess.WRITE)
	if not f:
		push_error("FAIL: Could not write corrupt test file.")
		return false
	f.store_string(JSON.stringify(corrupt_json))
	f.close()

	# Ensure stage container exists
	if AppState.stage_container == null:
		var root := Node3D.new()
		AppState.stage_container = root

	var load_success := ProjectSerializer.load_project(test_path)
	if not load_success:
		push_error("FAIL: ProjectSerializer failed to load recoverable project.")
		return false

	# Verify repaired object transform
	var loaded_child: Node3D = AppState.stage_container.get_child(0) as Node3D
	if loaded_child == null:
		push_error("FAIL: Repaired object was not added to stage container.")
		return false

	if not TransformGuard.is_finite_transform(loaded_child.global_transform):
		push_error("FAIL: Loaded object still has non-finite/unbounded transform: " + str(loaded_child.global_transform))
		return false

	# Verify autosave writes clean file
	AppState.is_modified = true
	ProjectSerializer.autosave()

	var auto_f := FileAccess.open(ProjectSerializer.AUTOSAVE_PATH, FileAccess.READ)
	if not auto_f:
		push_error("FAIL: Autosave file was not generated.")
		return false
	var auto_content := auto_f.get_as_text()
	auto_f.close()

	var auto_json := JSON.new()
	if auto_json.parse(auto_content) != OK:
		push_error("FAIL: Autosave output contains invalid JSON.")
		return false

	# Clean up test files
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)

	return true

static func test_degenerate_inputs() -> bool:
	# 1. Zero-length axis in rotation
	var zero_ax := Vector3.ZERO
	var safe_ax := TransformGuard.safe_normalized(zero_ax, Vector3.UP)
	if safe_ax != Vector3.UP:
		push_error("FAIL: Zero length rotation axis did not fallback to safe default.")
		return false
	# Ensuring Basis constructor won't throw normalize error
	var test_basis := Basis(safe_ax, 0.5)
	if not TransformGuard.is_finite_transform(Transform3D(test_basis, Vector3.ZERO)):
		push_error("FAIL: Resulting basis from safe axis is not finite.")
		return false

	# 2. Camera looking along axis (cross product produces zero length)
	var cam_forward := Vector3(0, 0, -1)
	var axis_dir := Vector3(0, 0, 1) # Anti-parallel
	var cross := axis_dir.cross(cam_forward)
	var safe_plane_norm := TransformGuard.safe_normalized(cross, Vector3.UP)
	if safe_plane_norm != Vector3.UP:
		push_error("FAIL: Camera looking along axis did not produce safe fallback normal.")
		return false

	# 3. Ray parallel to plane (|dot| < 1e-4)
	var ray_norm_parallel := Vector3(1, 0, 0)
	var plane_norm := Vector3(0, 1, 0)
	var dot_val := ray_norm_parallel.dot(plane_norm)
	if absf(dot_val) >= 1e-4:
		push_error("FAIL: Dot product calculation unexpected.")
		return false
	# Verify frame-skip condition:
	var is_frame_skip := absf(dot_val) < 1e-4
	if not is_frame_skip:
		push_error("FAIL: Parallel ray not recognized as frame skip.")
		return false

	# 4. NaN mouse position clamped or handled safely
	var nan_delta := Vector3(NAN, NAN, NAN)
	var clamped := TransformGuard.clamp_move_delta(nan_delta, 50.0)
	if clamped != Vector3.ZERO:
		push_error("FAIL: NaN mouse move delta was not clamped to Vector3.ZERO.")
		return false

	# 5. Subsequent valid frame works immediately
	var valid_delta := Vector3(1.5, 0.0, 2.0)
	var valid_clamped := TransformGuard.clamp_move_delta(valid_delta, 50.0)
	if not valid_clamped.is_equal_approx(valid_delta):
		push_error("FAIL: Subsequent valid frame delta was corrupted after degenerate frame.")
		return false

	return true
