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


func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _add_interactable(lines: PackedStringArray, flag: StringName, offset_x: float = 0.0) -> Area2D:
	var it: Area2D = load("res://scripts/game/interactable.gd").new()
	it.lines = lines
	it.grants_flag = flag
	it.position = Vector2(_player.global_position.x + offset_x, 810.0)
	_main.current_place().add_child(it)
	return it


## 오른쪽으로 걸으면서 조건이 참이 되면 멈춘다.
func _walk_right_until(cond: Callable, seconds: float) -> bool:
	Input.action_press(&"move_right")
	var ok := await _wait_until(cond, seconds)
	Input.action_release(&"move_right")
	await physics_frame
	return ok


func _speak_through(box: Control) -> void:
	# 대사 상자를 끝까지 넘긴다(줄마다 다 보이게 → 다음).
	var guard := 20
	while box.is_open() and guard > 0:
		await _press(&"interact")
		guard -= 1


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
	_check(not _dog.visible and not _dog.is_joined(), "합류 전에는 하늘이가 보이지 않는다")

	# 만남 장면(3-4)
	var meeting: Node2D = load("res://scripts/dog/dog_meeting.gd").new()
	meeting.position = Vector2(_player.global_position.x + 900.0, 810.0)
	_main.current_place().add_child(meeting)
	await _wait(0.3)
	_check(_dog.visible and _dog.state == _states["MEETING"], "만남: 하늘이가 보이지만 아직 합류하지 않았다")
	_check(not _dog.is_joined(), "만남: 합류 전이라 따라오지 않는다")
	var start_x := _dog.global_position.x
	var first := await _walk_right_until(func(): return meeting.retreats_left() == 1, 8.0)
	await _wait_until(func(): return not _dog.is_meet_moving(), 3.0)
	_check(first and _dog.global_position.x > start_x + 250.0, "만남: 다가가면 한 번 물러난다")
	var second := await _walk_right_until(func(): return meeting.retreats_left() == 0, 8.0)
	await _wait_until(func(): return not _dog.is_meet_moving(), 3.0)
	_check(second and _dog.global_position.x > start_x + 550.0, "만남: 다시 다가가면 두 번째로 물러난다")
	var offered := await _walk_right_until(func(): return meeting.has_node("Crouch"), 8.0)
	await _wait(0.3)
	_check(offered, "만남: 세 번째에는 물러나지 않는다")
	_check(offered and meeting.get_node("Crouch/Prompt").visible, "만남: [E] 쪼그려 앉기 안내가 뜬다")
	var meet_box: Control = _main.dialogue_box()
	await _press(&"interact")
	_check(_player.crouching and not _player.controls_enabled, "만남: E를 누르면 하윤이 쪼그려 앉고 멈춘다")
	var opened := await _wait_until(func(): return meet_box.is_open(), 5.0)
	_check(opened and _gap() <= 100.0, "만남: 하늘이가 다가와 곁에 선다 (%.0f)" % _gap())
	_check(meet_box.current_speaker() == "" and meet_box.current_text() == "하늘", "만남: 이름표 글 '하늘'")
	await _press(&"interact")
	await _press(&"interact")
	_check(meet_box.current_speaker() == "하윤" and meet_box.current_text() == "하늘이…?", "만남: 하윤 '하늘이…?'")
	await _speak_through(meet_box)
	await _wait(0.2)
	_check(_dog.is_joined() and _state.has_flag(_dog_consts["JOIN_FLAG"]), "만남: 대사가 끝나면 하늘이가 합류한다")
	_check(_player.controls_enabled and not _player.crouching, "만남: 하윤이 일어나 다시 걷는다")
	_check(not is_instance_valid(meeting), "만남: 끝나면 만남 부품이 사라진다")
	await _hold(&"move_right", 1.2)
	await _wait(0.8)
	_check(_gap() >= 80.0 and _gap() <= 120.0 and _is_behind(), "만남: 합류 뒤 하윤 뒤를 따라온다 (%.0f)" % _gap())

	var again: Node2D = load("res://scripts/dog/dog_meeting.gd").new()
	again.position = Vector2(_player.global_position.x + 500.0, 810.0)
	_main.current_place().add_child(again)
	await _wait(0.3)
	_check(not is_instance_valid(again) and _dog.is_joined(), "만남: 이미 합류했으면 만남 부품은 아무 일도 하지 않는다")

	# 합류와 따라오기
	_dog.join(_player)
	await _wait(0.2)
	_check(_dog.visible and _dog.is_joined(), "합류하면 하늘이가 보인다")
	_check(_state.has_flag(_dog_consts["JOIN_FLAG"]), "합류 플래그가 선다")

	await _hold(&"move_right", 2.0)
	await _wait(0.8)
	_check(_gap() >= 80.0 and _gap() <= 120.0, "오른쪽으로 걸은 뒤 80~120px 거리 (%.0f)" % _gap())
	_check(_is_behind(), "하늘이가 하윤 뒤(왼쪽)에 있다")
	_check(absf(_dog.global_position.y - 810.0) < 4.0, "하늘이가 땅 위에 서 있다")

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

	# 조작 잠금은 이유별로 따로 걸리고 풀린다
	_player.lock(&"test_a")
	_player.lock(&"test_b")
	_player.unlock(&"test_a")
	_check(not _player.controls_enabled, "잠금 이유 하나를 풀어도 다른 잠금이 남아 있으면 못 걷는다")
	_player.unlock(&"test_b")
	_check(_player.controls_enabled, "잠금 이유를 다 풀면 걷는다")

	# 조사(E)와 대사 상자
	var box: Control = _main.dialogue_box()
	await _press(&"interact")
	_check(not box.is_open(), "조사 대상 밖에서 E는 아무 일도 하지 않는다")

	var note := _add_interactable(PackedStringArray(["하윤: 이거 할아버지 글씨다.", "막차 놓치지 말 것"]), &"test_note")
	var note_done := [false]
	note.finished.connect(func(): note_done[0] = true)
	await _wait(0.2)
	_check(note.get_node("Prompt").visible, "조사 대상 안에서 [E] 안내가 뜬다")
	await _press(&"interact")
	_check(box.is_open(), "E를 누르면 대사 상자가 열린다")
	_check(not _player.controls_enabled, "대사 상자가 열려 있으면 하윤은 걷지 않는다")
	_check(not note.get_node("Prompt").visible, "대사 중에는 안내가 사라진다")
	_check(box.current_speaker() == "하윤" and box.current_text() == "이거 할아버지 글씨다.", "대사 줄은 이름과 내용으로 나뉜다")
	_check(not box.is_line_complete(), "글자가 찍히는 중이다")
	var x_before := _player.global_position.x
	await _hold(&"move_right", 0.15)
	_check(is_equal_approx(_player.global_position.x, x_before), "대사 중에 방향키를 눌러도 움직이지 않는다")
	await _press(&"interact")
	_check(box.is_line_complete() and box.current_text() == "이거 할아버지 글씨다.", "찍히는 중에 E를 누르면 그 줄이 다 보인다")
	await _press(&"interact")
	_check(box.current_speaker() == "" and box.current_text() == "막차 놓치지 말 것", "다음 줄로 넘어간다. 글은 이름이 없다")
	await _wait(1.0)
	await _press(&"interact")
	_check(not box.is_open() and note_done[0], "마지막 줄 뒤 E로 닫히고 finished가 온다")
	_check(_player.controls_enabled, "닫히면 다시 걷는다")
	_check(_state.has_flag(&"test_note"), "조사하면 플래그가 선다")
	await _wait(0.2)
	_check(note.get_node("Prompt").visible, "한 번만이 아니면 다시 조사할 수 있다")
	note.queue_free()
	await _wait(0.2)

	var once := _add_interactable(PackedStringArray(), &"test_once")
	once.one_shot = true
	await _wait(0.2)
	await _press(&"interact")
	_check(_state.has_flag(&"test_once") and not box.is_open(), "줄이 없는 조사는 상자 없이 끝난다")
	await _wait(0.2)
	_check(not once.get_node("Prompt").visible, "한 번만인 조사는 다시 안 된다")
	once.queue_free()

	var locked := _add_interactable(PackedStringArray(["열렸다"]), &"")
	locked.requires_flag = &"test_need"
	await _wait(0.2)
	await _press(&"interact")
	_check(not box.is_open() and not locked.get_node("Prompt").visible, "필요한 플래그가 없으면 조사할 수 없다")
	_state.set_flag(&"test_need")
	await _wait(0.2)
	await _press(&"interact")
	_check(box.is_open(), "필요한 플래그가 서면 조사할 수 있다")
	await _press(&"interact")
	await _press(&"interact")
	locked.queue_free()

	var near := _add_interactable(PackedStringArray(), &"", 30.0)
	var far2 := _add_interactable(PackedStringArray(), &"", 90.0)
	await _wait(0.2)
	_check(near.get_node("Prompt").visible and not far2.get_node("Prompt").visible, "겹치면 가장 가까운 것 하나만 안내가 뜬다")
	near.queue_free()
	far2.queue_free()
	await _wait(0.2)

	# 지도(M)
	var map: Control = _main.map_screen()
	var map_consts: Dictionary = load("res://scripts/game/map_data.gd").get_script_constant_map()
	var circles: Array = map_consts["CIRCLES"]
	await _press(&"open_map")
	await _wait(0.5)
	_check(not map.is_open(), "지도: 얻기 전에는 M이 먹지 않는다")
	_state.set_flag(map_consts["HAS_MAP_FLAG"])
	await _press(&"open_map")
	await _wait(0.5)
	_check(map.is_open() and _player.is_locked_by(&"map"), "지도: 얻은 뒤 M으로 펼치고, 펼친 동안 하윤은 멈춘다")
	var canvas: Control = map.canvas()
	_check(canvas.progress >= 0.0 and canvas.progress < 1.0, "지도: 집에 있으면 지나온 길이 집~들판 사이 (%.2f)" % canvas.progress)
	_check(canvas.get_node("Header").text == map_consts["HEADER"], "지도: 맨 위 메모")
	var notes_ok := true
	for n in range(1, circles.size() + 1):
		notes_ok = notes_ok and canvas.note_label(n).text == circles[n - 1]["note"]
	_check(notes_ok, "지도: 동그라미 메모 다섯이 데이터와 같다")
	var grandpa_ink: Color = canvas.note_label(1).get_theme_color("font_color")
	var child_ink: Color = canvas.note_label(5).get_theme_color("font_color")
	_check(child_ink != grandpa_ink, "지도: 다섯째 메모(하윤 글씨)만 다른 색이다")
	await _press(&"open_map")
	await _wait(0.5)
	_check(not map.is_open() and _player.controls_enabled, "지도: M으로 접으면 다시 걷는다")
	await _press(&"open_map")
	await _wait(0.5)
	await _press(&"interact")
	await _wait(0.5)
	_check(not map.is_open(), "지도: E로도 접힌다")
	await _press(&"open_map")
	await _wait(0.5)
	await _press(&"pause")
	await _wait(0.5)
	_check(not map.is_open(), "지도: Esc로도 접힌다")
	_check(not box.is_open(), "지도: 접는 E가 조사나 대사로 새지 않는다")

	_player.lock(&"dog_task")
	await _press(&"open_map")
	await _wait(0.5)
	_check(not map.is_open(), "지도: 하늘이 부탁 중에는 M이 먹지 않는다")
	_player.unlock(&"dog_task")

	var talk := _add_interactable(PackedStringArray(["하윤: 잠깐만."]), &"")
	await _wait(0.2)
	await _press(&"interact")
	await _press(&"open_map")
	await _wait(0.5)
	_check(box.is_open() and not map.is_open(), "지도: 대사 중에는 M이 먹지 않는다")
	await _speak_through(box)
	talk.queue_free()
	await _wait(0.2)

	var spot := _add_interactable(PackedStringArray(["하윤: 여기다."]), &"")
	spot.map_circle = 2
	var checked := [0]
	map.circle_checked.connect(func(n): checked[0] = n)
	await _wait(0.2)
	await _press(&"interact")
	var did_check := await _wait_until(func(): return checked[0] == 2, 3.0)
	_check(did_check and map.is_open(), "지도: map_circle 조사로 지도가 펼쳐지고 체크가 그어진다")
	_check(_state.has_flag(StringName("map_circle_2")) and is_equal_approx(canvas.checks.get(2, 0.0), 1.0), "지도: 체크 플래그가 서고 다 그어진다")
	_check(is_equal_approx(canvas.checks.get(1, 0.0), 0.0), "지도: 안 간 동그라미에는 체크가 없다")
	await _press(&"interact")
	var talked := await _wait_until(func(): return box.is_open(), 2.0)
	_check(talked and box.current_text() == "여기다.", "지도: 접은 뒤 그 자리의 대사가 나온다")
	await _speak_through(box)
	spot.queue_free()
	await _press(&"open_map")
	await _wait(0.5)
	_check(is_equal_approx(canvas.checks.get(2, 0.0), 1.0), "지도: 다시 펼쳐도 체크가 남아 있다")
	await _press(&"open_map")
	await _wait(0.5)

	# 장소 전환
	var place: Node2D = _main.current_place()
	_player.global_position.x = place.width - 320.0
	await _hold(&"move_right", 2.0)
	await _wait(1.3)
	_check(_state.current_place == &"field", "들판으로 넘어갔다")
	_check(_dog.visible and _gap() <= 150.0, "장소를 옮겨도 하늘이가 하윤 곁에 있다 (%.0f)" % _gap())
	await _press(&"open_map")
	await _wait(0.5)
	_check(canvas.progress >= 1.0 and canvas.progress < 2.0, "지도: 들판에 오면 지나온 길이 들판까지 늘어난다 (%.2f)" % canvas.progress)
	await _press(&"open_map")
	await _wait(0.5)

	await _check_save()

	if _failures == 0:
		print("게임플레이 검사 통과")
	else:
		print("게임플레이 검사 실패 %d건" % _failures)
	quit(1 if _failures > 0 else 0)


## 저장·이어하기·타이틀. 실제 저장 파일(user://save.cfg)은 건드리지 않는다.
func _check_save() -> void:
	const HOUSE := "res://scenes/places/house.tscn"
	_check(not _state.autosave, "저장: 헤드리스에서는 자동 저장이 꺼져 있다")
	_state.save_path = "user://test_save.cfg"
	_state.delete_save()
	_main.go_to(HOUSE)
	await _wait(1.6)
	_check(not _state.has_save(), "저장: 자동 저장이 꺼져 있으면 파일을 쓰지 않는다")

	_state.autosave = true
	_main.go_to(HOUSE)
	await _wait(1.6)
	_check(_state.has_save(), "저장: 장소에 들어가면 저장한다")
	var had_dog: bool = _state.has_flag(_dog_consts["JOIN_FLAG"])
	var had_check: bool = _state.has_flag(StringName("map_circle_2"))

	_state.reset()
	_check(_state.flags.is_empty(), "저장: (진행을 지운 상태)")
	var loaded: bool = _state.load_game()
	_check(loaded and _state.start_place == HOUSE, "저장: 이어하기는 저장한 장소에서 시작한다")
	_check(had_dog and _state.has_flag(_dog_consts["JOIN_FLAG"]), "저장: 하늘이 합류가 돌아온다")
	_check(had_check and _state.has_flag(StringName("map_circle_2")), "저장: 지도 체크가 돌아온다")

	_main.queue_free()
	await process_frame
	await process_frame
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await _wait(1.2)
	_check(_main.current_place().place_id == &"house", "이어하기: 저장한 장소로 들어간다")
	var dog: CharacterBody2D = _main.dog()
	_check(dog.is_joined() and dog.visible, "이어하기: 하늘이가 곁에 있다")
	_check(_state.start_place.is_empty(), "이어하기: 시작 장소는 한 번만 쓴다")

	var title: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	_check(not title.get_node("Menu/Continue").disabled, "타이틀: 저장이 있으면 이어하기가 켜져 있다")
	title.queue_free()
	_state.delete_save()
	title = load("res://scenes/ui/title_screen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	_check(title.get_node("Menu/Continue").disabled, "타이틀: 저장이 없으면 이어하기가 꺼져 있다")
	_check(title.get_node("Menu/New").has_focus(), "타이틀: 저장이 없으면 처음부터에 초점이 있다")

	_main.queue_free()
	_state.set_flag(&"test_leftover")
	_state.autosave = false
	title.start_new()
	await process_frame
	_check(_state.flags.is_empty() and not _state.has_save(), "타이틀: 처음부터는 진행과 저장을 지운다")
	await _wait(0.5)
	var started: Node = current_scene
	_check(started != null and started.scene_file_path == "res://scenes/main.tscn", "타이틀: 처음부터를 누르면 본편이 시작된다")
	_state.delete_save()
	_state.save_path = _state.SAVE_PATH
