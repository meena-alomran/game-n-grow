class_name CashierGame
extends Node

@export_file("*.tscn") var game_suite_path: String = "res://Screens/game_suite.tscn"

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
@export var stimulation_mode: int = 1 ## 0 Low, 1 normal, 2 high

@onready var background: Node3D = %Background

const VERTEX_COLOR_SIMPLE = preload("uid://cbv1i5ahbe5es")

var _tracker := CashierRunTracker.new() ## records each run for RunLog

var current_customer_groceries: Array[GroceryEntry]
var grocery_node_3ds: Array[Node3D]
var correct_price: float:
	set(value):
		correct_price = value
		print("Correct Price: ", correct_price)

func _ready() -> void:
	numerical_difficulty = GameSettings.difficulty
	stimulation_mode = GameSettings.stimulation
	_tracker.begin_run(numerical_difficulty, stimulation_mode)
	deal_with_difficulty()
	deal_with_stimulation_modes()
	generate_list_book_page_text()
	new_customer()
	
	customer_animation_player.seek(3.0)
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	

## Item names, which items are included and each item's price at the current difficulty
## come straight from the caretaker's settings (GameSettings.grocery_items), so there is
## no random price offset any more. The scene's exported grocery_list is the fallback.
func deal_with_difficulty():
	var settings_list := GameSettings.get_grocery_entries()
	if not settings_list.is_empty():
		grocery_list = settings_list

func deal_with_stimulation_modes():
	match stimulation_mode:
		0: background.visible = false
		1: background.visible = true
		2: background.visible = true

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
		
		# Make sure the material is right (this shouldnt work like this)
		for c in new_grocery_scene.get_children():
			if c is MeshInstance3D:
				c.set_surface_override_material(0, VERTEX_COLOR_SIMPLE)
				c.scale = Vector3.ONE * 0.5
		
		grocery_node_3ds.append(new_grocery_scene)
		i.add_child(new_grocery_scene)
		new_grocery_scene.rotation_degrees.y = randf_range(0.0, 360.0)
		
		
	correct_price = calculate_total_price_of_list(current_customer_groceries)
	_tracker.start_order(current_customer_groceries.size(), correct_price)

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
	var correct := false
	if str(amount) == str(correct_price): # Check the strings to avoid floating errors
		the_price_is_right()
		correct = true
	
	# Correctness is exactly what the game decides; the tracker only records it.
	if _tracker.record_attempt(amount, correct):
		_tracker.finish_order()
		if _tracker.is_run_complete():
			RunLog.save_run(_tracker.build_record(true))
			_tracker.begin_run(numerical_difficulty, stimulation_mode)

func _on_cashier_monitor_key_pushed() -> void:
	_tracker.note_first_input()

## Saves a partial run (completed = false) if the child quit mid-run.
func _save_abandoned_run() -> void:
	if _tracker.has_progress():
		RunLog.save_run(_tracker.build_record(false))
		_tracker.begin_run(numerical_difficulty, stimulation_mode) # avoid saving it twice

func _exit_tree() -> void:
	_save_abandoned_run()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_abandoned_run()
		
func the_price_is_right():
	# move groceries to bag bug this just deletes them
	for g in grocery_node_3ds:
		g.queue_free()
	grocery_node_3ds.clear()
	
	
	await get_tree().process_frame
	new_customer()

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file(game_suite_path)
