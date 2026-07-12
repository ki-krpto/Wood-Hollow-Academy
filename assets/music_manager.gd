extends Node

const CONFIG_PATH := "user://settings.cfg"

var menu_music
var overworld_music
var battle_music
var player: AudioStreamPlayer
var music_volume: float = 0.8

func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)

	menu_music = load("res://assets/moosic/Main-Menu-Theme.mp3")
	overworld_music = load("res://assets/moosic/Exploration_song_no_drums.mp3")
	battle_music = load("res://assets/moosic/copyrightedplaceholdermusic.mp3")

	load_volume()
	apply_volume()

func set_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	apply_volume()
	save_volume()

func apply_volume() -> void:
	if music_volume <= 0.0:
		player.volume_db = -80.0
	else:
		player.volume_db = linear_to_db(music_volume)

func save_volume() -> void:
	var config = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("audio", "music_volume", music_volume)
	config.save(CONFIG_PATH)

func load_volume() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		music_volume = config.get_value("audio", "music_volume", 0.8)

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
