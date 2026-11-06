extends CanvasLayer

@onready var points_label: Label = $HeaderContainer/HorizontalContainer/PointsLabel

signal exit_requested()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func set_points(value: int) -> void:
	points_label.text = "Points: %d" % value
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_exit_button_pressed() -> void:
	exit_requested.emit()
	
