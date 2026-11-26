class_name StatTile
extends PanelContainer
## A headline number with a small label and an optional change vs a previous period.
## The change is always written out ("Up 4 pts ..."), so color is never the only signal.

var _label := Label.new()
var _value := Label.new()
var _delta := Label.new()


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f1eddd")
	style.set_corner_radius_all(16)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", style)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", ChartStyle.INK_SECONDARY)
	_value.add_theme_font_size_override("font_size", 30)
	_value.add_theme_color_override("font_color", ChartStyle.INK)
	_delta.add_theme_font_size_override("font_size", 13)
	_delta.add_theme_color_override("font_color", ChartStyle.INK_SECONDARY)
	_delta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [_label, _value, _delta]:
		box.add_child(label)


## delta_good: 1 = change is an improvement, -1 = worse, 0 = neutral or unknown.
func set_values(label_text: String, value_text: String, delta_text: String = "", delta_good: int = 0) -> void:
	_label.text = label_text
	_value.text = value_text
	_delta.text = delta_text
	_delta.visible = not delta_text.is_empty()
	var color := ChartStyle.INK_SECONDARY
	if delta_good > 0:
		color = ChartStyle.GOOD_TEXT
	elif delta_good < 0:
		color = ChartStyle.BAD_TEXT
	_delta.add_theme_color_override("font_color", color)
