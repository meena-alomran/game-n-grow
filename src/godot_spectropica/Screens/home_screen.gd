extends Control

const GAME_SUITE := "res://Screens/game_suite.tscn"

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SUITE)

func _on_settings_pressed() -> void:
	$SettingsDialog.popup_centered()

func _on_progress_pressed() -> void:
	$ProgressDialog.popup_centered()
