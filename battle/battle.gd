extends Control

const COLOR_WHITE := Color(1, 1, 1, 1)
const COLOR_DARK_BLUE := Color(0.08, 0.08, 0.28, 1)
const COLOR_WOOD_BASE := Color(0.47, 0.31, 0.16, 1)
const COLOR_WOOD_DARK := Color(0.31, 0.2, 0.08, 1)
const COLOR_WOOD_LIGHT := Color(0.62, 0.47, 0.24, 1)
const COLOR_WOOD_CIRCLE := Color(0.55, 0.39, 0.22, 1)
const COLOR_WOOD_GRID := Color(0.4, 0.29, 0.16, 1)
const COLOR_HP_GOOD := Color(0.2, 0.95, 0.35, 1)
const COLOR_HP_WARN := Color(1.0, 0.85, 0.2, 1)
const COLOR_HP_DANGER := Color(0.95, 0.25, 0.25, 1)

var enemy_data: Dictionary = {}
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_attack_buff: int = 0
var player_attack_buff: int = 0
var player_poison_turns: int = 0

var enemy_poison_turns: int = 0
var player_extra_turns: int = 0
var enemy_jolt_turns: int = 0
var enemy_caffeiene_turns: int = 0

var state: String = "player_choice"
var move_selected: String = ""

var message_queue: Array[String] = []
var processing_message: bool = false

var screen_size: Vector2

var bottom_bar_rect: Rect2 = Rect2()
var left_menu_rect: Rect2 = Rect2()
var right_menu_rect: Rect2 = Rect2()
var message_circle_rect: Rect2 = Rect2()
var bg_orbs: Array[Dictionary] = []

@onready var enemy_name_label: Label = $EnemyName
@onready var enemy_hp_label: Label = $EnemyHPLabel
@onready var enemy_hp_bar: ColorRect = $EnemyHPBar
@onready var enemy_sprite: Sprite2D = $EnemySprite
@onready var bottom_bar: ColorRect = $BottomBar
@onready var bottom_bar_border: Panel = $BottomBarBorder
@onready var center_emblem: Panel = $CenterEmblem
@onready var ring1: Panel = $CenterEmblem/Ring1
@onready var ring2: Panel = $CenterEmblem/Ring2
@onready var ring3: Panel = $CenterEmblem/Ring3
@onready var ring4: Panel = $CenterEmblem/Ring4
@onready var right_panel_bg: Panel = $RightPanelBg
@onready var player_name_label: Label = $PlayerNameLabel
@onready var player_hp_label: Label = $PlayerHPLabel
@onready var player_hp_bar: ColorRect = $PlayerHPBar
@onready var player_detail_label: Label = $PlayerDetailLabel
@onready var btn_fight: Button = $BtnFight
@onready var btn_items: Button = $BtnItems
@onready var btn_defend: Button = $BtnDefend
@onready var btn_run: Button = $BtnRun
@onready var message_label: Label = $MessageLabel
@onready var orbs_container: Control = $OrbsContainer

func _ready():
	randomize()
	screen_size = size
	if screen_size == Vector2.ZERO:
		screen_size = Vector2(1152, 648)
	load_enemy()
	_create_background_orbs()
	_layout_enemy_display()
	_layout_bottom_bar()
	_layout_action_buttons()
	_layout_message_label()
	_layout_player_info()
	_connect_buttons()
	show_message("A wild " + enemy_data.get("name", "enemy") + " appeared!")

func load_enemy():
	var enemy_name = GameManager.current_enemy
	enemy_data = GameManager.get_enemy_data(enemy_name)
	enemy_data["name"] = enemy_name
	enemy_hp = enemy_data.get("hp", 50)
	enemy_max_hp = enemy_hp

func _create_background_orbs():
	bg_orbs.clear()
	var battle_area_height = screen_size.y * 0.7
	for x in range(0, int(screen_size.x), 40):
		for y in range(0, int(battle_area_height), 40):
			var orb = Panel.new()
			orb.size = Vector2(24, 24)
			orb.position = Vector2(x + 8, y + 8)
			var orb_style = StyleBoxFlat.new()
			var tone = float((x + y) % 120) / 120.0
			orb_style.bg_color = Color(0.16 + tone * 0.2, 0.16 + tone * 0.2, 0.46 + tone * 0.3, 0.34)
			orb_style.set_corner_radius_all(32)
			orb.add_theme_stylebox_override("panel", orb_style)
			orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			orbs_container.add_child(orb)
			bg_orbs.append({
				"node": orb,
				"phase": randf_range(0.0, TAU)
			})

func _process(_delta):
	var t = Time.get_ticks_msec() / 1000.0
	for orb_data in bg_orbs:
		var orb_node: Panel = orb_data["node"]
		var phase: float = orb_data["phase"]
		orb_node.modulate.a = 0.2 + 0.3 * (0.5 + 0.5 * sin(t * 1.8 + phase))

func _layout_enemy_display():
	enemy_name_label.text = enemy_data.get("name", "???")
	enemy_name_label.position = Vector2(screen_size.x * 0.5 - 100, screen_size.y * 0.06)
	enemy_name_label.size = Vector2(200, 30)

	enemy_hp_label.text = "HP: " + str(enemy_hp) + "/" + str(enemy_max_hp)
	enemy_hp_label.position = Vector2(screen_size.x * 0.5 - 130, screen_size.y * 0.33 - 24)
	enemy_hp_label.size = Vector2(260, 20)

	$EnemyHPBarBg.position = Vector2(screen_size.x * 0.5 - 110, screen_size.y * 0.33)
	$EnemyHPBarBg.size = Vector2(220, 20)

	enemy_hp_bar.position = $EnemyHPBarBg.position
	enemy_hp_bar.size = $EnemyHPBarBg.size

	var tex_path = "res://assets/img/" + enemy_data.get("image", "")
	if ResourceLoader.exists(tex_path):
		enemy_sprite.texture = load(tex_path)
	if enemy_data.get("name", "") == "Cave Spider":
		enemy_sprite.scale = Vector2(2, 2)
	enemy_sprite.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.18)

func _layout_bottom_bar():
	var bar_y = screen_size.y * 0.69
	var bar_height = screen_size.y - bar_y
	bottom_bar_rect = Rect2(0, bar_y, screen_size.x, bar_height)
	var panel_padding = 14.0
	var circle_size = min(bar_height - 20.0, 170.0)
	var circle_x = screen_size.x * 0.5 - circle_size * 0.5
	var circle_y = bar_y + (bar_height - circle_size) * 0.5
	message_circle_rect = Rect2(circle_x, circle_y, circle_size, circle_size)
	left_menu_rect = Rect2(
		panel_padding,
		bar_y + 14.0,
		max(180.0, message_circle_rect.position.x - panel_padding * 2.0),
		bar_height - 28.0
	)
	var right_x = message_circle_rect.end.x + panel_padding
	right_menu_rect = Rect2(
		right_x,
		bar_y + 14.0,
		max(180.0, screen_size.x - right_x - panel_padding),
		bar_height - 28.0
	)

	bottom_bar.position = bottom_bar_rect.position
	bottom_bar.size = bottom_bar_rect.size

	bottom_bar_border.position = bottom_bar_rect.position
	bottom_bar_border.size = bottom_bar_rect.size
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = COLOR_WOOD_DARK
	border_style.set_border_width_all(8)
	bottom_bar_border.add_theme_stylebox_override("panel", border_style)

	center_emblem.position = message_circle_rect.position
	center_emblem.size = message_circle_rect.size
	var emblem_style = StyleBoxFlat.new()
	emblem_style.bg_color = COLOR_WOOD_CIRCLE
	emblem_style.border_color = COLOR_WOOD_DARK
	emblem_style.set_border_width_all(7)
	emblem_style.set_corner_radius_all(int(circle_size * 0.5))
	center_emblem.add_theme_stylebox_override("panel", emblem_style)

	var rings := [ring1, ring2, ring3, ring4]
	for i in 4:
		var ring_panel: Panel = rings[i]
		var inset = 10 + i * 14
		ring_panel.position = Vector2(inset, inset)
		var ring_size = Vector2(circle_size - inset * 2, circle_size - inset * 2)
		ring_panel.size = ring_size
		var ring_style = StyleBoxFlat.new()
		ring_style.bg_color = Color(0, 0, 0, 0)
		ring_style.border_color = COLOR_WOOD_GRID
		ring_style.set_border_width_all(2)
		ring_style.set_corner_radius_all(int(ring_size.x * 0.5))
		ring_panel.add_theme_stylebox_override("panel", ring_style)

	right_panel_bg.position = right_menu_rect.position
	right_panel_bg.size = right_menu_rect.size
	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(0.3, 0.2, 0.1, 0.35)
	right_style.border_color = COLOR_WOOD_DARK
	right_style.set_border_width_all(2)
	right_style.set_corner_radius_all(8)
	right_panel_bg.add_theme_stylebox_override("panel", right_style)

func _layout_player_info():
	player_name_label.text = GameManager.player_data.get("name", "Kara")
	player_name_label.position = Vector2(right_menu_rect.position.x + 14, right_menu_rect.position.y + 10)

	player_hp_label.text = "HP: " + str(GameManager.player_data.get("hp", 0)) + "/" + str(GameManager.player_data.get("max_hp", 100))
	player_hp_label.position = Vector2(right_menu_rect.position.x + 14, right_menu_rect.position.y + 36)

	$PlayerHPBarBg.position = Vector2(right_menu_rect.position.x + 14, right_menu_rect.position.y + 56)
	$PlayerHPBarBg.size = Vector2(200, 14)

	player_hp_bar.position = $PlayerHPBarBg.position
	var player_pct = float(GameManager.player_data.get("hp", 0)) / float(GameManager.player_data.get("max_hp", 100))
	player_hp_bar.size = Vector2(200 * player_pct, 14)

	player_detail_label.text = "LV." + str(GameManager.player_data.get("level", 1)) + "\nATK: " + str(GameManager.player_data.get("attack", 10)) + "\nDEF: " + str(GameManager.player_data.get("defense", 5))
	player_detail_label.position = Vector2(right_menu_rect.position.x + 230, right_menu_rect.position.y + 12)

func apply_wood_button_style(btn: Button):
	var normal = StyleBoxFlat.new()
	normal.bg_color = COLOR_WOOD_BASE
	normal.border_color = COLOR_WOOD_DARK
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = COLOR_WOOD_LIGHT
	hover.border_color = COLOR_WOOD_DARK
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.4, 0.26, 0.12, 1)
	pressed.border_color = COLOR_WOOD_DARK
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", COLOR_WHITE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	btn.focus_mode = Control.FOCUS_NONE

func _layout_action_buttons():
	var btn_w = left_menu_rect.size.x
	var btn_h = 38
	var gap = 8
	var start_x = left_menu_rect.position.x
	var start_y = left_menu_rect.position.y + 8

	var buttons := [btn_fight, btn_items, btn_defend, btn_run]
	for i in buttons.size():
		var btn: Button = buttons[i]
		btn.position = Vector2(start_x, start_y + i * (btn_h + gap))
		btn.size = Vector2(btn_w, btn_h)
		apply_wood_button_style(btn)

func _layout_message_label():
	message_label.position = Vector2(message_circle_rect.position.x + 14, message_circle_rect.position.y + 16)
	message_label.size = Vector2(message_circle_rect.size.x - 28, message_circle_rect.size.y - 32)

func _connect_buttons():
	btn_fight.pressed.connect(_on_action_pressed.bind("fight"))
	btn_items.pressed.connect(_on_action_pressed.bind("items"))
	btn_defend.pressed.connect(_on_action_pressed.bind("defend"))
	btn_run.pressed.connect(_on_action_pressed.bind("run"))

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
	var btn_x = left_menu_rect.position.x
	var btn_y = left_menu_rect.position.y + 8
	var btn_w = left_menu_rect.size.x
	var btn_h = 34
	var row_gap = 6

	for move_name in moves:
		var btn = Button.new()
		btn.text = move_name
		btn.position = Vector2(btn_x, btn_y)
		btn.size = Vector2(btn_w, btn_h)
		btn.name = "MoveBtn_" + move_name
		apply_wood_button_style(btn)
		btn.pressed.connect(_on_move_selected.bind(move_name))
		add_child(btn)
		btn_y += btn_h + row_gap
		if btn_y > left_menu_rect.end.y - 80:
			break

	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(btn_x, left_menu_rect.end.y - 44)
	back_btn.size = Vector2(btn_w, 34)
	back_btn.name = "MoveBtn_Back"
	apply_wood_button_style(back_btn)
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
	var btn_x = right_menu_rect.position.x + 14
	var btn_y = right_menu_rect.position.y + 8
	var btn_w = right_menu_rect.size.x - 28
	var btn_h = 34
	var row_gap = 6
	for entry in usable:
		var btn = Button.new()
		btn.text = entry.get("name", "???") + " x" + str(entry.get("count", 1))
		btn.position = Vector2(btn_x, btn_y)
		btn.size = Vector2(btn_w, btn_h)
		btn.name = "ItemBtn_" + entry.get("name", "")
		var item_texture = GameManager.get_item_texture(entry.get("name", ""))
		if item_texture:
			btn.icon = item_texture
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_constant_override("icon_max_width", 28)
		apply_wood_button_style(btn)
		btn.pressed.connect(_on_item_selected.bind(entry.get("name", "")))
		add_child(btn)
		btn_y += btn_h + row_gap
		if btn_y > right_menu_rect.end.y - 80:
			break
	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(btn_x, right_menu_rect.end.y - 44)
	back_btn.size = Vector2(btn_w, 34)
	back_btn.name = "ItemBtn_Back"
	apply_wood_button_style(back_btn)
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
		if item_data.get("attribute") == "status_effect":
			var effect_name = str(item_data.get("effect", ""))
			var effect_data = GameManager.get_magic_effect_data(effect_name)
			var effect_turns = int(item_data.get("turns", effect_data.get("default_turns", 3)))
			_apply_enemy_magic_effect(effect_name, effect_turns)
			await get_tree().create_timer(1.0).timeout
			execute_enemy_turn(1.0)
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
	var wait_time := 1.0
	var attack_count := 1
	var skip_attack := false
	var caffeiene_active := enemy_caffeiene_turns > 0
	var caffeiene_data := {}

	if enemy_jolt_turns > 0:
		var jolt_data = GameManager.get_magic_effect_data("jolt")
		var jolt_dmg = max(1, int(enemy_max_hp * float(jolt_data.get("self_damage_pct", 0.08))))
		enemy_hp = max(0, enemy_hp - jolt_dmg)
		update_enemy_hp_bar()
		enemy_jolt_turns -= 1
		spawn_magic_particles("jolt")
		show_message(str(jolt_data.get("damage_message", enemy_data.get("name", "Enemy") + " jolts violently and takes " + str(jolt_dmg) + " damage!")).replace("{enemy}", enemy_data.get("name", "Enemy")).replace("{damage}", str(jolt_dmg)))
		await get_tree().create_timer(float(jolt_data.get("damage_delay", 0.8))).timeout
		if enemy_hp <= 0:
			victory()
			return
		var jolt_roll = randf()
		var skip_chance = float(jolt_data.get("skip_attack_chance", 0.3))
		var double_chance = float(jolt_data.get("double_attack_chance", 0.25))
		if jolt_roll < skip_chance:
			skip_attack = true
			show_message(str(jolt_data.get("skip_message", enemy_data.get("name", "Enemy") + " is too jittery to act!")).replace("{enemy}", enemy_data.get("name", "Enemy")))
			await get_tree().create_timer(float(jolt_data.get("skip_delay", 0.8))).timeout
		elif jolt_roll < skip_chance + double_chance:
			attack_count = 2
			show_message(str(jolt_data.get("double_message", enemy_data.get("name", "Enemy") + " jolts into a second attack!")).replace("{enemy}", enemy_data.get("name", "Enemy")))
			await get_tree().create_timer(float(jolt_data.get("double_delay", 0.6))).timeout

	if caffeiene_active:
		caffeiene_data = GameManager.get_magic_effect_data("caffeiene")
		enemy_caffeiene_turns -= 1
		wait_time = float(caffeiene_data.get("turn_delay", 0.55))
		if not skip_attack:
			show_message(str(caffeiene_data.get("start_message", enemy_data.get("name", "Enemy") + " is caffeiened and moving fast!")).replace("{enemy}", enemy_data.get("name", "Enemy")))
			await get_tree().create_timer(float(caffeiene_data.get("start_delay", 0.45))).timeout
			if attack_count < 2 and randf() < float(caffeiene_data.get("double_attack_chance", 0.35)):
				attack_count = 2

	if not skip_attack:
		for i in attack_count:
			_execute_single_enemy_attack(damage_mult)
			if GameManager.player_data.get("hp", 0) <= 0:
				defeat()
				return
			if i < attack_count - 1:
				var followup_delay = 0.35
				if caffeiene_active:
					followup_delay = float(caffeiene_data.get("followup_delay", 0.2))
				await get_tree().create_timer(followup_delay).timeout
		await get_tree().create_timer(wait_time).timeout

	if GameManager.player_data.get("hp", 0) <= 0:
		defeat()
		return

	if player_poison_turns > 0:
		execute_poison_tick()
		return

	state = "player_choice"
	show_action_buttons()

func _execute_single_enemy_attack(damage_mult: float) -> void:
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

func _apply_enemy_magic_effect(effect_name: String, turns: int) -> void:
	var effect_data = GameManager.get_magic_effect_data(effect_name)
	var applied_turns = max(1, turns)
	if effect_data.has("default_turns"):
		applied_turns = max(1, turns if turns > 0 else int(effect_data.get("default_turns", 3)))
	match effect_name:
		"jolt":
			enemy_jolt_turns += applied_turns
			spawn_magic_particles("jolt")
			show_message(str(effect_data.get("apply_message", "Used Jolt! Enemy is jittery, unstable, and taking shock damage.")).replace("{turns}", str(applied_turns)))
		"caffeiene":
			enemy_caffeiene_turns += applied_turns
			spawn_magic_particles("caffeiene")
			show_message(str(effect_data.get("apply_message", "Used Caffeiene! Enemy goes hyper and attacks rapidly.")).replace("{turns}", str(applied_turns)))
		_:
			show_message("Used item, but nothing happened.")

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
	spawn_magic_particles("poison")
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
			"lower_attack":
				if is_player:
					player_attack_buff -= 5
					show_message("Your attack was lowered!")
				else:
					enemy_attack_buff -= 3
					show_message(enemy_data.get("name", "Enemy") + " weakened!")
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
					spawn_magic_particles("poison")
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
	if enemy_hp_bar:
		var pct = float(enemy_hp) / float(enemy_max_hp)
		enemy_hp_bar.size.x = 220 * pct
		if pct < 0.25:
			enemy_hp_bar.color = COLOR_HP_DANGER
		elif pct < 0.5:
			enemy_hp_bar.color = COLOR_HP_WARN
		else:
			enemy_hp_bar.color = COLOR_HP_GOOD
	if enemy_hp_label:
		enemy_hp_label.text = "HP: " + str(enemy_hp) + "/" + str(enemy_max_hp)

func update_player_hp_bar():
	if player_hp_bar:
		var max_hp = GameManager.player_data.get("max_hp", 100)
		var hp = GameManager.player_data.get("hp", 0)
		var pct = float(hp) / float(max_hp)
		player_hp_bar.size.x = 200 * pct
		if pct < 0.25:
			player_hp_bar.color = COLOR_HP_DANGER
		elif pct < 0.5:
			player_hp_bar.color = COLOR_HP_WARN
		else:
			player_hp_bar.color = COLOR_HP_GOOD
	if player_hp_label:
		player_hp_label.text = "HP: " + str(GameManager.player_data["hp"]) + "/" + str(GameManager.player_data["max_hp"])

func show_message(text: String):
	if message_label:
		message_label.text = text

func spawn_magic_particles(effect_type: String) -> void:
	var particles = CPUParticles2D.new()
	particles.position = enemy_sprite.position
	particles.one_shot = true
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	match effect_type:
		"jolt":
			particles.amount = 30
			particles.lifetime = 0.6
			particles.explosiveness = 0.9
			particles.spread = 180.0
			particles.gravity = Vector2(0, 0)
			particles.initial_velocity_min = 150.0
			particles.initial_velocity_max = 300.0
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 5.0
			particles.color = Color(0.3, 0.8, 1.0, 1.0)
			var ramp = Gradient.new()
			ramp.set_color(0, Color(0.3, 0.8, 1.0, 1.0))
			ramp.set_color(1, Color(1.0, 1.0, 0.4, 0.0))
			particles.color_ramp = ramp
		"caffeiene":
			particles.amount = 25
			particles.lifetime = 0.5
			particles.explosiveness = 0.85
			particles.spread = 60.0
			particles.gravity = Vector2(0, 0)
			particles.initial_velocity_min = 200.0
			particles.initial_velocity_max = 350.0
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.0
			particles.color = Color(1.0, 0.3, 0.1, 1.0)
			var ramp = Gradient.new()
			ramp.set_color(0, Color(1.0, 0.5, 0.1, 1.0))
			ramp.set_color(1, Color(1.0, 0.2, 0.1, 0.0))
			particles.color_ramp = ramp
		"poison":
			particles.amount = 20
			particles.lifetime = 0.8
			particles.explosiveness = 0.7
			particles.spread = 120.0
			particles.gravity = Vector2(0, -40)
			particles.initial_velocity_min = 40.0
			particles.initial_velocity_max = 100.0
			particles.scale_amount_min = 3.0
			particles.scale_amount_max = 7.0
			particles.color = Color(0.4, 0.9, 0.2, 1.0)
			var ramp = Gradient.new()
			ramp.set_color(0, Color(0.4, 0.9, 0.2, 1.0))
			ramp.set_color(1, Color(0.6, 0.1, 0.8, 0.0))
			particles.color_ramp = ramp
	add_child(particles)

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
	GameManager.save_current_slot()
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
	GameManager.save_current_slot()
	await get_tree().create_timer(2.0).timeout
	return_to_overworld()

func return_to_overworld():
	GameManager.change_scene("res://scene.tscn")
