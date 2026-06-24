extends Node

var boss1defeated = false

func _ready():
	process_mode = PROCESS_MODE_ALWAYS

func start_game():
	boss1defeated = false
	_reset_player()
	play_music("res://assets/music/Exploration_song_no_drums.mp3")
	get_tree().change_scene_to_file("res://scenes/Overworld.tscn")

func start_battle(enemy_name: String):
	PlayerData.last_enemy_name = enemy_name
	play_music("res://assets/music/copyrightedplaceholdermusic.mp3")
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")

func return_to_overworld():
	play_music("res://assets/music/Exploration_song_no_drums.mp3")
	get_tree().change_scene_to_file("res://scenes/Overworld.tscn")

func return_to_menu():
	boss1defeated = false
	play_music("res://assets/music/Main-Menu-Theme.mp3")
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func play_music(path: String):
	var audio = AudioStreamPlayer.new()
	var stream = load(path)
	if stream:
		audio.stream = stream
		audio.volume_db = linear_to_db(0.2)
		audio.name = "MusicPlayer"
		var existing = get_node_or_null("MusicPlayer")
		if existing:
			existing.queue_free()
		add_child(audio)
		audio.play()

func _reset_player():
	var pd = PlayerData
	pd.level = 1
	pd.xp = 0
	pd.xp_to_next_level = 100
	pd.max_hp = 100
	pd.hp = 100
	pd.base_attack = 15
	pd.defense = 5
	pd.current_stance = "Neutral"
	pd.defending = false
	pd.poisoned = false
	pd.grid_pos = Vector2i(2, 2)
	pd.last_enemy_name = ""
	pd.inventory = []
	pd.armor = null
	pd.weapon = null
	pd.opened_chests = []
