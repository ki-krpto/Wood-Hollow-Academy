extends Area2D

var npc_name: String
var grid_pos: Vector2i
var dialogue_lines: Array
var dialogue_index = 0
var is_talking = false

func _ready():
	add_to_group("npcs")
	position = grid_pos * 32 + Vector2i(16, 16)

func get_current_line() -> String:
	if dialogue_index < dialogue_lines.size():
		return dialogue_lines[dialogue_index]
	return ""

func advance_dialogue() -> bool:
	if dialogue_index < dialogue_lines.size() - 1:
		dialogue_index += 1
		return true
	else:
		is_talking = false
		dialogue_index = 0
		return false
