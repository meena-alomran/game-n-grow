extends Node

signal coins_changed(new_amount: int)

const SAVE_PATH := "user://save.cfg"

var coins: int = 0


func _ready() -> void:
	load_data()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("wallet", "coins", coins)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("Wallet save failed: %s" % error_string(err))


func load_data() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		coins = config.get_value("wallet", "coins", 0)
	coins_changed.emit(coins)


# Safety net: save when the app is backgrounded or closed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()
