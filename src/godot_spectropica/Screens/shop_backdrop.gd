@tool
extends Control

const FLOOR_START := 0.75
const POST_BASE := 0.79
const TILE_ROWS := 5
const STONE_COLORS := [
	Color("#f5d6b6"),
	Color("#f2c5a7"),
	Color("#f9dfc1"),
	Color("#f1cfad"),
	Color("#f6cdb4"),
]
const CLOUD_TOP := Color(1.0, 0.99, 0.96, 0.88)
const CLOUD_BASE := Color(0.68, 0.85, 0.98, 0.66)
const CLOUD_START := Vector2(0.13, 0.84)
# Each segment contains two Bézier handles and the next point on the outline.
const CLOUD_CURVES := [
	[Vector2(0.04, 0.84), Vector2(0.00, 0.71), Vector2(0.01, 0.58)],
	[Vector2(0.02, 0.42), Vector2(0.10, 0.35), Vector2(0.20, 0.39)],
	[Vector2(0.24, 0.12), Vector2(0.36, 0.04), Vector2(0.45, 0.26)],
	[Vector2(0.53, 0.03), Vector2(0.68, 0.08), Vector2(0.73, 0.40)],
	[Vector2(0.84, 0.32), Vector2(0.93, 0.39), Vector2(0.94, 0.55)],
	[Vector2(1.04, 0.61), Vector2(1.01, 0.83), Vector2(0.91, 0.85)],
	[Vector2(0.70, 0.92), Vector2(0.36, 0.91), CLOUD_START],
]


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	_draw_clouds()
	_draw_distant_hills()
	_draw_floor()
	_draw_clothesline()



func _draw_clouds() -> void:
	var scale_factor := minf(size.x / 1152.0, size.y / 648.0)
	_draw_cloud(size * Vector2(0.32, 0.045), Vector2(186.0, 62.0) * scale_factor)
	_draw_cloud(size * Vector2(0.68, 0.10), Vector2(144.0, 46.0) * scale_factor, true)
	_draw_cloud(size * Vector2(-0.04, 0.34), Vector2(163.0, 57.0) * scale_factor, true)
	_draw_cloud(size * Vector2(0.86, 0.42), Vector2(192.0, 65.0) * scale_factor)
	_draw_cloud(size * Vector2(0.02, 0.60), Vector2(110.0, 39.0) * scale_factor)


func _draw_cloud(origin: Vector2, dimensions: Vector2, mirrored: bool = false) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var start := CLOUD_START
	for curve in CLOUD_CURVES:
		for step in range(10):
			var point := start.bezier_interpolate(curve[0], curve[1], curve[2], step / 10.0)
			colors.append(CLOUD_TOP.lerp(CLOUD_BASE, smoothstep(0.24, 0.88, point.y)))
			if mirrored:
				point.x = 1.0 - point.x
			points.append(origin + point * dimensions)
		start = curve[2]
	draw_polygon(points, colors)


func _draw_distant_hills() -> void:
	# The floor covers the lower half of each hill at the horizon.
	var hill_base := FLOOR_START + 0.025
	_draw_ellipse(size * Vector2(0.10, hill_base), size * Vector2(0.22, 0.16), Color("#81cc98"))
	_draw_ellipse(size * Vector2(0.49, hill_base), size * Vector2(0.27, 0.085), Color("#96d8a6"))
	_draw_ellipse(size * Vector2(0.87, hill_base), size * Vector2(0.24, 0.15), Color("#76c895"))
	_draw_ellipse(size * Vector2(0.13, hill_base), size * Vector2(0.23, 0.092), Color("#68bf79"))
	_draw_ellipse(size * Vector2(0.95, hill_base), size * Vector2(0.20, 0.10), Color("#61b97f"))



func _draw_bush(base: Vector2, scale_factor: float, mirrored: bool = false) -> void:
	_draw_ellipse(base + Vector2(5.0, 0.0) * scale_factor,
		Vector2(54.0, 9.0) * scale_factor, Color(0.45, 0.26, 0.15, 0.20))
	var direction := -1.0 if mirrored else 1.0
	draw_set_transform(base, 0.0, Vector2(direction, 1.0) * scale_factor)
	var shade := Color("#4d9368")
	draw_circle(Vector2(-28.0, -20.0), 23.0, shade, true, -1.0, true)
	draw_circle(Vector2(0.0, -33.0), 33.0, shade, true, -1.0, true)
	draw_circle(Vector2(29.0, -19.0), 22.0, shade, true, -1.0, true)
	draw_circle(Vector2(-32.0, -25.0), 17.0, Color("#78b87f"), true, -1.0, true)
	draw_circle(Vector2(-4.0, -40.0), 26.0, Color("#8cc68b"), true, -1.0, true)
	draw_circle(Vector2(28.0, -25.0), 17.0, Color("#72b078"), true, -1.0, true)
	draw_line(Vector2(-15.0, -49.0), Vector2(-9.0, -54.0), Color("#b9dd9e"), 4.0, true)
	draw_line(Vector2(18.0, -29.0), Vector2(23.0, -33.0), Color("#9ed093"), 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, color, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_floor() -> void:
	var horizon := size.y * FLOOR_START
	draw_rect(Rect2(0.0, horizon, size.x, size.y - horizon), Color("#dfab89"))
	draw_rect(Rect2(0.0, horizon, size.x, 3.0), Color("#ffedcf"))

	# Rows and joints spread out toward the viewer, like paving in perspective.
	for row in range(TILE_ROWS):
		var far_depth := pow(float(row) / TILE_ROWS, 1.5)
		var near_depth := pow(float(row + 1) / TILE_ROWS, 1.5)
		var far_y := lerpf(horizon, size.y, far_depth)
		var near_y := lerpf(horizon, size.y, near_depth)
		var stagger := 0.5 * (row % 2)
		for column in range(-9, 9):
			var left := float(column) + stagger
			var right := left + 1.0
			var tile := PackedVector2Array([
				Vector2(_floor_x(left, far_depth) + 1.0, far_y + 2.0),
				Vector2(_floor_x(right, far_depth) - 1.0, far_y + 2.0),
				Vector2(_floor_x(right, near_depth) - 1.0, near_y),
				Vector2(_floor_x(left, near_depth) + 1.0, near_y),
			])
			var color: Color = STONE_COLORS[posmod(column * 3 + row * 2, STONE_COLORS.size())]
			draw_colored_polygon(tile, color)


func _floor_x(column: float, depth: float) -> float:
	var tile_width := size.x / 9.0 * lerpf(0.62, 1.44, depth)
	return size.x * 0.5 + column * tile_width


func _draw_clothesline() -> void:
	var post_top := size.y * 0.16
	var post_bottom := size.y * POST_BASE
	for x in [size.x * 0.10, size.x * 0.90]:
		draw_set_transform(Vector2(x + 6.0, post_bottom), 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, 20.0, Color(0.49, 0.25, 0.16, 0.24), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_line(Vector2(x, post_top), Vector2(x, post_bottom), Color("#ad6947"), 18.0, true)
		draw_line(Vector2(x - 3.0, post_top), Vector2(x - 3.0, post_bottom), Color("#eab274"), 8.0, true)
		draw_circle(Vector2(x, post_top), 12.0, Color("#e98b73"), true, -1.0, true)
	for row in [0.23, 0.54]:
		var rope := PackedVector2Array()
		for step in range(33):
			var t := step / 32.0
			rope.append(Vector2(size.x * lerpf(0.10, 0.90, t), size.y * (row + 0.025 * sin(t * PI))))
		draw_polyline(rope, Color("#b97d4e"), 7.0, true)
		draw_polyline(rope, Color("#f7cf93"), 4.0, true)
		for x in [0.25, 0.50, 0.75]:
			var t: float = (x - 0.10) / 0.80
			var peg := Vector2(size.x * x, size.y * (row + 0.025 * sin(t * PI)))
			draw_rect(Rect2(peg + Vector2(-5.0, -6.0), Vector2(10.0, 18.0)), Color("#ce8e5d"))
			draw_rect(Rect2(peg + Vector2(-4.0, -6.0), Vector2(6.0, 16.0)), Color("#ffe1ad"))
