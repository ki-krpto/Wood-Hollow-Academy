extends CanvasLayer

const PANEL_LAYER := 10

var sequence: Array = []
var step_index: int = 0
var line_index: int = 0
var player: CharacterBody2D = null
var panel: PanelContainer = null
var name_label: Label = null
var text_label: Label = null
var hint_label: Label = null
var finished: bool = false

func play(steps: Array) -> void:
	sequence = steps
	layer = PANEL_LAYER
	_lock_player()
	_build_ui()
	GameManager.start_dialogue(_all_lines())
	_show_step()

func _all_lines() -> Array[String]:
	var result: Array[String] = []
	for step in sequence:
		var lines: Array = (step as Dictionary).get("lines", [])
		for line in lines:
			result.append(str(line))
	return result

func _lock_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		player.cutscene_lock = true
		player.moving = false
		player.move_dir = Vector2.ZERO
		player.buffered_dir = Vector2.ZERO
		player.move_timer = 0.0
		player.interacting = false

func _unlock_player() -> void:
	if player:
		player.cutscene_lock = false

func _process(_delta: float) -> void:
	if finished:
		return
	if Input.is_action_just_pressed("interact"):
		_advance()

func _advance() -> void:
	line_index += 1
	if line_index < _current_lines().size():
		_show_step()
		return
	line_index = 0
	step_index += 1
	if step_index >= sequence.size():
		_finish()
		return
	_show_step()

func _current_lines() -> Array:
	return (sequence[step_index] as Dictionary).get("lines", [])

func _show_step() -> void:
	var step: Dictionary = sequence[step_index]
	var lines: Array = step.get("lines", [])
	name_label.text = str(step.get("speaker", ""))
	text_label.text = str(lines[line_index])
	if line_index >= lines.size() - 1 and step_index >= sequence.size() - 1:
		hint_label.text = "[E] to close"
	else:
		hint_label.text = "[E] to continue"

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -150
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_bottom = -80
	add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	style.border_color = Color(0.45, 0.32, 0.18, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	vbox.add_child(name_label)

	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(text_label)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	vbox.add_child(hint_label)

func _finish() -> void:
	finished = true
	_unlock_player()
	queue_free()
	GameManager.end_dialogue()
