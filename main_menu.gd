extends Control

var settings_panel: PanelContainer = null
var res_label: Label = null
var fs_label: Label = null
var vol_label: Label = null
var save_panel: PanelContainer = null
var move_hint_label: Label = null
var save_slot_labels: Array[Label] = []
var save_slot_play_buttons: Array[Button] = []
var save_slot_delete_buttons: Array[Button] = []
var save_slot_move_buttons: Array[Button] = []
var move_source_slot: int = -1

func _ready():
	MusicManager.play_menu()
	_build_settings_panel()
	_build_save_panel()

func _on_start_button_pressed():
	_open_save_menu()

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

func _build_save_panel():
	save_panel = PanelContainer.new()
	save_panel.visible = false
	save_panel.set_anchors_preset(Control.PRESET_CENTER)
	save_panel.offset_left = -260
	save_panel.offset_top = -200
	save_panel.offset_right = 260
	save_panel.offset_bottom = 200
	add_child(save_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08, 0.97)
	style.border_color = Color(0.45, 0.32, 0.18, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	save_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	save_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Save Files"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	for slot in GameManager.SAVE_SLOT_COUNT:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var info_label = Label.new()
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.add_theme_font_size_override("font_size", 14)
		info_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		row.add_child(info_label)
		save_slot_labels.append(info_label)

		var play_btn = Button.new()
		play_btn.custom_minimum_size = Vector2(90, 30)
		play_btn.focus_mode = Control.FOCUS_NONE
		play_btn.pressed.connect(_on_save_slot_play.bind(slot))
		row.add_child(play_btn)
		save_slot_play_buttons.append(play_btn)

		var delete_btn = Button.new()
		delete_btn.text = "Delete"
		delete_btn.custom_minimum_size = Vector2(80, 30)
		delete_btn.focus_mode = Control.FOCUS_NONE
		delete_btn.pressed.connect(_on_save_slot_delete.bind(slot))
		row.add_child(delete_btn)
		save_slot_delete_buttons.append(delete_btn)

		var move_btn = Button.new()
		move_btn.custom_minimum_size = Vector2(95, 30)
		move_btn.focus_mode = Control.FOCUS_NONE
		move_btn.pressed.connect(_on_save_slot_move.bind(slot))
		row.add_child(move_btn)
		save_slot_move_buttons.append(move_btn)

	move_hint_label = Label.new()
	move_hint_label.add_theme_font_size_override("font_size", 13)
	move_hint_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	move_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_hint_label.visible = false
	vbox.add_child(move_hint_label)

	vbox.add_child(HSeparator.new())

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 32)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_close_save_menu)
	btn_row.add_child(back_btn)

	_refresh_save_menu()

func _open_save_menu() -> void:
	move_source_slot = -1
	_refresh_save_menu()
	save_panel.visible = true
	get_node("VBoxContainer").visible = false

func _close_save_menu() -> void:
	move_source_slot = -1
	save_panel.visible = false
	get_node("VBoxContainer").visible = true

func _refresh_save_menu() -> void:
	if move_source_slot >= 0 and not GameManager.has_save_slot(move_source_slot):
		move_source_slot = -1

	for slot in GameManager.SAVE_SLOT_COUNT:
		var summary: Dictionary = GameManager.get_save_slot_summary(slot)
		var exists: bool = summary.get("exists", false)
		var info_label := save_slot_labels[slot]
		if exists:
			info_label.text = "File %d: %s  Lv.%d  Gold %d" % [
				slot + 1,
				str(summary.get("name", "Hero")),
				int(summary.get("level", 1)),
				int(summary.get("gold", 0))
			]
		else:
			info_label.text = "File %d: Empty" % (slot + 1)

		save_slot_play_buttons[slot].text = "Continue" if exists else "New"
		save_slot_delete_buttons[slot].disabled = not exists

		var move_btn := save_slot_move_buttons[slot]
		if move_source_slot == -1:
			move_btn.text = "Move"
			move_btn.disabled = not exists
		elif move_source_slot == slot:
			move_btn.text = "Cancel"
			move_btn.disabled = false
		else:
			move_btn.text = "Move Here"
			move_btn.disabled = false

	if move_hint_label:
		move_hint_label.visible = move_source_slot != -1
		if move_source_slot != -1:
			move_hint_label.text = "Moving File %d: choose destination." % (move_source_slot + 1)

func _on_save_slot_play(slot: int) -> void:
	var loaded: bool
	if GameManager.has_save_slot(slot):
		loaded = GameManager.load_save_slot(slot)
	else:
		loaded = GameManager.create_new_save(slot)
	if loaded:
		GameManager.change_scene("res://scene.tscn")

func _on_save_slot_delete(slot: int) -> void:
	GameManager.delete_save_slot(slot)
	if move_source_slot == slot:
		move_source_slot = -1
	_refresh_save_menu()

func _on_save_slot_move(slot: int) -> void:
	if move_source_slot == -1:
		if GameManager.has_save_slot(slot):
			move_source_slot = slot
	elif move_source_slot == slot:
		move_source_slot = -1
	else:
		GameManager.move_save_slot(move_source_slot, slot)
		move_source_slot = -1
	_refresh_save_menu()

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
