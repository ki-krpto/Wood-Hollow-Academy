extends Node

static func roll_dice(num_dice: int = 1, num_sides: int = 20) -> Array:
	var results = []
	for i in range(num_dice):
		results.append(randi() % num_sides + 1)
	return results

static func roll_d20() -> int:
	return randi() % 20 + 1

static func roll_attack() -> Dictionary:
	var roll = roll_d20()
	var multiplier = 1.1

	if roll == 1:
		return {"roll": roll, "result_type": "critical_fail", "damage_dice": 1, "damage_sides": 4, "multiplier": 0, "message": "Critical Fail!"}
	elif roll >= 19:
		return {"roll": roll, "result_type": "critical_hit", "damage_dice": 3, "damage_sides": 4, "multiplier": multiplier, "message": "Critical Hit!"}
	elif roll >= 15:
		return {"roll": roll, "result_type": "good_hit", "damage_dice": 2, "damage_sides": 4, "multiplier": multiplier, "message": "Good Roll!"}
	else:
		return {"roll": roll, "result_type": "normal_hit", "damage_dice": 1, "damage_sides": 4, "multiplier": multiplier, "message": "Normal Roll."}

static func calculate_damage(attack_result: Dictionary, base_attack: int = 0) -> int:
	if attack_result["multiplier"] == 0:
		return 0
	var dice_damage = 0
	for val in roll_dice(attack_result["damage_dice"], attack_result["damage_sides"]):
		dice_damage += val
	var total = int((dice_damage + base_attack) * attack_result["multiplier"])
	return max(1, total)
