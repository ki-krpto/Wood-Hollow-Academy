extends Control

var enemy_data: Dictionary = {}
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_attack_buff: int = 0
var player_attack_buff: int = 0
var player_poison_turns: int = 0

var enemy_poison_turns: int = 0
var player_extra_turns: int = 0

var state: String = "player_choice"
var move_selected: String = ""

var message_queue: Array[String] = []
var processing_message: bool = false

var screen_size: Vector2

var shooting_stars: Array[Dictionary] = []
var shooting_star_timer: float = 0.0

func _ready():
	randomize()
	screen_size = size
	if screen_size == Vector2.ZERO:
		screen_size = Vector2(1152, 648)
	load_enemy()
	build_background()
	start_shooting_star_loop()
	build_enemy_display()
	build_bottom_bar()
	build_action_buttons()
	build_message_label()
	show_message("A wild " + enemy_data.get("name", "enemy") + " appeared!")

func load_enemy():
	var enemy_name = GameManager.current_enemy
	enemy_data = GameManager.get_enemy_data(enemy_name)
	enemy_data["name"] = enemy_name
	enemy_hp = enemy_data.get("hp", 50)
	enemy_max_hp = enemy_hp

func build_background():
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.12, 1)
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	create_stars()

	var mountain_colors = [Color(0.2, 0.15, 0.12, 1), Color(0.15, 0.1, 0.08, 1), Color(0.25, 0.2, 0.15, 1)]
	var mountain_heights = [0.4, 0.5, 0.35]
	for i in 3:
		var mtn = ColorRect.new()
		mtn.color = mountain_colors[i]
		mtn.position = Vector2(0, screen_size.y * (0.3 + i * 0.1))
		mtn.size = Vector2(screen_size.x, screen_size.y * mountain_heights[i])
		add_child(mtn)

	var platform_color = Color(0.3, 0.22, 0.15, 1)
	var left_plat = ColorRect.new()
	left_plat.color = platform_color
	left_plat.position = Vector2(screen_size.x * 0.1, screen_size.y * 0.45)
	left_plat.size = Vector2(screen_size.x * 0.25, screen_size.y * 0.03)
	add_child(left_plat)

	var right_plat = ColorRect.new()
	right_plat.color = platform_color
	right_plat.position = Vector2(screen_size.x * 0.55, screen_size.y * 0.35)
	right_plat.size = Vector2(screen_size.x * 0.3, screen_size.y * 0.03)
	add_child(right_plat)

func create_stars():
	var sky_height = screen_size.y * 0.72
	for i in 100:
		var star = ColorRect.new()
		var s = randf_range(1.0, 2.5)
		star.size = Vector2(s, s)
		star.position = Vector2(randf_range(0, screen_size.x), randf_range(0, sky_height))
		star.color = Color(1, 1, 1, randf_range(0.15, 0.9))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)

func start_shooting_star_loop():
	shooting_star_timer = randf_range(0.5, 3.0)

func _process(delta):
	var i = 0
	while i < shooting_stars.size():
		var s = shooting_stars[i]
		s.node.position += s.velocity * delta
		s.node.modulate.a -= s.fade_speed * delta
		if s.node.modulate.a <= 0 or s.node.position.y > screen_size.y * 0.72:
			s.node.queue_free()
			shooting_stars.remove_at(i)
		else:
			i += 1

	if shooting_star_timer > 0:
		shooting_star_timer -= delta
		if shooting_star_timer <= 0:
			spawn_shooting_star()

func spawn_shooting_star():
	if not is_inside_tree():
		return
	var star = ColorRect.new()
	var len = randi_range(20, 40)
	star.size = Vector2(2, len)
	star.rotation = 0.6
	star.position = Vector2(randf_range(screen_size.x * 0.3, screen_size.x * 0.95), -len)
	star.color = Color(1, 1, 1, 0.9)
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(star)

	var speed = randf_range(250, 400)
	shooting_stars.append({
		"node": star,
		"velocity": Vector2(-speed * 0.65, speed * 0.85),
		"fade_speed": randf_range(0.6, 1.2)
	})

	shooting_star_timer = randf_range(0.5, 3.0)

func build_enemy_display():
	var enemy_name = enemy_data.get("name", "???")
	var name_label = Label.new()
	name_label.text = enemy_name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.position = Vector2(screen_size.x * 0.1, screen_size.y * 0.08)
	name_label.name = "EnemyName"
	add_child(name_label)

	var hp_label = Label.new()
	hp_label.text = "HP: " + str(enemy_hp) + "/" + str(enemy_max_hp)
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.position = Vector2(screen_size.x * 0.1, screen_size.y * 0.15 - 18)
	hp_label.name = "EnemyHPLabel"
	add_child(hp_label)

	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2, 1)
	bar_bg.position = Vector2(screen_size.x * 0.1, screen_size.y * 0.15)
	bar_bg.size = Vector2(200, 18)
	bar_bg.name = "EnemyHPBarBg"
	add_child(bar_bg)

	var bar = ColorRect.new()
	bar.color = Color(0.9, 0.15, 0.15, 1)
	bar.position = Vector2(screen_size.x * 0.1, screen_size.y * 0.15)
	bar.size = Vector2(200, 18)
	bar.name = "EnemyHPBar"
	add_child(bar)

	var sprite = Sprite2D.new()
	var tex_path = "res://assets/img/" + enemy_data.get("image", "")
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	sprite.scale = Vector2(0.22, 0.22)
	sprite.position = Vector2(screen_size.x * 0.75, screen_size.y * 0.15)
	sprite.name = "EnemySprite"
	add_child(sprite)

func build_bottom_bar():
	var bar_y = screen_size.y * 0.72
	var bar_height = screen_size.y * 0.28
	var info_x = screen_size.x * 0.55

	var bg_bar = ColorRect.new()
	bg_bar.color = Color(0.35, 0.22, 0.12, 1)
	bg_bar.position = Vector2(0, bar_y)
	bg_bar.size = Vector2(screen_size.x, bar_height)
	bg_bar.name = "BottomBar"
	add_child(bg_bar)

	var wood_grain = ColorRect.new()
	wood_grain.color = Color(0.28, 0.17, 0.08, 0.5)
	wood_grain.position = Vector2(0, bar_y)
	wood_grain.size = Vector2(screen_size.x, 4)
	add_child(wood_grain)

	# Center emblem
	var center_x = screen_size.x * 0.45
	var emblem_size = bar_height * 0.75
	var emblem = ColorRect.new()
	emblem.color = Color(0.5, 0.32, 0.15, 1)
	emblem.position = Vector2(center_x - emblem_size / 2, bar_y + (bar_height - emblem_size) / 2)
	emblem.size = Vector2(emblem_size, emblem_size)
	emblem.name = "CenterEmblem"
	add_child(emblem)

	var inner_emblem = ColorRect.new()
	inner_emblem.color = Color(0.4, 0.25, 0.1, 1)
	inner_emblem.position = Vector2(center_x - emblem_size * 0.35, bar_y + (bar_height - emblem_size * 0.7) / 2)
	inner_emblem.size = Vector2(emblem_size * 0.3, emblem_size * 0.3)
	add_child(inner_emblem)

	# Player name (top of right section)
	var player_name_label = Label.new()
	player_name_label.text = GameManager.player_data.get("name", "Kara")
	player_name_label.add_theme_font_size_override("font_size", 18)
	player_name_label.add_theme_color_override("font_color", Color.WHITE)
	player_name_label.position = Vector2(info_x, bar_y + 8)
	player_name_label.name = "PlayerNameLabel"
	add_child(player_name_label)

	# Player HP label + bar
	var player_hp_label = Label.new()
	player_hp_label.text = "HP: " + str(GameManager.player_data.get("hp", 0)) + "/" + str(GameManager.player_data.get("max_hp", 100))
	player_hp_label.add_theme_font_size_override("font_size", 13)
	player_hp_label.add_theme_color_override("font_color", Color.WHITE)
	player_hp_label.position = Vector2(info_x, bar_y + 30)
	player_hp_label.name = "PlayerHPLabel"
	add_child(player_hp_label)

	var player_bar_bg = ColorRect.new()
	player_bar_bg.color = Color(0.2, 0.2, 0.2, 1)
	player_bar_bg.position = Vector2(info_x, bar_y + 48)
	player_bar_bg.size = Vector2(200, 14)
	player_bar_bg.name = "PlayerHPBarBg"
	add_child(player_bar_bg)

	var player_bar = ColorRect.new()
	player_bar.color = Color(0.15, 0.8, 0.15, 1)
	player_bar.position = Vector2(info_x, bar_y + 48)
	var player_pct = float(GameManager.player_data.get("hp", 0)) / float(GameManager.player_data.get("max_hp", 100))
	player_bar.size = Vector2(200 * player_pct, 14)
	player_bar.name = "PlayerHPBar"
	add_child(player_bar)

	# Detail info (right side)
	var detail_bg = ColorRect.new()
	detail_bg.color = Color(0.25, 0.15, 0.08, 1)
	detail_bg.position = Vector2(screen_size.x * 0.82, bar_y + 8)
	detail_bg.size = Vector2(screen_size.x * 0.16, bar_height - 16)
	add_child(detail_bg)

	var detail_label = Label.new()
	detail_label.text = "LV." + str(GameManager.player_data.get("level", 1)) + "\nATK: " + str(GameManager.player_data.get("attack", 10)) + "\nDEF: " + str(GameManager.player_data.get("defense", 5))
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8, 1))
	detail_label.position = Vector2(screen_size.x * 0.83, bar_y + 14)
	add_child(detail_label)

func build_action_buttons():
	var bar_y = screen_size.y * 0.72
	var bar_height = screen_size.y * 0.28
	var btn_w = 90
	var btn_h = 34
	var gap = 6
	var start_x = 15
	var start_y = bar_y + bar_height * 0.42

	var actions = [
		{"text": "FIGHT",  "action": "fight"},
		{"text": "ITEMS", "action": "items"},
		{"text": "DEFEND", "action": "defend"},
		{"text": "RUN",   "action": "run"},
	]

	for i in actions.size():
		var col = i % 2
		var row = i / 2
		var a = actions[i]
		var btn = Button.new()
		btn.text = a.text
		btn.position = Vector2(start_x + col * (btn_w + gap), start_y + row * (btn_h + gap))
		btn.size = Vector2(btn_w, btn_h)
		btn.name = "Btn" + a.action.capitalize()
		btn.pressed.connect(_on_action_pressed.bind(a.action))
		add_child(btn)

func build_message_label():
	var bar_y = screen_size.y * 0.72
	var msg = Label.new()
	msg.text = ""
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color(1, 1, 0.8, 1))
	msg.add_theme_color_override("font_shadow_color", Color.BLACK)
	msg.add_theme_constant_override("shadow_offset_x", 1)
	msg.add_theme_constant_override("shadow_offset_y", 1)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.position = Vector2(15, bar_y + 8)
	msg.size = Vector2(screen_size.x * 0.35, 55)
	msg.name = "MessageLabel"
	add_child(msg)

func _on_action_pressed(action: String):
	if state != "player_choice" or processing_message:
		return
	match action:
		"fight":
			show_move_selection()
		"items":
			show_item_selection()
		"defend":
			execute_defend()
		"run":
			execute_run()

func show_move_selection():
	state = "selecting_move"
	hide_action_buttons()
	var moves = GameManager.player_data.get("moves", [])
	var bar_y = screen_size.y * 0.72
	var bar_height = screen_size.y * 0.28
	var btn_x = 15
	var start_y = bar_y + bar_height * 0.42
	var btn_y = start_y

	for move_name in moves:
		var btn = Button.new()
		btn.text = move_name
		btn.position = Vector2(btn_x, btn_y)
		btn.size = Vector2(130, 35)
		btn.name = "MoveBtn_" + move_name
		btn.pressed.connect(_on_move_selected.bind(move_name))
		add_child(btn)
		btn_y += 40
		if btn_y > bar_y + bar_height - 50:
			btn_y = bar_y + 10
			btn_x += 140

	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(screen_size.x - 90, bar_y + bar_height - 45)
	back_btn.size = Vector2(80, 35)
	back_btn.name = "MoveBtn_Back"
	back_btn.pressed.connect(_on_move_back)
	add_child(back_btn)

func hide_action_buttons():
	for child in get_children():
		if child is Button and child.name.begins_with("Btn"):
			child.hide()

func show_action_buttons():
	for child in get_children():
		if child is Button and child.name.begins_with("Btn"):
			child.show()
	for child in get_children():
		if child is Button and (child.name.begins_with("MoveBtn") or child.name.begins_with("ItemBtn")):
			child.queue_free()

func _on_move_back():
	state = "player_choice"
	show_action_buttons()

func show_item_selection():
	var inv = GameManager.get_inventory()
	var usable: Array[Dictionary] = []
	for entry in inv:
		var item_data = GameManager.get_item_data(entry.get("name", ""))
		if item_data.get("type") == "healing" or item_data.get("type") == "combat_buff":
			usable.append(entry)
	if usable.is_empty():
		show_message("No usable items!")
		return
	state = "selecting_item"
	hide_action_buttons()
	var bar_y = screen_size.y * 0.72
	var bar_height = screen_size.y * 0.28
	var btn_x = 15
	var start_y = bar_y + bar_height * 0.42
	var btn_y = start_y
	for entry in usable:
		var btn = Button.new()
		btn.text = entry.get("name", "???") + " x" + str(entry.get("count", 1))
		btn.position = Vector2(btn_x, btn_y)
		btn.size = Vector2(180, 35)
		btn.name = "ItemBtn_" + entry.get("name", "")
		btn.pressed.connect(_on_item_selected.bind(entry.get("name", "")))
		add_child(btn)
		btn_y += 40
		if btn_y > bar_y + bar_height - 50:
			btn_y = bar_y + 10
			btn_x += 190
	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(screen_size.x - 90, bar_y + bar_height - 45)
	back_btn.size = Vector2(80, 35)
	back_btn.name = "ItemBtn_Back"
	back_btn.pressed.connect(_on_item_back)
	add_child(back_btn)

func _on_item_back():
	state = "player_choice"
	show_action_buttons()

func _on_item_selected(item_name: String):
	if state != "selecting_item" or processing_message:
		return
	state = "executing"
	hide_action_buttons()
	for child in get_children():
		if child is Button and child.name.begins_with("ItemBtn"):
			child.queue_free()
	var item_data = GameManager.get_item_data(item_name)
	GameManager.use_item(item_name)
	if item_data.get("type") == "combat_buff":
		if item_data.get("attribute") == "extra_turns":
			player_extra_turns += int(item_data.get("value", 1))
			show_message("Used " + item_name + "! You can attack again!")
			await get_tree().create_timer(1.0).timeout
			state = "player_choice"
			show_action_buttons()
			return
	update_player_hp_bar()
	show_message("Used " + item_name + "!")
	await get_tree().create_timer(1.0).timeout
	execute_enemy_turn(1.0)

func _on_move_selected(move_name: String):
	if state != "selecting_move" or processing_message:
		return
	state = "executing"
	move_selected = move_name
	hide_action_buttons()
	for child in get_children():
		if child is Button and child.name.begins_with("MoveBtn"):
			child.queue_free()
	execute_player_attack(move_name)

func execute_defend():
	state = "executing"
	show_message("You defend! Damage halved this turn.")
	await get_tree().create_timer(1.0).timeout
	execute_enemy_turn(0.5)

func execute_run():
	if randi() % 2 == 0:
		show_message("You fled successfully!")
		await get_tree().create_timer(1.0).timeout
		return_to_overworld()
	else:
		show_message("Failed to flee!")
		await get_tree().create_timer(0.8).timeout
		execute_enemy_turn(1.0)

func execute_player_attack(move_name: String):
	var attack_data = GameManager.get_attack_data(move_name)
	var atk = GameManager.player_data.get("attack", 10) + player_attack_buff
	var def = enemy_data.get("defense", 0)
	var power = attack_data.get("power", 0)
	var dmg = GameManager.calculate_damage(atk, power, def)

	if attack_data.get("type") == "status":
		handle_status_effect(attack_data.get("effects", []), true)
	else:
		enemy_hp = max(0, enemy_hp - dmg)
		update_enemy_hp_bar()
		show_message(GameManager.player_data.get("name", "You") + " used " + move_name + "! Dealt " + str(dmg) + " damage!")

	await get_tree().create_timer(1.0).timeout

	if enemy_hp <= 0:
		victory()
		return

	if attack_data.get("effects", []).has("poison"):
		handle_status_effect(["poison"], false, move_name)

	if enemy_poison_turns > 0:
		await execute_enemy_poison_tick()
		if enemy_hp <= 0:
			victory()
			return

	if player_extra_turns > 0:
		player_extra_turns -= 1
		state = "player_choice"
		show_action_buttons()
	else:
		execute_enemy_turn(1.0)

func execute_enemy_turn(damage_mult: float = 1.0):
	state = "enemy_turn"
	var move_name = pick_enemy_move()
	var attack_data = GameManager.get_attack_data(move_name)
	var atk = enemy_data.get("attack", 5) + enemy_attack_buff
	var def = GameManager.player_data.get("defense", 5)
	var power = attack_data.get("power", 0)
	var dmg = GameManager.calculate_damage(atk, power, def)
	dmg = int(ceil(dmg * damage_mult))

	if attack_data.get("type") == "status":
		handle_status_effect(attack_data.get("effects", []), false)
	else:
		var player_hp = GameManager.player_data.get("hp", 0)
		player_hp = max(0, player_hp - dmg)
		GameManager.player_data["hp"] = player_hp
		update_player_hp_bar()
		show_message(enemy_data.get("name", "Enemy") + " used " + move_name + "! Dealt " + str(dmg) + " damage!")
		if attack_data.get("effects", []).has("poison"):
			handle_status_effect(["poison"], true)

	await get_tree().create_timer(1.0).timeout

	if GameManager.player_data.get("hp", 0) <= 0:
		defeat()
		return

	if player_poison_turns > 0:
		execute_poison_tick()
		return

	state = "player_choice"
	show_action_buttons()

func execute_poison_tick():
	var poison_dmg = max(1, GameManager.player_data.get("max_hp", 100) / 10)
	var hp = GameManager.player_data.get("hp", 0)
	hp = max(0, hp - poison_dmg)
	GameManager.player_data["hp"] = hp
	update_player_hp_bar()
	player_poison_turns -= 1
	show_message("Poison deals " + str(poison_dmg) + " damage! (" + str(player_poison_turns) + " turns remaining)")
	await get_tree().create_timer(1.0).timeout

	if hp <= 0:
		defeat()
		return

	state = "player_choice"
	show_action_buttons()

func execute_enemy_poison_tick():
	var poison_dmg = max(1, enemy_max_hp / 10)
	enemy_hp = max(0, enemy_hp - poison_dmg)
	update_enemy_hp_bar()
	enemy_poison_turns -= 1
	show_message("Poison deals " + str(poison_dmg) + " damage to " + enemy_data.get("name", "Enemy") + "! (" + str(enemy_poison_turns) + " turns remaining)")
	await get_tree().create_timer(1.0).timeout

func handle_status_effect(effects: Array, is_player: bool, source_move: String = ""):
	for effect in effects:
		match effect:
			"raise_attack":
				if is_player:
					player_attack_buff += 8
					show_message("You focus your mind! Attack rose!")
				else:
					enemy_attack_buff += 5
					show_message(enemy_data.get("name", "Enemy") + " plots evilly! Attack rose!")
			"heal_self":
				if is_player:
					GameManager.heal_player(15)
					update_player_hp_bar()
					show_message(GameManager.player_data.get("name", "You") + " used " + source_move + "! Restored 15 HP!")
				else:
					var heal = enemy_max_hp / 4
					enemy_hp = min(enemy_hp + heal, enemy_max_hp)
					update_enemy_hp_bar()
					show_message(enemy_data.get("name", "Enemy") + " used " + source_move + "! Restored " + str(heal) + " HP!")
			"poison":
				if is_player:
					player_poison_turns += 3
					show_message("You've been poisoned! You'll take damage each turn!")
				else:
					enemy_poison_turns += 3
					show_message("The enemy is poisoned!")

func pick_enemy_move() -> String:
	var moves = enemy_data.get("moves", {})
	if moves.is_empty():
		return "Chomp"
	var total_weight = 0
	for move_name in moves:
		total_weight += int(moves[move_name])
	var roll = randi() % total_weight
	var cumulative = 0
	for move_name in moves:
		cumulative += moves[move_name]
		if roll < cumulative:
			return move_name
	return moves.keys()[0]

func update_enemy_hp_bar():
	var bar = get_node_or_null("EnemyHPBar")
	if bar:
		var pct = float(enemy_hp) / float(enemy_max_hp)
		bar.size.x = 200 * pct
		if pct < 0.25:
			bar.color = Color(0.9, 0.1, 0.1, 1)
		elif pct < 0.5:
			bar.color = Color(0.9, 0.6, 0.1, 1)
	var label = get_node_or_null("EnemyHPLabel")
	if label:
		label.text = "HP: " + str(enemy_hp) + "/" + str(enemy_max_hp)

func update_player_hp_bar():
	var bar = get_node_or_null("PlayerHPBar")
	if bar:
		var max_hp = GameManager.player_data.get("max_hp", 100)
		var hp = GameManager.player_data.get("hp", 0)
		var pct = float(hp) / float(max_hp)
		bar.size.x = 200 * pct
	var label = get_node_or_null("PlayerHPLabel")
	if label:
		label.text = "HP: " + str(GameManager.player_data["hp"]) + "/" + str(GameManager.player_data["max_hp"])

func show_message(text: String):
	var msg = get_node_or_null("MessageLabel")
	if msg:
		msg.text = text

func victory():
	state = "victory"
	var old_level = int(GameManager.player_data.get("level", 1))
	var xp = enemy_data.get("xp_reward", 50)
	GameManager.add_xp(xp)
	var new_level = int(GameManager.player_data.get("level", 1))
	if new_level > old_level:
		show_level_up(new_level)
		await get_tree().create_timer(3.0).timeout
	show_message("Victory! Gained " + str(xp) + " XP!")
	if not GameManager.defeated_enemies.has(GameManager.current_enemy):
		GameManager.defeated_enemies.append(GameManager.current_enemy)
	GameManager.current_enemy = ""
	await get_tree().create_timer(2.0).timeout
	return_to_overworld()

func show_level_up(new_level: int):
	var overlay = CanvasLayer.new()
	overlay.layer = 20
	get_tree().current_scene.add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_top = -60
	panel.offset_right = 200
	panel.offset_bottom = 60
	overlay.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	style.border_color = Color(0.9, 0.8, 0.55, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "LEVEL UP!"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var level_label = Label.new()
	level_label.text = "You are now Level " + str(new_level) + "!"
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(overlay.queue_free)

func defeat():
	state = "defeat"
	show_message("You were defeated...")
	GameManager.player_data["hp"] = GameManager.player_data.get("max_hp", 100)
	GameManager.current_enemy = ""
	await get_tree().create_timer(2.0).timeout
	return_to_overworld()

func return_to_overworld():
	GameManager.change_scene("res://scene.tscn")
