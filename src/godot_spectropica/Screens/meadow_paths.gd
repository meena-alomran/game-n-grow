
@tool
extends Control

const PATH_OUTLINE := Color("#D69B72")
const PATH_COLOR := Color("#FFE4B9")

const GRASS_COLOR := Color("#8BD58C")
const GRASS_LIGHT := Color("#A5E2A0")

const HORIZON := 0.53

const BUSH_COLORS := [
	Color("#65B97C"),
	Color("#79C98A"),
	Color("#91D99A")
]

const FLOWER_COLORS := [
	Color("#F5A7B5"),
	Color("#FFD36E"),
	Color("#FFFFFF"),
	Color("#C5A5E8")
]


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y

	if w <= 0 or h <= 0:
		return

	_draw_meadow(w, h)

	var path_width := h * 0.085

	# Draw all path outlines, then all path interiors.
	_draw_path_network(w, h, path_width + 9.0, PATH_OUTLINE)
	_draw_path_network(w, h, path_width, PATH_COLOR)

	# Greenery around the paths.
	_draw_bush(Vector2(w * 0.09, h * 0.82), h * 0.045, 0)
	_draw_bush(Vector2(w * 0.24, h * 0.91), h * 0.035, 1)
	_draw_bush(Vector2(w * 0.80, h * 0.90), h * 0.045, 2)
	_draw_bush(Vector2(w * 0.94, h * 0.81), h * 0.035, 0)

	# Flowers.
	_draw_flower(Vector2(w * 0.13, h * 0.68), h * 0.023, FLOWER_COLORS[0])
	_draw_flower(Vector2(w * 0.88, h * 0.67), h * 0.023, FLOWER_COLORS[1])
	_draw_flower(Vector2(w * 0.75, h * 0.83), h * 0.020, FLOWER_COLORS[2])
	_draw_flower(Vector2(w * 0.30, h * 0.83), h * 0.020, FLOWER_COLORS[3])


func _draw_meadow(w: float, h: float) -> void:
	# Gentle horizon where the meadow disappears into the distance.
	var points := PackedVector2Array([
		Vector2(0, h * HORIZON),
		Vector2(w * 0.18, h * (HORIZON - 0.015)),
		Vector2(w * 0.38, h * (HORIZON + 0.005)),
		Vector2(w * 0.60, h * (HORIZON - 0.005)),
		Vector2(w * 0.82, h * (HORIZON + 0.01)),
		Vector2(w, h * HORIZON),
		Vector2(w, h),
		Vector2(0, h)
	])

	draw_colored_polygon(points, GRASS_COLOR)

	# Lighter green near the foreground.
	var light_points := PackedVector2Array([
		Vector2(0, h * 0.91),
		Vector2(w * 0.25, h * 0.88),
		Vector2(w * 0.50, h * 0.92),
		Vector2(w * 0.75, h * 0.89),
		Vector2(w, h * 0.91),
		Vector2(w, h),
		Vector2(0, h)
	])

	draw_colored_polygon(light_points, GRASS_LIGHT)


func _draw_path_network(
	w: float,
	h: float,
	width: float,
	color: Color
) -> void:
	var horizon_y := h * HORIZON

	# Stop the rounded path caps exactly at the meadow horizon.
	var cap_offset := width * 0.5

	var left_outer := Vector2(w * 0.17, horizon_y + cap_offset)
	var left_inner := Vector2(w * 0.42, horizon_y + cap_offset)
	var right_inner := Vector2(w * 0.59, horizon_y + cap_offset)
	var right_outer := Vector2(w * 0.84, horizon_y + cap_offset)

	# Main path entering from the foreground.
	_draw_path([
		Vector2(w * 0.50, h * 1.04),
		Vector2(w * 0.49, h * 0.98),
		Vector2(w * 0.51, h * 0.91),
		Vector2(w * 0.50, h * 0.84)
	], width, color)

	# Main path divides into two broad, gentle routes.
	_draw_path([
		Vector2(w * 0.50, h * 0.84),
		Vector2(w * 0.43, h * 0.82),
		Vector2(w * 0.36, h * 0.77),
		Vector2(w * 0.33, h * 0.72)
	], width, color)

	_draw_path([
		Vector2(w * 0.50, h * 0.84),
		Vector2(w * 0.57, h * 0.82),
		Vector2(w * 0.64, h * 0.77),
		Vector2(w * 0.67, h * 0.72)
	], width, color)

	# Left branch divides into two paths leading to the horizon.
	_draw_path([
		Vector2(w * 0.33, h * 0.72),
		Vector2(w * 0.28, h * 0.68),
		Vector2(w * 0.21, h * 0.62),
		left_outer
	], width, color)

	_draw_path([
		Vector2(w * 0.33, h * 0.72),
		Vector2(w * 0.36, h * 0.68),
		Vector2(w * 0.40, h * 0.62),
		left_inner
	], width, color)

	# Right branch divides into two paths leading to the horizon.
	_draw_path([
		Vector2(w * 0.67, h * 0.72),
		Vector2(w * 0.64, h * 0.68),
		Vector2(w * 0.61, h * 0.62),
		right_inner
	], width, color)

	_draw_path([
		Vector2(w * 0.67, h * 0.72),
		Vector2(w * 0.73, h * 0.68),
		Vector2(w * 0.79, h * 0.62),
		right_outer
	], width, color)


func _draw_path(
	points: Array,
	width: float,
	color: Color
) -> void:
	var curve := _sample_curve(points, 40)

	for i in range(1, curve.size()):
		draw_line(curve[i - 1], curve[i], color, width, true)

	draw_circle(curve[0], width * 0.5, color)
	draw_circle(curve[curve.size() - 1], width * 0.5, color)


func _sample_curve(points: Array, segments: int) -> PackedVector2Array:
	var result := PackedVector2Array()

	if points.size() != 4:
		return result

	var p0: Vector2 = points[0]
	var p1: Vector2 = points[1]
	var p2: Vector2 = points[2]
	var p3: Vector2 = points[3]

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		result.append(p0.bezier_interpolate(p1, p2, p3, t))

	return result


func _draw_bush(center: Vector2, radius: float, color_index: int) -> void:
	var color: Color = BUSH_COLORS[color_index]

	draw_circle(center + Vector2(-radius * 0.55, radius * 0.12), radius * 0.72, color)
	draw_circle(center + Vector2(radius * 0.55, radius * 0.12), radius * 0.72, color)
	draw_circle(center + Vector2(0, -radius * 0.30), radius * 0.85, color)


func _draw_flower(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center + Vector2(0, -radius), radius * 0.72, color)
	draw_circle(center + Vector2(radius * 0.95, -radius * 0.30), radius * 0.72, color)
	draw_circle(center + Vector2(radius * 0.58, radius * 0.82), radius * 0.72, color)
	draw_circle(center + Vector2(-radius * 0.58, radius * 0.82), radius * 0.72, color)
	draw_circle(center + Vector2(-radius * 0.95, -radius * 0.30), radius * 0.72, color)

	draw_circle(center, radius * 0.48, Color("#F6C95F"))
