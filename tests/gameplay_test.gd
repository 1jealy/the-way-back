extends SceneTree
## 게임플레이(A 담당) 헤드리스 검사. 실패가 하나라도 있으면 종료 코드 1.
## godot --headless --path . --script res://tests/gameplay_test.gd
##
## 장소 씬은 고치지 않는다. 부탁 자리는 검사 중에 코드로 붙였다 뗀다.
##
## class_name(Dog, AskSpot, Player, Place)을 여기서 직접 쓰지 않는다. 쓰면 이 스크립트를
## 컴파일할 때 그 스크립트들도 같이 컴파일되는데, 그때는 아직 오토로드(GameState)가 없어
## "Identifier not found: GameState"로 실패한다. 실행 중에 load()로 불러 쓴다.

var _failures: int = 0
var _main: Node
var _player: CharacterBody2D
var _dog: CharacterBody2D
var _dog_consts: Dictionary
var _spot_script: GDScript
var _actions: Dictionary
var _states: Dictionary
## 오토로드 이름(GameState)은 이 스크립트가 컴파일될 때 아직 없다 — 노드로 찾는다.
var _state: Node


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    ", what)
	else:
		_failures += 1
		print("  FAIL  ", what)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)


func _press_ask() -> void:
	var down := InputEventAction.new()
	down.action = &"ask_dog"
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := InputEventAction.new()
	up.action = &"ask_dog"
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


## 조건이 참이 될 때까지 최대 seconds 기다린다.
func _wait_until(cond: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if cond.call():
			return true
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
	return cond.call()


func _gap() -> float:
	return absf(_dog.global_position.x - _player.global_position.x)


func _is_behind() -> bool:
	var side := signf(_dog.global_position.x - _player.global_position.x)
	return side == -_player.facing


func _add_spot(action: int, offset_x: float, flag: StringName) -> Area2D:
	var spot: Area2D = _spot_script.new()
	spot.action = action
	spot.target_offset = Vector2(offset_x, 0.0)
	spot.grants_flag = flag
	spot.position = Vector2(_player.global_position.x, 810.0)
	_main.current_place().add_child(spot)
	return spot


func _run() -> void:
	print("게임플레이 검사 시작")
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await _wait(1.0)
	_state = root.get_node("GameState")
	_dog_consts = load("res://scripts/dog/dog.gd").get_script_constant_map()
	_states = _dog_consts["State"]
	_spot_script = load("res://scripts/dog/ask_spot.gd")
	_actions = _spot_script.get_script_constant_map()["Action"]
	_player = _main.player()
	_dog = _main.dog()

	# 합류 전
	_check(not _dog.visible and not _dog.is_joined(), "합류 전에는 구름이가 보이지 않는다")

	# 합류와 따라오기
	_dog.join(_player)
	await _wait(0.2)
	_check(_dog.visible and _dog.is_joined(), "합류하면 구름이가 보인다")
	_check(_state.has_flag(_dog_consts["JOIN_FLAG"]), "합류 플래그가 선다")

	await _hold(&"move_right", 2.0)
	await _wait(0.8)
	_check(_gap() >= 80.0 and _gap() <= 120.0, "오른쪽으로 걸은 뒤 80~120px 거리 (%.0f)" % _gap())
	_check(_is_behind(), "구름이가 하윤 뒤(왼쪽)에 있다")
	_check(absf(_dog.global_position.y - 810.0) < 4.0, "구름이가 땅 위에 서 있다")

	await _hold(&"move_left", 1.5)
	await _wait(0.8)
	_check(_gap() >= 80.0 and _gap() <= 120.0, "돌아서 걸은 뒤에도 80~120px (%.0f)" % _gap())
	_check(_is_behind(), "돌아서면 반대쪽 뒤(오른쪽)로 간다")

	# 앉기
	await _wait(_dog_consts["SIT_DELAY"] + 0.3)
	_check(_dog.state == _states["SIT"], "멈추고 몇 초 뒤 앉는다")
	await _hold(&"move_right", 0.6)
	_check(_dog.state == _states["FOLLOW"], "다시 걸으면 일어난다")
	await _wait(0.8)

	# 부탁 자리 밖 (멀리 자리가 하나 있어도 하윤이 그 안에 없으면 안 먹어야 한다)
	var far := _add_spot(_actions["FETCH"], 200.0, &"test_far")
	far.position.x += 1500.0
	await _wait(0.2)
	await _press_ask()
	_check(not _dog.is_busy(), "부탁 자리 밖에서 F는 아무 일도 하지 않는다")
	_check(not _dog.get_node("PawMark").visible, "부탁 자리 밖에서는 발바닥 표시가 없다")
	_check(not _state.has_flag(&"test_far"), "멀리 있는 부탁 자리는 쓰이지 않는다")
	far.queue_free()
	await _wait(0.2)

	# 가져와
	var fetch := _add_spot(_actions["FETCH"], 260.0, &"test_fetched")
	var fetch_acted := [false]
	fetch.acted.connect(func(): fetch_acted[0] = true)
	await _wait(0.2)
	_check(_dog.get_node("PawMark").visible, "부탁 자리 안에서는 발바닥 표시가 뜬다")
	await _press_ask()
	_check(_dog.is_busy(), "가져와: F를 누르면 출발한다")
	_check(not _player.controls_enabled, "가져와: 그동안 하윤은 기다린다")
	var fetched := await _wait_until(func(): return fetch.used, 8.0)
	_check(fetched and fetch_acted[0], "가져와: 물어 오고 돌아온다")
	_check(_state.has_flag(&"test_fetched"), "가져와: 플래그가 선다")
	_check(_player.controls_enabled, "가져와: 끝나면 다시 걸을 수 있다")
	_check(_gap() <= 120.0 + 1.0, "가져와: 하윤 곁으로 돌아와 있다")
	await _press_ask()
	_check(not _dog.is_busy(), "한 번 쓴 자리에서는 F가 다시 먹지 않는다")
	fetch.queue_free()
	await _wait(0.3)

	# 냄새
	var sniff := _add_spot(_actions["SNIFF"], -300.0, &"test_sniffed")
	await _wait(0.2)
	await _press_ask()
	var sniffed := await _wait_until(func(): return sniff.used, 8.0)
	_check(sniffed and _state.has_flag(&"test_sniffed"), "냄새: 맞는 길 쪽으로 가서 짖고 돌아온다")
	sniff.queue_free()
	await _wait(0.3)

	# 기다려
	var hold := _add_spot(_actions["HOLD"], 200.0, &"test_holding")
	hold.release_offset = 250.0
	await _wait(0.2)
	await _press_ask()
	var holding := await _wait_until(func(): return _dog.state == _states["HOLD"], 6.0)
	_check(holding, "기다려: 정해진 자리에서 버틴다")
	_check(_player.controls_enabled, "기다려: 버티는 동안 하윤은 움직일 수 있다")
	_check(_state.has_flag(&"test_holding"), "기다려: 버티기 시작하면 플래그가 선다")
	await _wait(1.0)
	_check(_dog.state == _states["HOLD"], "기다려: 하윤이 안 지나가면 계속 버틴다")
	await _hold(&"move_right", 3.0)
	var released := await _wait_until(func(): return hold.used, 6.0)
	_check(released, "기다려: 하윤이 지나가면 따라온다")
	hold.queue_free()

	# 장소 전환
	var place: Node2D = _main.current_place()
	_player.global_position.x = place.width - 320.0
	await _hold(&"move_right", 2.0)
	await _wait(1.3)
	_check(_state.current_place == &"field", "들판으로 넘어갔다")
	_check(_dog.visible and _gap() <= 150.0, "장소를 옮겨도 구름이가 하윤 곁에 있다 (%.0f)" % _gap())

	if _failures == 0:
		print("게임플레이 검사 통과")
	else:
		print("게임플레이 검사 실패 %d건" % _failures)
	quit(1 if _failures > 0 else 0)
