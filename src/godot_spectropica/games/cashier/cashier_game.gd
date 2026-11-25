class_name CashierGame
extends Node

@export_category("3D")
@export var customer_animation_player: AnimationPlayer
@export var new_customer_transform: Marker3D
@export var old_customer_transform: Marker3D
@export var grocery_spots: Node3D
@export var list_page_l: CashierListPage
@export var list_page_r: CashierListPage

@export_category("Game Info")
@export var grocery_list: Array[GroceryEntry]
@export var item_limit: int = 4
@export var numerical_difficulty: int = 0 ## 0: integers, 1: 0:50s, 2: 0.25s, 3: 5s, 4: all decimals

var current_customer_groceries: Array[GroceryEntry]
var grocery_node_3ds: Array[Node3D]
var correct_price: float:
	set(value):
		correct_price = value
		print("Correct Price: ", correct_price)

func _ready() -> void:
	deal_with_difficulty()
	generate_list_book_page_text()
	new_customer()
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	

func deal_with_difficulty():
	var new_list: Array[GroceryEntry]
	for item in grocery_list:
		var new_item = item.duplicate()
		match numerical_difficulty:
			0: new_item.price = item.price
			1: new_item.price += 0.5 * randi_range(0, 1)
			2: new_item.price += 0.25 * randi_range(0, 3)
			3: new_item.price += 0.05 * randi_range(0, 19)
			4: new_item.price += 0.01 * randi_range(0, 99)
		new_list.append(new_item)
		
	grocery_list = new_list

## Called at game start and success. This function is the main loop of the game.
func new_customer():
	new_customer_animation()
	generate_new_groceries()
	
## Visual animation for customers moving
func new_customer_animation():
	customer_animation_player.play("switch_customer")

## Creates a list of groceries based on the player's preferences
func generate_new_groceries():
	current_customer_groceries.clear()
	
	var amount := randi_range(2, item_limit)
	var idx := -1
	for i: Node3D in grocery_spots.get_children():
		idx += 1
		if idx >= amount:
			break
		# pick a new random resource
		var new_grocery := make_random_grocery()
		current_customer_groceries.append(new_grocery)
		
		# Add it to the actual 3d scene
		var new_grocery_scene := new_grocery.visual_scene.instantiate() as Node3D
		grocery_node_3ds.append(new_grocery_scene)
		i.add_child(new_grocery_scene)
		new_grocery_scene.rotation_degrees.y = randf_range(0.0, 360.0)
		
		
	correct_price = calculate_total_price_of_list(current_customer_groceries)
		
## Brings a random grocery based on the preferences of the player
## Should make duplicates such that they can be modified
func make_random_grocery() -> GroceryEntry:
	return grocery_list.pick_random().duplicate()
	
## Sums up the correct price of a list for the player's answer
func calculate_total_price_of_list(list: Array[GroceryEntry]) -> float:
	var price := 0.0
	for item in current_customer_groceries:
		price += item.price
		
	return price
	
## Puts text onto the cashier's book
func generate_list_book_page_text():
	var _page_capacity := 5
	var _current_list: Array[GroceryEntry]
	
	for i in range(_page_capacity): # Build left page
		if i < grocery_list.size():
			_current_list.append(grocery_list[i])
	
	list_page_l.set_list(_current_list)
	_current_list.clear()
	
	for i in range(_page_capacity): # Build right page
		var i_adj = i + _page_capacity
		if i_adj < grocery_list.size():
			_current_list.append(grocery_list[i_adj])
	list_page_r.set_list(_current_list)
		
		
func _on_cashier_monitor_cash_button_pressed(amount: float) -> void:
	if amount == correct_price:
		the_price_is_right()
		
func the_price_is_right():
	# move groceries to bag bug this just deletes them
	for g in grocery_node_3ds:
		g.queue_free()
	grocery_node_3ds.clear()
	
	new_customer()
		
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		new_customer()
