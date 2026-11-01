class_name AssetPanel
extends PanelContainer

## Left Asset Catalog Browser for Stage-Builder.
## Provides real-time search, category filtering, and one-click placement for all production equipment.

@onready var search_input: LineEdit = %SearchInput
@onready var category_filter: OptionButton = %CategoryFilter
@onready var asset_list_container: VBoxContainer = %AssetListContainer

var current_category: String = "All"
var current_search: String = ""

func _ready() -> void:
	search_input.text_changed.connect(_on_search_changed)
	category_filter.item_selected.connect(_on_category_selected)
	CatalogManager.catalog_loaded.connect(_populate_categories)
	CatalogManager.catalog_loaded.connect(_refresh_asset_list)

	_populate_categories()
	_refresh_asset_list()

func _populate_categories() -> void:
	category_filter.clear()
	category_filter.add_item("All Categories")
	var cats := CatalogManager.get_categories()
	for cat in cats:
		category_filter.add_item(cat)

func _on_search_changed(new_text: String) -> void:
	current_search = new_text
	_refresh_asset_list()

func _on_category_selected(index: int) -> void:
	if index == 0:
		current_category = "All"
	else:
		current_category = category_filter.get_item_text(index)
	_refresh_asset_list()

func _refresh_asset_list() -> void:
	# Clear existing cards
	for child in asset_list_container.get_children():
		child.queue_free()

	var assets: Array[Dictionary]
	if current_search != "":
		assets = CatalogManager.search_assets(current_search)
		if current_category != "All":
			var filtered: Array[Dictionary] = []
			for item in assets:
				if item.get("category", "") == current_category:
					filtered.append(item)
			assets = filtered
	elif current_category != "All":
		assets = CatalogManager.get_assets_by_category(current_category)
	else:
		assets = CatalogManager.get_all_assets()

	if assets.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No equipment matches query."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		asset_list_container.add_child(empty_lbl)
		return

	for item in assets:
		var card := _create_asset_card(item)
		asset_list_container.add_child(card)

func _create_asset_card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.20)
	style.border_color = Color(0.24, 0.26, 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Row 1: Name and Category badge
	var header_hbox := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Asset")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	header_hbox.add_child(name_lbl)

	var cat_badge := Label.new()
	cat_badge.text = item.get("category", "")
	cat_badge.add_theme_font_size_override("font_size", 10)
	cat_badge.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	header_hbox.add_child(cat_badge)
	vbox.add_child(header_hbox)

	# Row 2: Dimensions & Weight
	var dims: Dictionary = item.get("dimensions", {})
	var dim_str := "%.1fx%.1fx%.1fm" % [dims.get("x", 1.0), dims.get("y", 1.0), dims.get("z", 1.0)]
	var weight_str := "%.1f kg" % float(item.get("weight_kg", 0.0))

	var info_lbl := Label.new()
	info_lbl.text = "%s  •  %s" % [dim_str, weight_str]
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	vbox.add_child(info_lbl)

	# Row 3: Action Buttons
	var btn_hbox := HBoxContainer.new()
	var place_btn := Button.new()
	place_btn.text = "Place"
	place_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_btn.add_theme_font_size_override("font_size", 12)
	var asset_id: String = item.get("id", "")
	place_btn.pressed.connect(func(): AppState.start_placement(asset_id))
	btn_hbox.add_child(place_btn)
	vbox.add_child(btn_hbox)

	card.add_child(vbox)
	return card

