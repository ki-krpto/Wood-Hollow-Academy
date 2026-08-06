extends StaticBody2D

@export var dialogue_text: String = ""
@export var display_name: String = ""
var dialogue_lines: PackedStringArray = PackedStringArray()
var is_talking: bool = false
var current_line: int = 0
var dialogue_ui: CanvasLayer = null

func _ready():
	add_to_group("npcs")
	var raw = dialogue_text if dialogue_text != "" else str(get_meta("dialogue", ""))
	dialogue_lines = raw.split("|")
	for i in dialogue_lines.size():
		dialogue_lines[i] = dialogue_lines[i].strip_edges()

func interact():
	if is_talking:
		_advance_dialogue()
		return
	if dialogue_lines.is_empty():
		return
	is_talking = true
	current_line = 0
	_show_dialogue_ui()

func _advance_dialogue():
	current_line += 1
	if current_line >= dialogue_lines.size():
		_close_dialogue()
		return
	_update_dialogue_text()

func _show_dialogue_ui():
	dialogue_ui = CanvasLayer.new()
	dialogue_ui.layer = 10
	get_tree().current_scene.add_child(dialogue_ui)

	var panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -150
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_bottom = -80
	dialogue_ui.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	style.border_color = Color(0.45, 0.32, 0.18, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.name = "DialogueVBox"
	panel.add_child(vbox)

	var name_label = Label.new()
	name_label.text = display_name if display_name != "" else "Vivi"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	vbox.add_child(name_label)

	var text_label = Label.new()
	text_label.name = "TextLabel"
	text_label.text = dialogue_lines[0]
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(text_label)

	var hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "[E] to continue"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	vbox.add_child(hint_label)

func _update_dialogue_text():
	if dialogue_ui == null:
		return
	var text_label = dialogue_ui.get_node_or_null("DialoguePanel/DialogueVBox/TextLabel")
	var hint_label = dialogue_ui.get_node_or_null("DialoguePanel/DialogueVBox/HintLabel")
	if text_label:
		text_label.text = dialogue_lines[current_line]
	if hint_label:
		if current_line >= dialogue_lines.size() - 1:
			hint_label.text = "[E] to close"
		else:
			hint_label.text = "[E] to continue"

func _close_dialogue():
	is_talking = false
	if dialogue_ui:
		dialogue_ui.queue_free()
		dialogue_ui = null
	GameManager.end_dialogue()
