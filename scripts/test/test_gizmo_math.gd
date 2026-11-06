class_name TestGizmoMath
extends RefCounted

const GizmoMath = preload("res://scripts/viewport/gizmo/gizmo_math.gd")

## Unit tests for GizmoMath pure-math functions.
## Validates hand-computed geometry values and ensures complete immunity to engine errors
## on degenerate / NaN / zero-length inputs.

static func run_all_tests() -> bool:
	print("[TEST] Running GizmoMath Unit Test Suite...")
	var passed := true

	passed = test_safe_normalized() and passed
	passed = test_ray_closest_point_on_axis() and passed
	passed = test_ray_plane_intersection() and passed
	passed = test_signed_angle_on_ring() and passed
	passed = test_snapping() and passed
	passed = test_point_to_segment_and_polyline_2d() and passed
	passed = test_ring_polyline() and passed
	passed = test_degenerate_resilience() and passed

	if passed:
		print("  -> GizmoMath: ALL TESTS PASSED.")
	else:
		push_error("  -> GizmoMath: ONE OR MORE TESTS FAILED.")
	return passed

static func test_safe_normalized() -> bool:
	# Unit vector preservation
	var v_unit := Vector3(0, 1, 0)
	if not GizmoMath.safe_normalized(v_unit).is_equal_approx(v_unit):
		push_error("safe_normalized altered an already-unit vector")
		return false

	# Normalization of arbitrary vector
	var v_arb := Vector3(3, 0, 4)
	var v_norm := GizmoMath.safe_normalized(v_arb)
	if not is_equal_approx(v_norm.length(), 1.0) or not v_norm.is_equal_approx(Vector3(0.6, 0.0, 0.8)):
		push_error("safe_normalized failed to normalize (3, 0, 4) to (0.6, 0, 0.8)")
		return false

	# Zero vector -> returns Vector3.ZERO safely
	if GizmoMath.safe_normalized(Vector3.ZERO) != Vector3.ZERO:
		push_error("safe_normalized did not return ZERO for Vector3.ZERO")
		return false

	# Near-zero vector below epsilon -> returns Vector3.ZERO safely without error
	var v_tiny := Vector3(1e-8, 0, 0)
	if GizmoMath.safe_normalized(v_tiny) != Vector3.ZERO:
		push_error("safe_normalized did not return ZERO for near-zero vector")
		return false

	# NaN / Inf vector -> returns Vector3.ZERO safely without error
	var v_nan := Vector3(NAN, 1.0, 0.0)
	if GizmoMath.safe_normalized(v_nan) != Vector3.ZERO:
		push_error("safe_normalized did not return ZERO for NaN vector")
		return false

	var v_inf := Vector3(INF, 0.0, 0.0)
	if GizmoMath.safe_normalized(v_inf) != Vector3.ZERO:
		push_error("safe_normalized did not return ZERO for INF vector")
		return false

	return true

static func test_ray_closest_point_on_axis() -> bool:
	# Hand-computed case 1:
	# Axis along +X: origin = (0, 0, 0), dir = (1, 0, 0)
	# Ray from (5, 10, 0) pointing down -Y (0, -1, 0).
	# Intersection is at (5, 0, 0), so distance along axis is exactly 5.0.
	var t1 := GizmoMath.ray_closest_point_on_axis(
		Vector3(5, 10, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 0), Vector3(1, 0, 0)
	)
	if not is_equal_approx(t1, 5.0):
		push_error("ray_closest_point_on_axis expected 5.0, got %f" % t1)
		return false

	# Hand-computed case 2 (Skew lines):
	# Axis along +Y from (2, 0, 0) with dir (0, 1, 0).
	# Ray from (0, 7, -5) with dir (0, 0, 1) (+Z).
	# Closest approach on axis is at (2, 7, 0), so distance along axis is t = 7.0.
	var t2 := GizmoMath.ray_closest_point_on_axis(
		Vector3(0, 7, -5), Vector3(0, 0, 1),
		Vector3(2, 0, 0), Vector3(0, 1, 0)
	)
	if not is_equal_approx(t2, 7.0):
		push_error("ray_closest_point_on_axis skew lines expected 7.0, got %f" % t2)
		return false

	# Degenerate: parallel ray and axis
	var t_par := GizmoMath.ray_closest_point_on_axis(
		Vector3(3, 4, 0), Vector3(1, 0, 0),
		Vector3(0, 4, 0), Vector3(1, 0, 0)
	)
	if not is_equal_approx(t_par, 3.0):
		push_error("ray_closest_point_on_axis parallel expected 3.0, got %f" % t_par)
		return false

	# Degenerate: zero ray direction or zero axis direction
	var t_zero := GizmoMath.ray_closest_point_on_axis(
		Vector3(1, 2, 3), Vector3.ZERO,
		Vector3.ZERO, Vector3.UP
	)
	if not is_equal_approx(t_zero, 0.0):
		push_error("ray_closest_point_on_axis with zero dir did not return 0.0")
		return false

	return true

static func test_ray_plane_intersection() -> bool:
	# Hand-computed case:
	# Horizontal plane at y = 5, point = (0, 5, 0), normal = (0, 1, 0).
	# Ray from (2, 15, 3) pointing down (0, -1, 0).
	# Intersection is (2, 5, 3).
	var hit1: Variant = GizmoMath.ray_plane_intersection(
		Vector3(2, 15, 3), Vector3(0, -1, 0),
		Vector3(0, 5, 0), Vector3(0, 1, 0)
	)
	if hit1 == null or not (hit1 as Vector3).is_equal_approx(Vector3(2, 5, 3)):
		push_error("ray_plane_intersection expected (2, 5, 3), got %s" % str(hit1))
		return false

	# Ray pointing away from plane (pointing up into +Y)
	var hit_away: Variant = GizmoMath.ray_plane_intersection(
		Vector3(2, 15, 3), Vector3(0, 1, 0),
		Vector3(0, 5, 0), Vector3(0, 1, 0)
	)
	if hit_away != null:
		push_error("ray_plane_intersection expected null for ray pointing away, got %s" % str(hit_away))
		return false

	# Ray parallel to plane
	var hit_par: Variant = GizmoMath.ray_plane_intersection(
		Vector3(0, 10, 0), Vector3(1, 0, 0),
		Vector3(0, 5, 0), Vector3(0, 1, 0)
	)
	if hit_par != null:
		push_error("ray_plane_intersection expected null for parallel ray, got %s" % str(hit_par))
		return false

	# Degenerate zero normal or zero ray dir
	var hit_deg: Variant = GizmoMath.ray_plane_intersection(
		Vector3.ZERO, Vector3.ZERO,
		Vector3.ZERO, Vector3.ZERO
	)
	if hit_deg != null:
		push_error("ray_plane_intersection expected null for zero inputs")
		return false

	return true

static func test_signed_angle_on_ring() -> bool:
	# Quarter-turn (+90 degrees = +PI/2) about Y:
	# Start vector along +Z (0, 0, 1), target vector along +X (1, 0, 0).
	var ang_y90 := GizmoMath.signed_angle_on_ring(
		Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3.UP
	)
	if not is_equal_approx(ang_y90, PI * 0.5):
		push_error("signed_angle_on_ring expected PI/2 (+90 deg), got %f" % ang_y90)
		return false

	# Opposite quarter-turn (-90 degrees = -PI/2) about Y:
	# Start vector along +Z (0, 0, 1), target vector along -X (-1, 0, 0).
	var ang_y_neg90 := GizmoMath.signed_angle_on_ring(
		Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3.UP
	)
	if not is_equal_approx(ang_y_neg90, -PI * 0.5):
		push_error("signed_angle_on_ring expected -PI/2 (-90 deg), got %f" % ang_y_neg90)
		return false

	# Quarter-turn about X: start along +Y, target along +Z, axis +X
	var ang_x90 := GizmoMath.signed_angle_on_ring(
		Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3.RIGHT
	)
	if not is_equal_approx(ang_x90, PI * 0.5):
		push_error("signed_angle_on_ring X axis expected PI/2, got %f" % ang_x90)
		return false

	# Quarter-turn about Z: start along +X, target along +Y, axis +Z
	var ang_z90 := GizmoMath.signed_angle_on_ring(
		Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3.BACK
	)
	if not is_equal_approx(ang_z90, PI * 0.5):
		push_error("signed_angle_on_ring Z axis expected PI/2, got %f" % ang_z90)
		return false

	# Non-unit unnormalized inputs (should normalize internally)
	var ang_scaled := GizmoMath.signed_angle_on_ring(
		Vector3(0, 0, 25.5), Vector3(14.2, 0, 0), Vector3(0, 2.55, 0)
	)
	if not is_equal_approx(ang_scaled, PI * 0.5):
		push_error("signed_angle_on_ring with unnormalized inputs expected PI/2, got %f" % ang_scaled)
		return false

	# Degenerate inputs: zero vectors or zero axis
	var ang_zero := GizmoMath.signed_angle_on_ring(Vector3.ZERO, Vector3.RIGHT, Vector3.UP)
	if not is_equal_approx(ang_zero, 0.0):
		push_error("signed_angle_on_ring with zero start_vec did not return 0.0")
		return false

	return true

static func test_snapping() -> bool:
	# Test snapping to 5 deg
	var step_5 := deg_to_rad(5.0)
	var sn_12 := GizmoMath.snap_angle(deg_to_rad(12.0), step_5)
	if not is_equal_approx(sn_12, deg_to_rad(10.0)):
		push_error("snap_angle 12 deg to 5 deg step expected 10 deg, got %f" % rad_to_deg(sn_12))
		return false

	var sn_14 := GizmoMath.snap_angle(deg_to_rad(14.0), step_5)
	if not is_equal_approx(sn_14, deg_to_rad(15.0)):
		push_error("snap_angle 14 deg to 5 deg step expected 15 deg, got %f" % rad_to_deg(sn_14))
		return false

	# Test snapping to 15 deg
	var step_15 := deg_to_rad(15.0)
	var sn_22 := GizmoMath.snap_angle(deg_to_rad(22.0), step_15)
	if not is_equal_approx(sn_22, deg_to_rad(15.0)):
		push_error("snap_angle 22 deg to 15 deg step expected 15 deg, got %f" % rad_to_deg(sn_22))
		return false

	var sn_23 := GizmoMath.snap_angle(deg_to_rad(23.0), step_15)
	if not is_equal_approx(sn_23, deg_to_rad(30.0)):
		push_error("snap_angle 23 deg to 15 deg step expected 30 deg, got %f" % rad_to_deg(sn_23))
		return false

	# Test snapping to 45 deg
	var step_45 := deg_to_rad(45.0)
	var sn_40 := GizmoMath.snap_angle(deg_to_rad(40.0), step_45)
	if not is_equal_approx(sn_40, deg_to_rad(45.0)):
		push_error("snap_angle 40 deg to 45 deg step expected 45 deg, got %f" % rad_to_deg(sn_40))
		return false

	# Test snapping to 90 deg
	var step_90 := deg_to_rad(90.0)
	var sn_80 := GizmoMath.snap_angle(deg_to_rad(80.0), step_90)
	if not is_equal_approx(sn_80, deg_to_rad(90.0)):
		push_error("snap_angle 80 deg to 90 deg step expected 90 deg, got %f" % rad_to_deg(sn_80))
		return false

	# Test snap_value
	var sv1 := GizmoMath.snap_value(2.34, 0.5)
	if not is_equal_approx(sv1, 2.5):
		push_error("snap_value 2.34 step 0.5 expected 2.5, got %f" % sv1)
		return false

	var sv2 := GizmoMath.snap_value(2.21, 0.5)
	if not is_equal_approx(sv2, 2.0):
		push_error("snap_value 2.21 step 0.5 expected 2.0, got %f" % sv2)
		return false

	# Degenerate step (0.0 or negative or NaN)
	var sv_deg := GizmoMath.snap_value(4.2, 0.0)
	if not is_equal_approx(sv_deg, 4.2):
		push_error("snap_value with 0.0 step should return original value")
		return false

	return true

static func test_point_to_segment_and_polyline_2d() -> bool:
	var seg_a := Vector2(0, 0)
	var seg_b := Vector2(10, 0)

	# Interior projection: p = (5, 2) -> closest is (5, 0), distance = 2.0
	var d_int := GizmoMath.dist_point_to_segment_2d(Vector2(5, 2), seg_a, seg_b)
	if not is_equal_approx(d_int, 2.0):
		push_error("dist_point_to_segment_2d interior expected 2.0, got %f" % d_int)
		return false

	# Clamped to endpoint A: p = (-3, 4) -> closest is (0, 0), distance = sqrt(9+16) = 5.0
	var d_a := GizmoMath.dist_point_to_segment_2d(Vector2(-3, 4), seg_a, seg_b)
	if not is_equal_approx(d_a, 5.0):
		push_error("dist_point_to_segment_2d clamp A expected 5.0, got %f" % d_a)
		return false

	# Clamped to endpoint B: p = (13, 4) -> closest is (10, 0), distance = sqrt(9+16) = 5.0
	var d_b := GizmoMath.dist_point_to_segment_2d(Vector2(13, 4), seg_a, seg_b)
	if not is_equal_approx(d_b, 5.0):
		push_error("dist_point_to_segment_2d clamp B expected 5.0, got %f" % d_b)
		return false

	# Degenerate zero-length segment: a = b = (2, 2), p = (5, 6), distance = sqrt(9+16) = 5.0
	var d_deg := GizmoMath.dist_point_to_segment_2d(Vector2(5, 6), Vector2(2, 2), Vector2(2, 2))
	if not is_equal_approx(d_deg, 5.0):
		push_error("dist_point_to_segment_2d zero length segment expected 5.0, got %f" % d_deg)
		return false

	# Polyline testing
	var poly := PackedVector2Array([
		Vector2(0, 0),
		Vector2(10, 0),
		Vector2(10, 10),
		Vector2(20, 10)
	])
	var d_poly := GizmoMath.dist_point_to_polyline_2d(Vector2(10, 5), poly)
	# Point (10, 5) is exactly on the second segment (10, 0) -> (10, 10), distance = 0.0
	if not is_equal_approx(d_poly, 0.0):
		push_error("dist_point_to_polyline_2d expected 0.0, got %f" % d_poly)
		return false

	var d_poly_near := GizmoMath.dist_point_to_polyline_2d(Vector2(12, 5), poly)
	if not is_equal_approx(d_poly_near, 2.0):
		push_error("dist_point_to_polyline_2d expected 2.0, got %f" % d_poly_near)
		return false

	# Empty polyline returns INF safely
	if not is_inf(GizmoMath.dist_point_to_polyline_2d(Vector2.ZERO, PackedVector2Array())):
		push_error("dist_point_to_polyline_2d empty polyline did not return INF")
		return false

	return true

static func test_ring_polyline() -> bool:
	var center := Vector3(1, 2, 3)
	var axis := Vector3.UP
	var radius := 1.5
	var segments := 64

	var ring := GizmoMath.ring_polyline(center, axis, radius, segments)
	if ring.size() != segments + 1:
		push_error("ring_polyline expected %d points, got %d" % [segments + 1, ring.size()])
		return false

	# Closed ring check: first and last points match
	if not ring[0].is_equal_approx(ring[segments]):
		push_error("ring_polyline is not closed: first != last")
		return false

	# Check that every point is radius distance from center and lies on horizontal plane y=2
	for pt in ring:
		if not is_equal_approx(pt.y, center.y):
			push_error("ring_polyline point y is not plane level: expected %f, got %f" % [center.y, pt.y])
			return false
		var d := pt.distance_to(center)
		if not is_equal_approx(d, radius):
			push_error("ring_polyline point radius expected %f, got %f" % [radius, d])
			return false

	# Degenerate ring: radius <= 0 or zero axis returns empty array
	var r_zero_rad := GizmoMath.ring_polyline(center, axis, 0.0)
	if not r_zero_rad.is_empty():
		push_error("ring_polyline with radius 0 did not return empty array")
		return false

	var r_zero_axis := GizmoMath.ring_polyline(center, Vector3.ZERO, 1.0)
	if not r_zero_axis.is_empty():
		push_error("ring_polyline with zero axis did not return empty array")
		return false

	return true

static func test_degenerate_resilience() -> bool:
	# Check that passing NaN, Inf, and zero vectors across all functions returns safely without crashing
	var nan_v3 := Vector3(NAN, NAN, NAN)
	var inf_v3 := Vector3(INF, INF, INF)

	var p1 := GizmoMath.ray_closest_point_on_axis(nan_v3, inf_v3, nan_v3, inf_v3)
	if is_nan(p1) or is_inf(p1):
		push_error("ray_closest_point_on_axis returned NaN/Inf for degenerate inputs")
		return false

	var p2: Variant = GizmoMath.ray_plane_intersection(nan_v3, inf_v3, nan_v3, inf_v3)
	if p2 != null:
		push_error("ray_plane_intersection did not return null for NaN inputs")
		return false

	var p3 := GizmoMath.signed_angle_on_ring(nan_v3, inf_v3, nan_v3)
	if is_nan(p3) or is_inf(p3):
		push_error("signed_angle_on_ring returned NaN/Inf for degenerate inputs")
		return false

	var p4 := GizmoMath.snap_angle(NAN, NAN)
	if is_nan(p4) or is_inf(p4):
		push_error("snap_angle returned NaN/Inf for degenerate inputs")
		return false

	var p5 := GizmoMath.snap_value(NAN, NAN)
	if is_nan(p5) or is_inf(p5):
		push_error("snap_value returned NaN/Inf for degenerate inputs")
		return false

	var p6 := GizmoMath.dist_point_to_segment_2d(Vector2(NAN, NAN), Vector2(NAN, NAN), Vector2(NAN, NAN))
	if not is_inf(p6):
		push_error("dist_point_to_segment_2d did not return INF for NaN inputs")
		return false

	var p7 := GizmoMath.ring_polyline(nan_v3, inf_v3, -5.0)
	if not p7.is_empty():
		push_error("ring_polyline did not return empty array for degenerate inputs")
		return false

	return true
