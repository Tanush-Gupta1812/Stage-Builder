class_name AssetPanel
extends PanelContainer

signal collapse_requested

const ThumbnailGenerator = preload("res://scripts/tools/thumbnail_generator.gd")

## Upgraded Asset Catalog Browser for Stage-Builder Phase 2 & 3.
## Features:
## - 147+ equipment items with debounced real-time multi-word search
## - Card reuse for instant 0ms filtering without losing textures or focus
## - Grid View vs. List View toggle
## - Multi-filter combination: Search AND Category AND Type AND Favorites/Recents
## - No-results empty state with Clear search button
## - Enter-to-place on single result & Esc to clear

enum ViewMode { LIST, GRID }
enum FilterTab { ALL, FAVORITES, RECENTS }

@onready var asset_title: Label = %AssetTitle
@onready var search_input: LineEdit = %SearchInput
@onready var category_filter: OptionButton = %CategoryFilter
@onready var subcategory_filter: OptionButton = %SubcategoryFilter
@onready var tab_all_btn: Button = %TabAllBtn
@onready var tab_favs_btn: Button = %TabFavsBtn
@onready var tab_recents_btn: Button = %TabRecentsBtn
@onready var view_mode_btn: Button = %ViewModeBtn
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var empty_state_container: VBoxContainer = %EmptyStateContainer
@onready var empty_search_label: Label = %EmptySearchLabel
@onready var clear_search_btn: Button = %ClearSearchBtn
@onready var asset_list_container: VBoxContainer = %AssetListContainer
@onready var asset_grid_container: HFlowContainer = %AssetGridContainer

var current_category: String = "All"
var current_subcategory: String = "All"
var current_search: String = ""
var current_tab: FilterTab = FilterTab.ALL
var current_view_mode: ViewMode = ViewMode.LIST

var _debounce_timer: Timer = null
var _list_cards_by_id: Dictionary = {} # asset_id -> Control
var _grid_cards_by_id: Dictionary = {} # asset_id -> Control
var _visible_assets: Array[Dictionary] = []
var _star_buttons: Array[Button] = []

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

	# Debounce Timer (~120ms)
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = 0.12
	_debounce_timer.timeout.connect(func(): apply_filters(true))
	add_child(_debounce_timer)

	search_input.text_changed.connect(_on_search_text_changed)
	search_input.text_submitted.connect(_on_search_text_submitted)
	search_input.gui_input.connect(_on_search_gui_input)
	if clear_search_btn:
		clear_search_btn.pressed.connect(_on_clear_search_pressed)

	category_filter.item_selected.connect(_on_category_selected)
	subcategory_filter.item_selected.connect(_on_subcategory_selected)

	tab_all_btn.pressed.connect(func(): _switch_tab(FilterTab.ALL))
	tab_favs_btn.pressed.connect(func(): _switch_tab(FilterTab.FAVORITES))
	tab_recents_btn.pressed.connect(func(): _switch_tab(FilterTab.RECENTS))
	view_mode_btn.pressed.connect(_toggle_view_mode)

	CatalogManager.catalog_loaded.connect(_on_catalog_loaded)
	CatalogManager.favorites_changed.connect(_on_favorites_changed)
	if is_instance_valid(ThumbnailRenderer.instance):
		ThumbnailRenderer.instance.thumbnail_ready.connect(_on_thumbnail_ready)

	_on_catalog_loaded()

func _on_catalog_loaded() -> void:
	_populate_categories()
	_populate_subcategories()
	_build_all_cards()
	apply_filters(false)

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

func _on_search_text_changed(new_text: String) -> void:
	current_search = new_text
	_debounce_timer.start()

func _on_search_changed(new_text: String) -> void:
	current_search = new_text
	apply_filters(true)

func _on_clear_search_pressed() -> void:
	search_input.text = ""
	current_search = ""
	apply_filters(true)
	search_input.grab_focus()

func _on_search_text_submitted(_text: String) -> void:
	if _visible_assets.size() == 1:
		var target_id: String = _visible_assets[0].get("id", "")
		if target_id != "":
			AppState.start_placement(target_id)
			search_input.release_focus()

func _on_search_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed:
		return

	# Esc clears search box
	if key.keycode == KEY_ESCAPE:
		search_input.text = ""
		current_search = ""
		apply_filters(true)
		search_input.release_focus()
		accept_event()
		return

	# Enter in search box with exactly one result starts placement
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		if _visible_assets.size() == 1:
			var target_id: String = _visible_assets[0].get("id", "")
			if target_id != "":
				AppState.start_placement(target_id)
				search_input.release_focus()
				accept_event()
				return

func _on_category_selected(index: int) -> void:
	if index == 0:
		current_category = "All"
	else:
		current_category = category_filter.get_item_text(index)
	current_subcategory = "All"
	_populate_subcategories()
	apply_filters(true)

func _on_subcategory_selected(index: int) -> void:
	if index == 0:
		current_subcategory = "All"
	else:
		current_subcategory = subcategory_filter.get_item_text(index)
	apply_filters(true)

func _switch_tab(tab: FilterTab) -> void:
	current_tab = tab
	tab_all_btn.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0) if tab == FilterTab.ALL else Color(0.7, 0.7, 0.7))
	tab_favs_btn.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0) if tab == FilterTab.FAVORITES else Color(0.7, 0.7, 0.7))
	tab_recents_btn.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0) if tab == FilterTab.RECENTS else Color(0.7, 0.7, 0.7))
	apply_filters(true)

func _toggle_view_mode() -> void:
	if current_view_mode == ViewMode.LIST:
		current_view_mode = ViewMode.GRID
		view_mode_btn.text = "List"
	else:
		current_view_mode = ViewMode.LIST
		view_mode_btn.text = "Grid"
	apply_filters(false)

func _on_favorites_changed() -> void:
	for btn in _star_buttons:
		if is_instance_valid(btn) and btn.has_meta("asset_id"):
			var asset_id: String = btn.get_meta("asset_id")
			var is_fav := CatalogManager.is_favorite(asset_id)
			btn.text = "★" if is_fav else "☆"
			btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if is_fav else Color(0.5, 0.5, 0.5))
	if current_tab == FilterTab.FAVORITES:
		apply_filters(false)

# --- Card Instantiation (Built once, reused forever) ---

func _build_all_cards() -> void:
	_list_cards_by_id.clear()
	_grid_cards_by_id.clear()
	_star_buttons.clear()

	for child in asset_list_container.get_children():
		child.queue_free()
	for child in asset_grid_container.get_children():
		child.queue_free()

	var all_assets := CatalogManager.get_all_assets()
	for item in all_assets:
		var asset_id: String = item.get("id", "")
		if asset_id == "":
			continue

		var list_card := _create_list_card(item)
		asset_list_container.add_child(list_card)
		_list_cards_by_id[asset_id] = list_card

		var grid_card := _create_grid_card(item)
		asset_grid_container.add_child(grid_card)
		_grid_cards_by_id[asset_id] = grid_card

# --- Central Multi-Filter Logic ---

func apply_filters(is_new_query: bool = false) -> void:
	_visible_assets.clear()

	var q := CatalogManager.strip_accents(current_search.strip_edges())
	var words: Array[String] = []
	if q != "":
		for part in q.split(" ", false):
			var w := part.strip_edges()
			if w != "":
				words.append(w)

	var all_assets := CatalogManager.get_all_assets()
	var matching_ids: Dictionary = {}

	for item in all_assets:
		var asset_id: String = item.get("id", "")
		if asset_id == "":
			continue

		# 1. Category Filter
		if current_category != "All" and item.get("category", "") != current_category:
			continue

		# 2. Subcategory Filter
		if current_subcategory != "All" and current_subcategory != "" and item.get("subcategory", "") != current_subcategory:
			continue

		# 3. Tab Filter (Favorites / Recents)
		if current_tab == FilterTab.FAVORITES and not CatalogManager.is_favorite(asset_id):
			continue
		elif current_tab == FilterTab.RECENTS and not CatalogManager.is_recent(asset_id):
			continue

		# 4. Multi-word search query (name, id, category, subcategory, tags)
		if not CatalogManager.matches_search_words(item, words):
			continue

		_visible_assets.append(item)
		matching_ids[asset_id] = true

	var match_count := _visible_assets.size()
	var total_count := all_assets.size()

	# Update visibility on all existing cards (0 node recreations)
	for id in _list_cards_by_id:
		var card: Control = _list_cards_by_id[id]
		if is_instance_valid(card):
			card.visible = matching_ids.has(id)

	for id in _grid_cards_by_id:
		var card: Control = _grid_cards_by_id[id]
		if is_instance_valid(card):
			card.visible = matching_ids.has(id)

	# Update Result Count Header (e.g. "12 of 147")
	if asset_title:
		if match_count == total_count and current_category == "All" and current_tab == FilterTab.ALL and current_search.strip_edges() == "":
			asset_title.text = "Equipment Catalog (%d)" % total_count
		else:
			asset_title.text = "Catalog (%d of %d)" % [match_count, total_count]

	# Empty State Feedback
	if match_count == 0:
		if empty_state_container:
			empty_state_container.visible = true
		if empty_search_label:
			if current_search.strip_edges() != "":
				empty_search_label.text = "No results for '%s'" % current_search.strip_edges()
			elif current_tab == FilterTab.FAVORITES:
				empty_search_label.text = "No favorites saved yet.\nClick ☆ to favorite equipment."
			elif current_tab == FilterTab.RECENTS:
				empty_search_label.text = "No recently used equipment."
			else:
				empty_search_label.text = "No equipment found."
		if clear_search_btn:
			clear_search_btn.visible = (current_search.strip_edges() != "")
		asset_list_container.visible = false
		asset_grid_container.visible = false
	else:
		if empty_state_container:
			empty_state_container.visible = false
		asset_list_container.visible = (current_view_mode == ViewMode.LIST)
		asset_grid_container.visible = (current_view_mode == ViewMode.GRID)

	# Reset scroll position to top on new query
	if is_new_query and scroll_container:
		scroll_container.scroll_vertical = 0

# --- List View Card Factory ---

func _create_list_card(item: Dictionary) -> Control:
	var asset_id: String = item.get("id", "")
	var card := PanelContainer.new()
	card.set_meta("is_catalog_card", true)
	card.set_meta("asset_id", asset_id)
	card.set_meta("asset_data", item)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.15, 0.18)
	style.border_color = Color(0.22, 0.24, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Thumbnail (Consistent size)
	var thumb_tex := ThumbnailGenerator.get_thumbnail(item)
	var thumb_rect := TextureRect.new()
	thumb_rect.name = "ThumbRect_" + asset_id
	thumb_rect.texture = thumb_tex
	thumb_rect.custom_minimum_size = Vector2(44, 44)
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
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	top_row.add_child(name_lbl)

	# Favorite star
	var is_fav := CatalogManager.is_favorite(asset_id)
	var star_btn := Button.new()
	star_btn.text = "★" if is_fav else "☆"
	star_btn.flat = true
	star_btn.set_meta("asset_id", asset_id)
	star_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if is_fav else Color(0.45, 0.48, 0.52))
	star_btn.pressed.connect(func():
		CatalogManager.toggle_favorite(asset_id)
	)
	_star_buttons.append(star_btn)
	top_row.add_child(star_btn)
	vbox.add_child(top_row)

	var dims: Dictionary = item.get("dimensions", {})
	var dim_str := "%.1fx%.1fx%.1fm" % [dims.get("x", 1.0), dims.get("y", 1.0), dims.get("z", 1.0)]
	var weight_str := "%.1f kg" % float(item.get("weight_kg", 0.0))

	var info_lbl := Label.new()
	info_lbl.text = "%s  •  %s" % [dim_str, weight_str]
	info_lbl.clip_text = true
	info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_lbl.add_theme_color_override("font_color", Color(0.60, 0.63, 0.68))
	vbox.add_child(info_lbl)

	hbox.add_child(vbox)

	# Place button (less dominant outline style)
	var place_btn := Button.new()
	place_btn.text = "Place"
	place_btn.custom_minimum_size = Vector2(48, 28)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.18, 0.22, 0.30, 0.25)
	p_style.border_color = Color(0.30, 0.40, 0.55, 0.8)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(4)
	p_style.content_margin_left = 6
	p_style.content_margin_right = 6
	p_style.content_margin_top = 2
	p_style.content_margin_bottom = 2
	place_btn.add_theme_stylebox_override("normal", p_style)

	var p_hov := p_style.duplicate() as StyleBoxFlat
	p_hov.bg_color = Color(0.22, 0.35, 0.55, 0.45)
	p_hov.border_color = Color(0.45, 0.65, 1.00)
	place_btn.add_theme_stylebox_override("hover", p_hov)

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
			var style_prev := StyleBoxFlat.new()
			style_prev.bg_color = Color(0.18, 0.20, 0.25, 0.95)
			style_prev.border_color = Color(0.3, 0.6, 1.0)
			style_prev.set_border_width_all(1)
			style_prev.set_corner_radius_all(4)
			preview.add_theme_stylebox_override("normal", style_prev)
			card.set_drag_preview(preview)
			return {"type": "stage_asset", "asset_id": asset_id},
		Callable(),
		Callable()
	)

	return card

# --- Grid View Card Factory ---

func _create_grid_card(item: Dictionary) -> Control:
	var asset_id: String = item.get("id", "")
	var card := PanelContainer.new()
	card.set_meta("is_catalog_card", true)
	card.set_meta("asset_id", asset_id)
	card.set_meta("asset_data", item)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.15, 0.18)
	style.border_color = Color(0.22, 0.24, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(96, 104)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	# Thumbnail (Consistent size)
	var thumb_tex := ThumbnailGenerator.get_thumbnail(item)
	var thumb_rect := TextureRect.new()
	thumb_rect.name = "ThumbRect_" + asset_id
	thumb_rect.texture = thumb_tex
	thumb_rect.custom_minimum_size = Vector2(84, 50)
	thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(thumb_rect)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Asset")
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.max_lines_visible = 1
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	vbox.add_child(name_lbl)

	# Click to place button (less dominant outline style)
	var place_btn := Button.new()
	place_btn.text = "Place"
	place_btn.custom_minimum_size = Vector2(0, 24)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.18, 0.22, 0.30, 0.25)
	p_style.border_color = Color(0.30, 0.40, 0.55, 0.8)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(4)
	p_style.content_margin_left = 4
	p_style.content_margin_right = 4
	p_style.content_margin_top = 1
	p_style.content_margin_bottom = 1
	place_btn.add_theme_stylebox_override("normal", p_style)

	var p_hov := p_style.duplicate() as StyleBoxFlat
	p_hov.bg_color = Color(0.22, 0.35, 0.55, 0.45)
	p_hov.border_color = Color(0.45, 0.65, 1.00)
	place_btn.add_theme_stylebox_override("hover", p_hov)

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
			var style_prev := StyleBoxFlat.new()
			style_prev.bg_color = Color(0.18, 0.20, 0.25, 0.95)
			style_prev.border_color = Color(0.3, 0.6, 1.0)
			style_prev.set_border_width_all(1)
			style_prev.set_corner_radius_all(4)
			preview.add_theme_stylebox_override("normal", style_prev)
			card.set_drag_preview(preview)
			return {"type": "stage_asset", "asset_id": asset_id},
		Callable(),
		Callable()
	)

	return card

func _on_thumbnail_ready(asset_id: String, _variant: String, texture: Texture2D) -> void:
	var target_name := "ThumbRect_" + asset_id
	var nodes := find_children(target_name, "TextureRect", true, false)
	for n in nodes:
		if is_instance_valid(n):
			(n as TextureRect).texture = texture
