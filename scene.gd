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
	if not GameManager.get_story_flag("intro_seen"):
		_play_intro_cutscene()

func _play_intro_cutscene() -> void:
	await get_tree().create_timer(0.8).timeout

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	player.cutscene_lock = true
	player.moving = false
	player.move_dir = Vector2.ZERO
	player.buffered_dir = Vector2.ZERO

	var altar := get_tree().get_first_node_in_group("interactables") as Node2D
	var cam := player.get_node_or_null("Camera2D") as Camera2D

	if cam and altar:
		var altar_offset: Vector2 = altar.global_position - player.global_position
		var move_in := create_tween()
		move_in.set_parallel(true)
		move_in.tween_property(cam, "position", altar_offset, 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		move_in.tween_property(cam, "zoom", Vector2(3.2, 3.2), 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await move_in.finished

		var bob := create_tween()
		bob.set_loops()
		bob.tween_property(cam, "position:y", altar_offset.y + 10, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		bob.tween_property(cam, "position:y", altar_offset.y, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		var cutscene = load("res://assets/maps/cutscene_player.gd").new()
		add_child(cutscene)
		cutscene.play([
			{
				"speaker": "The Altar",
				"lines": [
					"Welcome, child of the refugees. You have found your way to my heart.",
					"I am the last Sanctuary Altar. The Legend bound his voice to my stone."
				]
			},
			{
				"speaker": "The Altar",
				"lines": [
					"At my base rests a scroll written in his own hand.",
					"It is the only record of the road through the deep caverns... and of what the surface has become."
				]
			},
			{
				"speaker": "The Altar",
				"lines": [
					"Take it. Let it guide you where the others could not.",
					"Read it well, and the way forward will reveal itself."
				]
			}
		])
		await GameManager.dialogue_finished

		bob.kill()
		player.cutscene_lock = true
		var move_back := create_tween()
		move_back.set_parallel(true)
		move_back.tween_property(cam, "position", Vector2(50, -274), 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		move_back.tween_property(cam, "zoom", Vector2(1.7, 1.7), 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await move_back.finished
		player.cutscene_lock = false
		GameManager.set_story_flag("intro_seen")
		return

	var fallback = load("res://assets/maps/cutscene_player.gd").new()
	add_child(fallback)
	fallback.play([
		{
			"speaker": "The Altar",
			"lines": [
				"Welcome, child of the refugees. You have found your way to my heart.",
				"I am the last Sanctuary Altar. The Legend bound his voice to my stone."
			]
		},
		{
			"speaker": "The Altar",
			"lines": [
				"At my base rests a scroll written in his own hand.",
				"It is the only record of the road through the deep caverns... and of what the surface has become."
			]
		},
		{
			"speaker": "The Altar",
			"lines": [
				"Take it. Let it guide you where the others could not.",
				"Read it well, and the way forward will reveal itself."
			]
		}
	])
	await GameManager.dialogue_finished
	GameManager.set_story_flag("intro_seen")
