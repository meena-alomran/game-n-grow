extends Control
class_name CashierMonitor

signal cash_button_pressed(amount: float)

@export var max_string_length := 5

@onready var label: Label = %Label

var current_string: String:
	set(new):
		current_string = new
		display_string()

func _ready() -> void:
	current_string = ""

func pushed_button(key: StringName):
	if key == &"back":
		current_string = current_string.left(-1)
		return
		
	if current_string.length() >= max_string_length:
		return
		
	if key == &"dot":
		current_string += "."
		return
		
	else:
		current_string += key

func display_string():
	label.text = current_string
	
func cash_out():
	cash_button_pressed.emit(float(current_string))
	current_string = ""
