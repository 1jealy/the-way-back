class_name Dog
extends CharacterBody2D
## 하늘이. 하윤 뒤를 따라다니고, 부탁 자리(AskSpot)에서 F를 누르면 그 자리의 행동을 한다.
## 합류 전(HIDDEN)에는 보이지도 움직이지도 않는다. 만남 장면(DogMeeting) 동안은 MEETING:
## 보이지만 따라오지 않고, 만남 부품이 정해 준 자리로만 움직인다. 담당: A(게임플레이).

signal joined
signal task_started(spot: AskSpot)
signal task_finished(spot: AskSpot)
## MEETING에서 meet_move_to로 보낸 자리에 닿았을 때.
signal meet_arrived
## 하윤이 오래 서 있어서 다음 목표 쪽을 알려 줄 때. target_x는 그 목표.
signal hinted(target_x: float)

enum State { HIDDEN, MEETING, FOLLOW, SIT, HINT, TASK_GO, TASK_ACT, HOLD, TASK_RETURN }

const JOIN_FLAG := &"dog_joined"
## 하윤 뒤 이 거리에 서려고 한다. 설 자리에서 DEADBAND 안이면 멈춘다 → 80~120px.
const FOLLOW_GAP := 100.0
const DEADBAND := 20.0
const FOLLOW_MAX_SPEED := 300.0
## 멀어진 거리에 비례해 빨라진다(가까우면 천천히 붙는다).
const FOLLOW_GAIN := 3.0
const TASK_SPEED := 260.0
const MEET_SPEED := 340.0
## 하윤이 이만큼 가만히 있으면 다음 목표 쪽을 알려 준다(같은 정지 동안 한 번).
const HINT_DELAY := 8.0
## 목표 쪽으로 하윤보다 최대 이만큼 앞서 간다.
const HINT_STEP := 160.0
const HINT_LOOK_SECONDS := 1.5
const HINT_SPEED := 170.0
const SIT_DELAY := 2.0
const ACT_SECONDS := 0.8
## 하윤 조작을 막는 이유 이름(Player.lock).
const LOCK := &"dog_task"

@export var gravity: float = 2400.0

var state: State = State.HIDDEN
## 1 = 오른쪽, -1 = 왼쪽.
var facing: int = 1

var _player: Player
var _spot: AskSpot
var _idle: float = 0.0
var _act_left: float = 0.0
var _meet_goal_x: float = 0.0
var _meet_moving: bool = false
var _player_still: float = 0.0
var _hinted: bool = false
var _hint_x: float = 0.0
var _hint_left: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _stand: Node2D = $Visual/Stand
@onready var _sit: Node2D = $Visual/Sit
@onready var _paw: CanvasItem = $PawMark


func _ready() -> void:
	add_to_group("dog")
	_refresh_visuals()


## 하윤과 함께 다니기 시작한다. 플래그를 세워 장소를 옮겨도 유지된다.
## teleport가 false면 지금 자리에서 걸어서 하윤 뒤로 간다(만남 장면 끝).
func join(player: Player, teleport: bool = true) -> void:
	_player = player
	state = State.FOLLOW
	_idle = 0.0
	GameState.set_flag(JOIN_FLAG)
	if teleport:
		place_behind(player)
	joined.emit()


func is_joined() -> bool:
	return state != State.HIDDEN and state != State.MEETING


## 만남 장면을 시작한다. at에 앉아서 하윤 쪽(왼쪽)을 본다.
func begin_meeting(at: Vector2) -> void:
	if is_joined():
		return
	state = State.MEETING
	global_position = at
	velocity = Vector2.ZERO
	facing = -1
	_meet_goal_x = at.x
	_meet_moving = false
	_refresh_visuals()


## MEETING에서 x까지 달려간다. 닿으면 앉고 meet_arrived가 온다.
func meet_move_to(x: float) -> void:
	_meet_goal_x = x
	_meet_moving = true


func is_meet_moving() -> bool:
	return _meet_moving


func is_busy() -> bool:
	return state in [State.TASK_GO, State.TASK_ACT, State.HOLD, State.TASK_RETURN]


## 장소를 옮길 때 부른다. 하던 부탁은 취소한다.
func place_behind(player: Player) -> void:
	_player = player
	if state == State.HIDDEN:
		return
	if state == State.MEETING:
		# 만남 장면이 있던 장소를 떠났다. 그 장소에 다시 오면 만남 부품이 다시 부른다.
		state = State.HIDDEN
		_meet_moving = false
		_refresh_visuals()
		return
	if is_busy():
		_player.unlock(LOCK)
	_spot = null
	state = State.FOLLOW
	_idle = 0.0
	global_position = Vector2(_follow_x(), player.global_position.y)
	velocity = Vector2.ZERO
	_refresh_visuals()


## 지금 F를 누르면 쓸 수 있는 부탁 자리. 없으면 null.
func available_spot() -> AskSpot:
	if not is_joined() or is_busy():
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
		_player.lock(LOCK)
	spot.started.emit()
	task_started.emit(spot)


func _physics_process(delta: float) -> void:
	if state == State.HIDDEN:
		return
	_track_player_still(delta)
	var goal_x := global_position.x
	var max_speed := 0.0
	match state:
		State.MEETING:
			if _meet_moving:
				goal_x = _meet_goal_x
				max_speed = MEET_SPEED
				if absf(goal_x - global_position.x) < 2.0:
					_meet_moving = false
					meet_arrived.emit()
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
			if _player_still >= HINT_DELAY and not _hinted:
				_start_hint()
		State.HINT:
			if absf(_player.velocity.x) > 1.0:
				state = State.FOLLOW
			else:
				goal_x = _hint_x
				max_speed = HINT_SPEED
				if absf(goal_x - global_position.x) < 2.0:
					_hint_left -= delta
					if _hint_left <= 0.0:
						state = State.FOLLOW
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


## 하윤이 움직이지 않고(조작 가능한 채로) 서 있는 시간. 움직이면 다시 알려 줄 수 있다.
func _track_player_still(delta: float) -> void:
	if _player == null or not is_joined():
		return
	if absf(_player.velocity.x) > 1.0:
		_player_still = 0.0
		_hinted = false
	elif _player.controls_enabled:
		_player_still += delta


## 다음 목표: 하윤보다 오른쪽에 있는, 아직 쓰지 않은 부탁 자리 · 지도 체크 · 한 번만 조사 대상 중 가장 가까운 것.
## 없으면 장소 끝 지점.
func hint_target_x() -> float:
	var px := _player.global_position.x
	var best := INF
	for node in get_tree().get_nodes_in_group("ask_spot"):
		var spot := node as AskSpot
		if spot and not (spot.one_shot and spot.used) and spot.global_position.x > px + 40.0:
			best = minf(best, spot.global_position.x)
	for node in get_tree().get_nodes_in_group("interactable"):
		var it := node as Interactable
		if it and not it.used and (it.map_circle > 0 or it.one_shot) and it.global_position.x > px + 40.0:
			best = minf(best, it.global_position.x)
	if best == INF:
		var place := get_tree().get_first_node_in_group("place") as Place
		best = place.width - 120.0 if place else px + HINT_STEP
	return best


func _start_hint() -> void:
	_hinted = true
	var target := hint_target_x()
	var px := _player.global_position.x
	_hint_x = px + clampf(target - px, -HINT_STEP, HINT_STEP)
	_hint_left = HINT_LOOK_SECONDS
	state = State.HINT
	hinted.emit(target)


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
	_player.unlock(LOCK)
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
	elif state == State.MEETING:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p:
			facing = 1 if p.global_position.x >= global_position.x else -1


func _refresh_visuals() -> void:
	visible = state != State.HIDDEN
	_visual.scale.x = facing
	var sitting := state == State.SIT or (state == State.MEETING and not _meet_moving)
	_stand.visible = not sitting
	_sit.visible = sitting
	_paw.visible = available_spot() != null
