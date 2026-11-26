extends Node
class_name AnimalBlink

@export var blink_period: float = 5.0
@export var mesh_to_affect: MeshInstance3D

var blink_timer: Timer

func _ready() -> void:
	blink_timer = Timer.new()
	add_child(blink_timer)
	blink_timer.start(blink_period)
	blink_timer.timeout.connect(blink)
	
func blink():
	mesh_to_affect.set_blend_shape_value(0, 1.0)
	await get_tree().create_timer(0.3).timeout
	mesh_to_affect.set_blend_shape_value(0, 0.0)
