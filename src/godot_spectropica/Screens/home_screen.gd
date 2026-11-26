extends Control

const GAME_SUITE := "res://Screens/game_suite.tscn"
const CTM_SCREEN := "res://Screens/dashboard_screen.tscn"

func _ready() -> void:
	# Pick up any changes a caretaker made since the app launched.
	GameSettings.refresh_from_remote()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SUITE)

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(CTM_SCREEN)

func _on_progress_pressed() -> void:
	$ProgressDialog.popup_centered()
