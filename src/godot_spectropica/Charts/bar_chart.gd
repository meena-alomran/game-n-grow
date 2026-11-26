class_name BarChart
extends ChartBase
## Bar chart for comparing groups. NAN values draw no bar ("No data").
## Marks follow the dataviz specs: bars at most 24px thick, 4px rounded tip with a square
## baseline end, value at the tip, hairline gridlines, hover highlight + tooltip.

var _values: Array = []
var _labels: Array = []
var _extras: Array = []
var _color := ChartStyle.TIME


## values: floats (NAN = no data). labels: short category names (keep them short, they sit
## under each bar). extras: optional second tooltip line per bar (e.g. "4 runs").
## fixed_max > 0 pins the y axis (e.g. 1.0 for percentages).
func set_bars(values: Array, labels: Array, color: Color, formatter: Callable,
		fixed_max: float = -1.0, extras: Array = [], axis_formatter: Callable = Callable()) -> void:
	_values = values
	_labels = labels
	_extras = extras
	_color = color
	value_format = formatter
	axis_format = axis_formatter
	var max_value := 0.0
	for v in values:
		if not is_nan(v):
			max_value = maxf(max_value, v)
	_set_axis(max_value, fixed_max)
	_hover_index = -1
	queue_redraw()


func _band_width(plot: Rect2) -> float:
	return plot.size.x / maxf(_values.size(), 1.0)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var plot := _plot()
	var index := int(floorf((event.position.x - plot.position.x) / _band_width(plot)))
	if index < 0 or index >= _values.size():
		index = -1
	if index != _hover_index:
		_hover_index = index
		queue_redraw()


func _draw() -> void:
	var has_data := false
	for v in _values:
		if not is_nan(v):
			has_data = true
	if not has_data:
		_draw_empty()
		return

	_draw_axes()
	var plot := _plot()
	var band := _band_width(plot)
	var thickness := minf(band * 0.55, 24.0)

	for i in range(_values.size()):
		var center_x := plot.position.x + band * (i + 0.5)
		_draw_centered_text(center_x, plot.end.y + 20.0, str(_labels[i]), ChartStyle.INK_MUTED)

		var value: float = _values[i]
		if is_nan(value):
			_draw_centered_text(center_x, plot.end.y - 8.0, "No data", ChartStyle.INK_MUTED)
			continue

		var top := _y_for(value, plot)
		var height := plot.end.y - top
		if height >= 1.0:
			var style := StyleBoxFlat.new()
			style.bg_color = _color.darkened(0.12) if i == _hover_index else _color
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			draw_style_box(style, Rect2(center_x - thickness * 0.5, top, thickness, height))
		_draw_centered_text(center_x, maxf(top - 6.0, 12.0), _fmt(value), ChartStyle.INK)

	if _hover_index >= 0 and not is_nan(_values[_hover_index]):
		var anchor := Vector2(
			plot.position.x + band * (_hover_index + 0.5), _y_for(_values[_hover_index], plot))
		var lines := PackedStringArray([str(_labels[_hover_index]), _fmt(_values[_hover_index])])
		if _hover_index < _extras.size() and str(_extras[_hover_index]) != "":
			lines.append(str(_extras[_hover_index]))
		_draw_tooltip(anchor, lines)
