class_name Player
extends CharacterBody2D
## 하윤. 좌우로만 걷는다. 원점은 발밑이다.
## 담당: A(게임플레이).

## 걷는 속도(px/초). 화면 하나(1920px)를 약 6.4초에 지난다. 장소 폭은 200 기준으로 잡았다(#29, 2026-11-21에 300).
@export var walk_speed: float = 300.0
@export var gravity: float = 2400.0

## 조작을 막고 있는 이유들. 하나라도 있으면 걷지 않는다.
## 여러 곳(장소 전환, 하늘이 부탁, 대사 상자)이 각자 걸고 각자 푼다 — 서로 덮어쓰지 않게.
var _locks: Dictionary = {}
var controls_enabled: bool:
	get:
		return _locks.is_empty()
## 1 = 오른쪽, -1 = 왼쪽.
var facing: int = 1
## 지금 자세(#98): stand / crouch(쪼그려 앉기) / sit(벤치) / sit_floor(바닥).
var pose: StringName = &"stand"
## 서 있지 않으면 참(쪼그리기·앉기 모두).
var crouching: bool:
	get:
		return pose != &"stand"

## 이만큼 걸을 때마다 발소리 하나(px). 300px/초면 약 0.37초.
const STEP_DISTANCE := 110.0

var _step_left: float = STEP_DISTANCE * 0.5
## 연출용 자동 걷기(auto_move_to). 조작 잠금과 상관없이 이 x까지 간다.
var _auto_x: float = NAN
var _auto_speed: float = 0.0

## 손목 만지기(대기 동작, 장면표 "손목 만지기"): 이만큼 가만히 서 있으면 처음 나오고,
## 그 뒤로는 WRIST_AGAIN 사이 어느 때에 또 나온다. 벤치에 앉아 있을 때도 나온다(2-5, 3-3).
const WRIST_AFTER := 5.0
const WRIST_AGAIN := Vector2(9.0, 15.0)
## 손목 만지기를 막지 않는 잠금 이유(벤치에 앉아 있는 동안).
const WRIST_OK_LOCKS := [&"sit"]
var _still: float = 0.0
var _wrist_next: float = WRIST_AFTER

## auto_move_to로 보낸 곳에 닿았을 때.
signal auto_arrived
## 손목 만지기 대기 동작을 시작했을 때.
signal wrist_touched
var _steps: AudioStreamPlayer

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("player")
	_steps = AudioStreamPlayer.new()
	_steps.name = "Steps"
	_steps.bus = SoundBank.BUS_SFX
	_steps.volume_db = -4.0
	add_child(_steps)


## reason 이름으로 조작을 막는다. 같은 reason으로 unlock해야 풀린다.
func lock(reason: StringName) -> void:
	_locks[reason] = true
	velocity.x = 0.0


func unlock(reason: StringName) -> void:
	_locks.erase(reason)


func is_locked_by(reason: StringName) -> bool:
	return _locks.has(reason)


## 자세를 바꾼다(stand / crouch / sit / sit_floor). 하윤 컷아웃이 있으면 관절로 앉고,
## 없으면(그림이 없을 때) 키를 줄여 보여 준다. 원점이 발밑이라 발은 그대로다.
func set_pose(p: StringName) -> void:
	pose = p
	var rig := _rig()
	if rig:
		rig.set_pose(p)
		_visual.scale.y = 1.0
	else:
		_visual.scale.y = 1.0 if p == &"stand" else 0.62


## 쪼그려 앉기 / 일어서기.
func set_crouching(on: bool) -> void:
	set_pose(&"crouch" if on else &"stand")


## 돌 던지기 팔 동작(5-4). 손을 놓는 순간에 돌아온다. 컷아웃이 없으면 바로 돌아온다.
func play_throw() -> void:
	var rig := _rig()
	if rig:
		await rig.play_throw()


## 던진 물건이 출발할 손 자리(전역 좌표).
func hand_point() -> Vector2:
	var rig := _rig()
	if rig:
		return rig.hand_point()
	return global_position + Vector2(36.0 * facing, -120.0)


func _rig() -> Node:
	var rig := _visual.get_node_or_null("Rig")
	return rig if rig and rig.has_method("set_pose") else null


## 연출용: 그 쪽을 본다(1 = 오른쪽, -1 = 왼쪽).
func face(dir: int) -> void:
	facing = 1 if dir >= 0 else -1
	_visual.scale.x = facing


## 연출용: 조작과 상관없이 x까지 speed로 걸어(달려) 간다. 닿으면 auto_arrived.
func auto_move_to(x: float, speed: float = 0.0) -> void:
	_auto_x = x
	_auto_speed = speed if speed > 0.0 else walk_speed


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not controls_enabled:
		return
	var target := Interactable.nearest_available(get_tree(), global_position)
	if target:
		get_viewport().set_input_as_handled()
		target.interact()


func _physics_process(delta: float) -> void:
	var direction := 0.0
	var speed := walk_speed
	if not is_nan(_auto_x):
		var gap := _auto_x - global_position.x
		if absf(gap) <= _auto_speed * delta:
			global_position.x = _auto_x
			_auto_x = NAN
			auto_arrived.emit()
		else:
			direction = signf(gap)
			speed = _auto_speed
	elif controls_enabled:
		direction = Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	if direction != 0.0:
		facing = 1 if direction > 0.0 else -1
		_visual.scale.x = facing
	_update_steps(delta)
	_update_idle(delta)


## 가만히 서(앉아) 있으면 가끔 손목을 만진다.
func _update_idle(delta: float) -> void:
	var rig := _rig()
	var calm := absf(velocity.x) < 1.0 and is_nan(_auto_x) and (pose == &"stand" or pose == &"sit")
	for reason in _locks:
		if reason not in WRIST_OK_LOCKS:
			calm = false
	if not calm or rig == null or not rig.has_method("play_wrist_touch"):
		_still = 0.0
		_wrist_next = WRIST_AFTER
		return
	_still += delta
	if _still >= _wrist_next and not rig.is_gesturing():
		_wrist_next = _still + randf_range(WRIST_AGAIN.x, WRIST_AGAIN.y)
		rig.play_wrist_touch()
		wrist_touched.emit()


func _update_steps(delta: float) -> void:
	if not is_on_floor() or absf(velocity.x) < 1.0:
		_step_left = STEP_DISTANCE * 0.5  # 다시 걸으면 반 걸음 만에 첫 소리
		return
	_step_left -= absf(velocity.x) * delta
	if _step_left > 0.0:
		return
	_step_left += STEP_DISTANCE
	var place := get_tree().get_first_node_in_group("place") as Place
	var surface := place.surface_at(global_position.x) if place else &"dirt"
	var stream := SoundBank.pick("step_%s_" % surface)
	if stream:
		_steps.stream = stream
		_steps.pitch_scale = randf_range(0.94, 1.06)
		_steps.play()
