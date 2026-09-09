extends StaticBody2D

@export var required_items: Array[String] = ["The Scroll"]
@export var hint_message: String = "A heavy gate bars the way..."

var opened: bool = false
var toast_ui: CanvasLayer = null
var _last_hint_ms: int = -10000

func _ready() -> void:
	add_to_group("gates")
	GameManager.inventory_changed.connect(_check_should_open)
	_check_should_open()

func _check_should_open() -> void:
	if opened:
		return
	if _meets_requirements():
		open_gate()

func _meets_requirements() -> bool:
	if required_items.is_empty():
		return true
	for item_name in required_items:
		if not GameManager.has_item(item_name):
			return false
	return true

func open_gate() -> void:
	if opened:
		return
	opened = true
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)
	var visual := get_node_or_null("Visual")
	if visual:
		visual.visible = false
	show_toast("The gate grinds open!")

func on_blocked() -> void:
	if opened:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hint_ms < 2500:
		return
	_last_hint_ms = now
	show_toast(hint_message)

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
