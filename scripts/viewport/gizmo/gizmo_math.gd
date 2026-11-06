class_name GizmoMath
extends RefCounted

## Pure-math utility functions for 3D Viewport Transform Gizmo.
## Node-free, allocation-light, and strictly handles degenerate inputs (zero vectors,
## collinear rays, NaN/Inf) without triggering engine errors or crashes.

## Safely normalizes a Vector3. If the vector is zero, near-zero, or contains NaN/Inf,
## returns Vector3.ZERO without raising any engine error.
static func safe_normalized(v: Vector3, eps: float = 1e-6) -> Vector3:
	if is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or is_inf(v.x) or is_inf(v.y) or is_inf(v.z):
		return Vector3.ZERO
	var len_sq := v.length_squared()
	if len_sq < eps * eps:
		return Vector3.ZERO
	return v / sqrt(len_sq)

## Safely normalizes a Vector2. If zero, near-zero, or NaN/Inf, returns Vector2.ZERO.
static func safe_normalized_2d(v: Vector2, eps: float = 1e-6) -> Vector2:
	if is_nan(v.x) or is_nan(v.y) or is_inf(v.x) or is_inf(v.y):
		return Vector2.ZERO
	var len_sq := v.length_squared()
	if len_sq < eps * eps:
		return Vector2.ZERO
	return v / sqrt(len_sq)

## Calculates the distance along an axis line for the closest point between a mouse ray
## and that axis line.
## ray: P_ray = ray_origin + s * ray_dir
## axis: P_axis = axis_origin + t * axis_dir
## Returns t (distance along axis_dir from axis_origin).
## Returns 0.0 safely on degenerate or invalid inputs.
static func ray_closest_point_on_axis(
	ray_origin: Vector3,
	ray_dir: Vector3,
	axis_origin: Vector3,
	axis_dir: Vector3
) -> float:
	var d1 := safe_normalized(ray_dir)
	var d2 := safe_normalized(axis_dir)
	if d1.is_zero_approx() or d2.is_zero_approx():
		return 0.0

	var w0 := ray_origin - axis_origin
	var b := d1.dot(d2)
	var denom := 1.0 - (b * b)

	var d := d1.dot(w0)
	var e := d2.dot(w0)

	# Parallel or nearly parallel ray and axis
	if denom < 1e-6:
		return e

	var t := (e - b * d) / denom
	if is_nan(t) or is_inf(t):
		return 0.0
	return t

## Calculates intersection point of a ray with a plane defined by a point and normal.
## Returns Vector3 point of intersection, or null if parallel, behind ray, or degenerate.
static func ray_plane_intersection(
	ray_origin: Vector3,
	ray_dir: Vector3,
	plane_point: Vector3,
	plane_normal: Vector3
) -> Variant:
	var n := safe_normalized(plane_normal)
	var d := safe_normalized(ray_dir)
	if n.is_zero_approx() or d.is_zero_approx():
		return null

	var denom := d.dot(n)
	# Ray is parallel or nearly parallel to plane
	if absf(denom) < 1e-5:
		return null

	var t := (plane_point - ray_origin).dot(n) / denom
	if is_nan(t) or is_inf(t):
		return null

	# Allow small negative epsilon for points on origin plane
	if t < -1e-4:
		return null

	return ray_origin + d * t

## Calculates the signed angle (in radians) from start_vec to current_vec around axis.
## Normalizes inputs and projects vectors onto the plane perpendicular to axis.
## Returns angle in range [-PI, PI], or 0.0 on degenerate inputs.
static func signed_angle_on_ring(start_vec: Vector3, current_vec: Vector3, axis: Vector3) -> float:
	var n := safe_normalized(axis)
	if n.is_zero_approx():
		return 0.0

	# Project start_vec and current_vec onto plane perpendicular to n
	var v1 := start_vec - n * n.dot(start_vec)
	var v2 := current_vec - n * n.dot(current_vec)

	var u1 := safe_normalized(v1)
	var u2 := safe_normalized(v2)
	if u1.is_zero_approx() or u2.is_zero_approx():
		return 0.0

	var dot_val := clampf(u1.dot(u2), -1.0, 1.0)
	var cross_vec := u1.cross(u2)
	var sin_val := cross_vec.dot(n)

	var angle := atan2(sin_val, dot_val)
	if is_nan(angle) or is_inf(angle):
		return 0.0
	return angle

## Snaps an angle in radians or degrees to the nearest step.
## If step <= 1e-6 or invalid, returns angle untouched.
static func snap_angle(angle: float, step: float) -> float:
	if is_nan(angle) or is_inf(angle):
		return 0.0
	if is_nan(step) or is_inf(step) or step <= 1e-6:
		return angle
	return roundf(angle / step) * step

## Snaps a scalar value to the nearest step.
## If step <= 1e-6 or invalid, returns value untouched.
static func snap_value(v: float, step: float) -> float:
	if is_nan(v) or is_inf(v):
		return 0.0
	if is_nan(step) or is_inf(step) or step <= 1e-6:
		return v
	return roundf(v / step) * step

## Calculates distance from a 2D point to a line segment [a, b].
## Handles degenerate zero-length segments and invalid inputs gracefully.
static func dist_point_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	if is_nan(p.x) or is_nan(p.y) or is_nan(a.x) or is_nan(a.y) or is_nan(b.x) or is_nan(b.y):
		return INF
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 1e-8:
		return p.distance_to(a)

	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_to(proj)

## Calculates minimum distance from a 2D point to a polyline.
## Returns INF for empty polyline.
static func dist_point_to_polyline_2d(p: Vector2, points: PackedVector2Array) -> float:
	var count := points.size()
	if count == 0:
		return INF
	if count == 1:
		return p.distance_to(points[0])

	var min_dist := INF
	for i in range(count - 1):
		var d := dist_point_to_segment_2d(p, points[i], points[i + 1])
		if d < min_dist:
			min_dist = d
	return min_dist

## Generates a 3D closed circular polyline of 'segments' points around axis,
## centered at center with given radius.
## Returns empty array if degenerate.
static func ring_polyline(center: Vector3, axis: Vector3, radius: float, segments: int = 64) -> PackedVector3Array:
	var points := PackedVector3Array()
	if radius <= 0.0:
		return points
	var n := safe_normalized(axis)
	if n.is_zero_approx():
		return points

	var segs := clampi(segments, 3, 360)

	# Find two orthonormal basis vectors perpendicular to n
	var ref := Vector3.UP if absf(n.y) < 0.99 else Vector3.RIGHT
	var u := safe_normalized(n.cross(ref))
	var v := n.cross(u)

	points.resize(segs + 1)
	var step := (PI * 2.0) / float(segs)
	for i in range(segs):
		var theta := float(i) * step
		points[i] = center + (u * cos(theta) + v * sin(theta)) * radius
	points[segs] = points[0] # Close the ring

	return points

