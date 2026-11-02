class_name AssetPanel
extends PanelContainer

signal collapse_requested

const ThumbnailGenerator = preload("res://scripts/tools/thumbnail_generator.gd")

## Upgraded Asset Catalog Browser for Stage-Builder Phase 2.
## Features:
## - 125+ equipment items with real-time search & subcategory filtering
## - Auto-generated cached thumbnails
## - Grid View vs. List View toggle
## - Favorites (★) and Recently Used equipment history

enum ViewMode { LIST, GRID }
enum FilterTab { ALL, FAVORITES, RECENTS }

@onready var search_input: LineEdit = %SearchInput
@onready var category_filter: OptionButton = %CategoryFilter
@onready var subcategory_filter: OptionButton = %SubcategoryFilter
@onready var tab_all_btn: Button = %TabAllBtn
@onready var tab_favs_btn: Button = %TabFavsBtn
@onready var tab_recents_btn: Button = %TabRecentsBtn
@onready var view_mode_btn: Button = %ViewModeBtn
@onready var asset_list_container: VBoxContainer = %AssetListContainer
@onready var asset_grid_container: HFlowContainer = %AssetGridContainer

var current_category: String = "All"
var current_subcategory: String = "All"
var current_search: String = ""
var current_tab: FilterTab = FilterTab.ALL
var current_view_mode: ViewMode = ViewMode.LIST

func _ready() -> void:
	category_filter.fit_to_longest_item = false
	category_filter.clip_text = true
	subcategory_filter.fit_to_longest_item = false
	subcategory_filter.clip_text = true
	tab_all_btn.clip_text = true
	tab_favs_btn.clip_text = true
	tab_recents_btn.clip_text = true

	if has_node("%CollapseLeftBtn"):
		%CollapseLeftBtn.pressed.connect(func(): collapse_requested.emit())

	search_input.text_changed.connect(_on_search_changed)
	category_filter.item_selected.connect(_on_category_selected)
	subcategory_filter.item_selected.connect(_on_subcategory_selected)

	tab_all_btn.pressed.connect(func(): _switch_tab(FilterTab.ALL))
	tab_favs_btn.pressed.connect(func(): _switch_tab(FilterTab.FAVORITES))
	tab_recents_btn.pressed.connect(func(): _switch_tab(FilterTab.RECENTS))
	view_mode_btn.pressed.connect(_toggle_view_mode)

	CatalogManager.catalog_loaded.connect(_on_catalog_loaded)
	CatalogManager.favorites_changed.connect(_refresh_asset_list)

	_on_catalog_loaded()

func _on_catalog_loaded() -> void:
	_populate_categories()
	_populate_subcategories()
	_refresh_asset_list()

func _populate_categories() -> void:
	category_filter.clear()
	category_filter.add_item("All Categories")
	category_filter.fit_to_longest_item = false
	category_filter.clip_text = true
	var cats := CatalogManager.get_categories()
	for cat in cats:
		category_filter.add_item(cat)

func _populate_subcategories() -> void:
	subcategory_filter.clear()
	subcategory_filter.add_item("All Types")
	subcategory_filter.fit_to_longest_item = false
	subcategory_filter.clip_text = true

	if current_category != "All":
		var subcats := CatalogManager.get_subcategories(current_category)
		for s in subcats:
			subcategory_filter.add_item(s)
		subcategory_filter.disabled = false
	else:
		subcategory_filter.disabled = true

func _on_search_changed(new_text: String) -> void:
	current_search = new_text
	_refresh_asset_list()

func _on_category_selected(index: int) -> void:
	if index == 0:
		current_category = "All"
	else:
		current_category = category_filter.get_item_text(index)
	current_subcategory = "All"
	_populate_subcategories()
	_refresh_asset_list()

func _on_subcategory_selected(index: int) -> void:
	if index == 0:
		current_subcategory = "All"
	else:
		current_subcategory = subcategory_filter.get_item_text(index)
	_refresh_asset_list()

func _switch_tab(tab: FilterTab) -> void:
	current_tab = tab
	tab_all_btn.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0) if tab == FilterTab.ALL else Color(0.7, 0.7, 0.7))
	tab_favs_btn.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0) if tab == FilterTab.FAVORITES else Color(0.7, 0.7, 0.7))
	tab_recents_btn.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0) if tab == FilterTab.RECENTS else Color(0.7, 0.7, 0.7))
	_refresh_asset_list()

func _toggle_view_mode() -> void:
	if current_view_mode == ViewMode.LIST:
		current_view_mode = ViewMode.GRID
		view_mode_btn.text = "List"
		asset_list_container.visible = false
		asset_grid_container.visible = true
	else:
		current_view_mode = ViewMode.LIST
		view_mode_btn.text = "Grid"
		asset_list_container.visible = true
		asset_grid_container.visible = false
	_refresh_asset_list()

func _refresh_asset_list() -> void:
	# Clear both containers
	for child in asset_list_container.get_children():
		child.queue_free()
	for child in asset_grid_container.get_children():
		child.queue_free()

	var assets: Array[Dictionary] = []

	if current_tab == FilterTab.FAVORITES:
		var fav_ids := CatalogManager.get_favorites()
		for id in fav_ids:
			var item := CatalogManager.get_asset_by_id(id)
			if not item.is_empty():
				assets.append(item)
	elif current_tab == FilterTab.RECENTS:
		var rec_ids := CatalogManager.get_recently_used()
		for id in rec_ids:
			var item := CatalogManager.get_asset_by_id(id)
			if not item.is_empty():
				assets.append(item)
	else:
		assets = CatalogManager.search_assets(current_search, current_category, current_subcategory)

	if assets.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No equipment found."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if current_view_mode == ViewMode.LIST:
			asset_list_container.add_child(empty_lbl)
		else:
			asset_grid_container.add_child(empty_lbl)
		return

	for item in assets:
		if current_view_mode == ViewMode.LIST:
			var card := _create_list_card(item)
			asset_list_container.add_child(card)
		else:
			var card := _create_grid_card(item)
			asset_grid_container.add_child(card)

# --- List View Card ---

func _create_list_card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.16, 0.19)
	style.border_color = Color(0.24, 0.26, 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Thumbnail
	var thumb_tex := ThumbnailGenerator.get_thumbnail(item)
	var thumb_rect := TextureRect.new()
	thumb_rect.texture = thumb_tex
	thumb_rect.custom_minimum_size = Vector2(48, 48)
	thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(thumb_rect)

	# Info
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	var top_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Asset")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	top_row.add_child(name_lbl)

	# Favorite star
	var asset_id: String = item.get("id", "")
	var is_fav := CatalogManager.is_favorite(asset_id)
	var star_btn := Button.new()
	star_btn.text = "★" if is_fav else "☆"
	star_btn.flat = true
	star_btn.add_theme_font_size_override("font_size", 13)
	star_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if is_fav else Color(0.5, 0.5, 0.5))
	star_btn.pressed.connect(func():
		CatalogManager.toggle_favorite(asset_id)
	)
	top_row.add_child(star_btn)
	vbox.add_child(top_row)

	var dims: Dictionary = item.get("dimensions", {})
	var dim_str := "%.1fx%.1fx%.1fm" % [dims.get("x", 1.0), dims.get("y", 1.0), dims.get("z", 1.0)]
	var weight_str := "%.1f kg" % float(item.get("weight_kg", 0.0))

	var info_lbl := Label.new()
	info_lbl.text = "%s  •  %s" % [dim_str, weight_str]
	info_lbl.clip_text = true
	info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	vbox.add_child(info_lbl)

	hbox.add_child(vbox)

	# Place button
	var place_btn := Button.new()
	place_btn.text = "Place"
	place_btn.custom_minimum_size = Vector2(46, 0)
	place_btn.add_theme_font_size_override("font_size", 12)
	place_btn.pressed.connect(func(): AppState.start_placement(asset_id))
	hbox.add_child(place_btn)

	card.add_child(hbox)

	# Click card to enter placement mode
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			AppState.start_placement(asset_id)
	)

	# Drag-and-drop into 3D viewport
	card.set_drag_forwarding(
		func(_at_pos: Vector2):
			var preview := Label.new()
			preview.text = " 📦 " + item.get("name", "Asset") + " "
			var p_style := StyleBoxFlat.new()
			p_style.bg_color = Color(0.18, 0.20, 0.25, 0.95)
			p_style.border_color = Color(0.3, 0.6, 1.0)
			p_style.set_border_width_all(1)
			p_style.set_corner_radius_all(4)
			preview.add_theme_stylebox_override("normal", p_style)
			card.set_drag_preview(preview)
			return {"type": "stage_asset", "asset_id": asset_id},
		Callable(),
		Callable()
	)

	return card

# --- Grid View Card ---

func _create_grid_card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.16, 0.19)
	style.border_color = Color(0.24, 0.26, 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(100, 110)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	# Thumbnail
	var thumb_tex := ThumbnailGenerator.get_thumbnail(item)
	var thumb_rect := TextureRect.new()
	thumb_rect.texture = thumb_tex
	thumb_rect.custom_minimum_size = Vector2(88, 54)
	thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(thumb_rect)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Asset")
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.max_lines_visible = 1
	name_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(name_lbl)

	# Click to place button
	var place_btn := Button.new()
	place_btn.text = "Place"
	place_btn.add_theme_font_size_override("font_size", 10)
	var asset_id: String = item.get("id", "")
	place_btn.pressed.connect(func(): AppState.start_placement(asset_id))
	vbox.add_child(place_btn)

	card.add_child(vbox)

	# Click card to enter placement mode
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			AppState.start_placement(asset_id)
	)

	# Drag-and-drop into 3D viewport
	card.set_drag_forwarding(
		func(_at_pos: Vector2):
			var preview := Label.new()
			preview.text = " 📦 " + item.get("name", "Asset") + " "
			var p_style := StyleBoxFlat.new()
			p_style.bg_color = Color(0.18, 0.20, 0.25, 0.95)
			p_style.border_color = Color(0.3, 0.6, 1.0)
			p_style.set_border_width_all(1)
			p_style.set_corner_radius_all(4)
			preview.add_theme_stylebox_override("normal", p_style)
			card.set_drag_preview(preview)
			return {"type": "stage_asset", "asset_id": asset_id},
		Callable(),
		Callable()
	)

	return card
