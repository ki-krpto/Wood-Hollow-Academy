extends Node2D

func _ready():
	_play_overworld_music()

func _play_overworld_music():
	_stop_all_music()
	var path = "res://assets/moosic/Exploration_song_no_drums.mp3"
	if ResourceLoader.exists(path):
		var stream = load(path) as AudioStream
		if stream:
			var player = AudioStreamPlayer.new()
			player.name = "OverworldMusic"
			player.stream = stream
			player.volume_db = -14.0
			player.autoplay = true
			add_child(player)

func _stop_all_music():
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
