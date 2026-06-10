extends CharacterBody2D


const SPEED = 300.0
var moveDir = Vector2(0,0)


func _physics_process(delta: float) -> void:
	movement(delta)

func movement(d):
	if Input.is_action_pressed("right"):
		moveDir.x = 1
	if Input.is_action_pressed("left"):
		moveDir.x = -1
	if Input.is_action_pressed("up"):
		moveDir.y = -1
	if Input.is_action_pressed("down"):
		moveDir.y = 1
		
	if !Input.is_action_pressed("right") and !Input.is_action_pressed("left"):
		moveDir.x = 0
	if !Input.is_action_pressed("up") and !Input.is_action_pressed("down"):
		moveDir.y = 0
		
	move_and_collide(moveDir.normalized() * SPEED * d)
