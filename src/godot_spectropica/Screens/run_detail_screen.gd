class_name RunDetailScreen
extends Control
## One run in detail: headline numbers, a bar chart per measure (one bar per order), and
## the attempt-by-attempt text, which doubles as the table view of the charts.

const DASHBOARD_SCREEN := "res://Screens/dashboard_screen.tscn"

## Set by the Dashboard before it opens this scene (scene changes can't take arguments).
static var run_to_show: Dictionary = {}

@onready var subtitle_label: Label = %Subtitle
@onready var page: VBoxContainer = %Page


func _ready() -> void:
	page.add_theme_constant_override("separation", 18)
	if run_to_show.is_empty():
		subtitle_label.text = "No run selected. Go back and pick one from the Dashboard."
		return
	_build(run_to_show)


func _build(run: Dictionary) -> void:
	subtitle_label.text = "%s · %s · %s" % [
		RunStats.format_started(str(run.get("started_at", ""))),
		RunStats.difficulty_label(int(run.get("difficulty", 0))),
		RunStats.stimulation_label(int(run.get("stimulation", 1)))]

	# Headline numbers
	var accuracy := RunStats.run_accuracy(run)
	var orders_done := int(run.get("orders_completed", 0))
	var tile_row := HBoxContainer.new()
	tile_row.add_theme_constant_override("separation", 12)
	var completed: bool = run.get("completed", false)
	_add_tile(tile_row, "Total time", RunStats.format_time(int(run.get("total_time_ms", 0))),
		"" if completed else "Quit early")
	_add_tile(tile_row, "Accuracy", RunStats.format_percent(accuracy))
	_add_tile(tile_row, "Wrong attempts", str(int(run.get("incorrect_attempts", 0))))
	_add_tile(tile_row, "First-try", "%d of %d" % [int(run.get("first_try_correct", 0)), orders_done])
	page.add_child(tile_row)

	# One bar per order
	var orders: Array = run.get("orders", []) if run.get("orders") is Array else []
	if orders.is_empty():
		var none := Label.new()
		none.text = "No order details were recorded for this run."
		page.add_child(none)
		return

	var labels := []
	for i in range(orders.size()):
		labels.append("Order %d" % (i + 1))

	var time_chart := BarChart.new()
	time_chart.set_bars(RunStats.order_values(run, "time"), labels, ChartStyle.TIME,
		func(v): return "%.1fs" % v, -1.0, [], func(v): return ChartStyle.compact(v) + "s")
	var first_input_chart := BarChart.new()
	first_input_chart.empty_text = "Not recorded"
	first_input_chart.set_bars(RunStats.order_values(run, "first_input"), labels, ChartStyle.TIME,
		func(v): return "%.1fs" % v, -1.0, [], func(v): return ChartStyle.compact(v) + "s")
	var wrong_chart := BarChart.new()
	wrong_chart.integer_axis = true
	wrong_chart.set_bars(RunStats.order_values(run, "wrong"), labels, ChartStyle.WRONG,
		func(v): return "%d" % roundi(v))

	var chart_row := HBoxContainer.new()
	chart_row.add_theme_constant_override("separation", 14)
	chart_row.add_child(_chart_card("Time per order", "Seconds from customer arriving to the right answer", time_chart))
	chart_row.add_child(_chart_card("Time to first input", "Seconds before the first key press", first_input_chart))
	chart_row.add_child(_chart_card("Wrong attempts", "Wrong answers before the right one", wrong_chart))
	page.add_child(chart_row)

	# Attempt-by-attempt text (the table view)
	var heading := Label.new()
	heading.text = "Every attempt"
	heading.add_theme_font_size_override("font_size", 24)
	page.add_child(heading)

	var detail := RichTextLabel.new()
	detail.fit_content = true
	detail.scroll_active = false
	detail.text = RunStats.run_detail(run)
	page.add_child(detail)


func _add_tile(row: HBoxContainer, label: String, value: String, note: String = "") -> void:
	var tile := StatTile.new()
	tile.set_values(label, value, note)
	row.add_child(tile)


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

	var subtitle_label_node := Label.new()
	subtitle_label_node.text = subtitle
	subtitle_label_node.add_theme_font_size_override("font_size", 13)
	subtitle_label_node.add_theme_color_override("font_color", ChartStyle.INK_SECONDARY)
	subtitle_label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle_label_node)

	chart.custom_minimum_size = Vector2(200, 220)
	box.add_child(chart)
	return card


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCREEN)
