extends Control

signal back_requested

@export_file("*.tscn") var home_scene_path: String = "res://Screens/home_screen.tscn"

@onready var balance: Label = %Balance


func _ready() -> void:
	Wallet.coins_changed.connect(_update_balance)
	_update_balance(Wallet.coins)


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
