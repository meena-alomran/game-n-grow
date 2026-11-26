extends Control

signal back_requested

@export_file("*.tscn") var game_suite_scene_path: String = "res://Screens/game_suite.tscn"
@export var owned_item_material: ShaderMaterial

# The first field is the save ID and matches the scene's button name.
const ITEMS := [
	["Crown", "Golden Crown", 50],
	["Glasses", "Sunglasses", 30],
	["Hat", "Baseball Cap", 20],
	["Tie", "Bow Tie", 20],
	["Witch", "Witch Hat", 40],
	["Wings", "Butterfly Wings", 50],
]

var selected_item: int = 0
var pending_purchase: int = -1
var item_buttons: Array[Button] = []

@onready var balance: Label = %Balance
@onready var buy_button: Button = %Buy
@onready var purchase_confirmation: ConfirmationDialog = $PurchaseConfirmation


func _ready() -> void:
	Wallet.coins_changed.connect(_update_balance)
	for index in ITEMS.size():
		var button := get_node(NodePath(str(ITEMS[index][0]))) as Button
		button.pressed.connect(_select_item.bind(index))
		item_buttons.append(button)
	%Crown.button_pressed = true
	_select_item(0)
	_update_balance(Wallet.coins)


func _select_item(index: int) -> void:
	selected_item = index
	var item: Array = ITEMS[index]
	%ItemDetails.text = "%s · %d coins" % [item[1], item[2]]
	buy_button.accessibility_name = "Buy %s for %d coins" % [item[1], item[2]]
	_refresh_purchase_availability()


func _on_buy_pressed() -> void:
	if buy_button.disabled or purchase_confirmation.visible:
		return

	pending_purchase = selected_item
	var item: Array = ITEMS[pending_purchase]
	%PurchaseStatus.text = ""
	purchase_confirmation.dialog_text = "Buy %s for %d coins?" % [item[1], item[2]]
	purchase_confirmation.popup_centered()
	purchase_confirmation.get_cancel_button().grab_focus()


func _on_purchase_confirmed() -> void:
	if pending_purchase == -1:
		return

	var item: Array = ITEMS[pending_purchase]
	pending_purchase = -1
	if not Wallet.purchase_cosmetic(item[0], item[2]):
		_refresh_purchase_availability()
		if not buy_button.disabled:
			%PurchaseStatus.text = "Couldn't save the purchase. Try again."


func _on_purchase_canceled() -> void:
	pending_purchase = -1


func _update_balance(coins: int) -> void:
	balance.text = "%d coins" % coins
	for index in ITEMS.size():
		var item: Array = ITEMS[index]
		var button := item_buttons[index]
		var owned := Wallet.owns_cosmetic(item[0])
		button.material = owned_item_material if owned else null
		button.tooltip_text = "%s (already purchased)" % item[1] if owned else item[1]
		button.accessibility_name = button.tooltip_text
	_refresh_purchase_availability()


func _refresh_purchase_availability() -> void:
	var item: Array = ITEMS[selected_item]
	if Wallet.owns_cosmetic(item[0]):
		buy_button.disabled = true
		%PurchaseStatus.text = "Already purchased."
		return

	buy_button.disabled = Wallet.coins < item[2]
	%PurchaseStatus.text = "Not enough coins yet." if buy_button.disabled else ""


func _on_back_pressed() -> void:
	back_requested.emit()
	# A parent screen can handle navigation when the shop is embedded.
	if self != get_tree().current_scene:
		return

	var destination := game_suite_scene_path
	#if destination.is_empty() or not ResourceLoader.exists(destination):
		#destination = "res://Screens/game_suite.tscn"
	get_tree().change_scene_to_file(destination)
