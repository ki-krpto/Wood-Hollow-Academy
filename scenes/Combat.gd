extends Control

const Dice = preload("res://scripts/Dice.gd")
const Moves = preload("res://scripts/Moves.gd")

enum State { MENU, STANCES, ITEMS, ANIMATING, ENEMY_TURN, VICTORY, DEFEAT }

var state: int = State.MENU
var menu_options: Array[String] = ["Attack", "Items", "Stances", "Run Away"]
var stance_options: Array[String] = ["Neutral", "Aggressive", "Iron", "Berserk"]
var selected_option: int = 0
var selected_stance: int = 0
var selected_item: int = 0

var enemy: CombatEnemy = null
var message: String = "What will you do?"
var message_timer: int = 0
var shake_timer: int = 0
var enemy_offset: Vector2 = Vector2.ZERO
var battle_over: bool = false

var enemy_sprite: Texture2D = preload("res://assets/img/Pollutabloom.png")

@onready var enemy_sprite_rect = $EnemySprite
@onready var enemy_hp_bar = $EnemyHPBar
@onready var enemy_hp_fill = $EnemyHPBar/HPFill
@onready var enemy_hp_label = $EnemyHPBar/HPText
@onready var enemy_name_label = $EnemyName
@onready var message_label = $MessageLabel
@onready var menu_container = $MenuContainer
@onready var player_stats_label = $PlayerStats
@onready var item_container = $ItemContainer
@onready var stance_container = $StanceContainer

func _ready():
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.last_enemy_name != "":
		enemy = CombatEnemy.new(gm.last_enemy_name)
	else:
		enemy = CombatEnemy.new("Pollutabloom")
	
	_setup_enemy_display()
	_refresh_ui()
	_play_battle_music()

func _play_battle_music():
	var path = "res://assets/moosic/copyrightedplaceholdermusic.mp3"
	if ResourceLoader.exists(path):
		var stream = load(path) as AudioStream
		if stream:
			var player = AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = -14.0
			player.autoplay = true
			add_child(player)

func _setup_enemy_display():
	if enemy:
		enemy_name_label.text = enemy.name
		_update_hp_bar()
		var img_path = "res://assets/img/" + enemy.image_path
		if ResourceLoader.exists(img_path):
			enemy_sprite_rect.texture = load(img_path)
		else:
			enemy_sprite_rect.texture = preload("res://assets/img/Pollutabloom.png")

func _update_hp_bar():
	if not enemy:
		return
	var ratio = max(0.0, float(enemy.hp) / float(enemy.max_hp))
	enemy_hp_fill.size.x = enemy_hp_bar.size.x * ratio
	if ratio > 0.5:
		enemy_hp_fill.color = Color.GREEN
	elif ratio > 0.25:
		enemy_hp_fill.color = Color.YELLOW
	else:
		enemy_hp_fill.color = Color.RED
	enemy_hp_label.text = str(enemy.hp) + "/" + str(enemy.max_hp)

func _refresh_ui():
	menu_container.hide()
	item_container.hide()
	stance_container.hide()
	
	match state:
		State.MENU:
			menu_container.show()
			_build_menu()
		State.ITEMS:
			item_container.show()
			_build_items()
		State.STANCES:
			stance_container.show()
			_build_stances()
	
	message_label.text = message
	_update_player_stats()

func _update_player_stats():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		player_stats_label.text = gm.player_name + "\nHP: " + str(gm.player_hp) + "/" + str(gm.player_max_hp) + "\nStance: " + gm.player_current_stance

func _build_menu():
	for c in menu_container.get_children():
		c.queue_free()
	for i in menu_options.size():
		var btn = Button.new()
		btn.text = menu_options[i]
		btn.size = Vector2(200, 40)
		btn.position = Vector2(0, i * 48)
		if i == selected_option:
			btn.modulate = Color.YELLOW
		btn.pressed.connect(_on_menu_option_selected.bind(i))
		menu_container.add_child(btn)

var _item_slot_map: Array[int] = []

func _build_items():
	for c in item_container.get_children():
		c.queue_free()
	_item_slot_map.clear()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var inv = gm.get_inventory()
		var item_names = []
		for slot_idx in inv.size():
			var item = inv[slot_idx]
			if item != null:
				item_names.append(item[0])
				_item_slot_map.append(slot_idx)
		if item_names.is_empty():
			item_names.append("(No items)")
			_item_slot_map.append(-1)
		for i in item_names.size():
			var btn = Button.new()
			btn.text = item_names[i]
			btn.size = Vector2(200, 40)
			btn.position = Vector2(0, i * 48)
			if i == selected_item:
				btn.modulate = Color.YELLOW
			var idx = i
			btn.pressed.connect(_use_item.bind(idx))
			item_container.add_child(btn)

func _build_stances():
	for c in stance_container.get_children():
		c.queue_free()
	var gm = get_node_or_null("/root/GameManager")
	var current_stance = gm.player_current_stance if gm else "Neutral"
	for i in stance_options.size():
		var btn = Button.new()
		btn.text = stance_options[i]
		btn.size = Vector2(200, 40)
		btn.position = Vector2(0, i * 48)
		if stance_options[i] == current_stance:
			btn.modulate = Color.GREEN
		elif i == selected_stance:
			btn.modulate = Color.YELLOW
		var idx = i
		btn.pressed.connect(_set_stance.bind(idx))
		stance_container.add_child(btn)

func _on_menu_option_selected(idx: int):
	match menu_options[idx]:
		"Attack":
			_do_attack()
		"Items":
			state = State.ITEMS
			selected_item = 0
			message = "Choose an item:"
			_refresh_ui()
		"Stances":
			state = State.STANCES
			selected_stance = 0
			message = "Choose a stance:"
			_refresh_ui()
		"Run Away":
			message = "Escaped!"
			state = State.VICTORY
			message_timer = 60
			_refresh_ui()

func _do_attack():
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not enemy:
		return
	var attack_result = Dice.roll_attack()
	var roll = attack_result['roll']
	if attack_result['result_type'] == 'critical_fail':
		var self_damage = 0
		for val in Dice.roll_dice(2, 6):
			self_damage += val
		gm.player_hp = max(0, gm.player_hp - self_damage)
		message = "Roll: " + str(roll) + " - Critical Fail! Ouch: " + str(self_damage) + "!"
	elif attack_result['result_type'] == 'miss':
		message = "Roll: " + str(roll) + " - Miss!"
	else:
		var damage = Dice.calculate_damage(attack_result, gm.get_attack())
		var actual_damage = enemy.take_damage(damage)
		message = "Roll: " + str(roll) + " - " + attack_result['message'] + " " + str(actual_damage) + " damage!"
		shake_timer = 10
	message_timer = 90
	state = State.ANIMATING
	_refresh_ui()

func _set_stance(idx: int):
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	if gm.player_current_stance == stance_options[idx]:
		message = "Already in " + stance_options[idx] + "!"
		_refresh_ui()
		return
	gm.player_current_stance = stance_options[idx]
	message = "Shifted to " + stance_options[idx] + " Stance!"
	message_timer = 60
	state = State.ANIMATING
	_refresh_ui()

func _use_item(idx: int):
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
	if idx < 0 or idx >= _item_slot_map.size():
		return
	var slot = _item_slot_map[idx]
	if slot < 0:
		return
	var inv = gm.get_inventory()
	if slot >= inv.size() or inv[slot] == null:
		return
	var item = inv[slot]
	var item_type = str(item[2]).to_lower()
	var item_value = item[3]
	if item_type == "healing":
		gm.player_hp = min(gm.player_hp + item_value, gm.player_max_hp)
		message = "Used " + str(item[0]) + "! Healed " + str(item_value) + "!"
		gm.remove_item(slot)
	else:
		message = "Can't use that in battle!"
		return
	message_timer = 90
	state = State.ANIMATING
	_refresh_ui()

func _process(_delta):
	if battle_over:
		return
	if shake_timer > 0:
		shake_timer -= 1
		enemy_offset = Vector2(randi() % 4 - 2, randi() % 4 - 2)
		enemy_sprite_rect.position = Vector2(200, 100) + enemy_offset
	else:
		enemy_sprite_rect.position = Vector2(200, 100)
	
	if message_timer > 0:
		message_timer -= 1
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.player_hp <= 0 and state != State.DEFEAT:
		message = "You died..."
		state = State.DEFEAT
		message_timer = 90
		_refresh_ui()
		return
	
	if message_timer == 0:
		match state:
			State.ANIMATING:
				if enemy and not enemy.is_alive():
					if gm:
						gm.gain_xp(enemy.xp_reward)
					message = enemy.name + " defeated!"
					state = State.VICTORY
					message_timer = 90
					_refresh_ui()
				else:
					_enemy_turn()
			State.ENEMY_TURN:
				if gm and gm.player_hp <= 0:
					message = "You died..."
					state = State.DEFEAT
					message_timer = 90
				else:
					_start_player_turn()
			State.VICTORY, State.DEFEAT:
				battle_over = true
				await get_tree().create_timer(1.5).timeout
				_end_battle()

func _enemy_turn():
	state = State.ENEMY_TURN
	if not enemy:
		return
	var move_names = enemy.moves.keys()
	var move_weights = enemy.moves.values()
	if move_names.is_empty():
		message = "Enemy has no moves!"
		_start_player_turn()
		return
	var total_weight = 0
	for w in move_weights:
		total_weight += w
	var roll = randi() % total_weight
	var cumulative = 0
	var selected_move = move_names[0]
	for i in move_names.size():
		cumulative += move_weights[i]
		if roll < cumulative:
			selected_move = move_names[i]
			break
	var move_data = Moves.ENEMY_MOVES.get(selected_move, {"damage": 5, "effect": "none", "text": "attacks!"})
	var gm = get_node_or_null("/root/GameManager")
	message = enemy.name + " used " + selected_move + "! " + move_data["text"]
	var effect = move_data.get("effect")
	if effect == "poison" and gm:
		gm.player_poisoned = true
		message += " You are poisoned!"
	elif effect == "buff_atk":
		enemy.attack_stat = int(enemy.attack_stat * 1.5)
		message = enemy.name + "'s power surged massively!"
	elif effect == "stat_swap":
		var temp = enemy.attack_stat
		enemy.attack_stat = enemy.defense_stat
		enemy.defense_stat = temp
	elif effect == "recoil":
		enemy.hp -= 10
	var base_power = move_data.get("damage", 0)
	if base_power > 0 and gm:
		var total_power = base_power + enemy.get_attack()
		var actual_dmg = gm.take_damage(total_power)
	message_timer = 90
	_refresh_ui()

func _start_player_turn():
	state = State.MENU
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.player_poisoned:
		var poison_dmg = 5
		gm.player_hp = max(0, gm.player_hp - poison_dmg)
		message = "Poison dealt " + str(poison_dmg) + " damage!"
		message_timer = 60
	selected_option = 0
	_refresh_ui()

func _end_battle():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if state == State.VICTORY:
			gm.boss1_defeated = true
			gm.mark_enemy_defeated(gm.last_enemy_name, gm.last_enemy_grid_x, gm.last_enemy_grid_y)
			gm.in_combat = false
			var t = preload("res://scripts/Transition.tscn").instantiate()
			add_child(t)
			await get_tree().create_timer(0.5).timeout
			get_tree().change_scene_to_file("res://scene.tscn")
		elif state == State.DEFEAT or gm.player_hp <= 0:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _input(event):
	if event.is_action_pressed("ui_up"):
		match state:
			State.MENU:
				selected_option = (selected_option - 1 + menu_options.size()) % menu_options.size()
				_refresh_ui()
			State.ITEMS:
				selected_item = max(0, selected_item - 1)
				_refresh_ui()
			State.STANCES:
				selected_stance = (selected_stance - 1 + stance_options.size()) % stance_options.size()
				_refresh_ui()
	if event.is_action_pressed("ui_down"):
		match state:
			State.MENU:
				selected_option = (selected_option + 1) % menu_options.size()
				_refresh_ui()
			State.ITEMS:
				var count = _item_slot_map.size()
				if count > 0:
					selected_item = min(count - 1, selected_item + 1)
				_refresh_ui()
			State.STANCES:
				selected_stance = (selected_stance + 1) % stance_options.size()
				_refresh_ui()
	if event.is_action_pressed("interact"):
		match state:
			State.MENU:
				_on_menu_option_selected(selected_option)
			State.ITEMS:
				_use_item(selected_item)
			State.STANCES:
				_set_stance(selected_stance)
	if event.is_action_pressed("ui_cancel"):
		if state == State.ITEMS or state == State.STANCES:
			state = State.MENU
			_refresh_ui()
