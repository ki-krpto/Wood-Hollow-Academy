extends CharacterBody2D

const TILE_SIZE := 32

func _ready() -> void:
	add_to_group("rocks")
	var tile := Vector2(TILE_SIZE, TILE_SIZE)
	position = (position / tile).floor() * tile + tile * 0.5

func can_move(dir: Vector2) -> bool:
	return move_and_collide(dir * TILE_SIZE, true) == null