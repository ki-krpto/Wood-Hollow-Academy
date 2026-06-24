extends Area2D

var enemy_name: String
var grid_pos: Vector2i

func _ready():
	add_to_group("enemies")
	position = grid_pos * 32 + Vector2i(16, 16)
