class_name TransformGuard
extends RefCounted

## Global Safety Guard for 3D Transforms.
## Ensures all transforms in Stage-Builder are strictly finite, bounded, non-singular,
## and protects against division by zero, unnormalized vectors, and coordinate blowup.

const MAX_COORD: float = 100000.0 # 100 km bounding limit
const MAX_COORD_SQ: float = 100000.0 * 100000.0
const MIN_DET: float = 1e-5
const MIN_COL_LEN: float = 1e-4
const MAX_COL_LEN: float = 1e4
const MAX_DELTA_MOVE: float = 50.0 # Max per-frame translation in meters

static var _warning_timestamps: Dictionary = {}

## Returns true if the transform has all finite components, bounded coordinates,
## a non-singular determinant, and sane basis column lengths.
static func is_finite_transform(t: Transform3D) -> bool:
	# 1. Check origin coordinates
	if not (is_finite(t.origin.x) and is_finite(t.origin.y) and is_finite(t.origin.z)):
		return false
	if t.origin.length_squared() >= MAX_COORD_SQ:
		return false

	# 2. Check all basis elements
	if not (is_finite(t.basis.x.x) and is_finite(t.basis.x.y) and is_finite(t.basis.x.z)):
		return false
	if not (is_finite(t.basis.y.x) and is_finite(t.basis.y.y) and is_finite(t.basis.y.z)):
		return false
	if not (is_finite(t.basis.z.x) and is_finite(t.basis.z.y) and is_finite(t.basis.z.z)):
		return false

	# 3. Check basis determinant (> 1e-5 to reject singular/collapsed matrices)
	var det: float = t.basis.determinant()
	if not is_finite(det) or absf(det) < MIN_DET:
		return false

	# 4. Check basis column lengths are within realistic scale limits
	var lx_sq: float = t.basis.x.length_squared()
	var ly_sq: float = t.basis.y.length_squared()
	var lz_sq: float = t.basis.z.length_squared()

	if lx_sq < (MIN_COL_LEN * MIN_COL_LEN) or lx_sq > (MAX_COL_LEN * MAX_COL_LEN):
		return false
	if ly_sq < (MIN_COL_LEN * MIN_COL_LEN) or ly_sq > (MAX_COL_LEN * MAX_COL_LEN):
		return false
	if lz_sq < (MIN_COL_LEN * MIN_COL_LEN) or lz_sq > (MAX_COL_LEN * MAX_COL_LEN):
		return false

	return true

## Sanitizes a transform. If valid, returns t; otherwise logs a rate-limited warning
## and returns the fallback transform (guaranteed valid, default identity).
static func sanitize(t: Transform3D, fallback: Transform3D = Transform3D.IDENTITY, context: String = "") -> Transform3D:
	if is_finite_transform(t):
		return t

	warn_invalid_transform(context if context != "" else "TransformGuard", "Invalid transform: %s. Using fallback: %s" % [str(t), str(fallback)])
	if is_finite_transform(fallback):
		return fallback
	return Transform3D.IDENTITY

## Clamps translation delta to maximum 50 meters per frame, guarding against NaNs.
static func clamp_move_delta(delta: Vector3, max_delta: float = MAX_DELTA_MOVE) -> Vector3:
	if not (is_finite(delta.x) and is_finite(delta.y) and is_finite(delta.z)):
		return Vector3.ZERO

	var len_sq: float = delta.length_squared()
	if len_sq > (max_delta * max_delta):
		var length: float = sqrt(len_sq)
		if length > 1e-6:
			return (delta / length) * max_delta
		return Vector3.ZERO

	return delta

## Safely normalizes a vector with threshold check; returns fallback if near-zero or non-finite.
static func safe_normalized(v: Vector3, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)):
		return fallback
	var l_sq: float = v.length_squared()
	if l_sq < 1e-12:
		return fallback
	return v / sqrt(l_sq)

## Rate-limited warning logger (at most once every 1000ms per context).
static func warn_invalid_transform(tool_name: String, details: String) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var last_ms: int = _warning_timestamps.get(tool_name, -10000)
	if now_ms - last_ms > 1000:
		_warning_timestamps[tool_name] = now_ms
		push_warning("[TransformGuard] Blocked invalid transform in %s: %s" % [tool_name, details])

