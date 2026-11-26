extends Area3D

@export var viewport: SubViewport
@export var quad_size := Vector2(1, 1)  # must match your QuadMesh size

## From claude sonnet 5.5

func _ready():
	input_event.connect(_on_input_event)

func _on_input_event(_camera, event, event_position, _normal, _shape_idx):
	if not (event is InputEventMouse):
		return

	# world-space hit point -> local space of the quad
	var local = global_transform.affine_inverse() * event_position
	
	# local quad coords (centered, y up) -> viewport pixels (top-left origin, y down)
	var pos := Vector2(
		(local.x / quad_size.x + 0.5) * viewport.size.x,
		(-local.y / quad_size.y + 0.5) * viewport.size.y
	)
	
	var e = event.duplicate()
	e.position = pos
	e.global_position = pos
	viewport.push_input(e)
