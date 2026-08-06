extends CharacterBody2D

const TILE_SIZE = 32
const SPEED = 100.0
const MOVE_DELAY = 0.1

var moving = false
var target = Vector2.ZERO
var move_dir = Vector2.ZERO
var facing_dir = Vector2.DOWN
var buffered_dir = Vector2.ZERO
var move_timer = 0.0
var move_start = Vector2.ZERO
var move_progress = 0.0
var interacting = false
var current_interactable = null
var cutscene_lock = false
var stats_open = false
var stats_ui: CanvasLayer = null
var selected_slot: int = -1
var inv_slot_panels: Array[PanelContainer] = []
var inv_slot_icons: Array[TextureRect] = []
var desc_name: Label = null
var desc_text: Label = null
var use_button: Button = null
var hp_value_label: Label = null
var pause_open: bool = false
var pause_ui: CanvasLayer = null
var pause_settings_panel: PanelContainer = null
var pause_res_label: Label = null
var pause_fs_label: Label = null
var pause_vol_label: Label = null

func _ready() -> void:
	add_to_group("player")
	MusicManager.play_overworld()
	if GameManager.overworld_position == Vector2.ZERO:
		position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	target = position
	if GameManager.overworld_position != Vector2.ZERO:
		await get_tree().process_frame
		moving = false
		move_dir = Vector2.ZERO
		buffered_dir = Vector2.ZERO
		move_progress = 0.0
		move_timer = 0.0
		interacting = false
		stats_open = false
		position = GameManager.overworld_position
		target = GameManager.overworld_position
		var cam := get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.position = Vector2(50, -274)
			cam.zoom = Vector2(1.7, 1.7)

func _physics_process(delta: float) -> void:
	if cutscene_lock:
		return

	if Input.is_action_just_pressed("pause_menu"):
		_toggle_pause()
		return

	if pause_open:
		return

	if Input.is_action_just_pressed("stats_menu"):
		_toggle_stats()
		return

	if stats_open:
		return

	if interacting:
		if Input.is_action_just_pressed("interact"):
			_advance_current_interaction()
		return

	move_timer = max(move_timer - delta, 0.0)

	if GameManager.current_enemy:
		return

	if Input.is_action_just_pressed("interact"):
		_try_interact()
		return

	var held = Vector2.ZERO
	if Input.is_action_pressed("right"):
		held = Vector2.RIGHT
	elif Input.is_action_pressed("left"):
		held = Vector2.LEFT
	elif Input.is_action_pressed("up"):
		held = Vector2.UP
	elif Input.is_action_pressed("down"):
		held = Vector2.DOWN

	if moving:
		var tapped = Vector2.ZERO
		if Input.is_action_just_pressed("right"):
			tapped = Vector2.RIGHT
		elif Input.is_action_just_pressed("left"):
			tapped = Vector2.LEFT
		elif Input.is_action_just_pressed("up"):
			tapped = Vector2.UP
		elif Input.is_action_just_pressed("down"):
			tapped = Vector2.DOWN

		if tapped != Vector2.ZERO:
			buffered_dir = tapped

		move_progress += delta * (SPEED / TILE_SIZE)
		if move_progress >= 1.0:
			position = target
			GameManager.overworld_position = position
			moving = false
			move_timer = MOVE_DELAY
		else:
			var eased = _ease_in_out(move_progress)
			var desired = move_start.lerp(target, eased)
			var step = desired - position
			if move_and_collide(step):
				moving = false
				move_dir = Vector2.ZERO
				buffered_dir = Vector2.ZERO
				move_timer = MOVE_DELAY

	if not moving and move_timer <= 0.0:
		var next = Vector2.ZERO

		if buffered_dir != Vector2.ZERO:
			next = buffered_dir
			buffered_dir = Vector2.ZERO
		elif held != Vector2.ZERO:
			next = held

		if next != Vector2.ZERO:
			facing_dir = next
			var collision = move_and_collide(next * TILE_SIZE, true)
			if not collision:
				move_dir = next
				target = position + move_dir * TILE_SIZE
				move_start = position
				move_progress = 0.0
				moving = true
			else:
				var collider = collision.get_collider()
				if collider and collider.is_in_group("enemies"):
					var raw_id = collider.get("enemy_id")
					var enemy_id: String = "Pollutabloom" if raw_id == null else str(raw_id)
					_start_battle_transition(enemy_id, collider)
				move_dir = Vector2.ZERO

func _try_interact() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var player_shape := col.shape as RectangleShape2D
	var player_rect := Rect2(col.global_position - player_shape.size * 0.5, player_shape.size)
	var closest_body: Node2D = null
	var closest_dist: float = TILE_SIZE * 1.5

	for npc in get_tree().get_nodes_in_group("npcs"):
		var gap := _interact_gap(npc, player_rect)
		if gap < closest_dist:
			closest_dist = gap
			closest_body = npc

	for chest in get_tree().get_nodes_in_group("chests"):
		var gap := _interact_gap(chest, player_rect)
		if gap < closest_dist:
			closest_dist = gap
			closest_body = chest

	for interactable in get_tree().get_nodes_in_group("interactables"):
		var gap := _interact_gap(interactable, player_rect)
		if gap < closest_dist:
			closest_dist = gap
			closest_body = interactable

	if closest_body:
		interacting = true
		current_interactable = closest_body
		closest_body.interact()
		if closest_body.is_in_group("npcs") or closest_body.is_in_group("interactables"):
			await GameManager.dialogue_finished
		else:
			await get_tree().create_timer(1.5).timeout
		interacting = false
		current_interactable = null

func _interact_gap(body: Node2D, player_rect: Rect2) -> float:
	var body_col := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_col == null:
		return INF
	var body_shape := body_col.shape as RectangleShape2D
	if body_shape == null:
		return INF
	var body_rect := Rect2(body_col.global_position - body_shape.size * 0.5, body_shape.size)
	if player_rect.intersects(body_rect):
		return 0.0
	var dx := maxf(0.0, maxf(player_rect.position.x - body_rect.end.x, body_rect.position.x - player_rect.end.x))
	var dy := maxf(0.0, maxf(player_rect.position.y - body_rect.end.y, body_rect.position.y - player_rect.end.y))
	return Vector2(dx, dy).length()

func _advance_current_interaction() -> void:
	if current_interactable and current_interactable.has_method("interact"):
		current_interactable.interact()

func _start_battle_transition(enemy_id: String, enemy_body: Node2D) -> void:
	interacting = true
	moving = false
	MusicManager.play_battle()

	await get_tree().create_timer(0.5).timeout

	var cam := $Camera2D as Camera2D
	var desired_offset: Vector2 = enemy_body.global_position - global_position

	var overlay := CanvasLayer.new()
	overlay.layer = 20
	get_tree().current_scene.add_child(overlay)

	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	overlay.add_child(fade)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(cam, "position", desired_offset, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(cam, "zoom", Vector2(4.0, 4.0), 0.4).set_delay(0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade, "modulate:a", 1.0, 0.35).set_delay(0.55).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: GameManager.enter_battle(enemy_id))

func _toggle_stats() -> void:
	if stats_open:
		_close_stats()
	else:
		_open_stats()

func _open_stats() -> void:
	stats_open = true
	selected_slot = -1
	inv_slot_panels.clear()
	inv_slot_icons.clear()

	stats_ui = CanvasLayer.new()
	stats_ui.layer = 10
	get_tree().current_scene.add_child(stats_ui)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_ui.add_child(bg)

	var outer_panel := PanelContainer.new()
	outer_panel.set_anchors_preset(Control.PRESET_CENTER)
	outer_panel.offset_left = -320
	outer_panel.offset_top = -220
	outer_panel.offset_right = 320
	outer_panel.offset_bottom = 220
	stats_ui.add_child(outer_panel)

	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	outer_style.border_color = Color(0.45, 0.32, 0.18, 1.0)
	outer_style.set_border_width_all(4)
	outer_style.set_corner_radius_all(6)
	outer_style.set_content_margin_all(12)
	outer_panel.add_theme_stylebox_override("panel", outer_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	outer_panel.add_child(main_vbox)

	var top_hbox := HBoxContainer.new()
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(top_hbox)

	_build_character_panel(top_hbox)
	_build_inventory_panel(top_hbox)

	var bottom_sep := HSeparator.new()
	main_vbox.add_child(bottom_sep)
	_build_description_bar(main_vbox)

	var close_hint := Label.new()
	close_hint.text = "[C] to close"
	close_hint.add_theme_font_size_override("font_size", 11)
	close_hint.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(close_hint)

func _build_character_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(200, 0)
	parent.add_child(panel)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.1, 0.07, 0.9)
	ps.border_color = Color(0.35, 0.25, 0.15, 1.0)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(4)
	ps.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Character"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var pd := GameManager.player_data
	_add_stat_line(vbox, "Name", str(pd.get("name", "???")))
	_add_stat_line(vbox, "Lv.", str(pd.get("level", 1)))

	vbox.add_child(HSeparator.new())

	hp_value_label = _add_stat_line(vbox, "HP", str(pd.get("hp", 0)) + " / " + str(pd.get("max_hp", 100)))
	_add_bar(vbox, float(pd.get("hp", 0)) / float(pd.get("max_hp", 100)), Color(0.8, 0.2, 0.2))

	vbox.add_child(HSeparator.new())

	_add_stat_line(vbox, "STR", str(pd.get("attack", 10)))
	_add_stat_line(vbox, "DEF", str(pd.get("defense", 5)))

	vbox.add_child(HSeparator.new())

	_add_stat_line(vbox, "XP", str(pd.get("xp", 0)) + " / " + str(pd.get("xp_to_next", 100)))
	_add_stat_line(vbox, "Gold", str(pd.get("gold", 0)))

func _add_stat_line(parent: Control, label_text: String, value_text: String) -> Label:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	hbox.add_child(val)
	return val

func _add_bar(parent: Control, pct: float, bar_color: Color) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.13, 0.1, 1.0)
	bg.custom_minimum_size = Vector2(160, 6)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bg)

	var fill := ColorRect.new()
	fill.color = bar_color
	fill.size = Vector2(160 * clampf(pct, 0.0, 1.0), 6)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(fill)

func _build_inventory_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(260, 0)
	parent.add_child(panel)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.1, 0.07, 0.9)
	ps.border_color = Color(0.35, 0.25, 0.15, 1.0)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(4)
	ps.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	var inv := GameManager.get_inventory()
	for i in 16:
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(56, 56)
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(0.08, 0.07, 0.05, 0.8)
		ss.border_color = Color(0.3, 0.22, 0.14, 1.0)
		ss.set_border_width_all(2)
		ss.set_corner_radius_all(3)
		ss.set_content_margin_all(4)
		slot_panel.add_theme_stylebox_override("panel", ss)

		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(44, 44)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL

		if i < inv.size():
			var entry: Dictionary = inv[i]
			var item_texture: Texture2D = GameManager.get_item_texture(entry.get("name", ""))
			icon.texture = item_texture

		slot_panel.add_child(icon)
		grid.add_child(slot_panel)
		inv_slot_panels.append(slot_panel)
		inv_slot_icons.append(icon)

		var idx: int = i
		var btn := Button.new()
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.modulate.a = 0.01
		btn.pressed.connect(_on_slot_pressed.bind(idx))
		slot_panel.add_child(btn)

func _build_description_bar(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 60)
	parent.add_child(panel)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.08, 0.05, 0.9)
	ps.border_color = Color(0.35, 0.25, 0.15, 1.0)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(4)
	ps.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", ps)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var desc_vbox := VBoxContainer.new()
	desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(desc_vbox)

	desc_name = Label.new()
	desc_name.text = "No item selected"
	desc_name.add_theme_font_size_override("font_size", 14)
	desc_name.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	desc_vbox.add_child(desc_name)

	desc_text = Label.new()
	desc_text.text = "Select an item from the grid."
	desc_text.add_theme_font_size_override("font_size", 12)
	desc_text.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_vbox.add_child(desc_text)

	use_button = Button.new()
	use_button.text = "Use"
	use_button.custom_minimum_size = Vector2(70, 30)
	use_button.visible = false
	use_button.pressed.connect(_on_use_pressed)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.45, 0.2, 1.0)
	btn_style.border_color = Color(0.4, 0.7, 0.3, 1.0)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(4)
	use_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.3, 0.55, 0.25, 1.0)
	btn_hover.border_color = Color(0.5, 0.8, 0.4, 1.0)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(4)
	btn_hover.set_content_margin_all(4)
	use_button.add_theme_stylebox_override("hover", btn_hover)

	use_button.add_theme_font_size_override("font_size", 13)
	use_button.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(use_button)

func _on_slot_pressed(index: int) -> void:
	var inv := GameManager.get_inventory()
	if index >= inv.size():
		selected_slot = -1
		desc_name.text = "No item selected"
		desc_text.text = "Select an item from the grid."
		use_button.visible = false
		return

	selected_slot = index
	var entry: Dictionary = inv[index]
	var item_name: String = entry.get("name", "???")
	var item_data: Dictionary = GameManager.get_item_data(item_name)

	desc_name.text = item_name + "  x" + str(entry.get("count", 1))
	desc_text.text = item_data.get("description", "No description.")

	var item_type: String = item_data.get("type", "")
	use_button.visible = item_type == "healing"

	for i in inv_slot_panels.size():
		var ss: StyleBoxFlat = inv_slot_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		if ss:
			if i == index:
				ss.border_color = Color(0.9, 0.8, 0.4, 1.0)
			else:
				ss.border_color = Color(0.3, 0.22, 0.14, 1.0)

func _on_use_pressed() -> void:
	if selected_slot < 0:
		return
	var inv := GameManager.get_inventory()
	if selected_slot >= inv.size():
		return
	var entry: Dictionary = inv[selected_slot]
	var item_name: String = entry.get("name", "")
	var item_data: Dictionary = GameManager.get_item_data(item_name)
	if item_data.get("type", "") != "healing":
		return

	var heal_amount: int = item_data.get("value", 0)
	GameManager.use_item(item_name)

	_refresh_inventory_grid()
	_refresh_stats_display()

	var new_inv := GameManager.get_inventory()
	if selected_slot >= new_inv.size():
		selected_slot = -1
		desc_name.text = "No item selected"
		desc_text.text = "Select an item from the grid."
		use_button.visible = false
	else:
		_on_slot_pressed(selected_slot)

func _refresh_inventory_grid() -> void:
	var inv := GameManager.get_inventory()
	for i in 16:
		if i >= inv_slot_icons.size():
			break
		var icon: TextureRect = inv_slot_icons[i]
		var panel: PanelContainer = inv_slot_panels[i]
		if i < inv.size():
			var entry: Dictionary = inv[i]
			icon.texture = GameManager.get_item_texture(entry.get("name", ""))
		else:
			icon.texture = null
		var ss: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if ss:
			ss.bg_color = Color(0.08, 0.07, 0.05, 0.8)

func _refresh_stats_display() -> void:
	var pd := GameManager.player_data
	if hp_value_label:
		hp_value_label.text = str(pd.get("hp", 0)) + " / " + str(pd.get("max_hp", 100))

func _close_stats() -> void:
	stats_open = false
	selected_slot = -1
	if stats_ui:
		stats_ui.queue_free()
		stats_ui = null

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _toggle_pause() -> void:
	if pause_open:
		_close_pause()
	else:
		_open_pause()

func _open_pause() -> void:
	pause_open = true
	moving = false
	move_dir = Vector2.ZERO
	buffered_dir = Vector2.ZERO

	pause_ui = CanvasLayer.new()
	pause_ui.layer = 15
	get_tree().current_scene.add_child(pause_ui)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(bg)

	var outer_panel := PanelContainer.new()
	outer_panel.set_anchors_preset(Control.PRESET_CENTER)
	outer_panel.offset_left = -160
	outer_panel.offset_top = -140
	outer_panel.offset_right = 160
	outer_panel.offset_bottom = 140
	pause_ui.add_child(outer_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	style.border_color = Color(0.45, 0.32, 0.18, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	outer_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	outer_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(200, 36)
	resume_btn.focus_mode = Control.FOCUS_NONE
	resume_btn.pressed.connect(_close_pause)
	vbox.add_child(resume_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(200, 36)
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.pressed.connect(_open_pause_settings)
	vbox.add_child(settings_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(200, 36)
	quit_btn.focus_mode = Control.FOCUS_NONE
	quit_btn.pressed.connect(_quit_to_menu)
	vbox.add_child(quit_btn)

	pause_settings_panel = null

func _close_pause() -> void:
	pause_open = false
	if pause_ui:
		pause_ui.queue_free()
		pause_ui = null
	pause_settings_panel = null

func _open_pause_settings() -> void:
	if pause_ui:
		pause_ui.queue_free()
		pause_ui = null

	pause_ui = CanvasLayer.new()
	pause_ui.layer = 15
	get_tree().current_scene.add_child(pause_ui)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(bg)

	pause_settings_panel = PanelContainer.new()
	pause_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_settings_panel.offset_left = -200
	pause_settings_panel.offset_top = -160
	pause_settings_panel.offset_right = 200
	pause_settings_panel.offset_bottom = 160
	pause_ui.add_child(pause_settings_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	style.border_color = Color(0.45, 0.32, 0.18, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	pause_settings_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	pause_settings_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 12)
	vbox.add_child(res_row)

	var res_title := Label.new()
	res_title.text = "Resolution"
	res_title.add_theme_font_size_override("font_size", 15)
	res_title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	res_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(res_title)

	var res_left := Button.new()
	res_left.text = "<"
	res_left.custom_minimum_size = Vector2(36, 28)
	res_left.focus_mode = Control.FOCUS_NONE
	res_left.pressed.connect(_on_pause_res_left)
	res_row.add_child(res_left)

	pause_res_label = Label.new()
	pause_res_label.text = ScreenManager.get_resolution_text()
	pause_res_label.add_theme_font_size_override("font_size", 15)
	pause_res_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	pause_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_res_label.custom_minimum_size = Vector2(120, 0)
	res_row.add_child(pause_res_label)

	var res_right := Button.new()
	res_right.text = ">"
	res_right.custom_minimum_size = Vector2(36, 28)
	res_right.focus_mode = Control.FOCUS_NONE
	res_right.pressed.connect(_on_pause_res_right)
	res_row.add_child(res_right)

	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	vbox.add_child(fs_row)

	var fs_title := Label.new()
	fs_title.text = "Fullscreen"
	fs_title.add_theme_font_size_override("font_size", 15)
	fs_title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	fs_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_title)

	var fs_left := Button.new()
	fs_left.text = "<"
	fs_left.custom_minimum_size = Vector2(36, 28)
	fs_left.focus_mode = Control.FOCUS_NONE
	fs_left.pressed.connect(_on_pause_fs_left)
	fs_row.add_child(fs_left)

	pause_fs_label = Label.new()
	pause_fs_label.text = "On" if ScreenManager.fullscreen else "Off"
	pause_fs_label.add_theme_font_size_override("font_size", 15)
	pause_fs_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	pause_fs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_fs_label.custom_minimum_size = Vector2(120, 0)
	fs_row.add_child(pause_fs_label)

	var fs_right := Button.new()
	fs_right.text = ">"
	fs_right.custom_minimum_size = Vector2(36, 28)
	fs_right.focus_mode = Control.FOCUS_NONE
	fs_right.pressed.connect(_on_pause_fs_right)
	fs_row.add_child(fs_right)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	vbox.add_child(vol_row)

	var vol_title := Label.new()
	vol_title.text = "Music"
	vol_title.add_theme_font_size_override("font_size", 15)
	vol_title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	vol_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_row.add_child(vol_title)

	var vol_slider := HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = MusicManager.music_volume
	vol_slider.custom_minimum_size = Vector2(140, 0)
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.focus_mode = Control.FOCUS_NONE
	vol_row.add_child(vol_slider)

	pause_vol_label = Label.new()
	pause_vol_label.text = str(int(MusicManager.music_volume * 100)) + "%"
	pause_vol_label.add_theme_font_size_override("font_size", 15)
	pause_vol_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	pause_vol_label.custom_minimum_size = Vector2(40, 0)
	vol_row.add_child(pause_vol_label)

	vol_slider.value_changed.connect(_on_pause_vol_changed)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 32)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_close_pause_settings)
	btn_row.add_child(back_btn)

func _close_pause_settings() -> void:
	_close_pause()
	_open_pause()

func _on_pause_res_left() -> void:
	ScreenManager.cycle_resolution(-1)
	pause_res_label.text = ScreenManager.get_resolution_text()

func _on_pause_res_right() -> void:
	ScreenManager.cycle_resolution(1)
	pause_res_label.text = ScreenManager.get_resolution_text()

func _on_pause_fs_left() -> void:
	ScreenManager.fullscreen = not ScreenManager.fullscreen
	ScreenManager.apply_settings()
	ScreenManager.save_settings()
	pause_fs_label.text = "On" if ScreenManager.fullscreen else "Off"

func _on_pause_fs_right() -> void:
	ScreenManager.fullscreen = not ScreenManager.fullscreen
	ScreenManager.apply_settings()
	ScreenManager.save_settings()
	pause_fs_label.text = "On" if ScreenManager.fullscreen else "Off"

func _on_pause_vol_changed(value: float) -> void:
	MusicManager.set_volume(value)
	pause_vol_label.text = str(int(value * 100)) + "%"

func _quit_to_menu() -> void:
	pause_open = false
	if pause_ui:
		pause_ui.queue_free()
		pause_ui = null
	GameManager.overworld_position = position
	GameManager.save_current_slot()
	GameManager.change_scene("res://main_menu.tscn")
