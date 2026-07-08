extends Control

func _ready():
	MusicManager.play_menu()

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://scene.tscn")
