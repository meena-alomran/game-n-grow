extends Area3D

signal scored(amount: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("hello")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	print("Hi hi bi")
	if body is PlayerCharacter:
		if body.velocity.length() > 0.8:
			print("Velocity: ", body.velocity.length())
			scored.emit(2)
		else: 
			print("Velocity: ", body.velocity.length())
			scored.emit(1)
