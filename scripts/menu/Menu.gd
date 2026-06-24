extends Control

func _ready():
	$TitleLabel.text = "Wood Hollow Academy"
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	GameManager.play_music("res://assets/music/Main-Menu-Theme.mp3")

func _on_start_pressed():
	GameManager.start_game()

func _on_quit_pressed():
	get_tree().quit()
