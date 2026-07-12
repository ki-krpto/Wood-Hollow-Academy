extends Node

var player_data: Dictionary = {}
var attacks_data: Dictionary = {}
var enemies_data: Dictionary = {}
var items_data: Dictionary = {}
var current_enemy: String = ""
var defeated_enemies: Array[String] = []
var inventory: Array[Dictionary] = []
var overworld_position: Vector2 = Vector2.ZERO

signal inventory_changed
signal dialogue_started(lines: Array[String])
signal dialogue_finished

func _ready():
	load_all_data()

func load_all_data():
	load_json("res://assets/jason/player.json", player_data)
	load_json("res://assets/jason/attacks.json", attacks_data)
	load_json("res://assets/jason/enemies.json", enemies_data)
	load_json("res://assets/jason/items.json", items_data)

func load_json(path: String, target: Dictionary) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK:
			var data = json.data
			for key in data:
				target[key] = data[key]
			return data
	return {}

func save_player_data():
	var file = FileAccess.open("res://assets/jason/player.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.new().stringify(player_data, "\t"))

func heal_player(amount: int):
	player_data["hp"] = min(player_data["hp"] + amount, player_data["max_hp"])

func add_xp(amount: int):
	player_data["xp"] += amount
	var level_up_data = load_json("res://assets/jason/levelUpXp.json", {})
	while true:
		var needed = level_up_data.get(str(int(player_data["level"])), -1)
		if needed == -1 or player_data["xp"] < needed:
			break
		player_data["xp"] -= needed
		level_up()
	save_player_data()

func level_up():
	player_data["level"] += 1
	player_data["max_hp"] += 10
	player_data["hp"] = player_data["max_hp"]
	player_data["attack"] += 2
	player_data["defense"] += 1
	player_data["xp_to_next"] = _get_xp_for_next_level()
	save_player_data()

func _get_xp_for_next_level() -> int:
	var level_up_data = {}
	load_json("res://assets/jason/levelUpXp.json", level_up_data)
	return level_up_data.get(str(int(player_data["level"])), player_data["xp_to_next"] * 2)

func get_enemy_data(enemy_name: String) -> Dictionary:
	return enemies_data.get(enemy_name, {})

func get_attack_data(attack_name: String) -> Dictionary:
	return attacks_data.get(attack_name, {"power": 0, "type": "physical", "effects": []})

func get_item_data(item_name: String) -> Dictionary:
	return items_data.get(item_name, {})

func enter_battle(enemy_name: String) -> void:
	current_enemy = enemy_name
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		overworld_position = player.position
	change_scene("res://battle/battle.tscn")

func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func calculate_damage(attacker_attack: int, move_power: int, defender_defense: int) -> int:
	var base = max(1, attacker_attack + move_power - defender_defense)
	var multiplier = randf_range(0.9, 1.05)
	return int(roundi(base * multiplier))

func add_item(item_name: String) -> bool:
	var item_data = get_item_data(item_name)
	if item_data.is_empty():
		return false
	for entry in inventory:
		if entry.get("name") == item_name:
			entry["count"] = entry.get("count", 1) + 1
			inventory_changed.emit()
			return true
	inventory.append({"name": item_name, "count": 1})
	inventory_changed.emit()
	return true

func use_item(item_name: String) -> bool:
	for i in inventory.size():
		if inventory[i].get("name") == item_name:
			var item_data = get_item_data(item_name)
			var success = _apply_item_effect(item_name, item_data)
			if success:
				inventory[i]["count"] = inventory[i].get("count", 1) - 1
				if inventory[i]["count"] <= 0:
					inventory.remove_at(i)
				inventory_changed.emit()
			return success
	return false

func _apply_item_effect(item_name: String, item_data: Dictionary) -> bool:
	var item_type = item_data.get("type", "")
	match item_type:
		"healing":
			var heal_amount = item_data.get("value", 0)
			heal_player(heal_amount)
			return true
		"combat_buff":
			return true
		"world_ability":
			return true
	return false

func get_inventory() -> Array[Dictionary]:
	return inventory

func has_item(item_name: String) -> bool:
	for entry in inventory:
		if entry.get("name") == item_name:
			return entry.get("count", 0) > 0
	return false

func get_item_count(item_name: String) -> int:
	for entry in inventory:
		if entry.get("name") == item_name:
			return entry.get("count", 0)
	return 0

func start_dialogue(lines: Array[String]):
	dialogue_started.emit(lines)

func end_dialogue():
	dialogue_finished.emit()
