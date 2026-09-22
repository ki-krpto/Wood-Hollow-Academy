extends StaticBody2D

@export var item_name: String = ""
@export var item_count: int = 1
@export var chest_id: String = ""
var opened: bool = false
var chest_key: String = ""
var notification_ui: CanvasLayer = null
var chest_sprite: Sprite2D = null

const CHEST_UNOPENED_TEXTURE: Texture2D = preload("res://assets/img/chestUnopened.png")
const CHEST_OPENED_TEXTURE: Texture2D = preload("res://assets/img/chestOpenend.png")

func _ready() -> void:
	add_to_group("chests")
	if item_name == "":
		item_name = str(get_meta("item_name", "Unknown Item"))
	_build_visual()
	_resolve_chest_key()
	if GameManager.is_chest_opened(chest_key):
		opened = true
		_change_appearance()

func _build_visual() -> void:
	chest_sprite = Sprite2D.new()
	chest_sprite.texture = CHEST_UNOPENED_TEXTURE
	add_child(chest_sprite)

func interact():
	if opened:
		return
	var item_data = GameManager.get_item_data(item_name)
	if item_data.is_empty():
		_show_notification("Found nothing useful...")
		_mark_opened()
		return
	for i in item_count:
		GameManager.add_item(item_name)
	_show_notification("Obtained: " + item_name + " x" + str(item_count) + "!", item_name)
	_mark_opened()

func _change_appearance() -> void:
	if chest_sprite:
		chest_sprite.texture = CHEST_OPENED_TEXTURE

func _show_notification(text: String, item_name: String = ""):
	if notification_ui:
		notification_ui.queue_free()
	notification_ui = CanvasLayer.new()
	notification_ui.layer = 10
	get_tree().current_scene.add_child(notification_ui)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 40
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_bottom = 80
	notification_ui.add_child(panel)

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
	timer.timeout.connect(_remove_notification)

func _remove_notification():
	if notification_ui:
		notification_ui.queue_free()
		notification_ui = null

func _resolve_chest_key() -> void:
	var custom_id := chest_id.strip_edges()
	if not custom_id.is_empty():
		chest_key = custom_id
		return
	var scene_path := ""
	if owner and owner.scene_file_path != "":
		scene_path = owner.scene_file_path
	elif get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
		scene_path = get_tree().current_scene.scene_file_path
	else:
		scene_path = "runtime_scene"
	chest_key = scene_path + ":" + str(get_path())

func _mark_opened() -> void:
	opened = true
	_change_appearance()
	GameManager.mark_chest_opened(chest_key)
