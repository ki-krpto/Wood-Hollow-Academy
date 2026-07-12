extends StaticBody2D

@export var enemy_id: String = "Pollutabloom"

func _ready():
	add_to_group("enemies")
	if GameManager.defeated_enemies.has(enemy_id):
		queue_free()
