extends CharacterBody2D

const TILE_SIZE = 32
const SPEED = 100.0
const MOVE_DELAY = 0.1

var moving = false
var target = Vector2.ZERO
var move_dir = Vector2.ZERO
var buffered_dir = Vector2.ZERO
var move_timer = 0.0
var move_start = Vector2.ZERO
var move_progress = 0.0

func _ready():
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	target = position

func _physics_process(delta):
	move_timer = max(move_timer - delta, 0.0)

	var held = Vector2.ZERO
	if Input.is_action_pressed("right"):
		held = Vector2.RIGHT
	elif Input.is_action_pressed("left"):
		held = Vector2.LEFT
	elif Input.is_action_pressed("up"):
		held = Vector2.UP
	elif Input.is_action_pressed("down"):
		held = Vector2.DOWN

	if moving:
		var tapped = Vector2.ZERO
		if Input.is_action_just_pressed("right"):
			tapped = Vector2.RIGHT
		elif Input.is_action_just_pressed("left"):
			tapped = Vector2.LEFT
		elif Input.is_action_just_pressed("up"):
			tapped = Vector2.UP
		elif Input.is_action_just_pressed("down"):
			tapped = Vector2.DOWN

		if tapped != Vector2.ZERO:
			buffered_dir = tapped

		move_progress += delta * (SPEED / TILE_SIZE)
		if move_progress >= 1.0:
			position = target
			moving = false
			move_timer = MOVE_DELAY
		else:
			var eased = _ease_in_out(move_progress)
			var desired = move_start.lerp(target, eased)
			var step = desired - position
			if move_and_collide(step):
				moving = false
				move_dir = Vector2.ZERO
				buffered_dir = Vector2.ZERO
				move_timer = MOVE_DELAY

	if not moving and move_timer <= 0.0:
		var next = Vector2.ZERO

		if buffered_dir != Vector2.ZERO:
			next = buffered_dir
			buffered_dir = Vector2.ZERO
		elif held != Vector2.ZERO:
			next = held

		if next != Vector2.ZERO:
			if not move_and_collide(next * TILE_SIZE, true):
				move_dir = next
				target = position + move_dir * TILE_SIZE
				move_start = position
				move_progress = 0.0
				moving = true
			else:
				move_dir = Vector2.ZERO

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
