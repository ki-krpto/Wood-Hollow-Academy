extends StaticBody2D

@export var enemy_id: String = "Pollutabloom"

var defeat_key: String = ""

func _ready():
	add_to_group("enemies")
	defeat_key = str(get_path())
	if GameManager.defeated_enemies.has(defeat_key):
		queue_free()
