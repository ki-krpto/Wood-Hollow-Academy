extends Node

var name: String
var max_hp: int
var hp: int
var attack_stat: int
var defense_stat: int
var xp_reward: int
var moves: Dictionary

func _init(enemy_name: String):
	var file = FileAccess.open("res://assets/data/enemies.json", FileAccess.READ)
	if not file:
		hp = 50; max_hp = 50; attack_stat = 10; defense_stat = 5; xp_reward = 20; moves = {"Chomp": 50}
		return

	var data = JSON.parse_string(file.get_as_text())
	if not data:
		hp = 50; max_hp = 50; attack_stat = 10; defense_stat = 5; xp_reward = 20; moves = {"Chomp": 50}
		return

	var entry = null
	for k in data.keys():
		if k.to_lower() == enemy_name.to_lower():
			entry = data[k]
			name = k
			break

	if not entry:
		hp = 50; max_hp = 50; attack_stat = 10; defense_stat = 5; xp_reward = 20; moves = {"Chomp": 50}
		return

	max_hp = entry.get("hp", 50)
	hp = max_hp
	attack_stat = entry.get("attack", 10)
	defense_stat = entry.get("defense", 5)
	xp_reward = entry.get("xp_reward", 20)
	moves = entry.get("moves", {"Chomp": 50})

func take_damage(incoming: int) -> int:
	var reduction = 100.0 / (100.0 + defense_stat)
	var actual = max(1, int(incoming * reduction))
	hp = max(0, hp - actual)
	return actual

func is_alive() -> bool:
	return hp > 0
