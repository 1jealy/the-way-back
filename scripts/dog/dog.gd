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
## 연출(엔딩 등)에서 script_move_to로 보낸 곳에 닿았을 때.
signal script_arrived
## 하윤이 오래 서 있어서 다음 목표 쪽을 알려 줄 때. target_x는 그 목표.
signal hinted(target_x: float)

enum State { HIDDEN, MEETING, FOLLOW, SIT, HINT, TASK_GO, TASK_ACT, HOLD, TASK_RETURN, SCRIPTED }

const JOIN_FLAG := &"dog_joined"
## 부탁 자리에서 머리 위 표시에 띄우는 말(행동마다). 0 가져와 / 1 냄새 / 2 기다려 = AskSpot.Action 순서.
const ASK_HINTS := {0: "가져와", 1: "냄새 맡아 줘", 2: "기다려"}
## 하윤 뒤 이 거리에 서려고 한다. 설 자리에서 DEADBAND 안이면 멈춘다 → 120~180px(#92에서 인물 1.5배).
const FOLLOW_GAP := 150.0
const DEADBAND := 30.0
const FOLLOW_MAX_SPEED := 450.0
## 멀어진 거리에 비례해 빨라진다(가까우면 천천히 붙는다).
const FOLLOW_GAIN := 3.0
const TASK_SPEED := 390.0
const MEET_SPEED := 510.0
## 하윤이 이만큼 가만히 있으면 다음 목표 쪽을 알려 준다(같은 정지 동안 한 번).
const HINT_DELAY := 8.0
## 목표 쪽으로 하윤보다 최대 이만큼 앞서 간다.
const HINT_STEP := 160.0
const HINT_LOOK_SECONDS := 1.5
const HINT_SPEED := 255.0
const SIT_DELAY := 2.0
const ACT_SECONDS := 0.8
## 하윤 조작을 막는 이유 이름(Player.lock).
const LOCK := &"dog_task"

@export var gravity: float = 2400.0

var state: State = State.HIDDEN
## 1 = 오른쪽, -1 = 왼쪽.
var facing: int = 1
## 돌아서는 데 걸리는 시간(초, #120 모션 손질).
const TURN_SECONDS := 0.16
## 쓰다듬기(#120): 하윤 앞 이만큼에 와서 앉고, PET_SECONDS 동안 쓰다듬는다. 가만히 서 있으면 LOOK_UP_AFTER초 뒤 올려다본다.
const PET_GAP := 175.0
const PET_SECONDS := 2.6
const LOOK_UP_AFTER := 3.5
var petting: bool = false
signal pet_started

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
@onready var _paw: PawMark = $PawMark


## 발톱 소리가 들리는 장소. 장면표: 간이역·숲에서만, 강가부터는 없다(복선).
const CLAW_PLACES := [&"station", &"forest"]
## 이만큼 걸을 때마다 발톱 소리 하나(px).
const CLAW_DISTANCE := 75.0

var _claw_left: float = CLAW_DISTANCE
var _script_goal_x: float = 0.0
var _script_speed: float = 0.0
var _script_moving: bool = false
var _claws: AudioStreamPlayer
## 하늘이 컷아웃(#101). 그림이 있으면 회색 네모(Stand/Sit) 대신 이것이 서고 앉는다.
var _rig: Node2D


func _ready() -> void:
	add_to_group("dog")
	_claws = AudioStreamPlayer.new()
	_claws.name = "Claws"
	_claws.bus = SoundBank.BUS_SFX
	_claws.volume_db = -8.0
	add_child(_claws)
	if DogRig.available():
		_rig = DogRig.new()
		_rig.name = "Rig"
		_visual.add_child(_rig)
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
	# 연출(작은 순간·엔딩) 중에는 부탁을 받지 않는다. 받으면 연출이 끊기고 script_arrived가 영영 안 온다(#85).
	if not is_joined() or is_busy() or (state == State.SCRIPTED and not petting):
		return null
	# 하윤이 대사·지도·벤치·연출로 막혀 있으면 부탁도 안 받는다. 받으면 돌아와서 띄우는 대사가
	# 읽던 대사를 덮어썼다(#107).
	if _player and not _player.controls_enabled:
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
	elif can_pet():
		pet()
		get_viewport().set_input_as_handled()


func _start_task(spot: AskSpot) -> void:
	petting = false  # 쓰다듬던 중이면 부탁이 먼저(#120)
	_spot = spot
	state = State.TASK_GO
	if spot.action != AskSpot.Action.HOLD:
		_player.lock(LOCK)
	spot.started.emit()
	task_started.emit(spot)


func _physics_process(delta: float) -> void:
	if state == State.HIDDEN:
		return
	if hopping:
		return  # 디딤돌 뛰기(#147): 자리는 hop_to의 트윈이 정한다(땅·중력 없이)
	_track_player_still(delta)
	# 하윤이 가만히 서 있으면 앉아서 올려다본다(#120). 쓰다듬는 동안에도.
	if _rig and _rig.has_method("set_look_up"):
		_rig.set_look_up(petting or (state == State.SIT and _player_still > LOOK_UP_AFTER))
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
		State.SCRIPTED:
			if _script_moving:
				goal_x = _script_goal_x
				max_speed = _script_speed
				if absf(goal_x - global_position.x) < 2.0:
					_script_moving = false
					script_arrived.emit()
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
	# 아직 안 쓴 부탁 자리를 지나쳐 왔으면 그쪽(뒤)을 가리킨다. 부탁은 진행에 필요한데, 지나친 뒤에는
	# 앞쪽 목표(잠긴 문·장소 끝)만 가리켜 되돌아가라는 신호가 없었다(간이역 3-5, #107).
	var behind := -INF
	for node in get_tree().get_nodes_in_group("ask_spot"):
		var spot := node as AskSpot
		if spot and not (spot.one_shot and spot.used) and spot.global_position.x < px - spot.size.x * 0.5:
			behind = maxf(behind, spot.global_position.x)
	if behind != -INF:
		return behind
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
	if _spot.action == AskSpot.Action.SNIFF:
		_bark()
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
	if not spot.lines.is_empty():
		var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
		if box:
			box.play(spot.lines)


func _follow_x() -> float:
	return _player.global_position.x - _player.facing * FOLLOW_GAP


func _move_toward_x(goal_x: float, max_speed: float, delta: float) -> void:
	var gap := goal_x - global_position.x
	var speed := minf(max_speed, absf(gap) / delta) if max_speed > 0.0 else 0.0
	velocity.x = signf(gap) * speed
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	_update_claws(delta)
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
	# 돌아설 때 TURN_SECONDS에 걸쳐 돈다(물리 프레임에서만. 연출 호출은 바로)
	if Engine.is_in_physics_frame():
		_visual.scale.x = move_toward(_visual.scale.x, facing, get_physics_process_delta_time() * 2.0 / TURN_SECONDS)
	else:
		_visual.scale.x = facing
	var sitting := state == State.SIT or (state == State.MEETING and not _meet_moving) \
			or (state == State.SCRIPTED and not _script_moving)
	if _rig:
		_stand.visible = false
		_sit.visible = false
		_rig.set_pose(_rig_pose(sitting))
	else:
		_stand.visible = not sitting
		_sit.visible = sitting
	var ask := available_spot()
	_paw.show_hint(ask != null, ASK_HINTS.get(ask.action, "") if ask else "")


func _update_claws(delta: float) -> void:
	if not visible or absf(velocity.x) < 1.0 or GameState.current_place not in CLAW_PLACES:
		_claw_left = CLAW_DISTANCE
		return
	_claw_left -= absf(velocity.x) * delta
	if _claw_left > 0.0:
		return
	_claw_left += CLAW_DISTANCE
	var stream := SoundBank.pick("sfx_dog_claw_")
	if stream:
		_claws.stream = stream
		_claws.pitch_scale = randf_range(0.9, 1.1)
		_claws.play()


## 연출용: 따라오기·부탁을 멈추고 x까지 간 뒤 앉아 있는다. 닿으면 script_arrived.
## 다시 따라오게 하려면 release_script().
func script_move_to(x: float, speed: float = MEET_SPEED) -> void:
	if not is_joined():
		return
	state = State.SCRIPTED
	_script_goal_x = x
	_script_speed = speed
	_script_moving = true
	_refresh_visuals()


## 디딤돌 뛰기(#147, 철교 강둑): 땅 밖(강 위 돌)으로 포물선을 그리며 뛴다. 뛰는 동안은 물리(중력·땅)를 쓰지 않는다.
## 마지막에는 땅 위(y = Place.GROUND_Y)에 내려 land_hops()로 물리를 되돌린다. await로 기다릴 수 있다.
var hopping: bool = false
var _hop_tween: Tween


func hop_to(target: Vector2, seconds: float = 0.45, height: float = 90.0) -> void:
	if not is_joined():
		return
	state = State.SCRIPTED
	_script_moving = false
	hopping = true
	velocity = Vector2.ZERO
	if absf(target.x - global_position.x) > 1.0:
		facing = 1 if target.x > global_position.x else -1
	_refresh_visuals()
	if _rig and _rig.has_method("set_pose"):
		_rig.set_pose(&"stand")
	var from := global_position
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	var t := create_tween()
	_hop_tween = t
	t.tween_method(func(u: float) -> void:
		global_position = from.lerp(target, u) + Vector2(0.0, -sin(u * PI) * height), 0.0, 1.0, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## 디딤돌 뛰기를 끝낸다(땅 위에 내려선 뒤). 그 자리에 앉아 있고, release_script()로 다시 따라온다.
func land_hops() -> void:
	hopping = false
	_refresh_visuals()


## 연출용: 멈춘 채로 그쪽을 본다(1 = 오른쪽, -1 = 왼쪽). 작은 순간(Moment)에서 돌아보기.
func look(dir: int) -> void:
	if dir == 0:
		return
	facing = 1 if dir > 0 else -1
	_refresh_visuals()


## 소리·움직임에 귀를 쫑긋(#120, 미니게임 중 반응). 컷아웃이 없으면 아무 일도 없다.
func perk(amount: float = 1.0) -> void:
	if _rig and _rig.has_method("perk") and is_joined():
		_rig.perk(amount)


## 부탁 자리 밖에서 F를 누르면 쓰다듬기를 할 수 있나(#120).
func can_pet() -> bool:
	return is_joined() and not petting and state in [State.FOLLOW, State.SIT] \
			and _player != null and _player.controls_enabled and _player.is_on_floor()


## 쓰다듬기(#120): 하늘이가 하윤 앞으로 와서 앉아 올려다보며 꼬리를 흔들고, 하윤이 쪼그려 앉아 머리를 쓰다듬는다.
## 하윤을 잠그지 않는다 — 걷기 시작하면 곧바로 끝난다. 대사 없음.
func pet() -> void:
	if not can_pet():
		return
	petting = true
	var side := _player.facing
	var px := _player.global_position.x
	script_move_to(px + side * PET_GAP)
	var waited := 0.0
	while _script_moving and petting and waited < 2.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if absf(_player.velocity.x) > 1.0:
			petting = false
	if petting:
		look(-side)
		wag(true)
		_player.set_pose(&"crouch")
		pet_started.emit()
		var t := 0.0
		while petting and t < PET_SECONDS:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if absf(_player.velocity.x) > 1.0 or not _player.controls_enabled:
				break
			# 손을 앞으로 뻗어 머리를 쓰다듬는다(앞뒤로 천천히)
			_player.set_motion({"shoulder": -32.0 + sin(t * 6.5) * 8.0, "elbow": -12.0, "head": 4.0, "torso": 6.0})
		_player.set_motion({})
		_player.set_pose(&"stand")
	petting = false
	wag(false)
	if state == State.SCRIPTED:
		release_script()


## 연출용: 꼬리를 신나게 흔든다 / 그친다(4-3 빈터). 컷아웃이 없으면 아무 일도 없다.
var wagging: bool = false


func wag(on: bool) -> void:
	wagging = on
	if _rig and _rig.has_method("set_excited"):
		_rig.set_excited(on)


func release_script() -> void:
	hopping = false
	if state == State.SCRIPTED:
		state = State.FOLLOW
		_script_moving = false


## 컷아웃 자세(#103): 심부름 중이면 그 동작, 아니면 앉기·서기.
func _rig_pose(sitting: bool) -> StringName:
	if _spot:
		match state:
			State.TASK_ACT:
				return &"sniff" if _spot.action == AskSpot.Action.SNIFF else &"fetch"
			State.HOLD:
				return &"hold"
			State.TASK_GO:
				if _spot.action == AskSpot.Action.SNIFF:
					return &"sniff_walk"
	return &"sit" if sitting else &"stand"


## 짖는다(소리 + 고개 젖히기). 미니게임 도움(#145)에서 다음 음 쪽을 알려 줄 때.
func bark() -> void:
	_bark()


func _bark() -> void:
	if _rig:
		_rig.bark()
	var stream := SoundBank.pick("sfx_dog_bark_near_")
	if stream:
		_claws.stream = stream
		_claws.pitch_scale = 1.0
		_claws.play()
