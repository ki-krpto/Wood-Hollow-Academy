extends Node2D

const TILE_SIZE = 32
const WORLD_TILES_X = 80
const WORLD_TILES_Y = 120

var tilemap: TileMap
var player: CharacterBody2D

@onready var dialogue_label = $DialogueUI/DialogueLabel
@onready var dialogue_panel = $DialogueUI/DialoguePanel

func _ready():
	_create_tilemap()
	_spawn_entities()
	_setup_player()
	_setup_camera()
	_setup_inventory_ui()

func _create_tilemap():
	var tileset = TileSet.new()
	var source = TileSetAtlasSource.new()
	source.texture = preload("res://assets/maps/cave_tilesheet.png")
	source.texture_region_size = Vector2i(32, 32)

	for i in range(4):
		source.create_tile(Vector2i(i, 0))

	tileset.add_source(source, 0)

	for i in range(3):
		var td = source.get_tile_data(Vector2i(i, 0), 0)
		if td:
			var poly = PackedVector2Array([Vector2(0,0), Vector2(32,0), Vector2(32,32), Vector2(0,32)])
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, poly)

	var ground_td = source.get_tile_data(Vector2i(3, 0), 0)
	if ground_td:
		ground_td.set_navigation_polygon(0, NavigationPolygon.new())

	tilemap = TileMap.new()
	tilemap.name = "TileMap"
	tilemap.tile_set = tileset
	add_child(tilemap)

	var file = FileAccess.open("res://assets/maps/tilemap_grid.json", FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	var grid = JSON.parse_string(text)
	if not grid:
		return

	for y in range(grid.size()):
		var row = grid[y]
		for x in range(row.size()):
			var gid = row[x]
			if gid > 0:
				tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(gid - 1, 0))

func _spawn_entities():
	var entity_data = [
		{"type": "NPC", "name": "Vivi", "x": 9, "y": 3, "props": {"dialogue": "Hello! |How is your day? |Glad to hear that! |Make sure to slay that monster!"}},
		{"type": "Enemy", "name": "Pollutabloom", "x": 12, "y": 3, "props": {}},
		{"type": "Chest", "id": 1, "name": "Potion Chest", "x": 13, "y": 3, "props": {"item_name": "Basic Health Potion"}}
	]

	var npc_scene = preload("res://scenes/NPC.tscn")
	var enemy_scene = preload("res://scenes/EnemyEntity.tscn")
	var chest_scene = preload("res://scenes/ChestEntity.tscn")

	for data in entity_data:
		if data.type == "NPC":
			var npc = npc_scene.instantiate()
			npc.npc_name = data.name
			npc.grid_pos = Vector2i(data.x, data.y)
			npc.dialogue_lines = data.props.dialogue.split("|")
			add_child(npc)
			var sprite = Sprite2D.new()
			sprite.texture = preload("res://assets/img/vivi-right.png")
			sprite.scale = Vector2(32.0 / sprite.texture.get_width(), 32.0 / sprite.texture.get_height())
			npc.add_child(sprite)

		elif data.type == "Enemy":
			if data.name == "Pollutabloom":
				var enemy = enemy_scene.instantiate()
				enemy.enemy_name = data.name
				enemy.grid_pos = Vector2i(data.x, data.y)
				add_child(enemy)
				var sprite = Sprite2D.new()
				sprite.texture = preload("res://assets/img/Pollutabloom.png")
				sprite.scale = Vector2(32.0 / sprite.texture.get_width(), 32.0 / sprite.texture.get_height())
				enemy.add_child(sprite)

		elif data.type == "Chest":
			if not PlayerData.has_opened_chest(data.id):
				var chest = chest_scene.instantiate()
				chest.chest_id = data.id
				chest.grid_pos = Vector2i(data.x, data.y)
				chest.item_name = data.props.item_name
				add_child(chest)
				var sprite = Sprite2D.new()
				sprite.texture = preload("res://assets/img/kim-forward.png")
				sprite.self_modulate = Color(1, 1, 0)
				sprite.scale = Vector2(32.0 / sprite.texture.get_width(), 32.0 / sprite.texture.get_height())
				chest.add_child(sprite)

func _setup_player():
	player = preload("res://scenes/Player.tscn").instantiate()
	player.name = "Player"
	add_child(player)

func _setup_camera():
	var camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_TILES_X * TILE_SIZE
	camera.limit_bottom = WORLD_TILES_Y * TILE_SIZE
	player.add_child(camera)

func _setup_inventory_ui():
	var inv = preload("res://scenes/InventoryUI.tscn").instantiate()
	inv.name = "InventoryUI"
	add_child(inv)

func is_dialogue_active() -> bool:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_talking:
			return true
	return false

func is_inventory_open() -> bool:
	return $InventoryUI.visible

func _input(event):
	if event.is_action_pressed("interact"):
		var active_npc = null
		for npc in get_tree().get_nodes_in_group("npcs"):
			if npc.is_talking:
				active_npc = npc
				break

		if active_npc:
			if not active_npc.advance_dialogue():
				active_npc.is_talking = false
				dialogue_panel.hide()
		else:
			for npc in get_tree().get_nodes_in_group("npcs"):
				var dx = abs(player.grid_pos.x - npc.grid_pos.x)
				var dy = abs(player.grid_pos.y - npc.grid_pos.y)
				if dx + dy == 1:
					npc.is_talking = true
					npc.dialogue_index = 0
					break

	if event.is_action_pressed("toggle_inventory"):
		var inv_ui = $InventoryUI
		inv_ui.visible = not inv_ui.visible

	if event.is_action_pressed("ui_cancel"):
		GameManager.return_to_menu()

func _process(_delta):
	var active_npc = null
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_talking:
			active_npc = npc
			break

	if active_npc:
		dialogue_panel.show()
		dialogue_label.text = active_npc.get_current_line()
	else:
		dialogue_panel.hide()
