extends Node

var name = "Kim"
var level = 1
var xp = 0
var xp_to_next_level = 100
var max_hp = 100
var hp = 100
var base_attack = 15
var defense = 5
var current_stance = "Neutral"
var defending = false
var poisoned = false

var grid_pos = Vector2i(2, 2)
var last_enemy_name = ""

var inventory = []  # array of {"name": str, "desc": str, "type": str, "value": int}
var armor = null
var weapon = null
var opened_chests = []

var stances = {
	"Neutral":    {"def": 1.0, "atk": 1.0},
	"Aggressive": {"def": 1.3, "atk": 1.5},
	"Iron":       {"def": 0.5, "atk": 0.7},
	"Berserk":    {"def": 1.8, "atk": 2.0}
}

func attack() -> int:
	var stance_data = stances.get(current_stance, {"atk": 1.0})
	var atk_mult = stance_data.get("atk", 1.0)
	return int(base_attack * atk_mult)

func take_damage(amount: int) -> int:
	var mult = stances.get(current_stance, {}).get("def", 1.0)
	var final_damage = int(amount * mult)
	hp = max(0, hp - final_damage)
	return final_damage

func is_alive() -> bool:
	return hp > 0

func gain_xp(amount: int):
	xp += amount
	check_levelup()

func check_levelup():
	var file = FileAccess.open("res://assets/data/levelUpXp.json", FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	var xp_requirements = JSON.parse_string(text)
	if not xp_requirements:
		return
	var level_str = str(level)
	if xp_requirements.has(level_str):
		var req = xp_requirements[level_str]
		xp_to_next_level = req
		if xp >= req:
			level += 1
			base_attack += 5
			defense += 2
			max_hp += 20
			hp = max_hp
			xp = 0

func add_item(item: Array):
	if inventory.size() < 8:
		inventory.append({"name": item[0], "desc": item[1], "type": item[2], "value": item[3]})
		return true
	return false

func use_item(index: int):
	if index < 0 or index >= inventory.size():
		return
	var item = inventory[index]
	var type_lower = item["type"].to_lower()
	if type_lower == "weapon":
		var old = weapon
		weapon = item
		base_attack += item["value"]
		inventory[index] = old
	elif type_lower == "armor":
		var old = armor
		armor = item
		defense += item["value"]
		inventory[index] = old
	elif type_lower == "healing":
		hp = min(hp + item["value"], max_hp)
		inventory.remove_at(index)

func has_opened_chest(id: int) -> bool:
	return id in opened_chests

func open_chest(id: int):
	if not has_opened_chest(id):
		opened_chests.append(id)
