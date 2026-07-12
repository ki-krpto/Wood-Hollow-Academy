extends Control

var settings_panel: PanelContainer = null
var res_label: Label = null
var fs_label: Label = null
var vol_label: Label = null

func _ready():
	MusicManager.play_menu()
	_build_settings_panel()

func _on_start_button_pressed():
	GameManager.change_scene("res://scene.tscn")

func _on_settings_button_pressed():
	settings_panel.visible = true
	get_node("VBoxContainer").visible = false

func _on_quit_button_pressed():
	get_tree().quit()

func _build_settings_panel():
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -200
	settings_panel.offset_top = -180
	settings_panel.offset_right = 200
	settings_panel.offset_bottom = 180
	add_child(settings_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	style.border_color = Color(0.45, 0.32, 0.18, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	settings_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	settings_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var res_row = HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 12)
	vbox.add_child(res_row)

	var res_title = Label.new()
	res_title.text = "Resolution"
	res_title.add_theme_font_size_override("font_size", 15)
	res_title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	res_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(res_title)

	var res_left = Button.new()
	res_left.text = "<"
	res_left.custom_minimum_size = Vector2(36, 28)
	res_left.focus_mode = Control.FOCUS_NONE
	res_left.pressed.connect(_on_res_left)
	res_row.add_child(res_left)

	res_label = Label.new()
	res_label.text = ScreenManager.get_resolution_text()
	res_label.add_theme_font_size_override("font_size", 15)
	res_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_label.custom_minimum_size = Vector2(120, 0)
	res_row.add_child(res_label)

	var res_right = Button.new()
	res_right.text = ">"
	res_right.custom_minimum_size = Vector2(36, 28)
	res_right.focus_mode = Control.FOCUS_NONE
	res_right.pressed.connect(_on_res_right)
	res_row.add_child(res_right)

	var fs_row = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	vbox.add_child(fs_row)

	var fs_title = Label.new()
	fs_title.text = "Fullscreen"
	fs_title.add_theme_font_size_override("font_size", 15)
	fs_title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	fs_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_title)

	var fs_left = Button.new()
	fs_left.text = "<"
	fs_left.custom_minimum_size = Vector2(36, 28)
	fs_left.focus_mode = Control.FOCUS_NONE
	fs_left.pressed.connect(_on_fs_left)
	fs_row.add_child(fs_left)

	fs_label = Label.new()
	fs_label.text = "On" if ScreenManager.fullscreen else "Off"
	fs_label.add_theme_font_size_override("font_size", 15)
	fs_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	fs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fs_label.custom_minimum_size = Vector2(120, 0)
	fs_row.add_child(fs_label)

	var fs_right = Button.new()
	fs_right.text = ">"
	fs_right.custom_minimum_size = Vector2(36, 28)
	fs_right.focus_mode = Control.FOCUS_NONE
	fs_right.pressed.connect(_on_fs_right)
	fs_row.add_child(fs_right)

	var vol_row = HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	vbox.add_child(vol_row)

	var vol_title = Label.new()
	vol_title.text = "Music"
	vol_title.add_theme_font_size_override("font_size", 15)
	vol_title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	vol_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_row.add_child(vol_title)

	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = MusicManager.music_volume
	vol_slider.custom_minimum_size = Vector2(140, 0)
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.focus_mode = Control.FOCUS_NONE
	vol_row.add_child(vol_slider)

	vol_label = Label.new()
	vol_label.text = str(int(MusicManager.music_volume * 100)) + "%"
	vol_label.add_theme_font_size_override("font_size", 15)
	vol_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	vol_label.custom_minimum_size = Vector2(40, 0)
	vol_row.add_child(vol_label)

	vol_slider.value_changed.connect(_on_vol_changed)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 32)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_on_settings_back)
	btn_row.add_child(back_btn)

func _on_res_left():
	ScreenManager.cycle_resolution(-1)
	res_label.text = ScreenManager.get_resolution_text()

func _on_res_right():
	ScreenManager.cycle_resolution(1)
	res_label.text = ScreenManager.get_resolution_text()

func _on_fs_left():
	ScreenManager.fullscreen = not ScreenManager.fullscreen
	ScreenManager.apply_settings()
	ScreenManager.save_settings()
	fs_label.text = "On" if ScreenManager.fullscreen else "Off"

func _on_fs_right():
	ScreenManager.fullscreen = not ScreenManager.fullscreen
	ScreenManager.apply_settings()
	ScreenManager.save_settings()
	fs_label.text = "On" if ScreenManager.fullscreen else "Off"

func _on_vol_changed(value: float):
	MusicManager.set_volume(value)
	vol_label.text = str(int(value * 100)) + "%"

func _on_settings_back():
	settings_panel.visible = false
	get_node("VBoxContainer").visible = true
