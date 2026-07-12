extends Node2D

func _ready() -> void:
	MusicManager.play_overworld()
	if GameManager.overworld_position != Vector2.ZERO:
		await get_tree().process_frame
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if player:
			player.moving = false
			player.move_dir = Vector2.ZERO
			player.buffered_dir = Vector2.ZERO
			player.move_progress = 0.0
			player.move_timer = 0.0
			player.interacting = false
			player.stats_open = false
			player.position = GameManager.overworld_position
			player.target = GameManager.overworld_position
			var cam := player.get_node_or_null("Camera2D") as Camera2D
			if cam:
				cam.position = Vector2(50, -274)
				cam.zoom = Vector2(1.7, 1.7)
