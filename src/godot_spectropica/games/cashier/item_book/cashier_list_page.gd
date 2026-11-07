extends SubViewport
class_name CashierListPage

@onready var label: Label = %Label

func set_list(list: Array[GroceryEntry]):
	var new_text: String = ""
	for i in list:
		new_text += i.display_name + ": $" + str(int(i.price)) + "\n"
		
	label.text = new_text
