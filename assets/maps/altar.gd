extends StaticBody2D

@export var scroll_item: String = "The Scroll"

var is_talking: bool = false
var dialogue_lines: Array[String] = []
var current_line: int = 0
var dialogue_ui: CanvasLayer = null
var on_dialogue_done: Callable = Callable()

func _ready() -> void:
	add_to_group("interactables")

func interact() -> void:
	if is_talking:
		_advance_dialogue()
		return
	if GameManager.get_story_flag("got_scroll"):
		_rest()
		return
	_start_legend_dialogue()

func _start_legend_dialogue() -> void:
	dialogue_lines = [
		"The altar's core pulses with a soft golden light as you step close...",
		"A deep voice echoes from the stone: \"So you are the one who found the path.\"",
		"\"This scroll is my last testament. It holds the way through the deep caverns.\"",
		"\"Guard it well, child. The surface cannot be reclaimed without what it describes.\""
	]
	current_line = 0
	on_dialogue_done = _grant_scroll
	is_talking = true
	_show_dialogue_ui()

func _rest() -> void:
	GameManager.player_data["hp"] = GameManager.player_data.get("max_hp", 100)
	GameManager.save_current_slot()
	_show_toast("The altar's warmth washes over you. HP fully restored.")
	GameManager.end_dialogue()

func _grant_scroll() -> void:
	GameManager.add_item(scroll_item)
	GameManager.set_story_flag("got_scroll")
	_show_toast("Obtained: " + scroll_item + "!", scroll_item)

func _advance_dialogue() -> void:
	current_line += 1
	if current_line >= dialogue_lines.size():
		_close_dialogue()
		return
	_update_dialogue_text()

func _close_dialogue() -> void:
	is_talking = false
	if dialogue_ui:
		dialogue_ui.queue_free()
		dialogue_ui = null
	if on_dialogue_done.is_valid():
		var callback: Callable = on_dialogue_done
		on_dialogue_done = Callable()
		callback.call()
	GameManager.end_dialogue()

func _show_dialogue_ui() -> void:
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
	name_label.text = "The Altar"
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

func _update_dialogue_text() -> void:
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

func _show_toast(text: String, item_name: String = "") -> void:
	var toast_ui := CanvasLayer.new()
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

	var item_texture = GameManager.get_item_texture(item_name)
	if item_texture:
		var item_icon = TextureRect.new()
		item_icon.texture = item_texture
		item_icon.custom_minimum_size = Vector2(40, 40)
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hbox.add_child(item_icon)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(toast_ui.queue_free)
