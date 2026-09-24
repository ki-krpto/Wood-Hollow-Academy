extends StaticBody2D

@export var enemy_id: String = "Pollutabloom"
## Unique id for THIS enemy instance. Copy-pasted enemies share the same
## enemy_id, so set a unique Spawn Id here if a gate must require this
## exact enemy (e.g. "Crypt Guardian"). Leave empty to use the node path.
@export var spawn_id: String = ""

var defeat_key: String = ""

func _ready():
	add_to_group("enemies")
	defeat_key = spawn_id if not spawn_id.is_empty() else str(get_path())
	if GameManager.defeated_enemies.has(defeat_key):
		queue_free()
