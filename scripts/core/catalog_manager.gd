extends Node

## Singleton catalog loader and factory for Stage-Builder.
## Reads data/catalog.json and instantiates StageObject nodes dynamically.

signal catalog_loaded

var _assets_by_id: Dictionary = {}
var _categories: Array[String] = []
var _catalog_path: String = "res://data/catalog.json"

func _ready() -> void:
	load_catalog(_catalog_path)

func load_catalog(path: String) -> bool:
	_assets_by_id.clear()
	_categories.clear()

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
		var id: String = asset.get("id", "")
		if id != "":
			_assets_by_id[id] = asset
			var cat: String = asset.get("category", "General")
			if not _categories.has(cat):
				_categories.append(cat)

	_categories.sort()
	catalog_loaded.emit()
	print("CatalogManager: Loaded %d assets across %d categories." % [_assets_by_id.size(), _categories.size()])
	return true

func get_all_assets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _assets_by_id.values():
		result.append(item)
	return result

func get_categories() -> Array[String]:
	return _categories.duplicate()

func get_assets_by_category(cat: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _assets_by_id.values():
		if item.get("category", "") == cat:
			result.append(item)
	return result

func get_asset_by_id(id: String) -> Dictionary:
	return _assets_by_id.get(id, {})

func search_assets(query: String) -> Array[Dictionary]:
	var q := query.strip_edges().to_lower()
	if q == "":
		return get_all_assets()

	var result: Array[Dictionary] = []
	for item in _assets_by_id.values():
		var name_match: bool = q in item.get("name", "").to_lower()
		var cat_match: bool = q in item.get("category", "").to_lower()
		var tag_match: bool = false
		for tag in item.get("tags", []):
			if q in str(tag).to_lower():
				tag_match = true
				break

		if name_match or cat_match or tag_match:
			result.append(item)

	return result

func instantiate_asset(id: String) -> StageObject:
	var data := get_asset_by_id(id)
	if data.is_empty():
		push_error("Cannot instantiate asset: ID not found '%s'" % id)
		return null

	var obj := StageObject.new()
	obj.name = data.get("name", "StageObject").replace(" ", "_")
	obj.setup_from_catalog(data)
	return obj
