extends Control

@export_file("*.tscn") var shop_scene_path: String = "res://Screens/shop.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_rewards_pressed() -> void:
	var destination := shop_scene_path
	get_tree().change_scene_to_file(destination)
