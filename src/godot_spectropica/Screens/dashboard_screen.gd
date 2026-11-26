extends Control
## Care Team Member dashboard (Overview): filters, headline numbers, trend line charts,
## setting-comparison bar charts and a list of runs. Click a run for its detail page.
## Data comes from Supabase through RunLog (falls back to this device's saved runs).
## The UI below the header is built in code to keep this scene small.

const HOME_SCREEN := "res://Screens/home_screen.tscn"
const SETTINGS_SCREEN := "res://Screens/ctm_settings_screen.tscn"
const RUN_DETAIL_SCREEN := "res://Screens/run_detail_screen.tscn"

const RANGE_PRESETS := [3, 10, 30, 0] ## 0 = all runs
const RANGE_NAMES := ["Last 3", "Last 10", "Last 30", "All"]
const MAX_LISTED_RUNS := 30

# Remembered across visits, so Back from Run Detail returns to the same view instantly.
static var s_range := 10
static var s_difficulty := -1 ## -1 = any
static var s_stimulation := -1 ## -1 = any
static var s_group_by := "difficulty" ## or "stimulation"
static var s_runs: Array = []
static var s_has_runs := false

@onready var status_label: Label = %Status
@onready var page: VBoxContainer = %Page
@onready var refresh_button: Button = %Refresh
@onready var settings_button: Button = %Settings

var _runs: Array = []

var _sections: VBoxContainer
var _empty_label: Label
var _range_buttons: Array[Button] = []
var _group_buttons: Array[Button] = [] ## [difficulty, stimulation]
var _difficulty_option: OptionButton
var _stimulation_option: OptionButton
var _tiles := {}
var _time_trend: LineChart
var _accuracy_trend: LineChart
var _time_compare: BarChart
var _accuracy_compare: BarChart
var _compare_caption: Label
var _runs_caption: Label
var _runs_box: VBoxContainer


func _ready() -> void:
	_make_primary(settings_button)
	_build_ui()
	_apply_state_to_controls()
	if s_has_runs:
		_runs = s_runs
		_render()
	_load_runs()


# --- Loading ----------------------------------------------------------------

func _load_runs() -> void:
	refresh_button.disabled = true
	status_label.text = "Updating..." if s_has_runs else "Loading..."

	var result: Dictionary = await RunLog.fetch_remote_runs()
	if result["ok"]:
		_runs = result["runs"]
		s_runs = _runs
		s_has_runs = true
		status_label.text = ""
	elif s_has_runs:
		status_label.text = "Couldn't refresh. Showing the last loaded data."
	else:
		_runs = RunLog.get_local_runs().filter(func(r): return r.get("game_id", "") == "cashier")
		if GameSettings.is_remote_configured():
			status_label.text = "Couldn't reach the server. Showing runs saved on this device."
		else:
			status_label.text = "Supabase isn't configured. Showing runs saved on this device."

	_render()
	refresh_button.disabled = false


# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	page.add_theme_constant_override("separation", 18)
	page.add_child(_build_filter_row())

	_empty_label = Label.new()
	_empty_label.text = "No runs yet. Play the cashier game and the results will show up here."
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.visible = false
	page.add_child(_empty_label)

	_sections = VBoxContainer.new()
	_sections.add_theme_constant_override("separation", 18)
	page.add_child(_sections)

	# Headline numbers
	var tile_row := _row(12)
	for key in ["runs", "time", "accuracy", "first_try"]:
		var tile := StatTile.new()
		_tiles[key] = tile
		tile_row.add_child(tile)
	_sections.add_child(tile_row)

	# Trends over time
	_sections.add_child(_section_title("Trends over time"))
	var trend_row := _row(14)
	_time_trend = LineChart.new()
	_accuracy_trend = LineChart.new()
	trend_row.add_child(_chart_card(
		"Time per run", "Seconds to finish 3 orders (completed runs only)", _time_trend))
	trend_row.add_child(_chart_card(
		"Accuracy per run", "Share of answers that were right", _accuracy_trend))
	_sections.add_child(trend_row)

	# Compare settings
	var compare_head := _row(10)
	var compare_title := _section_title("Compare settings")
	compare_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare_head.add_child(compare_title)
	compare_head.add_child(_small_label("Group by"))
	var group := ButtonGroup.new()
	for i in range(2):
		var button := _toggle_button(["Difficulty", "Stimulation"][i], group)
		button.pressed.connect(_on_group_pressed.bind(["difficulty", "stimulation"][i]))
		compare_head.add_child(button)
		_group_buttons.append(button)
	_sections.add_child(compare_head)

	_compare_caption = _small_label("")
	_compare_caption.add_theme_color_override("font_color", ChartStyle.INK_SECONDARY)
	_compare_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sections.add_child(_compare_caption)

	var compare_row := _row(14)
	_time_compare = BarChart.new()
	_accuracy_compare = BarChart.new()
	compare_row.add_child(_chart_card("Average time", "Seconds per completed run", _time_compare))
	compare_row.add_child(_chart_card("Accuracy", "Share of answers that were right", _accuracy_compare))
	_sections.add_child(compare_row)

	# Run list
	_sections.add_child(_section_title("Runs"))
	_runs_caption = _small_label("")
	_runs_caption.add_theme_color_override("font_color", ChartStyle.INK_SECONDARY)
	_sections.add_child(_runs_caption)
	_runs_box = VBoxContainer.new()
	_runs_box.add_theme_constant_override("separation", 8)
	_sections.add_child(_runs_box)


func _build_filter_row() -> Control:
	var row := _row(10)

	row.add_child(_small_label("Range"))
	var group := ButtonGroup.new()
	for i in range(RANGE_PRESETS.size()):
		var button := _toggle_button(RANGE_NAMES[i], group)
		button.pressed.connect(_on_range_pressed.bind(RANGE_PRESETS[i]))
		row.add_child(button)
		_range_buttons.append(button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_small_label("Difficulty"))
	_difficulty_option = _option(["All"] + GameSettings.DIFFICULTY_LABELS)
	_difficulty_option.item_selected.connect(_on_difficulty_selected)
	row.add_child(_difficulty_option)

	row.add_child(_small_label("Stimulation"))
	_stimulation_option = _option(["All"] + GameSettings.STIMULATION_LABELS)
	_stimulation_option.item_selected.connect(_on_stimulation_selected)
	row.add_child(_stimulation_option)
	return row


func _row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	return row


func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	return label


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _toggle_button(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(0, 42)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _option(items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 42)
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for item in items:
		option.add_item(str(item))
	return option


func _chart_card(title: String, subtitle: String, chart: Control) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = ChartStyle.SURFACE
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", ChartStyle.INK)
	box.add_child(title_label)

	var subtitle_label := _small_label(subtitle)
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", ChartStyle.INK_SECONDARY)
	box.add_child(subtitle_label)

	chart.custom_minimum_size = Vector2(260, 230)
	box.add_child(chart)
	return card


func _make_primary(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.42, 0.34) if state == "hover" else Color(0.17, 0.35, 0.28)
		style.set_corner_radius_all(14)
		style.content_margin_left = 14.0
		style.content_margin_right = 14.0
		button.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color.WHITE)


func _apply_state_to_controls() -> void:
	for i in range(RANGE_PRESETS.size()):
		_range_buttons[i].set_pressed_no_signal(RANGE_PRESETS[i] == s_range)
	_difficulty_option.select(s_difficulty + 1)
	_stimulation_option.select(s_stimulation + 1)
	_group_buttons[0].set_pressed_no_signal(s_group_by == "difficulty")
	_group_buttons[1].set_pressed_no_signal(s_group_by == "stimulation")


# --- Filters ------------------------------------------------------------------

func _on_range_pressed(preset: int) -> void:
	s_range = preset
	_render()


func _on_difficulty_selected(index: int) -> void:
	s_difficulty = index - 1
	_render()


func _on_stimulation_selected(index: int) -> void:
	s_stimulation = index - 1
	_render()


func _on_group_pressed(field: String) -> void:
	s_group_by = field
	_render()


# --- Rendering ----------------------------------------------------------------

func _render() -> void:
	var chrono := RunStats.chronological(_runs)
	if chrono.is_empty():
		_empty_label.visible = true
		_sections.visible = false
		return
	_empty_label.visible = false
	_sections.visible = true

	var filtered := RunStats.filter_runs(chrono, s_difficulty, s_stimulation)
	var in_range := RunStats.last_n(filtered, s_range)
	var previous := RunStats.previous_window(filtered, s_range)

	_update_tiles(in_range, previous)
	_update_trends(in_range, filtered.is_empty())
	_update_compare(RunStats.last_n(chrono, s_range))
	_update_run_list(in_range)


func _update_tiles(in_range: Array, previous: Array) -> void:
	var summary := RunStats.summarize(in_range)
	var delta := {}
	if not previous.is_empty():
		delta = RunStats.deltas(summary, RunStats.summarize(previous), previous.size())

	_tiles["runs"].set_values("Runs", str(summary["runs"]), "%d completed" % summary["completed_runs"])
	_tiles["time"].set_values("Avg time per run",
		RunStats.format_time(summary["avg_time_ms"]),
		_delta_text(delta, "time"), _delta_good(delta, "time"))
	_tiles["accuracy"].set_values("Accuracy",
		RunStats.format_percent(summary["accuracy"]),
		_delta_text(delta, "accuracy"), _delta_good(delta, "accuracy"))
	_tiles["first_try"].set_values("First-try rate",
		RunStats.format_percent(summary["first_try_rate"]),
		_delta_text(delta, "first_try"), _delta_good(delta, "first_try"))


func _delta_text(delta: Dictionary, key: String) -> String:
	return delta[key]["text"] if delta.has(key) else ""


func _delta_good(delta: Dictionary, key: String) -> int:
	return delta[key]["good"] if delta.has(key) else 0


func _update_trends(in_range: Array, nothing_matches: bool) -> void:
	var message := "No runs match these filters" if nothing_matches else "No data yet"
	_time_trend.empty_text = message
	_accuracy_trend.empty_text = message

	var series := RunStats.run_series(in_range)
	_time_trend.set_series(series["time_s"], series["labels"], ChartStyle.TIME,
		func(v): return "%.1fs" % v, -1.0, series["titles"],
		func(v): return ChartStyle.compact(v) + "s")
	_accuracy_trend.set_series(series["accuracy"], series["labels"], ChartStyle.ACCURACY,
		func(v): return "%d%%" % roundi(v * 100.0), 1.0, series["titles"])


func _update_compare(range_runs: Array) -> void:
	var by_difficulty := s_group_by == "difficulty"
	var groups := RunStats.group_by_field(range_runs, s_group_by, 5 if by_difficulty else 3)
	var labels: Array = RunStats.SHORT_DIFFICULTY if by_difficulty else RunStats.SHORT_STIMULATION

	var times := []
	var accuracies := []
	var extras := []
	for g in groups:
		times.append(float(g["avg_time_ms"]) / 1000.0 if g["avg_time_ms"] >= 0.0 else NAN)
		accuracies.append(g["accuracy"] if g["accuracy"] >= 0.0 else NAN)
		extras.append("%d run%s" % [g["runs"], "" if g["runs"] == 1 else "s"])

	_compare_caption.text = "Uses the Range above across all settings; the Difficulty and Stimulation filters don't apply here."
	_time_compare.set_bars(times, labels, ChartStyle.TIME,
		func(v): return "%.1fs" % v, -1.0, extras,
		func(v): return ChartStyle.compact(v) + "s")
	_accuracy_compare.set_bars(accuracies, labels, ChartStyle.ACCURACY,
		func(v): return "%d%%" % roundi(v * 100.0), 1.0, extras)


func _update_run_list(in_range: Array) -> void:
	for child in _runs_box.get_children():
		_runs_box.remove_child(child)
		child.queue_free()

	var newest_first := in_range.duplicate()
	newest_first.reverse()
	var shown := mini(newest_first.size(), MAX_LISTED_RUNS)
	if newest_first.is_empty():
		_runs_caption.text = "No runs match these filters."
	elif shown < newest_first.size():
		_runs_caption.text = "Showing the newest %d of %d runs. Click a run for details." % [shown, newest_first.size()]
	else:
		_runs_caption.text = "%d run%s. Click a run for details." % [shown, "" if shown == 1 else "s"]

	for i in range(shown):
		var run: Dictionary = newest_first[i]
		var button := Button.new()
		button.text = RunStats.run_line(run)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 46)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_open_run.bind(run))
		_runs_box.add_child(button)


# --- Navigation ---------------------------------------------------------------

func _open_run(run: Dictionary) -> void:
	RunDetailScreen.run_to_show = run
	get_tree().change_scene_to_file(RUN_DETAIL_SCREEN)


func _on_refresh_pressed() -> void:
	_load_runs()


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCREEN)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCREEN)
