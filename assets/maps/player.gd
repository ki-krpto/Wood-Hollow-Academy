extends CharacterBody2D

const TILE_SIZE = 32
const MOVE_SPEED = 3.0

var grid_pos: Vector2i
var target_pos: Vector2
var moving: bool = false
var can_move: bool = true
var is_talking: bool = false
var current_dialogue_lines: Array[String] = []
var dialogue_index: int = 0

@onready var sprite = $Sprite2D
@onready var cam = $Camera2D

func _ready():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		grid_pos = Vector2i(gm.player_grid_x, gm.player_grid_y)
	else:
		grid_pos = Vector2i(2, 2)
	target_pos = Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)
	position = target_pos

func _physics_process(_delta):
	if moving:
		position = position.move_toward(target_pos, MOVE_SPEED)
		if position == target_pos:
			moving = false
			_on_arrived()
		return
	if not can_move or is_talking:
		return
	var dir = Vector2i.ZERO
	if Input.is_action_just_pressed("right"):
		dir = Vector2i.RIGHT
	elif Input.is_action_just_pressed("left"):
		dir = Vector2i.LEFT
	elif Input.is_action_just_pressed("up"):
		dir = Vector2i.UP
	elif Input.is_action_just_pressed("down"):
		dir = Vector2i.DOWN
	if dir != Vector2i.ZERO:
		_try_move(dir)

func _try_move(dir: Vector2i):
	var new_grid = grid_pos + dir
	var new_rect = Rect2(new_grid.x * TILE_SIZE, new_grid.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	var col = get_parent().get_node_or_null("Collision")
	if col:
		for child in col.get_children():
			if child is StaticBody2D:
				var shape_node = child.get_node_or_null("CollisionShape2D")
				if shape_node and shape_node.shape is RectangleShape2D:
					var shape_rect = Rect2(
						child.position.x + shape_node.position.x - shape_node.shape.size.x/2,
						child.position.y + shape_node.position.y - shape_node.shape.size.y/2,
						shape_node.shape.size.x,
						shape_node.shape.size.y
					)
					if new_rect.intersects(shape_rect):
						return
	# Also block movement onto NPC tiles
	var entities = get_parent().get_node_or_null("Entities")
	if entities:
		for child in entities.get_children():
			if child is StaticBody2D and child.has_meta("dialogue"):
				var egx = int(child.position.x / TILE_SIZE)
				var egy = int(child.position.y / TILE_SIZE)
				if new_grid.x == egx and new_grid.y == egy:
					return
	grid_pos = new_grid
	target_pos = Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)
	moving = true

func _on_arrived():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.player_grid_x = grid_pos.x
		gm.player_grid_y = grid_pos.y
	var entities = get_parent().get_node_or_null("Entities")
	if not entities:
		return
	# Check exact tile matches (enemies, chests)
	for child in entities.get_children():
		if not child is StaticBody2D:
			continue
		var egx = int(child.position.x / TILE_SIZE)
		var egy = int(child.position.y / TILE_SIZE)
		if egx != grid_pos.x or egy != grid_pos.y:
			continue
		var ename = child.name.replace(" (SB)", "")
		if gm and ename in ["Pollutabloom", "Ryan Gosling", "Cave Bat", "Limestone Golem"]:
			if gm.is_enemy_defeated(ename, egx, egy):
				return
			can_move = false
			gm.last_enemy_name = ename
			gm.last_enemy_grid_x = egx
			gm.last_enemy_grid_y = egy
			gm.in_combat = true
			get_tree().change_scene_to_file("res://scenes/Combat.tscn")
			return
		if child.has_meta("item_name"):
			var cid = child.get_instance_id()
			if gm and cid in gm.opened_chests:
				return
			if gm:
				gm.add_item_by_name(child.get_meta("item_name"))
				gm.opened_chests.append(cid)
				print("Got ", child.get_meta("item_name"))
			child.queue_free()
			return
	# Check adjacent tiles for NPCs
	for child in entities.get_children():
		if not child is StaticBody2D or not child.has_meta("dialogue"):
			continue
		var egx = int(child.position.x / TILE_SIZE)
		var egy = int(child.position.y / TILE_SIZE)
		var dx = abs(grid_pos.x - egx)
		var dy = abs(grid_pos.y - egy)
		if dx + dy == 1:
			current_dialogue_lines = str(child.get_meta("dialogue")).split("|")
			dialogue_index = 0
			is_talking = true
			can_move = false
			_show_dialogue()
			return

func _show_dialogue():
	var box = get_node_or_null("/root/Overworld/CanvasLayer/DialogueBox")
	if box:
		box.show_text(current_dialogue_lines[dialogue_index])

func advance_dialogue():
	dialogue_index += 1
	if dialogue_index < current_dialogue_lines.size():
		var box = get_node_or_null("/root/Overworld/CanvasLayer/DialogueBox")
		if box:
			box.show_text(current_dialogue_lines[dialogue_index])
	else:
		is_talking = false
		can_move = true
		current_dialogue_lines = []
		dialogue_index = 0
		var box = get_node_or_null("/root/Overworld/CanvasLayer/DialogueBox")
		if box:
			box.hide()

func _input(event):
	if event.is_action_pressed("interact") and is_talking:
		advance_dialogue()
	if event.is_action_pressed("inventory"):
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.emit_signal("toggle_inventory")
	if event.is_action_pressed("ui_cancel") and not is_talking:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
