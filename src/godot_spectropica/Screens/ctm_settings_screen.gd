extends Control
## Care Team Member settings page. Edits difficulty, stimulation and the grocery items
## (included, name, price at each difficulty). Apply writes everything to Supabase in one
## request through GameSettings, which also updates this device's cache.
## On open it shows the cached values, then loads what is currently applied.
## Reached from the Dashboard; Back returns there. The UI is built in code.

const DASHBOARD_SCREEN := "res://Screens/dashboard_screen.tscn"
const PRICE_HEADERS := ["0 · Whole $", "1 · 50¢", "2 · 25¢", "3 · 5¢", "4 · Any"]

@onready var status_label: Label = %Status
@onready var page: VBoxContainer = %Page
@onready var apply_button: Button = %Apply

var _difficulty_option: OptionButton
var _stimulation_option: OptionButton
## One entry per item: {"slug": String, "included": Button, "name": LineEdit, "prices": Array[SpinBox]}
var _rows: Array = []


func _ready() -> void:
	page.add_theme_constant_override("separation", 16)
	_build_ui()
	_fill_from_settings()

	if not GameSettings.is_remote_configured():
		status_label.text = "Supabase isn't configured. Showing the settings saved on this device."
		return

	# Load what is actually applied, not just the cache. Apply stays off until then, so a
	# caretaker can't overwrite the database with stale values.
	apply_button.disabled = true
	status_label.text = "Loading current settings..."
	var ok: bool = await GameSettings.refresh_from_remote()
	if ok:
		_fill_from_settings()
		status_label.text = ""
	else:
		status_label.text = "Couldn't reach the server. Showing the last saved settings on this device."
	apply_button.disabled = false


# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	page.add_child(_section_title("Game"))
	var game_row := HBoxContainer.new()
	game_row.add_theme_constant_override("separation", 10)
	game_row.add_child(_label("Difficulty"))
	_difficulty_option = _option(GameSettings.DIFFICULTY_LABELS)
	game_row.add_child(_difficulty_option)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(20, 0)
	game_row.add_child(gap)
	game_row.add_child(_label("Stimulation"))
	_stimulation_option = _option(GameSettings.STIMULATION_LABELS)
	game_row.add_child(_stimulation_option)
	page.add_child(game_row)

	page.add_child(_section_title("Grocery items"))
	var help := _label("Choose which items appear, rename them, and set each item's price for every difficulty. Each price snaps to its level's step (whole dollars, 50¢, 25¢, 5¢, any cents).")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", ChartStyle.INK_SECONDARY)
	page.add_child(help)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ChartStyle.SURFACE
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	page.add_child(card)

	var grid := GridContainer.new()
	grid.columns = 2 + GroceryCatalog.PRICE_COUNT
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	card.add_child(grid)

	for header in ["Shown", "Name"] + PRICE_HEADERS:
		var header_label := _label(header)
		header_label.add_theme_font_size_override("font_size", 14)
		header_label.add_theme_color_override("font_color", ChartStyle.INK_SECONDARY)
		grid.add_child(header_label)

	for item in GameSettings.grocery_items:
		_rows.append(_build_item_row(grid, str(item["slug"])))


func _build_item_row(grid: GridContainer, slug: String) -> Dictionary:
	var included := Button.new()
	included.toggle_mode = true
	included.custom_minimum_size = Vector2(110, 42)
	included.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	grid.add_child(included)

	var name_edit := LineEdit.new()
	name_edit.max_length = GroceryCatalog.MAX_NAME_LENGTH
	name_edit.placeholder_text = "Name"
	name_edit.custom_minimum_size = Vector2(190, 42)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_edit)

	var spin_boxes: Array[SpinBox] = []
	for difficulty in range(GroceryCatalog.PRICE_COUNT):
		var step := GroceryCatalog.price_step(difficulty)
		var spin := SpinBox.new()
		spin.min_value = step
		spin.max_value = GroceryCatalog.MAX_PRICE
		spin.step = step
		spin.prefix = "$"
		spin.update_on_text_changed = true
		spin.custom_minimum_size = Vector2(112, 42)
		grid.add_child(spin)
		spin_boxes.append(spin)

	var row := {"slug": slug, "included": included, "name": name_edit, "prices": spin_boxes}
	included.toggled.connect(_on_included_toggled.bind(row))
	return row


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _section_title(text: String) -> Label:
	var label := _label(text)
	label.add_theme_font_size_override("font_size", 24)
	return label


func _option(labels: Array) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 42)
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for text in labels:
		option.add_item(str(text))
	return option


# --- Filling and reading the controls ---------------------------------------------

func _fill_from_settings() -> void:
	_difficulty_option.select(GameSettings.difficulty)
	_stimulation_option.select(GameSettings.stimulation)
	_fill_items(GameSettings.grocery_items)


func _fill_items(items: Array) -> void:
	var by_slug := {}
	for item in items:
		by_slug[str(item["slug"])] = item
	for row in _rows:
		var item = by_slug.get(row["slug"])
		if item == null:
			continue
		row["included"].set_pressed_no_signal(bool(item["included"]))
		row["name"].text = str(item["name"])
		for difficulty in range(GroceryCatalog.PRICE_COUNT):
			var spin: SpinBox = row["prices"][difficulty]
			spin.set_value_no_signal(float(item["prices"][difficulty]))
		_refresh_row_look(row)


func _collect_items() -> Array:
	var items := []
	for row in _rows:
		var prices := []
		for spin in row["prices"]:
			prices.append(snappedf(spin.value, 0.01))
		items.append({
			"slug": row["slug"],
			"name": row["name"].text.strip_edges(),
			"included": row["included"].button_pressed,
			"prices": prices,
		})
	return items


## Excluded rows are dimmed (still editable) and the toggle says what it does.
func _refresh_row_look(row: Dictionary) -> void:
	var included: bool = row["included"].button_pressed
	row["included"].text = "Included" if included else "Excluded"
	var alpha := 1.0 if included else 0.5
	row["name"].modulate.a = alpha
	for spin in row["prices"]:
		spin.modulate.a = alpha


func _on_included_toggled(_pressed: bool, row: Dictionary) -> void:
	_refresh_row_look(row)


# --- Buttons ------------------------------------------------------------------

func _on_reset_pressed() -> void:
	_fill_items(GroceryCatalog.default_items())
	status_label.text = "Default items loaded. Press Apply to save them."


func _on_apply_pressed() -> void:
	apply_button.disabled = true
	status_label.text = "Saving..."

	var ok: bool = await GameSettings.push_to_remote(
		_difficulty_option.selected, _stimulation_option.selected, _collect_items())

	if ok:
		_fill_from_settings() # shows exactly what was stored (names are trimmed, prices snapped)
		status_label.text = "Saved!"
	elif not GameSettings.last_error.is_empty():
		status_label.text = GameSettings.last_error
	elif not GameSettings.is_remote_configured():
		status_label.text = "Supabase isn't configured."
	else:
		status_label.text = "Couldn't save. Check your connection and try again."
	apply_button.disabled = false


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCREEN)
