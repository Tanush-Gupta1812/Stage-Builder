class_name SnapSystem
extends RefCounted

## Resolves grid snapping and snap-point-to-snap-point alignment for Stage-Builder.
## Enables seamless assembly of truss grids, stage decks, and modular arrays.

const SNAP_RADIUS: float = 0.25 # in meters

class SnapResult:
	var position: Vector3
	var snapped_to_point: bool = false
	var snap_world_pos: Vector3 = Vector3.ZERO
	var tag: String = ""

	func _init(pos: Vector3) -> void:
		position = pos

static func is_snap_disabled_by_modifier() -> bool:
	return Input.is_key_pressed(KEY_ALT)

static func resolve_position(candidate_pos: Vector3, moving_obj: StageObject = null, candidate_rotation: Basis = Basis()) -> SnapResult:
	var result := SnapResult.new(candidate_pos)

	# 0. Override check: Alt key temporarily disables ALL snapping while held
	if is_snap_disabled_by_modifier():
		return result

	# 1. Point-to-Point Snapping (higher priority than grid if within SNAP_RADIUS threshold)
	if AppState.snap_to_points and moving_obj != null and not moving_obj.snap_points.is_empty():
		var best_dist := SNAP_RADIUS
		var best_offset := Vector3.ZERO
		var found_snap := false
		var matched_pos := Vector3.ZERO
		var matched_tag := ""

		var stage_objects := AppState.get_stage_objects()
		for other in stage_objects:
			if other == moving_obj or other.is_selected:
				continue

			var target_snaps := other.get_global_snap_points()
			for t_snap in target_snaps:
				var t_pos: Vector3 = t_snap["global_pos"]
				var t_norm: Vector3 = t_snap["global_normal"]
				var t_tag: String = t_snap["tag"]

				for m_sp in moving_obj.snap_points:
					var m_tag: String = m_sp.get("tag", "")
					if not _are_tags_compatible(m_tag, t_tag):
						continue

					var local_arr: Array = m_sp.get("pos", [0, 0, 0])
					var m_local_pos := Vector3(local_arr[0], local_arr[1], local_arr[2])
					var m_world_pos := candidate_pos + (candidate_rotation * m_local_pos)

					# Normal orientation check (faces must roughly oppose, or have neutral normal)
					var norm_arr: Array = m_sp.get("normal", [0, 0, 0])
					var m_local_norm := Vector3(norm_arr[0], norm_arr[1], norm_arr[2])
					var m_world_norm := (candidate_rotation * m_local_norm).normalized()

					if t_norm.length_squared() > 0.1 and m_world_norm.length_squared() > 0.1:
						# Opposing normals have dot product < 0.2
						if t_norm.dot(m_world_norm) > 0.2:
							continue

					var dist := m_world_pos.distance_to(t_pos)
					if dist < best_dist:
						best_dist = dist
						best_offset = t_pos - m_world_pos
						found_snap = true
						matched_pos = t_pos
						matched_tag = t_tag

		if found_snap:
			result.position = candidate_pos + best_offset
			result.snapped_to_point = true
			result.snap_world_pos = matched_pos
			result.tag = matched_tag
			return result

	# 2. Grid Snapping (applied relative to world origin)
	if AppState.snap_to_grid:
		var step := AppState.grid_step
		if step > 0.001:
			result.position.x = roundf(candidate_pos.x / step) * step
			result.position.z = roundf(candidate_pos.z / step) * step
			# Keep Y on grid or snap Y to nearest 0.1m step if elevated
			if candidate_pos.y > 0.05:
				result.position.y = roundf(candidate_pos.y / 0.1) * 0.1
			else:
				result.position.y = 0.0

	return result

static func _are_tags_compatible(tag_a: String, tag_b: String) -> bool:
	if tag_a == "" or tag_b == "":
		return false
	if tag_a == tag_b:
		return true

	# Cross-compatible tags for truss, towers, decks, and modular rigging
	if (tag_a == "truss_f34" and tag_b == "tower_mast") or (tag_a == "tower_mast" and tag_b == "truss_f34"):
		return true
	if (tag_a == "deck_edge_1m" and tag_b == "deck_edge_2m") or (tag_a == "deck_edge_2m" and tag_b == "deck_edge_1m"):
		return true
	if (tag_a == "deck_edge_half" and (tag_b == "deck_edge_1m" or tag_b == "deck_edge_2m")) or ((tag_a == "deck_edge_1m" or tag_a == "deck_edge_2m") and tag_b == "deck_edge_half"):
		return true

	return false
