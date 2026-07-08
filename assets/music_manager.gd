extends Node

var menu_music: AudioStream
var overworld_music: AudioStream
var player: AudioStreamPlayer

func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)

	menu_music = load("res://assets/moosic/Main-Menu-Theme.mp3")
	overworld_music = load("res://assets/moosic/Exploration_song_no_drums.mp3")

func play_menu():
	if player.stream == menu_music and player.playing:
		return
	player.stop()
	player.stream = menu_music
	player.play()

func play_overworld():
	if player.stream == overworld_music and player.playing:
		return
	player.stop()
	player.stream = overworld_music
	player.play()
