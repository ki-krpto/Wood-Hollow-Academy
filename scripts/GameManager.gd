extends Node

# Persistent player data
var player_name: String = "Kim"
var player_level: int = 1
var player_xp: int = 0
var player_xp_to_next: int = 100
var player_max_hp: int = 100
var player_hp: int = 100
var player_base_attack: int = 15
var player_defense: int = 5
var player_current_stance: String = "Neutral"
var player_poisoned: bool = false
var player_defending: bool = false

# Overworld position
var player_grid_x: int = 2
var player_grid_y: int = 2
var last_enemy_name: String = ""
var last_enemy_grid_x: int = 0
var last_enemy_grid_y: int = 0

# Opened chests
var opened_chests: Array[int] = []

# Inventory
var inventory_slots: Array = []
var armor_slot = null
var weapon_slot = null

# Scene state
var in_combat: bool = false
var boss1_defeated: bool = false
var defeated_enemies: Array[Dictionary] = []

# Loaded data
var enemy_data: Dictionary = {}
var item_data: Dictionary = {}
var xp_data: Dictionary = {}

func _ready():
	load_data()

func load_data():
	var dir = "res://assets/jason/"
	var files = {
		"enemies.json": "enemy_data",
		"items.json": "item_data",
		"levelUpXp.json": "xp_data"
	}
	for filename in files:
		var path = dir + filename
		if ResourceLoader.exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var text = file.get_as_text()
				var json = JSON.new()
				if json.parse(text) == OK:
					set(files[filename], json.data)
	_init_inventory()

func _init_inventory():
	inventory_slots = []
	for i in range(8):
		inventory_slots.append(null)

func add_item(item: Array) -> bool:
	for i in range(8):
		if inventory_slots[i] == null:
			inventory_slots[i] = item.duplicate()
			return true
	return false

func add_item_by_name(item_name: String) -> bool:
	if item_name in item_data:
		var info = item_data[item_name]
		var item = [
			item_name,
			info.get("description", "No description"),
			info.get("type", "misc"),
			info.get("value", 0),
			null
		]
		return add_item(item)
	return false

func remove_item(slot: int):
	if slot >= 0 and slot < 8:
		inventory_slots[slot] = null

func get_inventory() -> Array:
	return inventory_slots

func gain_xp(amount: int):
	player_xp += amount
	_check_level_up()

func _check_level_up():
	var level_str = str(player_level)
	if level_str in xp_data:
		var req = xp_data[level_str]
		if player_xp >= req:
			player_level += 1
			player_base_attack += 5
			player_defense += 2
			player_max_hp += 20
			player_hp = player_max_hp
			player_xp = 0
			_check_level_up()

func take_damage(amount: int) -> int:
	var stances = {
		"Neutral": {"def": 1.0, "atk": 1.0},
		"Aggressive": {"def": 1.3, "atk": 1.5},
		"Iron": {"def": 0.5, "atk": 0.7},
		"Berserk": {"def": 1.8, "atk": 2.0}
	}
	var mult = stances.get(player_current_stance, {"def": 1.0})["def"]
	var final_damage = int(amount * mult)
	player_hp = max(0, player_hp - final_damage)
	return final_damage

func get_attack() -> int:
	var stances = {
		"Neutral": {"def": 1.0, "atk": 1.0},
		"Aggressive": {"def": 1.3, "atk": 1.5},
		"Iron": {"def": 0.5, "atk": 0.7},
		"Berserk": {"def": 1.8, "atk": 2.0}
	}
	var mult = stances.get(player_current_stance, {"atk": 1.0})["atk"]
	return int(player_base_attack * mult)

func mark_enemy_defeated(enemy_name: String, grid_x: int, grid_y: int):
	for e in defeated_enemies:
		if e["name"] == enemy_name:
			return
	defeated_enemies.append({"name": enemy_name, "grid_x": grid_x, "grid_y": grid_y})

func is_enemy_defeated(enemy_name: String, grid_x: int, grid_y: int) -> bool:
	for e in defeated_enemies:
		if e["name"] == enemy_name and e["grid_x"] == grid_x and e["grid_y"] == grid_y:
			return true
	return false

func reset_player():
	player_level = 1
	player_xp = 0
	player_xp_to_next = 100
	player_max_hp = 100
	player_hp = 100
	player_base_attack = 15
	player_defense = 5
	player_current_stance = "Neutral"
	player_poisoned = false
	player_defending = false
	player_grid_x = 2
	player_grid_y = 2
	opened_chests.clear()
	defeated_enemies.clear()
	_init_inventory()
	boss1_defeated = false
