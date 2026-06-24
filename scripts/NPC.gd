extends Node

class_name GameNPC

var npc_name: String
var grid_x: int
var grid_y: int
var dialogue: Array[String]
var dialogue_index: int = 0
var is_talking: bool = false

func _init(nname: String, gx: int, gy: int, dialogue_list: Array[String]):
	npc_name = nname
	grid_x = gx
	grid_y = gy
	dialogue = dialogue_list

func get_current_line() -> String:
	if dialogue_index < dialogue.size():
		return dialogue[dialogue_index]
	return ""

func advance_dialogue() -> bool:
	if dialogue_index < dialogue.size() - 1:
		dialogue_index += 1
		return true
	else:
		is_talking = false
		dialogue_index = 0
		return false
