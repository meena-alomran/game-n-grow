class_name ChartStyle
extends RefCounted
## Colors and small helpers shared by the custom charts.
## Palette follows the dataviz skill's validated categorical slots 1-3 (checked against
## the cream card surface). Color follows the entity everywhere:
##   time = blue, wrong attempts = orange, accuracy = aqua.
## Text never wears a series color; it uses the ink tokens below.

const TIME := Color("#2a78d6")
const WRONG := Color("#eb6834")
const ACCURACY := Color("#1baf7a")

const INK := Color("#0b0b0b")
const INK_SECONDARY := Color("#52514e")
const INK_MUTED := Color("#898781")
const GRID := Color("#e1e0d9")
const BASELINE := Color("#c3c2b7")
const SURFACE := Color("#fffdf6") ## chart card surface, used for marker rings

const GOOD_TEXT := Color("#006300")
const BAD_TEXT := Color("#d03b3b")

const TOOLTIP_BG := Color(0.043, 0.043, 0.043, 0.94)
const TOOLTIP_TITLE := Color("#c3c2b7")
const TOOLTIP_VALUE := Color("#ffffff")


## 12 -> "12", 2.5 -> "2.5". For axis ticks, so whole numbers don't read "12.0".
static func compact(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return "%.1f" % value


## Clean axis for values from 0 to max_value: {"max": axis_max, "step": tick_step}.
## Steps are 1, 2 or 5 times a power of ten, so ticks read as round numbers.
static func nice_axis(max_value: float, tick_count: int = 4) -> Dictionary:
	if max_value <= 0.0:
		return {"max": 1.0, "step": 0.25}
	var raw_step := max_value / tick_count
	var magnitude := pow(10.0, floorf(log(raw_step) / log(10.0)))
	var normalized := raw_step / magnitude
	var nice := 10.0
	if normalized <= 1.0:
		nice = 1.0
	elif normalized <= 2.0:
		nice = 2.0
	elif normalized <= 5.0:
		nice = 5.0
	var step := nice * magnitude
	return {"max": ceilf(max_value / step) * step, "step": step}
