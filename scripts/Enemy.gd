extends Node

class_name CombatEnemy

var name: String
var max_hp: int
var hp: int
var attack_stat: int
var defense_stat: int
var xp_reward: int
var moves: Dictionary
var image_path: String

var current_stance: String = "Neutral"

var STANCES = {
	"Neutral": [1.0, 1.0],
	"Aggressive": [1.5, 0.5],
	"Iron": [0.6, 2.0],
	"Berserk": [2.0, 0.2]
}

func _init(enemy_name: String):
	_setup_from_data(enemy_name)

func _setup_from_data(enemy_name: String):
	var all_enemies = _load_enemy_data()
	var data = null
	for k in all_enemies.keys():
		if k.to_lower() == enemy_name.to_lower():
			data = all_enemies[k]
			name = k
			break
	if data == null:
		data = {"hp": 50, "attack": 10, "defense": 5, "xp_reward": 20, "image": "placeholder.png"}
		name = enemy_name
	max_hp = data["hp"]
	hp = max_hp
	attack_stat = data["attack"]
	defense_stat = data["defense"]
	xp_reward = data.get("xp_reward", 0)
	moves = data.get("moves", {"Chomp": 100})
	image_path = data.get("image", "placeholder.png")

func _load_enemy_data() -> Dictionary:
	var path = "res://assets/jason/enemies.json"
	if ResourceLoader.exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			if json.parse(text) == OK:
				return json.data
	return {}

func get_attack() -> int:
	var atk_mult = STANCES.get(current_stance, [1.0, 1.0])[0]
	return int(attack_stat * atk_mult)

func take_damage(incoming_damage: int) -> int:
	var stance_def_mult = STANCES.get(current_stance, [1.0, 1.0])[1]
	var effective_defense = defense_stat * stance_def_mult
	var reduction_factor = 100.0 / (100.0 + effective_defense)
	var actual_damage = max(1, int(incoming_damage * reduction_factor))
	hp = max(0, hp - actual_damage)
	return actual_damage

func is_alive() -> bool:
	return hp > 0
