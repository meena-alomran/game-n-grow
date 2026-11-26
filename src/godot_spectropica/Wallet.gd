extends Node

signal coins_changed(new_amount: int)

const SAVE_PATH := "user://save.cfg"

var coins: int = 0
var _owned_cosmetics := PackedStringArray()


func _ready() -> void:
	load_data()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if amount <= 0 or amount > coins:
		return false

	coins -= amount
	coins_changed.emit(coins)
	return true


func owns_cosmetic(item_id: String) -> bool:
	return _owned_cosmetics.has(item_id)


func purchase_cosmetic(item_id: String, price: int) -> bool:
	if item_id.is_empty() or owns_cosmetic(item_id) or price <= 0 or price > coins:
		return false

	coins -= price
	_owned_cosmetics.append(item_id)
	if save_data() != OK:
		_owned_cosmetics.remove_at(_owned_cosmetics.size() - 1)
		coins += price
		return false

	coins_changed.emit(coins)
	return true


func save_data() -> Error:
	var config := ConfigFile.new()
	config.set_value("wallet", "coins", coins)
	config.set_value("wallet", "owned_cosmetics", _owned_cosmetics)

	# Replace the previous save only after writing the new balance and ownership.
	var temp_path := SAVE_PATH + ".tmp"
	var err := config.save(temp_path)
	if err == OK:
		err = DirAccess.rename_absolute(temp_path, SAVE_PATH)
	if err != OK:
		push_error("Wallet save failed: %s" % error_string(err))
	return err


func load_data() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		coins = config.get_value("wallet", "coins", 0)
		var saved_cosmetics = config.get_value("wallet", "owned_cosmetics", PackedStringArray())
		if saved_cosmetics is PackedStringArray:
			_owned_cosmetics = saved_cosmetics
	coins_changed.emit(coins)


# Safety net: save when the app is backgrounded or closed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()
