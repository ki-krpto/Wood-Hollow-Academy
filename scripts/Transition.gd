extends CanvasLayer

enum State { FADE_IN, WAIT, FADE_OUT, DONE }

var state: int = State.FADE_IN
var progress: float = 0.0
var callback: Callable

@onready var color_rect = $ColorRect

func _ready():
	color_rect.color = Color.BLACK
	color_rect.modulate.a = 0.0

func _process(delta):
	match state:
		State.FADE_IN:
			progress += delta * 2.0
			color_rect.modulate.a = progress
			if progress >= 1.0:
				state = State.WAIT
				progress = 0.0
				if callback.is_valid():
					callback.call()
		State.WAIT:
			progress += delta
			if progress >= 0.5:
				state = State.FADE_OUT
				progress = 0.0
		State.FADE_OUT:
			progress += delta * 2.0
			color_rect.modulate.a = 1.0 - progress
			if progress >= 1.0:
				state = State.DONE
				queue_free()

static func run(callable: Callable):
	var transition = preload("res://scripts/Transition.tscn").instantiate()
	transition.callback = callable
	get_tree().current_scene.add_child(transition)
