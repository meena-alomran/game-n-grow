class_name ChartBase
extends Control
## Shared drawing helpers for the custom charts: plot area, y axis with gridlines,
## hover tooltip and the empty state. LineChart and BarChart extend this.

const PAD_LEFT := 52.0
const PAD_RIGHT := 16.0
const PAD_TOP := 26.0
const PAD_BOTTOM := 30.0
const FONT_SIZE := 14

## Shown instead of the plot when there is nothing to draw.
var empty_text := "No data yet"
## Formats a value for tooltips and labels (float -> String).
var value_format: Callable = Callable()
## Formats y-axis ticks. Falls back to value_format.
var axis_format: Callable = Callable()
## For counts: tick values are whole numbers (0, 1, 2, ...) instead of 0.25 steps.
var integer_axis := false

var _axis_max := 1.0
var _axis_step := 0.25
var _hover_index := -1
var _tip_style := StyleBoxFlat.new()


func _init() -> void:
	# PASS so hovering a chart inside a ScrollContainer doesn't block mouse-wheel scrolling.
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(240, 200)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tip_style.bg_color = ChartStyle.TOOLTIP_BG
	_tip_style.set_corner_radius_all(8)
	_tip_style.set_content_margin_all(8)
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover_index != -1:
		_hover_index = -1
		queue_redraw()


func _plot() -> Rect2:
	return Rect2(
		PAD_LEFT, PAD_TOP,
		maxf(size.x - PAD_LEFT - PAD_RIGHT, 1.0),
		maxf(size.y - PAD_TOP - PAD_BOTTOM, 1.0))


func _y_for(value: float, plot: Rect2) -> float:
	return plot.end.y - clampf(value / _axis_max, 0.0, 1.0) * plot.size.y


func _set_axis(max_value: float, fixed_max: float) -> void:
	if integer_axis:
		var top := maxf(ceilf(max_value), 1.0)
		var step := ceilf(top / 4.0)
		_axis_step = step
		_axis_max = ceilf(top / step) * step
	elif fixed_max > 0.0:
		_axis_max = fixed_max
		_axis_step = fixed_max / 4.0
	else:
		var axis := ChartStyle.nice_axis(max_value)
		_axis_max = axis["max"]
		_axis_step = axis["step"]


func _fmt(value: float) -> String:
	return str(value_format.call(value)) if value_format.is_valid() else str(value)


func _fmt_axis(value: float) -> String:
	if axis_format.is_valid():
		return str(axis_format.call(value))
	return _fmt(value)


func _draw_axes() -> void:
	var plot := _plot()
	var font := get_theme_default_font()
	var ticks := int(roundf(_axis_max / _axis_step))
	for i in range(ticks + 1):
		var y := _y_for(_axis_step * i, plot)
		var line_color := ChartStyle.BASELINE if i == 0 else ChartStyle.GRID
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), line_color, 1.0)
		var text := _fmt_axis(_axis_step * i)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(plot.position.x - 8.0 - width, y + 5.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ChartStyle.INK_MUTED)


func _draw_centered_text(center_x: float, baseline_y: float, text: String, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var x := clampf(center_x - width * 0.5, 0.0, maxf(size.x - width, 0.0))
	draw_string(font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _draw_empty() -> void:
	_draw_centered_text(size.x * 0.5, size.y * 0.5, empty_text, ChartStyle.INK_MUTED)


## First line is the title (muted), the rest are values. Flips side/edge to stay on screen.
func _draw_tooltip(anchor: Vector2, lines: PackedStringArray) -> void:
	var font := get_theme_default_font()
	var text_width := 0.0
	for line in lines:
		text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var line_height := font.get_height(FONT_SIZE)
	var box := Vector2(text_width + 16.0, line_height * lines.size() + 16.0)

	var pos := anchor + Vector2(12.0, -box.y - 8.0)
	if pos.x + box.x > size.x:
		pos.x = anchor.x - box.x - 12.0
	pos.x = maxf(pos.x, 0.0)
	if pos.y < 0.0:
		pos.y = anchor.y + 12.0

	draw_style_box(_tip_style, Rect2(pos, box))
	for i in range(lines.size()):
		var color := ChartStyle.TOOLTIP_TITLE if i == 0 else ChartStyle.TOOLTIP_VALUE
		draw_string(font, pos + Vector2(8.0, 8.0 + font.get_ascent(FONT_SIZE) + line_height * i),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
