
@tool
extends Control

const SUN_POSITION := Vector2(0.18, 0.28)
const SUN_RADIUS := 0.065

const SUN_COLOR := Color("#FFD66B")
const TRUNK_COLOR := Color("#B97850")
const TRUNK_SHADE := Color("#A96648")
const GROUND_COLOR := Color("#70C77B")

const LEAF_COLORS := [
	Color("#45BD78"),
	Color("#63CE83"),
	Color("#8AD98A"),
	Color("#35AA70"),
	Color("#78D18B")
]


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var screen_size := size

	if screen_size.x <= 0 or screen_size.y <= 0:
		return

	_draw_sun(screen_size)
	_draw_ground(screen_size)

	# Palm trees along the bottom of the screen.
	_draw_palm_tree(
		Vector2(screen_size.x * 0.10, screen_size.y * 0.99),
		screen_size.y * 0.25,
		0.90
	)

	_draw_palm_tree(
		Vector2(screen_size.x * 0.34, screen_size.y * 0.99),
		screen_size.y * 0.20,
		0.82
	)

	_draw_palm_tree(
		Vector2(screen_size.x * 0.69, screen_size.y * 0.99),
		screen_size.y * 0.23,
		0.88
	)

	_draw_palm_tree(
		Vector2(screen_size.x * 0.94, screen_size.y * 0.99),
		screen_size.y * 0.28,
		0.92
	)


func _draw_sun(screen_size: Vector2) -> void:
	var sun_pos := Vector2(
		screen_size.x * SUN_POSITION.x,
		screen_size.y * SUN_POSITION.y
	)

	var radius: float = minf(screen_size.x, screen_size.y) * SUN_RADIUS

	draw_circle(sun_pos, radius, SUN_COLOR)


func _draw_ground(screen_size: Vector2) -> void:
	var w := screen_size.x
	var h := screen_size.y

	var points := PackedVector2Array([
		Vector2(0, h * 0.96),
		Vector2(w * 0.22, h * 0.94),
		Vector2(w * 0.48, h * 0.96),
		Vector2(w * 0.73, h * 0.94),
		Vector2(w, h * 0.96),
		Vector2(w, h),
		Vector2(0, h)
	])

	draw_colored_polygon(points, GROUND_COLOR)


func _draw_palm_tree(base: Vector2, tree_height: float, tree_scale: float) -> void:
	var top := base + Vector2(-tree_height * 0.03, -tree_height)

	# Draw the trunk as a soft, slightly curved shape.
	var trunk_left := PackedVector2Array()
	var trunk_right := PackedVector2Array()

	for i in range(17):
		var t := float(i) / 16.0

		var center := base.lerp(top, t)
		center.x += sin(t * PI) * tree_height * 0.07

		var width := lerpf(
			tree_height * 0.075,
			tree_height * 0.045,
			t
		)

		trunk_left.append(center + Vector2(-width, 0))
		trunk_right.append(center + Vector2(width, 0))

	var trunk_shape := PackedVector2Array()

	for point in trunk_left:
		trunk_shape.append(point)

	for i in range(trunk_right.size() - 1, -1, -1):
		trunk_shape.append(trunk_right[i])

	draw_colored_polygon(trunk_shape, TRUNK_COLOR)

	# Small rounded top where the leaves meet.
	draw_circle(top, tree_height * 0.065, TRUNK_SHADE)

	# Broad, rounded leaves spreading out from the crown.
	_draw_leaf(top, -165, tree_height * 0.43 * tree_scale, LEAF_COLORS[0])
	_draw_leaf(top, -135, tree_height * 0.48 * tree_scale, LEAF_COLORS[1])
	_draw_leaf(top, -105, tree_height * 0.46 * tree_scale, LEAF_COLORS[2])
	_draw_leaf(top, -75, tree_height * 0.48 * tree_scale, LEAF_COLORS[0])
	_draw_leaf(top, -45, tree_height * 0.46 * tree_scale, LEAF_COLORS[3])
	_draw_leaf(top, -15, tree_height * 0.40 * tree_scale, LEAF_COLORS[1])


func _draw_leaf(
	center: Vector2,
	angle_degrees: float,
	length: float,
	color: Color
) -> void:
	var angle := deg_to_rad(angle_degrees)
	var direction := Vector2(cos(angle), sin(angle))
	var side := Vector2(-direction.y, direction.x)

	var tip := center + direction * length

	# A wide leaf with a rounded, plump silhouette.
	var points := PackedVector2Array()

	for i in range(13):
		var t := float(i) / 12.0

		var along := center.lerp(tip, t)
		var width := sin(t * PI) * length * 0.19

		points.append(along + side * width)

	for i in range(12, -1, -1):
		var t := float(i) / 12.0

		var along := center.lerp(tip, t)
		var width := sin(t * PI) * length * 0.19

		points.append(along - side * width)

	draw_colored_polygon(points, color)
