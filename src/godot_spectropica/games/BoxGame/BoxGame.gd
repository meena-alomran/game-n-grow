extends Node

var points: int = 0
var path := "user://sessions.jsonl"
var started_at := ""
@export_file("*.tscn") var exit_scene: String = "res://Screens/game_suite.tscn"

func _ready() -> void:
	started_at = Time.get_datetime_string_from_system(true)
	$StaticCounter/ScoreZone.scored.connect(_on_scored)
	$HUD.set_points(points)
	$HUD.exit_requested.connect(on_exit_pressed)
	print("Connected")
	

func _on_scored(amount: int) -> void:
	points += amount
	print("Points: ", points)
	$HUD.set_points(points)
	if points >= 10:
		_score_reached()

func add_points(amount: int) -> void:
	points += amount
	# If you use add_points elsewhere to increase score, add the check here too:
	if points >= 10:
		_score_reached()

func _score_reached() -> void:
	await get_tree().create_timer(2.0).timeout 
	save_session("completed")
	if exit_scene:
		get_tree().change_scene_to_file(exit_scene)
	else:
		print("Warning: No scene assigned to next_scene!")
	

func on_exit_pressed() -> void:
	print("Exit Button pressed")
	save_session("aborted")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if exit_scene:
		get_tree().change_scene_to_file(exit_scene)
	else:
		print("Warning: No scene assigned to next_scene!")

func _new_uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40  # version 4
	b[8] = (b[8] & 0x3f) | 0x80  # variant
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

func save_session(outcome: String) -> void:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if mode == FileAccess.READ_WRITE:
		file.seek_end()
	var session := {
	"id": _new_uuid(),
	"game_id": "trial_box_game",
	"started_at": started_at + "Z",
	"ended_at": Time.get_datetime_string_from_system(true) + "Z",
	"outcome": outcome,
	"points": points,
}
	file.store_line(JSON.stringify(session))
