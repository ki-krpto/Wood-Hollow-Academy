extends Node

const SAVE_SLOT_COUNT := 3

var player_data: Dictionary = {}
var attacks_data: Dictionary = {}
var enemies_data: Dictionary = {}
var items_data: Dictionary = {}
var current_enemy: String = ""
var defeated_enemies: Array[String] = []
var inventory: Array[Dictionary] = []
var opened_chests: Array[String] = []
var overworld_position: Vector2 = Vector2.ZERO
var active_save_slot: int = -1
var _default_player_data: Dictionary = {}

signal inventory_changed
signal dialogue_started(lines: Array[String])
signal dialogue_finished

func _ready():
	load_all_data()
	_default_player_data = player_data.duplicate(true)

func load_all_data():
	player_data.clear()
	attacks_data.clear()
	enemies_data.clear()
	items_data.clear()
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
	save_current_slot()

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
	save_current_slot()
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
			save_current_slot()
			return true
	inventory.append({"name": item_name, "count": 1})
	inventory_changed.emit()
	save_current_slot()
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
				save_current_slot()
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

func get_save_slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % (slot + 1)

func has_save_slot(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return false
	return FileAccess.file_exists(get_save_slot_path(slot))

func get_save_slot_summary(slot: int) -> Dictionary:
	var result := {
		"exists": false,
		"name": "---",
		"level": 0,
		"gold": 0
	}
	if not has_save_slot(slot):
		return result

	var file = FileAccess.open(get_save_slot_path(slot), FileAccess.READ)
	if file == null:
		return result
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return result

	var save_data: Dictionary = json.data
	var saved_player: Dictionary = save_data.get("player_data", {})
	result["exists"] = true
	result["name"] = str(saved_player.get("name", "Hero"))
	result["level"] = int(saved_player.get("level", 1))
	result["gold"] = int(saved_player.get("gold", 0))
	return result

func create_new_save(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return false
	player_data = _default_player_data.duplicate(true)
	current_enemy = ""
	defeated_enemies.clear()
	inventory.clear()
	opened_chests.clear()
	overworld_position = Vector2.ZERO
	active_save_slot = slot
	inventory_changed.emit()
	return save_current_slot()

func load_save_slot(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return false
	var file = FileAccess.open(get_save_slot_path(slot), FileAccess.READ)
	if file == null:
		return false
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false

	var save_data: Dictionary = json.data
	_apply_save_data(save_data)
	active_save_slot = slot
	inventory_changed.emit()
	return true

func delete_save_slot(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return false
	if not has_save_slot(slot):
		return true
	var dir = DirAccess.open("user://")
	if dir == null:
		return false
	var err = dir.remove(get_save_slot_path(slot).get_file())
	if err != OK:
		return false
	if active_save_slot == slot:
		active_save_slot = -1
	return true

func move_save_slot(from_slot: int, to_slot: int) -> bool:
	if from_slot == to_slot:
		return true
	if from_slot < 0 or from_slot >= SAVE_SLOT_COUNT:
		return false
	if to_slot < 0 or to_slot >= SAVE_SLOT_COUNT:
		return false
	if not has_save_slot(from_slot):
		return false

	var source_data = _read_save_file(from_slot)
	if source_data.is_empty():
		return false
	var target_exists = has_save_slot(to_slot)
	var target_data := {}
	if target_exists:
		target_data = _read_save_file(to_slot)
		if target_data.is_empty():
			return false

	if not _write_save_file(to_slot, source_data):
		return false

	if target_exists:
		if not _write_save_file(from_slot, target_data):
			return false
	else:
		if not delete_save_slot(from_slot):
			return false

	if active_save_slot == from_slot:
		active_save_slot = to_slot
	elif active_save_slot == to_slot and target_exists:
		active_save_slot = from_slot
	return true

func save_current_slot() -> bool:
	if active_save_slot < 0 or active_save_slot >= SAVE_SLOT_COUNT:
		return false
	var save_data := {
		"player_data": player_data,
		"inventory": inventory,
		"defeated_enemies": defeated_enemies,
		"opened_chests": opened_chests,
		"overworld_position": {
			"x": overworld_position.x,
			"y": overworld_position.y
		}
	}
	return _write_save_file(active_save_slot, save_data)

func is_chest_opened(chest_key: String) -> bool:
	if chest_key.is_empty():
		return false
	return opened_chests.has(chest_key)

func mark_chest_opened(chest_key: String) -> void:
	if chest_key.is_empty():
		return
	if not opened_chests.has(chest_key):
		opened_chests.append(chest_key)

func _read_save_file(slot: int) -> Dictionary:
	var file = FileAccess.open(get_save_slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func _write_save_file(slot: int, save_data: Dictionary) -> bool:
	var file = FileAccess.open(get_save_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	return true

func _apply_save_data(save_data: Dictionary) -> void:
	var saved_player = save_data.get("player_data", {})
	if typeof(saved_player) == TYPE_DICTIONARY:
		player_data = (saved_player as Dictionary).duplicate(true)
	else:
		player_data = _default_player_data.duplicate(true)

	var saved_inventory = save_data.get("inventory", [])
	inventory.clear()
	if typeof(saved_inventory) == TYPE_ARRAY:
		for entry in saved_inventory:
			if typeof(entry) == TYPE_DICTIONARY:
				inventory.append((entry as Dictionary).duplicate(true))

	var saved_defeated = save_data.get("defeated_enemies", [])
	defeated_enemies.clear()
	if typeof(saved_defeated) == TYPE_ARRAY:
		for enemy_id in saved_defeated:
			defeated_enemies.append(str(enemy_id))

	var saved_opened_chests = save_data.get("opened_chests", [])
	opened_chests.clear()
	if typeof(saved_opened_chests) == TYPE_ARRAY:
		for chest_key in saved_opened_chests:
			opened_chests.append(str(chest_key))

	var saved_pos = save_data.get("overworld_position", {})
	if typeof(saved_pos) == TYPE_DICTIONARY:
		overworld_position = Vector2(
			float((saved_pos as Dictionary).get("x", 0.0)),
			float((saved_pos as Dictionary).get("y", 0.0))
		)
	else:
		overworld_position = Vector2.ZERO
	current_enemy = ""
