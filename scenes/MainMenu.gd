extends Control

func _ready():
	$StartButton.pressed.connect(_on_start)
	$QuitButton.pressed.connect(_on_quit)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.reset_player()
	_play_menu_music()

func _play_menu_music():
	_stop_all_music()
	var path = "res://assets/moosic/Main-Menu-Theme.mp3"
	if ResourceLoader.exists(path):
		var stream = load(path) as AudioStream
		if stream:
			var player = AudioStreamPlayer.new()
			player.name = "MusicPlayer"
			player.stream = stream
			player.volume_db = -14.0
			player.autoplay = true
			add_child(player)

func _stop_all_music():
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()

func _on_start():
	get_tree().change_scene_to_file("res://scene.tscn")

func _on_quit():
	get_tree().quit()
