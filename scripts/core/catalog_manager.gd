extends Node

## Singleton catalog loader and factory for Stage-Builder Phase 2.
## Reads data/catalog.json, merges user://imported_catalog.json,
## and manages subcategories, favorites, and recently used equipment.

signal catalog_loaded
signal favorites_changed

const USER_IMPORTED_CATALOG = "user://imported_catalog.json"
const USER_FAVORITES_PATH = "user://favorites.json"
const USER_RECENTS_PATH = "user://recent_assets.json"
const MAX_RECENT_ASSETS = 20

## Phase 1 Backward Compatibility ID Alias Map
const PHASE1_LEGACY_ALIASES: Dictionary = {
	"truss_straight_05m": "truss_box_05m",
	"truss_straight_1m": "truss_box_1m",
	"truss_straight_2m": "truss_box_2m",
	"truss_straight_3m": "truss_box_3m",
	"truss_corner": "truss_corner_2way_90",
	"truss_tower_section": "truss_tower_section_2m",
	"truss_base_plate": "truss_base_plate_small",
	"staging_deck_2x1": "staging_deck_2x1m",
	"staging_deck_1x1": "staging_deck_1x1m",
	"staging_stairs": "staging_stairs_4step",
	"staging_handrail": "staging_barricade_straight",
	"staging_barricade": "staging_barricade_straight",
	"audio_line_array": "audio_array_standard_10in",
	"audio_subwoofer": "audio_sub_dual_18in",
	"audio_stage_monitor": "audio_wedge_monitor_12in",
	"audio_foh_console": "audio_console_foh_large",
	"audio_amp_rack": "audio_amprack_touring_12u",
	"lighting_moving_head": "lighting_moving_spot",
	"lighting_par_can": "lighting_par_touring_led",
	"lighting_led_bar": "lighting_bar_pixel_1m",
	"video_led_panel": "video_led_panel_05m",
	"power_distro_rack": "power_distro_63a",
	"power_water_tank": "power_ballast_water_tank_1000l",
	"dj_table_booth": "dj_booth_curved_facade",
	"dj_4deck_setup": "dj_setup_4deck",
	"crowd_single_figure": "crowd_single_standing",
	"crowd_block": "crowd_block_medium_100pax"
}

var _assets_by_id: Dictionary = {}
var _categories: Array[String] = []
var _subcategories_by_cat: Dictionary = {}
var _favorites: Array[String] = []
var _recent_assets: Array[String] = []
var _catalog_path: String = "res://data/catalog.json"

func _ready() -> void:
	_load_favorites()
	_load_recents()
	load_catalog(_catalog_path)

func load_catalog(path: String) -> bool:
	_assets_by_id.clear()
	_categories.clear()
	_subcategories_by_cat.clear()

	# 1. Load Core Built-in Catalog
	if not FileAccess.file_exists(path):
		push_error("Catalog file not found: " + path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_error("Failed to parse catalog JSON: " + json.get_error_message())
		return false

	var data: Dictionary = json.data
	var asset_list: Array = data.get("assets", [])

	for asset in asset_list:
		_register_asset_dict(asset)

	# 2. Merge User-Imported Catalog (outside the repo)
	_merge_user_imported_catalog()

	_categories.sort()
	catalog_loaded.emit()
	print("CatalogManager: Loaded %d assets across %d categories." % [_assets_by_id.size(), _categories.size()])
	return true

func _register_asset_dict(asset: Dictionary) -> void:
	var id: String = asset.get("id", "")
	if id == "":
		return

	_assets_by_id[id] = asset
	var cat: String = asset.get("category", "General")
	if not _categories.has(cat):
		_categories.append(cat)

	if not _subcategories_by_cat.has(cat):
		_subcategories_by_cat[cat] = []
	var subcat: String = asset.get("subcategory", "General")
	if not _subcategories_by_cat[cat].has(subcat):
		_subcategories_by_cat[cat].append(subcat)

func _merge_user_imported_catalog() -> void:
	if not FileAccess.file_exists(USER_IMPORTED_CATALOG):
		return

	var file := FileAccess.open(USER_IMPORTED_CATALOG, FileAccess.READ)
	var content := file.get_as_text()
	var json := JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		var imported_list: Array = json.data.get("assets", [])
		for asset in imported_list:
			_register_asset_dict(asset)
		print("CatalogManager: Merged %d user-imported assets." % imported_list.size())

func register_imported_asset(asset_dict: Dictionary) -> bool:
	_register_asset_dict(asset_dict)

	# Read existing user imported catalog or create new
	var imported_data := {"assets": []}
	if FileAccess.file_exists(USER_IMPORTED_CATALOG):
		var file := FileAccess.open(USER_IMPORTED_CATALOG, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			imported_data = json.data

	var assets_arr: Array = imported_data.get("assets", [])
	# Update or append
	var existing_idx := -1
	for i in range(assets_arr.size()):
		if assets_arr[i].get("id", "") == asset_dict.get("id", ""):
			existing_idx = i
			break

	if existing_idx != -1:
		assets_arr[existing_idx] = asset_dict
	else:
		assets_arr.append(asset_dict)

	imported_data["assets"] = assets_arr

	var out_file := FileAccess.open(USER_IMPORTED_CATALOG, FileAccess.WRITE)
	if out_file:
		out_file.store_string(JSON.stringify(imported_data, "  "))
		catalog_loaded.emit()
		return true
	return false

# --- Query Methods ---

func get_all_assets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _assets_by_id.values():
		result.append(item)
	return result

func get_categories() -> Array[String]:
	return _categories.duplicate()

func get_subcategories(category: String) -> Array[String]:
	if _subcategories_by_cat.has(category):
		var list: Array[String] = []
		for s in _subcategories_by_cat[category]:
			list.append(s)
		list.sort()
		return list
	return []

func get_assets_by_category(cat: String, subcat: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _assets_by_id.values():
		if item.get("category", "") == cat:
			if subcat == "" or subcat == "All" or item.get("subcategory", "") == subcat:
				result.append(item)
	return result

func get_asset_by_id(id: String) -> Dictionary:
	if _assets_by_id.has(id):
		return _assets_by_id[id]
	if PHASE1_LEGACY_ALIASES.has(id):
		var mapped_id: String = PHASE1_LEGACY_ALIASES[id]
		return _assets_by_id.get(mapped_id, {})
	return {}

func get_asset(id: String) -> Dictionary:
	return get_asset_by_id(id)

func search_assets(query: String, cat: String = "All", subcat: String = "All") -> Array[Dictionary]:
	var q := query.strip_edges().to_lower()
	var result: Array[Dictionary] = []

	for item in _assets_by_id.values():
		if cat != "All" and item.get("category", "") != cat:
			continue
		if subcat != "All" and subcat != "" and item.get("subcategory", "") != subcat:
			continue

		if q == "":
			result.append(item)
			continue

		var name_match: bool = q in item.get("name", "").to_lower()
		var cat_match: bool = q in item.get("category", "").to_lower()
		var subcat_match: bool = q in item.get("subcategory", "").to_lower()
		var tag_match: bool = false
		for tag in item.get("tags", []):
			if q in str(tag).to_lower():
				tag_match = true
				break

		if name_match or cat_match or subcat_match or tag_match:
			result.append(item)

	return result

func instantiate_asset(id: String, variant_id: String = "") -> StageObject:
	var data := get_asset_by_id(id)
	if data.is_empty():
		push_error("Cannot instantiate asset: ID not found '%s'" % id)
		return null

	var obj := StageObject.new()
	obj.name = data.get("name", "StageObject").replace(" ", "_")
	obj.setup_from_catalog(data, variant_id)
	record_recently_used(id)
	return obj

# --- Favorites Management ---

func is_favorite(asset_id: String) -> bool:
	return _favorites.has(asset_id)

func toggle_favorite(asset_id: String) -> void:
	if _favorites.has(asset_id):
		_favorites.erase(asset_id)
	else:
		_favorites.append(asset_id)
	_save_favorites()
	favorites_changed.emit()

func get_favorites() -> Array[String]:
	return _favorites.duplicate()

func _load_favorites() -> void:
	if FileAccess.file_exists(USER_FAVORITES_PATH):
		var file := FileAccess.open(USER_FAVORITES_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Array:
			_favorites.clear()
			for item in json.data:
				if item is String:
					_favorites.append(item)

func _save_favorites() -> void:
	var file := FileAccess.open(USER_FAVORITES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_favorites))

# --- Recently Used History ---

func record_recently_used(asset_id: String) -> void:
	_recent_assets.erase(asset_id)
	_recent_assets.push_front(asset_id)
	if _recent_assets.size() > MAX_RECENT_ASSETS:
		_recent_assets.resize(MAX_RECENT_ASSETS)
	_save_recents()

func get_recently_used() -> Array[String]:
	return _recent_assets.duplicate()

func _load_recents() -> void:
	if FileAccess.file_exists(USER_RECENTS_PATH):
		var file := FileAccess.open(USER_RECENTS_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Array:
			_recent_assets.clear()
			for item in json.data:
				if item is String:
					_recent_assets.append(item)

func _save_recents() -> void:
	var file := FileAccess.open(USER_RECENTS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_recent_assets))
