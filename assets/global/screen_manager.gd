extends Node

const CONFIG_PATH := "user://settings.cfg"

var resolutions := [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
var resolution_index: int = 2
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	apply_settings()

func apply_settings() -> void:
	var res = resolutions[resolution_index]

	var was_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	if fullscreen:
		if was_fullscreen:
			return
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if was_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(res)
		var screen = DisplayServer.get_primary_screen()
		var screen_size = DisplayServer.screen_get_size(screen)
		var centered_pos = Vector2i(
			(screen_size.x - res.x) / 2,
			(screen_size.y - res.y) / 2
		)
		DisplayServer.window_set_position(centered_pos)

func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, resolutions.size() - 1)
	apply_settings()
	save_settings()

func cycle_resolution(direction: int) -> void:
	resolution_index = (resolution_index + direction) % resolutions.size()
	if resolution_index < 0:
		resolution_index = resolutions.size() - 1
	apply_settings()
	save_settings()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_settings()
	save_settings()

func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_settings()
	save_settings()

func get_resolution_text() -> String:
	var res = resolutions[resolution_index]
	return str(res.x) + "x" + str(res.y)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(CONFIG_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		resolution_index = config.get_value("display", "resolution_index", 2)
		fullscreen = config.get_value("display", "fullscreen", false)
