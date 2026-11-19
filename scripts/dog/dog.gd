class_name Dog
extends CharacterBody2D
## 하늘이. 하윤 뒤를 따라다니고, 부탁 자리(AskSpot)에서 F를 누르면 그 자리의 행동을 한다.
## 합류 전(HIDDEN)에는 보이지도 움직이지도 않는다. 담당: A(게임플레이).

signal joined
signal task_started(spot: AskSpot)
signal task_finished(spot: AskSpot)

enum State { HIDDEN, FOLLOW, SIT, TASK_GO, TASK_ACT, HOLD, TASK_RETURN }

const JOIN_FLAG := &"dog_joined"
## 하윤 뒤 이 거리에 서려고 한다. 설 자리에서 DEADBAND 안이면 멈춘다 → 80~120px.
const FOLLOW_GAP := 100.0
const DEADBAND := 20.0
const FOLLOW_MAX_SPEED := 300.0
## 멀어진 거리에 비례해 빨라진다(가까우면 천천히 붙는다).
const FOLLOW_GAIN := 3.0
const TASK_SPEED := 260.0
const SIT_DELAY := 2.0
const ACT_SECONDS := 0.8

@export var gravity: float = 2400.0

var state: State = State.HIDDEN
## 1 = 오른쪽, -1 = 왼쪽.
var facing: int = 1

var _player: Player
var _spot: AskSpot
var _idle: float = 0.0
var _act_left: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _stand: Node2D = $Visual/Stand
@onready var _sit: Node2D = $Visual/Sit
@onready var _paw: CanvasItem = $PawMark


func _ready() -> void:
	add_to_group("dog")
	_refresh_visuals()


## 하윤과 함께 다니기 시작한다. 플래그를 세워 장소를 옮겨도 유지된다.
func join(player: Player) -> void:
	_player = player
	state = State.FOLLOW
	GameState.set_flag(JOIN_FLAG)
	place_behind(player)
	joined.emit()


func is_joined() -> bool:
	return state != State.HIDDEN


func is_busy() -> bool:
	return state in [State.TASK_GO, State.TASK_ACT, State.HOLD, State.TASK_RETURN]


## 장소를 옮길 때 부른다. 하던 부탁은 취소한다.
func place_behind(player: Player) -> void:
	_player = player
	if state == State.HIDDEN:
		return
	if is_busy():
		_player.set_controls_enabled(true)
	_spot = null
	state = State.FOLLOW
	_idle = 0.0
	global_position = Vector2(_follow_x(), player.global_position.y)
	velocity = Vector2.ZERO
	_refresh_visuals()


## 지금 F를 누르면 쓸 수 있는 부탁 자리. 없으면 null.
func available_spot() -> AskSpot:
	if state == State.HIDDEN or is_busy():
		return null
	for node in get_tree().get_nodes_in_group("ask_spot"):
		var spot := node as AskSpot
		if spot and spot.is_inside_tree() and spot.is_available():
			return spot
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ask_dog"):
		return
	var spot := available_spot()
	if spot:
		_start_task(spot)
		get_viewport().set_input_as_handled()


func _start_task(spot: AskSpot) -> void:
	_spot = spot
	state = State.TASK_GO
	if spot.action != AskSpot.Action.HOLD:
		_player.set_controls_enabled(false)
	spot.started.emit()
	task_started.emit(spot)


func _physics_process(delta: float) -> void:
	if state == State.HIDDEN:
		return
	var goal_x := global_position.x
	var max_speed := 0.0
	match state:
		State.FOLLOW, State.SIT:
			goal_x = _follow_x()
			if absf(goal_x - global_position.x) > DEADBAND:
				max_speed = minf(FOLLOW_MAX_SPEED, absf(goal_x - global_position.x) * FOLLOW_GAIN)
				state = State.FOLLOW
				_idle = 0.0
			else:
				goal_x = global_position.x
				_idle = _idle + delta if is_zero_approx(_player.velocity.x) else 0.0
				if _idle >= SIT_DELAY:
					state = State.SIT
		State.TASK_GO:
			goal_x = _spot.target_position().x
			max_speed = TASK_SPEED
			if absf(goal_x - global_position.x) < 2.0:
				_arrive()
		State.TASK_ACT:
			_act_left -= delta
			if _act_left <= 0.0:
				state = State.TASK_RETURN
		State.HOLD:
			if _player.global_position.x >= _spot.release_x():
				state = State.TASK_RETURN
		State.TASK_RETURN:
			goal_x = _follow_x()
			max_speed = TASK_SPEED
			if absf(goal_x - global_position.x) <= DEADBAND:
				_finish_task()

	_move_toward_x(goal_x, max_speed, delta)
	_refresh_visuals()


func _arrive() -> void:
	match _spot.action:
		AskSpot.Action.HOLD:
			state = State.HOLD
		_:
			state = State.TASK_ACT
			_act_left = ACT_SECONDS
	if not _spot.grants_flag.is_empty():
		GameState.set_flag(_spot.grants_flag)
	_spot.acted.emit()


func _finish_task() -> void:
	var spot := _spot
	spot.used = true
	_spot = null
	state = State.FOLLOW
	_idle = 0.0
	_player.set_controls_enabled(true)
	spot.completed.emit()
	task_finished.emit(spot)


func _follow_x() -> float:
	return _player.global_position.x - _player.facing * FOLLOW_GAP


func _move_toward_x(goal_x: float, max_speed: float, delta: float) -> void:
	var gap := goal_x - global_position.x
	var speed := minf(max_speed, absf(gap) / delta) if max_speed > 0.0 else 0.0
	velocity.x = signf(gap) * speed
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1
	elif state in [State.FOLLOW, State.SIT] and _player:
		facing = 1 if _player.global_position.x >= global_position.x else -1


func _refresh_visuals() -> void:
	visible = state != State.HIDDEN
	_visual.scale.x = facing
	_stand.visible = state != State.SIT
	_sit.visible = state == State.SIT
	_paw.visible = available_spot() != null
