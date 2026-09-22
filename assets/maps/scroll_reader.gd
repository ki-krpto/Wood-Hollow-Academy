extends CanvasLayer

signal closed

const PCC := Color(0.9, 0.8, 0.58, 1.0)
const PCC_DARK := Color(0.62, 0.5, 0.34, 1.0)
const TUBE_MID := Color(0.72, 0.6, 0.4, 1.0)
const TUBE_HIGH := Color(0.88, 0.78, 0.58, 1.0)
const TUBE_DARK := Color(0.45, 0.34, 0.2, 1.0)
const INK := Color(0.2, 0.13, 0.07, 1.0)
const INK_RIGHT := Color(0.58, 0.47, 0.3, 1.0)

const TUBE_H := 26.0
const TUBE_OVERLAP := 6.0
const FRAME_PAD_X := 30.0
const CONTENT_PAD_X := 36.0
const TOP_PAD := 84.0
const BOTTOM_PAD := 120.0
const WHEEL_STEP := 110.0
const KEY_STEP := 240.0
const JUMP_TIME := 0.55
const CLOSE_TIME := 0.9

var pages: Array = []
var title_text: String = "Scroll"
var icon_texture: Texture2D = null

var window: Control = null
var strip: Control = null
var para_labels: Array[Label] = []
var para_ys: Array[float] = []

var scroll_pos := 0.0
var max_scroll := 0.0
var para_index := 0
var _layout_ready := false
var _closed := false
var _scroll_tween: Tween = null
var _dragging := false
var _drag_moved := false
var _drag_y := 0.0

func open(scroll_pages: Array, scroll_title: String = "Scroll", icon: Texture2D = null) -> void:
	pages = scroll_pages
	title_text = scroll_title
	icon_texture = icon
	layer = 12
	_build_ui()

func _process(delta: float) -> void:
	if _closed:
		return
	_apply_scroll()
	if Input.is_action_pressed("ui_down"):
		_nudge(KEY_STEP * delta)
	if Input.is_action_pressed("ui_up"):
		_nudge(-KEY_STEP * delta)
	if not _dragging and _layout_ready and max_scroll > 0.0 and scroll_pos >= max_scroll:
		_close()
	if Input.is_action_just_pressed("interact") and not _dragging:
		_advance()

func _on_cover_input(event: InputEvent) -> void:
	if _closed or not _layout_ready:
		return
	if event is InputEventMouseButton:
		var eb := event as InputEventMouseButton
		if eb.button_index == MOUSE_BUTTON_LEFT:
			if eb.pressed:
				_dragging = true
				_drag_moved = false
				_drag_y = eb.position.y
				_kill_tween()
			elif _dragging:
				_dragging = false
				if not _drag_moved:
					_advance()
		elif eb.pressed and eb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(-WHEEL_STEP * eb.factor)
		elif eb.pressed and eb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(WHEEL_STEP * eb.factor)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var dy := mm.position.y - _drag_y
		if absf(dy) > 1.0:
			_drag_moved = true
			_nudge(-dy)
			_drag_y = mm.position.y

func _advance() -> void:
	if not _layout_ready:
		return
	if para_index < pages.size() - 1:
		para_index += 1
		_jump_to_para(para_index)
	else:
		_start_close()

func _nudge(delta_off: float) -> void:
	if not _layout_ready:
		return
	_kill_tween()
	scroll_pos = clampf(scroll_pos + delta_off, 0.0, max_scroll)
	_apply_scroll()

func _jump_to_para(index: int) -> void:
	var target := clampf(para_ys[index] - window.size.y * 0.32, 0.0, max_scroll)
	_scroll_to(target, JUMP_TIME, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)

func _scroll_to(target: float, time: float, trans: int, ease_mode: int) -> void:
	_kill_tween()
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(_tween_set, scroll_pos, clampf(target, 0.0, max_scroll), time)\
		.set_trans(trans).set_ease(ease_mode)

func _start_close() -> void:
	_kill_tween()
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(_tween_set, scroll_pos, max_scroll, CLOSE_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_scroll_tween.tween_callback(_finish_close)

func _finish_close() -> void:
	_close()

func _kill_tween() -> void:
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
		_scroll_tween = null

func _tween_set(value: float) -> void:
	scroll_pos = clampf(value, 0.0, max_scroll)
	_apply_scroll()

func _close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit()
	queue_free()

func _apply_scroll() -> void:
	scroll_pos = clampf(scroll_pos, 0.0, max_scroll)
	if strip:
		strip.position = Vector2(0, -scroll_pos)

func _parchment_image(w: int, h: int) -> Image:
	var img := Image.create(maxi(w, 2), maxi(h, 2), false, Image.FORMAT_RGBA8)
	var n_fiber := FastNoiseLite.new()
	n_fiber.seed = 101
	n_fiber.frequency = 0.9
	n_fiber.fractal_octaves = 2
	var n_blot := FastNoiseLite.new()
	n_blot.seed = 202
	n_blot.frequency = 0.018
	n_blot.fractal_octaves = 3
	var n_varn := FastNoiseLite.new()
	n_varn.seed = 303
	n_varn.frequency = 0.55
	n_varn.fractal_octaves = 2
	var n_curl := FastNoiseLite.new()
	n_curl.seed = 404
	n_curl.frequency = 0.04
	n_curl.fractal_octaves = 2

	for yy in img.get_height():
		var v := float(yy) / float(img.get_height() - 1)
		var ey := minf(v, 1.0 - v)
		var fold := 0.0
		if ey < 0.16:
			fold = pow(1.0 - ey / 0.16, 1.6)
		var crease := 0.0
		var saw := absf(fmod(v * 5.0, 1.0) - 0.5)
		var curl_row: float = n_curl.get_noise_2d(0.0, yy)
		if saw < 0.05 and curl_row > 0.0:
			crease = (0.05 - saw) / 0.05 * clampf(curl_row, 0.0, 1.0) * 0.8
		for xx in img.get_width():
			var u := float(xx) / float(img.get_width() - 1)
			var ex := minf(u, 1.0 - u)
			var curl := 0.0
			if ex < 0.34:
				curl = pow(1.0 - ex / 0.34, 1.4)
			var shade := 1.0 - 0.48 * curl - 0.42 * fold - 0.14 * crease
			var fiber: float = n_fiber.get_noise_2d(xx, yy)
			var blot: float = n_blot.get_noise_2d(xx, yy)
			var varn: float = n_varn.get_noise_2d(xx, yy)
			var r := (0.965 + 0.03 * fiber) * shade
			var g := (0.89 + 0.025 * fiber) * shade
			var b := (0.705 + 0.02 * fiber) * shade
			if blot > 0.15:
				var a: float = clampf((blot - 0.15) / 0.6, 0.0, 1.0)
				r = lerpf(r, 0.55, a * 0.5)
				g = lerpf(g, 0.43, a * 0.5)
				b = lerpf(b, 0.27, a * 0.5)
			if varn > 0.62:
				var a2: float = (varn - 0.62) / 0.38
				r = maxf(r - 0.1 * a2, 0.0)
				g = maxf(g - 0.09 * a2, 0.0)
				b = maxf(b - 0.08 * a2, 0.0)
			var sheen := pow(maxf(0.0, 1.0 - absf(ex - 0.05) / 0.035), 2.0)
			r = lerpf(r, minf(r + 0.07, 1.0), sheen * 0.6)
			g = lerpf(g, minf(g + 0.065, 1.0), sheen * 0.6)
			b = lerpf(b, minf(b + 0.06, 1.0), sheen * 0.6)
			img.set_pixel(xx, yy, Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0), 1.0))
	return img

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var cover := Button.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.flat = true
	cover.focus_mode = Control.FOCUS_NONE
	cover.mouse_default_cursor_shape = Control.CURSOR_DRAG
	cover.gui_input.connect(_on_cover_input)
	add_child(cover)

	var viewport_size := get_viewport().get_visible_rect().size
	var scroll_h := minf(760.0, viewport_size.y * 0.94)
	var scroll_w := clampf(scroll_h * 0.6, 320.0, 430.0)
	var body_x := (viewport_size.x - scroll_w) * 0.5
	var body_y := (viewport_size.y - scroll_h) * 0.5

	var body := Panel.new()
	body.position = Vector2(body_x, body_y)
	body.size = Vector2(scroll_w, scroll_h)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(0, 0, 0, 0)
	body_style.shadow_color = Color(0, 0, 0, 0.55)
	body_style.shadow_size = 24
	body_style.shadow_offset = Vector2(0, 6)
	body_style.set_corner_radius_all(8)
	body.add_theme_stylebox_override("panel", body_style)
	cover.add_child(body)

	var window_x := FRAME_PAD_X
	var window_y := TUBE_H - TUBE_OVERLAP
	var window_w := scroll_w - FRAME_PAD_X * 2.0
	var window_h := scroll_h - (TUBE_H - TUBE_OVERLAP) * 2.0

	window = Control.new()
	window.position = Vector2(window_x, window_y)
	window.size = Vector2(window_w, window_h)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.clip_contents = true
	body.add_child(window)

	strip = Control.new()
	strip.position = Vector2.ZERO
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(strip)

	var content_w := window_w - CONTENT_PAD_X * 2.0
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(CONTENT_PAD_X, TOP_PAD)
	vbox.size = Vector2(content_w, 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 40)
	strip.add_child(vbox)

	if icon_texture:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.modulate = Color(0.55, 0.42, 0.24, 0.7)
		vbox.add_child(icon)

	_add_title_block(vbox)

	for i in pages.size():
		var body_label := Label.new()
		body_label.text = str(pages[i])
		body_label.add_theme_font_size_override("font_size", 19)
		body_label.add_theme_color_override("font_color", INK)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(body_label)
		para_labels.append(body_label)
		if i < pages.size() - 1:
			vbox.add_child(_make_rule(58))

	await get_tree().process_frame
	var content_h: float = vbox.get_combined_minimum_size().y
	var strip_h := TOP_PAD + content_h + BOTTOM_PAD
	strip.size = Vector2(window_w, strip_h)
	vbox.size = Vector2(content_w, content_h)

	max_scroll = maxf(strip_h - window_h, 0.0)
	para_ys.clear()
	await get_tree().process_frame
	for label in para_labels:
		para_ys.append(TOP_PAD + label.position.y)

	_layout_ready = true
	scroll_pos = clampf(para_ys[0] - window_h * 0.1, 0.0, max_scroll)

	var grain := TextureRect.new()
	grain.texture = ImageTexture.create_from_image(_parchment_image(int(window_w / 2), int(strip_h / 2)))
	grain.position = Vector2.ZERO
	grain.size = strip.size
	grain.stretch_mode = TextureRect.STRETCH_SCALE
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(grain)
	vbox.move_to_front()

	_add_peel_shadows()
	_add_vignettes()
	_add_inner_frame()
	_add_tube(cover, body_x, body_y, scroll_w, TUBE_H)
	_add_tube(cover, body_x, body_y + scroll_h - TUBE_H, scroll_w, TUBE_H)

func _add_title_block(parent: Control) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(title)

	var rule := _make_rule(120)
	parent.add_child(rule)

func _make_rule(width: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var line_l := ColorRect.new()
	line_l.color = Color(0.4, 0.3, 0.17, 0.55)
	line_l.custom_minimum_size = Vector2(width, 2)
	line_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line_l)

	var diamond := _make_diamond(6.0)
	diamond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(diamond)
	return row

func _make_diamond(px: float) -> Control:
	var d := Panel.new()
	d.custom_minimum_size = Vector2(px, px)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.pivot_offset = Vector2(px * 0.5, px * 0.5)
	d.rotation = 45.0
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.5, 0.38, 0.22, 0.9)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.35, 0.26, 0.15, 0.9)
	ds.set_corner_radius_all(2)
	d.add_theme_stylebox_override("panel", ds)
	return d

func _add_peel_shadows() -> void:
	var shadow := Color(0.3, 0.2, 0.1, 0.25)
	for side in 2:
		var peel := Panel.new()
		var w := 8.0
		peel.position = Vector2(0.0 if side == 0 else window.size.x - w, 6)
		peel.size = Vector2(w, window.size.y - 12)
		peel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ps := StyleBoxFlat.new()
		ps.bg_color = shadow
		ps.set_corner_radius_all(4)
		peel.add_theme_stylebox_override("panel", ps)
		window.add_child(peel)

func _fade_texture(top: bool) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([
		Color(0.16, 0.1, 0.05, 0.42),
		Color(0.16, 0.1, 0.05, 0.0)
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_LINEAR
	if top:
		gt.fill_from = Vector2(0.5, 0.0)
		gt.fill_to = Vector2(0.5, 1.0)
	else:
		gt.fill_from = Vector2(0.5, 1.0)
		gt.fill_to = Vector2(0.5, 0.0)
	return gt

func _add_vignettes() -> void:
	var fade_h := 86.0
	for fade in 2:
		var band := TextureRect.new()
		band.texture = _fade_texture(fade == 0)
		band.position = Vector2(0, 0.0 if fade == 0 else window.size.y - fade_h)
		band.size = Vector2(window.size.x, fade_h)
		band.stretch_mode = TextureRect.STRETCH_SCALE
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.add_child(band)

func _add_inner_frame() -> void:
	var frame := Panel.new()
	frame.position = Vector2(8, 10)
	frame.size = Vector2(window.size.x - 16, window.size.y - 20)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.border_color = Color(0.34, 0.26, 0.15, 0.42)
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", fs)
	window.add_child(frame)

func _add_tube(parent: Control, tx: float, ty: float, tw: float, th: float) -> void:
	var base := Panel.new()
	base.position = Vector2(tx - 3, ty)
	base.size = Vector2(tw + 6, th)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = TUBE_MID
	bs.border_color = TUBE_DARK
	bs.set_border_width_all(3)
	bs.set_corner_radius_all(int(th * 0.5))
	bs.shadow_color = Color(0, 0, 0, 0.35)
	bs.shadow_size = 6
	base.add_theme_stylebox_override("panel", bs)
	parent.add_child(base)

	var hl := Panel.new()
	hl.position = Vector2(tx + 10, ty + 4)
	hl.size = Vector2(tw - 20, th - 8)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hs := StyleBoxFlat.new()
	hs.bg_color = TUBE_HIGH
	hs.border_color = Color(0.98, 0.92, 0.78, 0.85)
	hs.set_border_width_all(1)
	hs.set_corner_radius_all(int(th * 0.5))
	hl.add_theme_stylebox_override("panel", hs)
	parent.add_child(hl)

	var seam_count := int(tw / 26.0)
	if seam_count < 2:
		seam_count = 2
	for i in range(seam_count):
		var sx := tx + 12 + i * (tw - 24) / float(seam_count - 1)
		var seam := ColorRect.new()
		seam.position = Vector2(sx, ty + 5)
		seam.size = Vector2(2, th - 10)
		seam.color = Color(0.3, 0.22, 0.14, 0.22)
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(seam)

	var cap_w := th * 1.3
	var cap_h := th * 0.92
	var cap_y := ty + (th - cap_h) * 0.5
	_add_cap(parent, tx - 3, cap_y, cap_w, cap_h)
	_add_cap(parent, tx + tw + 2, cap_y, cap_w, cap_h)

func _add_cap(parent: Control, cx: float, cy: float, cw: float, ch: float) -> void:
	var cap := Panel.new()
	cap.position = Vector2(cx, cy)
	cap.size = Vector2(cw, ch)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cs := StyleBoxFlat.new()
	cs.bg_color = PCC_DARK
	cs.border_color = TUBE_DARK
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(int(ch * 0.5))
	cap.add_theme_stylebox_override("panel", cs)
	parent.add_child(cap)

	var dot := Panel.new()
	dot.position = Vector2(cx + cw * 0.5 - ch * 0.18, cy + ch * 0.5 - ch * 0.18)
	dot.size = Vector2(ch * 0.36, ch * 0.36)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.72, 0.62, 0.45, 1.0)
	ds.border_color = Color(0.4, 0.3, 0.18, 0.8)
	ds.set_border_width_all(1)
	ds.set_corner_radius_all(int(ch * 0.18))
	dot.add_theme_stylebox_override("panel", ds)
	parent.add_child(dot)