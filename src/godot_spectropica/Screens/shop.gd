extends Control

signal back_requested

@export_file("*.tscn") var home_scene_path: String = "res://Screens/home_screen.tscn"

const ITEMS := [
	["Crown", "Golden Crown", 50],
	["Glasses", "Sunglasses", 30],
	["Hat", "Baseball Cap", 20],
	["Tie", "Bow Tie", 20],
	["Witch", "Witch Hat", 40],
	["Wings", "Butterfly Wings", 50],
]

var selected_item: int = 0

@onready var balance: Label = %Balance


func _ready() -> void:
	Wallet.coins_changed.connect(_update_balance)
	_update_balance(Wallet.coins)
	for index in ITEMS.size():
		var button := get_node(NodePath(str(ITEMS[index][0]))) as Button
		button.pressed.connect(_select_item.bind(index))
	%Crown.button_pressed = true
	_select_item(0)


func _select_item(index: int) -> void:
	selected_item = index
	var item: Array = ITEMS[index]
	%ItemDetails.text = "%s · %d coins" % [item[1], item[2]]
	%Buy.accessibility_name = "Buy %s for %d coins" % [item[1], item[2]]
	%PurchaseStatus.text = ""


func _on_buy_pressed() -> void:
	var item: Array = ITEMS[selected_item]
	if Wallet.spend_coins(item[2]):
		%PurchaseStatus.text = "%s purchased!" % item[1]
	else:
		%PurchaseStatus.text = "Not enough coins yet."


func _update_balance(coins: int) -> void:
	balance.text = "%d coins" % coins


func _on_back_pressed() -> void:
	back_requested.emit()
	# A parent screen can handle navigation when the shop is embedded.
	if self != get_tree().current_scene:
		return

	var destination := home_scene_path
	if destination.is_empty() or not ResourceLoader.exists(destination):
		destination = "res://Screens/game_suite.tscn"
	get_tree().change_scene_to_file(destination)
