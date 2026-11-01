class_name SnapSystem
extends RefCounted

## Resolves grid snapping and snap-point-to-snap-point alignment for Stage-Builder.
## Enables seamless assembly of truss grids, stage decks, and modular arrays.

class SnapResult:
	var position: Vector3
	var snapped_to_point: bool = false
	var snap_world_pos: Vector3 = Vector3.ZERO
	var tag: String = ""

	func _init(pos: Vector3) -> void:
		position = pos

static func resolve_position(candidate_pos: Vector3, moving_obj: StageObject = null, candidate_rotation: Basis = Basis()) -> SnapResult:
	var result := SnapResult.new(candidate_pos)

	# 1. Point-to-Point Snapping (higher priority than grid if within threshold)
	if AppState.snap_to_points and moving_obj != null and not moving_obj.snap_points.is_empty():
		var best_dist := AppState.snap_threshold
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
				var t_tag: String = t_snap["tag"]

				for m_sp in moving_obj.snap_points:
					var m_tag: String = m_sp.get("tag", "")
					if not _are_tags_compatible(m_tag, t_tag):
						continue

					var local_arr: Array = m_sp.get("pos", [0, 0, 0])
					var m_local_pos := Vector3(local_arr[0], local_arr[1], local_arr[2])
					var m_world_pos := candidate_pos + (candidate_rotation * m_local_pos)

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

	# 2. Grid Snapping
	if AppState.snap_to_grid:
		var step := AppState.grid_step
		if step > 0.001:
			result.position.x = roundf(candidate_pos.x / step) * step
			result.position.z = roundf(candidate_pos.z / step) * step
			# Keep Y on grid or snap Y to nearest 0.2m / 0.4m riser step
			if candidate_pos.y > 0.05:
				result.position.y = roundf(candidate_pos.y / 0.1) * 0.1

	return result

static func _are_tags_compatible(tag_a: String, tag_b: String) -> bool:
	if tag_a == "" or tag_b == "":
		return false
	if tag_a == tag_b:
		return true

	# Cross-compatible tags
	if (tag_a == "truss_30" and tag_b == "tower_40") or (tag_a == "tower_40" and tag_b == "truss_30"):
		return true
	if (tag_a == "deck_edge_1m" and tag_b == "deck_edge_2m") or (tag_a == "deck_edge_2m" and tag_b == "deck_edge_1m"):
		return true

	return false

