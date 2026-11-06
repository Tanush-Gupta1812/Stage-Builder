extends Node

## Central Rigging, Load Calculation, and Graph Solver for Stage-Builder (Phase 3A).
## Evaluates structural load paths, simply supported beam statics, hoist capacities,
## support tower loads, and structural warnings off the main thread via WorkerThreadPool.

signal rigging_solved(results: Dictionary)
signal overlay_toggled(is_visible: bool)
signal unit_changed(new_unit: String)
signal safety_factors_changed(static_sf: float, motor_sf: float)

enum Unit { KG, KN, LB }
enum Severity { INFO, WARNING, CRITICAL }

const GRAVITY: float = 9.80665 # m/s^2
const LB_PER_KG: float = 2.20462262
const DISCLAIMER: String = "All calculations are PLANNING AIDS ONLY, not engineering sign-off or structural certification. Verify all rigging, loads, and ballasting with a certified structural engineer or licensed rigger before production."

var active_unit: String = "kg" # "kg", "kN", "lb"
var static_safety_factor: float = 1.5
var motor_safety_factor: float = 5.0
var overlay_visible: bool = true

# Solver state
var warnings: Array[Dictionary] = []
var critical_count: int = 0
var warning_count: int = 0
var info_count: int = 0
var spans_data: Array[Dictionary] = []
var supports_data: Array[Dictionary] = []
var overlay_lines: Array[Dictionary] = []

var _solve_timer: Timer = null
var _current_generation: int = 0
var _is_solving: bool = false

func _ready() -> void:
	_solve_timer = Timer.new()
	_solve_timer.wait_time = 0.15 # 150 ms debounce
	_solve_timer.one_shot = true
	_solve_timer.timeout.connect(_on_solve_timer_timeout)
	add_child(_solve_timer)

	AppState.project_modified.connect(request_solve)
	AppState.project_loaded.connect(func(_p): request_solve())

func request_solve() -> void:
	if _solve_timer:
		_solve_timer.start()

func toggle_overlay() -> void:
	overlay_visible = not overlay_visible
	overlay_toggled.emit(overlay_visible)
	AppState.status_message.emit("Rigging Overlay: " + ("ON" if overlay_visible else "OFF"))

func set_unit(u: String) -> void:
	if u in ["kg", "kN", "lb"] and u != active_unit:
		active_unit = u
		unit_changed.emit(active_unit)
		request_solve()

func set_safety_factors(static_sf: float, motor_sf: float) -> void:
	static_safety_factor = maxf(1.0, static_sf)
	motor_safety_factor = maxf(1.0, motor_sf)
	safety_factors_changed.emit(static_safety_factor, motor_safety_factor)
	request_solve()

# --- Unit Conversion Helpers ---

func format_mass(kg: float) -> String:
	match active_unit:
		"kN":
			return "%.2f kN" % (kg * GRAVITY / 1000.0)
		"lb":
			return "%.1f lb" % (kg * LB_PER_KG)
		_:
			return "%.1f kg" % kg

func format_force(n_newtons: float) -> String:
	match active_unit:
		"kN":
			return "%.2f kN" % (n_newtons / 1000.0)
		"lb":
			return "%.1f lb" % ((n_newtons / GRAVITY) * LB_PER_KG)
		_:
			return "%.1f kg" % (n_newtons / GRAVITY)

func format_moment(kgm: float) -> String:
	match active_unit:
		"kN":
			return "%.2f kN·m" % (kgm * GRAVITY / 1000.0)
		"lb":
			return "%.1f lb·ft" % (kgm * 7.23301)
		_:
			return "%.1f kg·m" % kgm

# --- Statics Calculations (Pure Math, Testable Independently) ---

static func interpolate_load_rating(table: Array, span_m: float) -> Dictionary:
	if table.is_empty():
		return {"max_udl_kgm": 100.0, "max_point_load_kg": 300.0}

	if span_m <= table[0].get("span_m", 2.0):
		return {
			"max_udl_kgm": float(table[0].get("max_udl_kgm", 900.0)),
			"max_point_load_kg": float(table[0].get("max_point_load_kg", 900.0))
		}

	var last_idx := table.size() - 1
	if span_m >= table[last_idx].get("span_m", 12.0):
		return {
			"max_udl_kgm": float(table[last_idx].get("max_udl_kgm", 50.0)),
			"max_point_load_kg": float(table[last_idx].get("max_point_load_kg", 210.0))
		}

	for i in range(last_idx):
		var p1: Dictionary = table[i]
		var p2: Dictionary = table[i + 1]
		var s1 := float(p1.get("span_m", 2.0))
		var s2 := float(p2.get("span_m", 4.0))
		if span_m >= s1 and span_m <= s2:
			var t := (span_m - s1) / maxf(0.001, (s2 - s1))
			var udl := lerpf(float(p1.get("max_udl_kgm", 100.0)), float(p2.get("max_udl_kgm", 50.0)), t)
			var pt := lerpf(float(p1.get("max_point_load_kg", 500.0)), float(p2.get("max_point_load_kg", 200.0)), t)
			return {"max_udl_kgm": udl, "max_point_load_kg": pt}

	return {"max_udl_kgm": 100.0, "max_point_load_kg": 300.0}

static func calculate_simply_supported_beam(
	span_m: float,
	udl_kgm: float,
	point_loads: Array, # Array of { "x": float, "load_kg": float }
	load_table: Array = []
) -> Dictionary:
	var L := maxf(0.1, span_m)
	var R_A := (udl_kgm * L) * 0.5
	var R_B := (udl_kgm * L) * 0.5
	var center_equiv_point := (udl_kgm * L) * 0.5
	var total_point_kg := 0.0

	for pt in point_loads:
		var px := clampf(float(pt.get("x", 0.0)), 0.0, L)
		var p_kg := float(pt.get("load_kg", 0.0))
		total_point_kg += p_kg
		R_A += p_kg * ((L - px) / L)
		R_B += p_kg * (px / L)
		center_equiv_point += p_kg * (4.0 * px * (L - px)) / (L * L)

	var rating := interpolate_load_rating(load_table, L)
	var allow_pt := float(rating.get("max_point_load_kg", 500.0))
	var allow_udl := float(rating.get("max_udl_kgm", 100.0))

	var util_bending := center_equiv_point / maxf(1.0, allow_pt)
	var util_udl := udl_kgm / maxf(0.1, allow_udl)
	var final_utilization := maxf(util_bending, util_udl)

	return {
		"span_m": L,
		"udl_kgm": udl_kgm,
		"total_load_kg": total_point_kg + (udl_kgm * L),
		"reaction_a": R_A,
		"reaction_b": R_B,
		"center_equiv_load_kg": center_equiv_point,
		"allowed_point_load_kg": allow_pt,
		"allowed_udl_kgm": allow_udl,
		"utilization": final_utilization
	}

# --- Threaded Solve Architecture ---

func _on_solve_timer_timeout() -> void:
	if AppState.stage_container == null:
		return

	# 1. Main-Thread Snapshot
	var snapshot: Array[Dictionary] = []
	for child in AppState.stage_container.get_children():
		if child is StageObject and is_instance_valid(child):
			var so := child as StageObject
			# Exclude crowds and general dressing from structural rigging graph
			if so.category == "Crowd" or so.subcategory == "Crowd":
				continue
			if so.category == "Environment & Dressing":
				continue

			var aabb := so.get_world_aabb()
			var raw_merged: Dictionary = so.raw_catalog_data.duplicate(true)
			for ov_k in so.rigging_overrides:
				raw_merged[ov_k] = so.rigging_overrides[ov_k]

			snapshot.append({
				"node_ref": so,
				"instance_id": so.instance_id,
				"catalog_id": so.catalog_id,
				"name": so.asset_name,
				"category": so.category,
				"subcategory": so.subcategory,
				"transform": so.global_transform,
				"dimensions": so.dimensions,
				"weight_kg": so.weight_kg,
				"raw_catalog_data": raw_merged,
				"snap_points": so.get_global_snap_points(),
				"world_aabb": aabb
			})

	_current_generation += 1
	var gen := _current_generation

	# 2. Dispatch Worker Thread Task
	_is_solving = true
	WorkerThreadPool.add_task(Callable(self, "_solve_worker").bind(snapshot, gen))

func _solve_worker(snapshot: Array[Dictionary], gen: int) -> void:
	if gen != _current_generation:
		return

	var res := _run_rigging_solve(snapshot, gen)

	if gen == _current_generation:
		call_deferred("_apply_solve_results", res, gen)

func _run_rigging_solve(snapshot: Array[Dictionary], gen: int) -> Dictionary:
	var result_warnings: Array[Dictionary] = []
	var result_spans: Array[Dictionary] = []
	var result_supports: Array[Dictionary] = []
	var result_lines: Array[Dictionary] = []

	var trusses: Array[Dictionary] = []
	var hoists: Array[Dictionary] = []
	var supports: Array[Dictionary] = []
	var fixtures: Array[Dictionary] = []

	# Classify objects
	for obj in snapshot:
		var cat: String = obj.category
		var subcat: String = obj.subcategory
		var raw: Dictionary = obj.raw_catalog_data

		if cat == "Truss":
			trusses.append(obj)
		elif cat == "Rigging" and ("hoist" in obj.catalog_id or "motor" in obj.catalog_id):
			hoists.append(obj)
		elif raw.get("is_support", false) or "tower" in obj.catalog_id or "base" in obj.catalog_id:
			supports.append(obj)
		else:
			fixtures.append(obj)

	# --- Rule 6: Check Mixed Truss Profiles ---
	for i in range(trusses.size()):
		var t1: Dictionary = trusses[i]
		var prof1: String = t1.raw_catalog_data.get("truss_profile", "box_f34")
		for j in range(i + 1, trusses.size()):
			var t2: Dictionary = trusses[j]
			var prof2: String = t2.raw_catalog_data.get("truss_profile", "box_f34")
			if prof1 != prof2:
				var dist: float = (t1.transform.origin - t2.transform.origin).length()
				if dist < 0.6: # Snapped or flush together
					result_warnings.append({
						"severity": Severity.WARNING,
						"rule_id": "mixed_truss_profiles",
						"object_id": t1.instance_id,
						"object_name": t1.name,
						"message": "Incompatible truss connection between '%s' (%s) and '%s' (%s)" % [t1.name, prof1, t2.name, prof2],
						"details": "Directly joining triangle (F33) and box (F34) profiles is unsafe without a rated adapter.",
						"suggested_fix": "Use uniform truss profiles throughout the run or insert an engineered transition block."
					})

	# --- Rule 5: Hoist with no load path (hung in air with no structure) ---
	for h in hoists:
		var h_pos: Vector3 = h.transform.origin
		var has_structure := false
		for sup in supports:
			if (sup.transform.origin - h_pos).length() < 3.0:
				has_structure = true
				break
		if not has_structure and h_pos.y > 0.5:
			# Check if near truss above it
			for tr in trusses:
				if tr.transform.origin.y >= h_pos.y and (tr.transform.origin - h_pos).length() < 1.5:
					has_structure = true
					break
		if not has_structure and h_pos.y > 1.0:
			result_warnings.append({
				"severity": Severity.WARNING,
				"rule_id": "hoist_no_load_path",
				"object_id": h.instance_id,
				"object_name": h.name,
				"message": "Hoist '%s' has no structural anchor / dead-hung in air" % h.name,
				"details": "Electric chain hoist is floating without connection to mother grid or roof structure.",
				"suggested_fix": "Rig top hook to an overhead beam, tower, or structural truss chord."
			})

	# --- Solve Truss Spans & Support Reactions ---
	# Group connected collinear trusses into spans
	var processed_trusses: Dictionary = {}

	for tr in trusses:
		var tr_id: String = tr.instance_id
		if processed_trusses.has(tr_id):
			continue

		# Form run
		var run: Array[Dictionary] = [tr]
		processed_trusses[tr_id] = true
		var tr_dir: Vector3 = tr.transform.basis.z.normalized()

		for other in trusses:
			var o_id: String = other.instance_id
			if processed_trusses.has(o_id):
				continue
			var delta: Vector3 = other.transform.origin - tr.transform.origin
			if delta.length() < 4.5 and absf(tr_dir.dot((other.transform.basis.z).normalized())) > 0.95:
				run.append(other)
				processed_trusses[o_id] = true

		# Compute total span length
		var total_length := 0.0
		var min_pos: Vector3 = tr.transform.origin
		var max_pos: Vector3 = tr.transform.origin
		var total_truss_weight := 0.0

		for member in run:
			var d_len := float(member.dimensions.z)
			total_length += d_len
			total_truss_weight += float(member.weight_kg)
			var o_pos: Vector3 = member.transform.origin
			min_pos.x = minf(min_pos.x, o_pos.x)
			min_pos.y = minf(min_pos.y, o_pos.y)
			min_pos.z = minf(min_pos.z, o_pos.z)
			max_pos.x = maxf(max_pos.x, o_pos.x)
			max_pos.y = maxf(max_pos.y, o_pos.y)
			max_pos.z = maxf(max_pos.z, o_pos.z)

		var span_len := maxf(total_length, (max_pos - min_pos).length())
		span_len = maxf(span_len, 2.0)
		var udl_kgm := total_truss_weight / span_len

		# Find attached fixtures
		var point_loads: Array[Dictionary] = []
		for fix in fixtures:
			var fix_pos: Vector3 = fix.transform.origin
			# Check proximity to span bounding box
			var near_span := false
			for member in run:
				var aabb: AABB = member.world_aabb
				if aabb.grow(0.35).has_point(fix_pos + Vector3(0, fix.dimensions.y, 0)):
					near_span = true
					break
			if near_span:
				var local_x := clampf((fix_pos - min_pos).length(), 0.0, span_len)
				point_loads.append({
					"x": local_x,
					"load_kg": fix.weight_kg,
					"fixture": fix
				})

				# Visual line from fixture to truss
				result_lines.append({
					"from": fix_pos + Vector3(0, fix.dimensions.y * 0.8, 0),
					"to": fix_pos + Vector3(0, fix.dimensions.y + 0.1, 0),
					"color": Color(0.2, 0.9, 0.3),
					"utilization": 0.3,
					"text": "%.1f kg" % fix.weight_kg
				})

		# Solve beam statics
		var load_table: Array = tr.raw_catalog_data.get("load_rating", {}).get("table", [])
		var beam_result := calculate_simply_supported_beam(span_len, udl_kgm, point_loads, load_table)
		beam_result["run_members"] = run
		result_spans.append(beam_result)

		var util: float = beam_result.utilization
		var color := Color(0.2, 0.85, 0.3) # Green < 60%
		if util >= 1.0:
			color = Color(0.95, 0.15, 0.15) # Red > 100%
		elif util >= 0.90:
			color = Color(0.95, 0.55, 0.1) # Orange 90-100%
		elif util >= 0.60:
			color = Color(0.95, 0.85, 0.15) # Yellow 60-90%

		# Span representation line
		result_lines.append({
			"from": min_pos,
			"to": max_pos,
			"color": color,
			"utilization": util,
			"text": "%.1f%% Util (%.1f kg)" % [util * 100.0, beam_result.total_load_kg]
		})

		# --- Rule 1: Overloaded Truss Span ---
		if util > 1.0:
			result_warnings.append({
				"severity": Severity.CRITICAL,
				"rule_id": "overloaded_truss",
				"object_id": tr.instance_id,
				"object_name": tr.name,
				"message": "Truss span '%s' (%.1fm) is overloaded: %.1f%% utilization (%s / %s)" % [
					tr.name, span_len, util * 100.0,
					format_mass(beam_result.center_equiv_load_kg),
					format_mass(beam_result.allowed_point_load_kg)
				],
				"details": "Calculated center-equivalent bending load exceeds allowable capacity.",
				"suggested_fix": "Add an intermediate support hoist/tower or reduce attached equipment weight."
			})

		# Assign reactions to nearby hoists or towers
		var reaction_a: float = beam_result.reaction_a
		var reaction_b: float = beam_result.reaction_b

		for h in hoists:
			var h_pos: Vector3 = h.transform.origin
			if (h_pos - min_pos).length() < 1.5:
				_evaluate_hoist(h, reaction_a, result_warnings, result_lines)
			elif (h_pos - max_pos).length() < 1.5:
				_evaluate_hoist(h, reaction_b, result_warnings, result_lines)

		for sup in supports:
			var s_pos: Vector3 = sup.transform.origin
			if (s_pos - min_pos).length() < 1.5:
				_evaluate_support(sup, reaction_a, result_warnings, result_lines)
			elif (s_pos - max_pos).length() < 1.5:
				_evaluate_support(sup, reaction_b, result_warnings, result_lines)

	# --- Rule 4: Unsupported / Floating Objects ---
	for fix in fixtures:
		var fix_pos: Vector3 = fix.transform.origin
		if fix_pos.y > 0.05:
			# Check if supported by any truss, deck, or ground
			var supported := false
			for tr in trusses:
				if tr.world_aabb.grow(0.4).has_point(fix_pos + Vector3(0, fix.dimensions.y, 0)):
					supported = true
					break
			if not supported:
				# Check if resting on elevated deck or riser
				for other in snapshot:
					if other.category == "Staging" and other.world_aabb.grow(0.05).has_point(fix_pos):
						supported = true
						break
			if not supported:
				result_warnings.append({
					"severity": Severity.WARNING,
					"rule_id": "unsupported_object",
					"object_id": fix.instance_id,
					"object_name": fix.name,
					"message": "Object '%s' is floating / unsupported at elevation %.2fm" % [fix.name, fix_pos.y],
					"details": "Item has no structural load path to any truss, hoist, deck, or ground support.",
					"suggested_fix": "Clamp to a truss chord, hang from a hoist, or lower onto a stage deck."
				})

	# --- Rule 7: Item hung from a non-rated point ---
	for fix in fixtures:
		var fix_pos: Vector3 = fix.transform.origin
		if fix_pos.y > 0.5:
			for other in snapshot:
				if other.instance_id == fix.instance_id or other.category == "Truss":
					continue
				var aabb: AABB = other.world_aabb
				if aabb.grow(0.3).has_point(fix_pos + Vector3(0, fix.dimensions.y, 0)):
					var raw_other: Dictionary = other.raw_catalog_data
					var is_sup: bool = raw_other.get("is_support", false)
					var has_rated_point := false
					if raw_other.has("rigging_points") and raw_other["rigging_points"] is Array:
						for rp in raw_other["rigging_points"]:
							if rp.get("type", "") in ["hang", "load"]:
								has_rated_point = true
								break
					if not is_sup and not has_rated_point and other.category != "Staging":
						result_warnings.append({
							"severity": Severity.WARNING,
							"rule_id": "non_rated_point",
							"object_id": fix.instance_id,
							"object_name": fix.name,
							"message": "Item '%s' hung from non-rated point on '%s'" % [fix.name, other.name],
							"details": "Suspension from '%s' is unrated for overhead dynamic or dead loads." % other.name,
							"suggested_fix": "Rig from a certified truss chord, rated clamp point, or structural steel."
						})
						break

	# Sort warnings: CRITICAL first, then WARNING, then INFO
	result_warnings.sort_custom(func(a, b): return int(a.severity) > int(b.severity))

	return {
		"warnings": result_warnings,
		"spans": result_spans,
		"supports": result_supports,
		"lines": result_lines,
		"generation": gen
	}

func _evaluate_hoist(hoist: Dictionary, load_kg: float, warnings_out: Array, lines_out: Array) -> void:
	var swl := float(hoist.raw_catalog_data.get("swl_kg", 1000.0))
	var capacity := swl / motor_safety_factor
	var util := load_kg / maxf(1.0, capacity)

	var color := Color(0.2, 0.85, 0.3)
	if util >= 1.0:
		color = Color(0.95, 0.15, 0.15)
	elif util >= 0.90:
		color = Color(0.95, 0.55, 0.1)
	elif util >= 0.60:
		color = Color(0.95, 0.85, 0.15)

	lines_out.append({
		"from": hoist.transform.origin,
		"to": hoist.transform.origin + Vector3(0, hoist.dimensions.y, 0),
		"color": color,
		"utilization": util,
		"text": "Hoist: %s / %s (%.0f%%)" % [format_mass(load_kg), format_mass(capacity), util * 100.0]
	})

	# --- Rule 2: Overloaded Hoist ---
	if util > 1.0:
		warnings_out.append({
			"severity": Severity.CRITICAL,
			"rule_id": "overloaded_hoist",
			"object_id": hoist.instance_id,
			"object_name": hoist.name,
			"message": "Hoist '%s' overloaded: %.1f%% utilization (%s / rated %s with SF %.1f)" % [
				hoist.name, util * 100.0, format_mass(load_kg), format_mass(swl), motor_safety_factor
			],
			"details": "Applied reaction exceeds motor working limit with current safety factor.",
			"suggested_fix": "Upgrade to a higher capacity hoist (e.g. 2t) or add an additional pickup point."
		})

func _evaluate_support(support: Dictionary, load_kg: float, warnings_out: Array, lines_out: Array) -> void:
	var max_load := float(support.raw_catalog_data.get("max_vertical_load_kg", 4000.0))
	var sup_w := float(support.get("weight_kg", 0.0))
	var total_vert := load_kg + sup_w
	var util := total_vert / maxf(1.0, max_load)

	var color := Color(0.2, 0.85, 0.3)
	if util >= 1.0:
		color = Color(0.95, 0.15, 0.15)
	elif util >= 0.90:
		color = Color(0.95, 0.55, 0.1)
	elif util >= 0.60:
		color = Color(0.95, 0.85, 0.15)

	lines_out.append({
		"from": support.transform.origin,
		"to": support.transform.origin + Vector3(0, support.dimensions.y, 0),
		"color": color,
		"utilization": util,
		"text": "Support: %s / %s" % [format_mass(total_vert), format_mass(max_load)]
	})

	# --- Rule 3: Overloaded Tower / Support ---
	if util > 1.0:
		warnings_out.append({
			"severity": Severity.CRITICAL,
			"rule_id": "overloaded_tower",
			"object_id": support.instance_id,
			"object_name": support.name,
			"message": "Support tower '%s' overloaded: %.1f%% utilization (%s / %s)" % [
				support.name, util * 100.0, format_mass(total_vert), format_mass(max_load)
			],
			"details": "Total vertical reaction from attached truss exceeds tower maximum rated capacity.",
			"suggested_fix": "Add intermediate ground support masts or reduce total carried load."
		})

# --- Main-Thread Result Application ---

func _apply_solve_results(res: Dictionary, gen: int) -> void:
	if gen != _current_generation:
		return

	_is_solving = false
	warnings = res.get("warnings", [])
	spans_data = res.get("spans", [])
	supports_data = res.get("supports", [])
	overlay_lines = res.get("lines", [])

	critical_count = 0
	warning_count = 0
	info_count = 0

	for w in warnings:
		match int(w.severity):
			Severity.CRITICAL: critical_count += 1
			Severity.WARNING: warning_count += 1
			Severity.INFO: info_count += 1

	rigging_solved.emit(res)
