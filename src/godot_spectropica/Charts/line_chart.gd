class_name LineChart
extends ChartBase
## Line chart for change over time. NAN values leave a gap in the line.
## Marks follow the dataviz specs: 2px line, 8px markers with a 2px surface ring,
## ~10% area wash, hairline gridlines, only the last point labeled, hover crosshair + tooltip.

var _values: Array = []
var _labels: Array = []
var _titles: Array = []
var _color := ChartStyle.TIME


## values: floats (NAN = no data). labels: short x labels. titles: full tooltip titles
## (defaults to labels). fixed_max > 0 pins the y axis (e.g. 1.0 for percentages).
func set_series(values: Array, labels: Array, color: Color, formatter: Callable,
		fixed_max: float = -1.0, titles: Array = [], axis_formatter: Callable = Callable()) -> void:
	_values = values
	_labels = labels
	_titles = titles if not titles.is_empty() else labels
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


func _x_for(index: int, plot: Rect2) -> float:
	var count := _values.size()
	if count <= 1:
		return plot.position.x + plot.size.x * 0.5
	var inset := 12.0
	return plot.position.x + inset + (plot.size.x - 2.0 * inset) * float(index) / float(count - 1)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var plot := _plot()
	var best := -1
	var best_distance := 1e9
	for i in range(_values.size()):
		if is_nan(_values[i]):
			continue
		var distance := absf(_x_for(i, plot) - event.position.x)
		if distance < best_distance:
			best_distance = distance
			best = i
	if best != _hover_index:
		_hover_index = best
		queue_redraw()


func _draw() -> void:
	var valid := 0
	for v in _values:
		if not is_nan(v):
			valid += 1
	if valid == 0:
		_draw_empty()
		return

	_draw_axes()
	var plot := _plot()
	var font := get_theme_default_font()

	# Split into runs of consecutive valid points so NAN leaves a gap.
	var segments: Array = []
	var current := PackedVector2Array()
	var last_valid := -1
	for i in range(_values.size()):
		if is_nan(_values[i]):
			if current.size() > 0:
				segments.append(current)
				current = PackedVector2Array()
		else:
			current.append(Vector2(_x_for(i, plot), _y_for(_values[i], plot)))
			last_valid = i
	if current.size() > 0:
		segments.append(current)

	for segment in segments:
		if segment.size() < 2:
			continue
		var lowest_point := 0.0
		for p in segment:
			lowest_point = maxf(lowest_point, p.y)
		if lowest_point < plot.end.y - 0.5: # skip a flat-at-zero line: nothing to fill
			var area := PackedVector2Array(segment)
			area.append(Vector2(segment[segment.size() - 1].x, plot.end.y))
			area.append(Vector2(segment[0].x, plot.end.y))
			draw_colored_polygon(area, Color(_color, 0.10))
		draw_polyline(segment, _color, 2.0, true)

	# X labels, thinned so they never collide.
	var label_count := _labels.size()
	var max_labels := maxi(int(plot.size.x / 70.0), 1)
	var label_step := maxi(int(ceilf(float(label_count) / max_labels)), 1)
	for i in range(0, label_count, label_step):
		_draw_centered_text(_x_for(i, plot), plot.end.y + 20.0, str(_labels[i]), ChartStyle.INK_MUTED)

	# Markers: every point when there are few, otherwise just the last one.
	var show_all := valid <= 20
	for i in range(_values.size()):
		if is_nan(_values[i]) or (not show_all and i != last_valid):
			continue
		var p := Vector2(_x_for(i, plot), _y_for(_values[i], plot))
		draw_circle(p, 6.0, ChartStyle.SURFACE) # 2px surface ring
		draw_circle(p, 4.0, _color)

	if _hover_index >= 0 and not is_nan(_values[_hover_index]):
		var hp := Vector2(_x_for(_hover_index, plot), _y_for(_values[_hover_index], plot))
		draw_line(Vector2(hp.x, plot.position.y), Vector2(hp.x, plot.end.y), ChartStyle.BASELINE, 1.0)
		draw_circle(hp, 8.0, ChartStyle.SURFACE)
		draw_circle(hp, 5.5, _color)
		var title := str(_titles[_hover_index]) if _hover_index < _titles.size() else ""
		_draw_tooltip(hp, PackedStringArray([title, _fmt(_values[_hover_index])]))
	elif last_valid >= 0:
		# Direct label on the last point only.
		var lp := Vector2(_x_for(last_valid, plot), _y_for(_values[last_valid], plot))
		_draw_centered_text(lp.x, lp.y - 12.0, _fmt(_values[last_valid]), ChartStyle.INK)
