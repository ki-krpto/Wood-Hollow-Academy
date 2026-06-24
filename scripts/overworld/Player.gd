extends CharacterBody2D

const TILE_SIZE = 32
const SPEED = 2

var grid_pos = Vector2i(2, 2)
var target_pos = Vector2()
var moving = false

@onready var sprite = $Sprite2D

func _ready():
	grid_pos = PlayerData.grid_pos
	position = grid_pos * TILE_SIZE + Vector2i(TILE_SIZE/2, TILE_SIZE/2)
	target_pos = position

func _physics_process(_delta):
	if moving:
		var diff = target_pos - position
		if diff.length() < SPEED:
			position = target_pos
			_on_move_finished()
		else:
			position += diff.normalized() * SPEED
		return

	if is_dialogue_active() or is_inventory_open():
		return

	var dir = Vector2i.ZERO
	if Input.is_action_pressed("move_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"):
		dir = Vector2i.RIGHT
	elif Input.is_action_pressed("move_up"):
		dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"):
		dir = Vector2i.DOWN

	if dir != Vector2i.ZERO:
		var next_grid = grid_pos + dir
		if can_move_to(next_grid):
			grid_pos = next_grid
			target_pos = grid_pos * TILE_SIZE + Vector2i(TILE_SIZE/2, TILE_SIZE/2)
			moving = true

func can_move_to(target: Vector2i) -> bool:
	if target.x < 0 or target.y < 0 or target.x >= 80 or target.y >= 120:
		return false
	var tilemap = get_parent().get_node("TileMap")
	var tile_data = tilemap.get_cell_tile_data(0, target)
	if tile_data and tile_data.get_collision_polygons_count(0) > 0:
		return false
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.grid_pos == target:
			return false
	return true

func _on_move_finished():
	moving = false
	PlayerData.grid_pos = grid_pos
	check_enemy_encounter()
	check_chest_pickup()

func check_enemy_encounter():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.grid_pos == grid_pos:
			GameManager.start_battle(enemy.enemy_name)

func check_chest_pickup():
	for chest in get_tree().get_nodes_in_group("chests"):
		if chest.grid_pos == grid_pos and not chest.opened:
			chest.open_chest()

func is_dialogue_active() -> bool:
	return get_parent().is_dialogue_active()

func is_inventory_open() -> bool:
	return get_parent().is_inventory_open()
