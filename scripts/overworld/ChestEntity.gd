extends Area2D

var chest_id: int
var grid_pos: Vector2i
var item_name: String
var opened = false

func _ready():
	add_to_group("chests")
	position = grid_pos * 32 + Vector2i(16, 16)

func open_chest():
	if opened:
		return
	opened = true
	PlayerData.open_chest(chest_id)
	var file = FileAccess.open("res://assets/data/items.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data and data.has(item_name):
			var info = data[item_name]
			PlayerData.add_item([item_name, info.get("description", ""), info.get("type", "misc"), info.get("value", 0)])
	visible = false
