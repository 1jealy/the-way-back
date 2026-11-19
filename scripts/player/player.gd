class_name Player
extends CharacterBody2D
## 하윤. 좌우로만 걷는다. 원점은 발밑이다.
## 담당: A(게임플레이).

## 걷는 속도(px/초). 화면 하나(1920px)를 약 10초에 지난다 — 장면표 시간의 기준.
@export var walk_speed: float = 200.0
@export var gravity: float = 2400.0

var controls_enabled: bool = true
## 1 = 오른쪽, -1 = 왼쪽.
var facing: int = 1

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("player")


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		velocity.x = 0.0


func _physics_process(delta: float) -> void:
	var direction := 0.0
	if controls_enabled:
		direction = Input.get_axis("move_left", "move_right")
	velocity.x = direction * walk_speed
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	if direction != 0.0:
		facing = 1 if direction > 0.0 else -1
		_visual.scale.x = facing
