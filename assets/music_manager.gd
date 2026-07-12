extends Node

var menu_music
var overworld_music
var battle_music
var player

func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)

	menu_music = load("res://assets/moosic/Main-Menu-Theme.mp3")
	overworld_music = load("res://assets/moosic/Exploration_song_no_drums.mp3")
	battle_music = load("res://assets/moosic/copyrightedplaceholdermusic.mp3")

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

func play_battle():
	if player.stream == battle_music and player.playing:
		return
	player.stop()
	player.stream = battle_music
	player.play()
