extends StaticBody2D

@export_group("Items")
@export var required_items: Array[String] = ["The Scroll"]
@export_group("Enemies")
## Enemy types that must be defeated before this gate opens.
## e.g. ["Cave Spider", "Limestone Golem"]
@export var required_enemies: Array[String] = []
## Spawn Ids of specific enemy instances that must be defeated. Copy-pasted
## enemies share the same enemy_id, so give the exact enemy a unique Spawn Id
## (in its Inspector) and list it here to target that one enemy.
@export var required_spawn_ids: Array[String] = []
## Kills of the required_enemies types needed per entry. Empty/0 for each
## entry means "defeat that enemy type once". Use with kill_count below
## for a simple "defeat N enemies" gate instead.
@export var required_enemy_counts: Array[int] = []
## Total kills needed across all enemies (or of required_enemies types if
## non-empty). 0 disables this check. Great for dungeon kill counters.
@export var kill_count: int = 0
@export_group("Behavior")
## Optional stable id so the opened state persists across save/load and
## re-entering the room. Leave empty to use the node path instead.
@export var gate_id: String = ""
@export var hint_message: String = "A heavy gate bars the way..."
@export var open_message: String = "The gate grinds open!"

var opened: bool = false
var toast_ui: CanvasLayer = null
var _last_hint_ms: int = -10000

func _ready() -> void:
	add_to_group("gates")
	GameManager.enemy_defeated.connect(_on_enemy_defeated)
	_check_should_open(false)

func _on_enemy_defeated(_enemy_id: String, _enemy_key: String) -> void:
	_check_should_open(true)

func _check_should_open(announce: bool = true) -> void:
	if opened:
		return
	if _meets_requirements():
		open_gate(announce)

func _meets_requirements() -> bool:
	if not _items_met():
		return false
	if not _enemy_requirements_met():
		return false
	return true

func _items_met() -> bool:
	if required_items.is_empty():
		return true
	for item_name in required_items:
		if not GameManager.has_item(item_name):
			return false
	return true

func _enemy_requirements_met() -> bool:
	for spawn_id in required_spawn_ids:
		if not GameManager.defeated_enemies.has(spawn_id):
			return false
	for i in required_enemies.size():
		var needed := 1
		if i < required_enemy_counts.size() and required_enemy_counts[i] > 0:
			needed = required_enemy_counts[i]
		if GameManager.enemy_defeat_count(required_enemies[i]) < needed:
			return false
	if kill_count > 0:
		if required_enemies.is_empty():
			if GameManager.total_enemy_defeats() < kill_count:
				return false
		else:
			var type_total := 0
			for enemy_type in required_enemies:
				type_total += GameManager.enemy_defeat_count(enemy_type)
			if type_total < kill_count:
				return false
	return true

func _missing_requirement_text() -> String:
	if not _items_met():
		var missing_text := ""
		for item_name in required_items:
			if not GameManager.has_item(item_name):
				if missing_text.is_empty():
					missing_text = item_name
				else:
					missing_text += ", " + item_name
		return "It needs: " + missing_text + "."
	for spawn_id in required_spawn_ids:
		if not GameManager.defeated_enemies.has(spawn_id):
			return "Slay the " + spawn_id + " first."
	for i in required_enemies.size():
		var needed := 1
		if i < required_enemy_counts.size() and required_enemy_counts[i] > 0:
			needed = required_enemy_counts[i]
		var have := GameManager.enemy_defeat_count(required_enemies[i])
		if have < needed:
			return "Slay %s (%d/%d) first." % [required_enemies[i], have, needed]
	if kill_count > 0:
		var have_kills := 0
		if required_enemies.is_empty():
			have_kills = GameManager.total_enemy_defeats()
		else:
			for enemy_type in required_enemies:
				have_kills += GameManager.enemy_defeat_count(enemy_type)
		return "Slay %d enemies (%d/%d) first." % [kill_count, mini(have_kills, kill_count), kill_count]
	return hint_message

func open_gate(announce: bool = true) -> void:
	if opened:
		return
	opened = true
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)
	var visual := get_node_or_null("Visual")
	if visual:
		visual.visible = false
	if announce:
		show_toast(open_message)

func on_blocked() -> void:
	if opened:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hint_ms < 2500:
		return
	_last_hint_ms = now
	show_toast(_missing_requirement_text())

func show_toast(text: String) -> void:
	if toast_ui:
		toast_ui.queue_free()
	toast_ui = CanvasLayer.new()
	toast_ui.layer = 10
	get_tree().current_scene.add_child(toast_ui)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 40
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_bottom = 80
	toast_ui.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	style.border_color = Color(0.45, 0.32, 0.18, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(_remove_toast)

func _remove_toast() -> void:
	if toast_ui:
		toast_ui.queue_free()
		toast_ui = null
