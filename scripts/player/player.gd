class_name Player
extends CharacterBody2D
## 하윤. 좌우로만 걷는다. 원점은 발밑이다.
## 담당: A(게임플레이).

## 걷는 속도(px/초). 화면 하나(1920px)를 약 7.7초에 지난다. 장소 폭은 200 기준으로 잡았다(#29).
@export var walk_speed: float = 250.0
@export var gravity: float = 2400.0

## 조작을 막고 있는 이유들. 하나라도 있으면 걷지 않는다.
## 여러 곳(장소 전환, 하늘이 부탁, 대사 상자)이 각자 걸고 각자 푼다 — 서로 덮어쓰지 않게.
var _locks: Dictionary = {}
var controls_enabled: bool:
	get:
		return _locks.is_empty()
## 1 = 오른쪽, -1 = 왼쪽.
var facing: int = 1
var crouching: bool = false

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("player")


## reason 이름으로 조작을 막는다. 같은 reason으로 unlock해야 풀린다.
func lock(reason: StringName) -> void:
	_locks[reason] = true
	velocity.x = 0.0


func unlock(reason: StringName) -> void:
	_locks.erase(reason)


func is_locked_by(reason: StringName) -> bool:
	return _locks.has(reason)


## 쪼그려 앉기(회색 네모 단계에서는 키를 줄여 보여 준다). 원점이 발밑이라 발은 그대로다.
func set_crouching(on: bool) -> void:
	crouching = on
	_visual.scale.y = 0.62 if on else 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not controls_enabled:
		return
	var target := Interactable.nearest_available(get_tree(), global_position)
	if target:
		get_viewport().set_input_as_handled()
		target.interact()


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
