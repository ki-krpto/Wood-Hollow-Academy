extends Node2D

var enemy: EnemyCombatant
var state = "menu"
var message = ""
var message_timer = 0
var battle_over = false
var result = "LOSE"
var shake_timer = 0
var enemy_offset = Vector2.ZERO
var enemy_name: String

@onready var enemy_sprite = $EnemySprite
@onready var hp_bar = $EnemyHPBar
@onready var enemy_name_label = $EnemyName
@onready var message_label = $MenuPanel/MessageLabel
@onready var player_hp_label = $MenuPanel/RightPanel/PlayerStats/HPLabel
@onready var item_options = $MenuPanel/RightPanel/ItemOptions
@onready var stance_options = $MenuPanel/RightPanel/StanceOptions
@onready var player_stats = $MenuPanel/RightPanel/PlayerStats
@onready var menu_buttons = $MenuPanel/MenuButtons
@onready var info_panel = $MenuPanel/InfoPanel

func _ready():
	enemy_name = PlayerData.last_enemy_name
	enemy = EnemyCombatant.new(enemy_name)
	enemy_name_label.text = enemy.name

	load_enemy_sprite()
	connect_buttons()
	show_menu()

func load_enemy_sprite():
	var tex = null
	var path = "res://assets/img/" + enemy.name.replace(" ", "_") + ".png"
	if ResourceLoader.exists(path):
		tex = load(path)
	path = "res://assets/img/" + enemy.name + ".png"
	if not tex and ResourceLoader.exists(path):
		tex = load(path)
	path = "res://assets/img/" + enemy.name.to_lower() + ".png"
	if not tex and ResourceLoader.exists(path):
		tex = load(path)

	if tex:
		enemy_sprite.texture = tex

func connect_buttons():
	$MenuPanel/MenuButtons/AttackBtn.pressed.connect(_on_attack)
	$MenuPanel/MenuButtons/ItemsBtn.pressed.connect(_on_items)
	$MenuPanel/MenuButtons/StancesBtn.pressed.connect(_on_stances)
	$MenuPanel/MenuButtons/RunBtn.pressed.connect(_on_run)

func _process(_delta):
	if message_timer > 0:
		message_timer -= 1
		return

	if shake_timer > 0:
		shake_timer -= 1
		enemy_offset = Vector2(randi() % 6 - 3, randi() % 6 - 3)
	else:
		enemy_offset = Vector2.ZERO

	enemy_sprite.position = Vector2(320, 140) + enemy_offset
	hp_bar.value = float(enemy.hp) / max(enemy.max_hp, 1) * 100
	enemy_name_label.text = enemy.name + " - " + str(enemy.hp) + "/" + str(enemy.max_hp)

	var hp_color = Color.GREEN
	if float(PlayerData.hp) / PlayerData.max_hp < 0.3:
		hp_color = Color.RED
	elif float(PlayerData.hp) / PlayerData.max_hp < 0.6:
		hp_color = Color.YELLOW
	player_hp_label.text = "HP: " + str(PlayerData.hp) + "/" + str(PlayerData.max_hp)
	player_hp_label.theme_override_colors/font_color = hp_color

	message_label.text = message if message else "What will you do?"

	if message_timer > 0:
		return

	if state == "animating":
		if not enemy.is_alive():
			PlayerData.gain_xp(enemy.xp_reward)
			message = enemy.name + " defeated! +" + str(enemy.xp_reward) + " XP"
			state = "victory"
			message_timer = 120
		else:
			enemy_turn()
	elif state == "enemy_turn":
		if not PlayerData.is_alive():
			message = "You died..."
			state = "defeat"
			message_timer = 120
		else:
			start_player_turn()
	elif state in ["victory", "defeat"]:
		battle_over = true
		result = "WIN" if state == "victory" else "LOSE"
		_on_battle_end()

func show_menu():
	state = "menu"
	menu_buttons.show()
	player_stats.show()
	item_options.hide()
	stance_options.hide()

func start_player_turn():
	if PlayerData.poisoned:
		PlayerData.hp = max(0, PlayerData.hp - 5)
		message = "Poison dealt 5 damage!"
		message_timer = 60
	else:
		message = ""
	show_menu()

func enemy_turn():
	state = "enemy_turn"
	var move_names = []
	var move_weights = []
	for m in enemy.moves.keys():
		move_names.append(m)
		move_weights.append(enemy.moves[m])

	var total = 0
	for w in move_weights:
		total += w
	var roll = randi() % max(total, 1)
	var cumulative = 0
	var move_name = move_names[0]
	for i in range(move_names.size()):
		cumulative += move_weights[i]
		if roll < cumulative:
			move_name = move_names[i]
			break

	var move_data = Moves.ENEMY_MOVES.get(move_name, {"damage": 7, "effect": "none", "text": "attacks!"})
	message = enemy.name + " used " + move_name + "! " + move_data["text"]

	var effect = move_data.get("effect")
	if effect == "poison":
		PlayerData.poisoned = true
		message += " You are poisoned!"
	elif effect == "buff_atk":
		enemy.attack_stat = int(enemy.attack_stat * 1.5)
		message = enemy.name + "'s power surged massively!"
	elif effect == "stat_swap":
		var tmp = enemy.attack_stat
		enemy.attack_stat = enemy.defense_stat
		enemy.defense_stat = tmp
	elif effect == "recoil":
		enemy.hp -= 10

	var base_power = move_data.get("damage", 0)
	if base_power > 0:
		PlayerData.take_damage(base_power + enemy.attack_stat)

	message_timer = 90

func _on_attack():
	var attack_result = Dice.roll_attack()
	var roll = attack_result["roll"]
	if attack_result["result_type"] == "critical_fail":
		var dmg = 0
		for v in Dice.roll_dice(2, 6):
			dmg += v
		PlayerData.hp = max(0, PlayerData.hp - dmg)
		message = "Roll: " + str(roll) + " - Critical Fail! Self-damage: " + str(dmg) + "!"
	elif attack_result["result_type"] == "miss":
		message = "Roll: " + str(roll) + " - Miss!"
	else:
		var damage = Dice.calculate_damage(attack_result, PlayerData.attack())
		var actual = enemy.take_damage(damage)
		message = "Roll: " + str(roll) + " - " + attack_result["message"] + " " + str(actual) + " damage!"
		shake_timer = 10
	message_timer = 90
	state = "animating"

func _on_items():
	item_options.show()
	player_stats.hide()
	menu_buttons.hide()

	for c in item_options.get_children():
		c.queue_free()

	for i in range(PlayerData.inventory.size()):
		var item = PlayerData.inventory[i]
		var btn = Button.new()
		btn.text = item.name
		btn.theme_override_font_sizes/font_size = 16
		var idx = i
		btn.pressed.connect(func(): _use_item(idx))
		item_options.add_child(btn)

func _use_item(index: int):
	if index < 0 or index >= PlayerData.inventory.size():
		return
	var item = PlayerData.inventory[index]
	var heal_val = item.value
	PlayerData.hp = min(PlayerData.hp + heal_val, PlayerData.max_hp)
	PlayerData.inventory.remove_at(index)
	message = "Used " + item.name + "! Healed " + str(heal_val) + "!"
	message_timer = 90
	state = "animating"
	show_menu()

func _on_stances():
	stance_options.show()
	player_stats.hide()
	menu_buttons.hide()

	for c in stance_options.get_children():
		c.queue_free()

	for s in ["Neutral", "Aggressive", "Iron", "Berserk"]:
		var btn = Button.new()
		btn.text = s + (" (active)" if PlayerData.current_stance == s else "")
		btn.theme_override_font_sizes/font_size = 16
		var stance_name = s
		btn.pressed.connect(func(): _set_stance(stance_name))
		stance_options.add_child(btn)

func _set_stance(stance_name: String):
	if PlayerData.current_stance == stance_name:
		message = "Already in " + stance_name + "!"
		return
	PlayerData.current_stance = stance_name
	message = "Shifted to " + stance_name + " Stance!"
	message_timer = 60
	state = "animating"
	show_menu()

func _on_run():
	message = "Escaped!"
	state = "victory"
	message_timer = 60

func _on_battle_end():
	await get_tree().create_timer(1.5).timeout
	if result == "WIN":
		GameManager.boss1defeated = true
	if not PlayerData.is_alive():
		GameManager.return_to_menu()
	else:
		GameManager.return_to_overworld()
