extends Control

func _ready() -> void:
	var menu = load("res://main_menu.tscn").instantiate()
	add_child(menu)
