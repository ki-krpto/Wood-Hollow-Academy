extends CanvasLayer

var selected_slot = -1
var hover_slot = -1

const SLOT_POSITIONS = [
	Vector2i(115, 95), Vector2i(160, 95), Vector2i(205, 95), Vector2i(250, 95),
	Vector2i(115, 160), Vector2i(160, 160), Vector2i(205, 160), Vector2i(250, 160)
]
const SLOT_SIZE = Vector2i(35, 45)

@onready var panel_bg = $PanelBg

func _ready():
	visible = false

func _input(event):
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse = get_local_mouse_position()
		for i in range(8):
			var rect = Rect2(SLOT_POSITIONS[i], SLOT_SIZE)
			if rect.has_point(mouse):
				if selected_slot == i:
					selected_slot = -1
				else:
					selected_slot = i
				accept_event()
				return

		if Rect2(245, 255, 35, 20).has_point(mouse):
			use_selected()
			accept_event()
			return
		selected_slot = -1

func _process(_delta):
	if visible:
		update_hover()
		queue_redraw()

func _draw():
	if not visible:
		return

	draw_rect(Rect2(310, 50, 90, 200), Color(0.4, 0.4, 0.4))
	draw_rect(Rect2(50, 75, 250, 150), Color(0.4, 0.4, 0.4))
	draw_rect(Rect2(100, 250, 200, 50), Color(0.4, 0.4, 0.4))

	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(320, 60), "Attack: " + str(PlayerData.attack()), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
	draw_string(font, Vector2(320, 110), "Health: " + str(PlayerData.hp) + "/" + str(PlayerData.max_hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
	draw_string(font, Vector2(320, 160), "XP: " + str(PlayerData.xp) + "/" + str(PlayerData.xp_to_next_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
	draw_string(font, Vector2(320, 210), "Level: " + str(PlayerData.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

	for i in range(8):
		var pos = SLOT_POSITIONS[i]
		var col = Color(0.78, 0.78, 0.78) if i == selected_slot else Color.WHITE
		draw_rect(Rect2(pos, SLOT_SIZE), col)

		if i < PlayerData.inventory.size():
			var item = PlayerData.inventory[i]
			draw_rect(Rect2(pos + Vector2i(3, 3), SLOT_SIZE - Vector2i(6, 6)), Color(0, 0.6, 1))
			draw_string(font, pos + Vector2i(5, 25), item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK)

	draw_rect(Rect2(60, 95, 35, 45), Color.WHITE)
	draw_rect(Rect2(60, 160, 35, 45), Color.WHITE)

	if selected_slot >= 0 and selected_slot < PlayerData.inventory.size():
		var item = PlayerData.inventory[selected_slot]
		draw_string(font, Vector2(110, 260), item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		draw_string(font, Vector2(110, 275), item.desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
		draw_rect(Rect2(245, 255, 35, 20), Color(0.78, 0.78, 0.78))
		draw_string(font, Vector2(250, 268), "Use", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

func update_hover():
	var mouse = get_local_mouse_position()
	hover_slot = -1
	for i in range(8):
		var rect = Rect2(SLOT_POSITIONS[i], SLOT_SIZE)
		if rect.has_point(mouse):
			hover_slot = i
			return

func use_selected():
	if selected_slot < 0 or selected_slot >= PlayerData.inventory.size():
		return
	PlayerData.use_item(selected_slot)
	selected_slot = -1
