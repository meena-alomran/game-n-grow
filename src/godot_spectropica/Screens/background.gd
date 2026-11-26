@tool
extends Control

const FLOOR_START := 0.75


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	_draw_sun()
	#_draw_distant_hills()
	_draw_floor()
	_draw_trees()


func _draw_sun() -> void:
	var center := size * Vector2(0.08, 0.15)
	var radius: float = minf(size.x, size.y) * 0.065

	# Soft glow fading outward
	for i in range(12, 0, -1):
		var t: float = float(i) / 12.0
		var alpha: float = 0.035 + 0.12 * (1.0 - t)
		var color := Color("#fff2a6", alpha)

		draw_circle(center, radius * t, color)

	# Light yellow centre
	draw_circle(center, radius * 0.55, Color("#fff5b8"))


func _draw_distant_hills() -> void:
	# Overlapping hills create a softer valley shape.
	var base_y := size.y * 0.77

	_draw_ellipse(
		size * Vector2(0.02, 0.76),
		size * Vector2(0.34, 0.19),
		Color("#68bf79")
	)

	_draw_ellipse(
		size * Vector2(0.98, 0.76),
		size * Vector2(0.34, 0.19),
		Color("#68bf79")
	)

	_draw_ellipse(
		size * Vector2(0.12, 0.70),
		size * Vector2(0.27, 0.14),
		Color("#81cc98")
	)

	_draw_ellipse(
		size * Vector2(0.88, 0.70),
		size * Vector2(0.27, 0.14),
		Color("#81cc98")
	)

	_draw_ellipse(
		size * Vector2(0.50, 0.82),
		size * Vector2(0.55, 0.12),
		Color("#96d8a6")
	)


func _draw_floor() -> void:
	var horizon := size.y * FLOOR_START

	draw_rect(
		Rect2(0.0, horizon, size.x, size.y - horizon),
		Color("#a6d58b")
	)


func _draw_trees() -> void:
	var scale_factor := minf(size.x / 1152.0, size.y / 648.0)

	_draw_tree(Vector2(size.x * 0.12, size.y * 0.79), scale_factor, 0)
	_draw_tree(Vector2(size.x * 0.88, size.y * 0.79), scale_factor, 1)


func _draw_tree(base: Vector2, scale_factor: float, variation: int) -> void:
	draw_set_transform(base, 0.0, Vector2.ONE * scale_factor)

	var trunk := Color("#a87958")
	var leaves := Color("#639b70")
	var light_leaves := Color("#83b77b")
	var dark_leaves := Color("#548b67")

	# Trunk
	draw_line(Vector2.ZERO, Vector2(2.0, -105.0), trunk, 11.0, true)
	draw_line(Vector2(1.0, -55.0), Vector2(-27.0, -91.0), trunk, 6.0, true)
	draw_line(Vector2(2.0, -72.0), Vector2(29.0, -108.0), trunk, 6.0, true)

	# Leaf canopy
	if variation == 0:
		# Wider, uneven canopy
		draw_circle(Vector2(-30.0, -111.0), 32.0, dark_leaves)
		draw_circle(Vector2(4.0, -132.0), 39.0, leaves)
		draw_circle(Vector2(37.0, -112.0), 29.0, light_leaves)
		draw_circle(Vector2(-13.0, -157.0), 27.0, light_leaves)
		draw_circle(Vector2(27.0, -151.0), 25.0, leaves)
	else:
		# Taller, more loosely shaped canopy
		draw_circle(Vector2(-25.0, -112.0), 27.0, leaves)
		draw_circle(Vector2(15.0, -119.0), 32.0, dark_leaves)
		draw_circle(Vector2(-8.0, -148.0), 35.0, light_leaves)
		draw_circle(Vector2(25.0, -164.0), 25.0, leaves)
		draw_circle(Vector2(-28.0, -166.0), 22.0, light_leaves)

	draw_set_transform(Vector2.ZERO)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, color, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
