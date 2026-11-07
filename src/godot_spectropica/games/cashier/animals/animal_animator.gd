extends Node3D
class_name AnimalAnimator

@export var animation_tree: AnimationTree
@export var walk_velocity: float = 0.2
@export var jog_velocity: float = 4.0

var last_pos: Vector3
var vel: Vector3
var smooth_spd: float

func _physics_process(delta: float) -> void:
	vel = (global_position - last_pos) / delta
	last_pos = global_position
	
	var spd := vel.length()
	smooth_spd = lerp(smooth_spd, spd, delta * 10.0)
	
	animation_tree.set(&"parameters/Walk/blend_position", smooth_spd)

	
