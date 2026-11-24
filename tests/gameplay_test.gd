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

	await _check_place_card()

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
	_check(opened and _gap() <= 150.0, "만남: 하늘이가 다가와 곁에 선다 (%.0f)" % _gap())
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
	_check(_gap() >= 120.0 and _gap() <= 180.0 and _is_behind(), "만남: 합류 뒤 하윤 뒤를 따라온다 (%.0f)" % _gap())

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
	_check(_gap() >= 120.0 and _gap() <= 180.0, "오른쪽으로 걸은 뒤 120~180px 거리 (%.0f)" % _gap())
	_check(_is_behind(), "하늘이가 하윤 뒤(왼쪽)에 있다")
	_check(absf(_dog.global_position.y - 810.0) < 4.0, "하늘이가 땅 위에 서 있다")

	await _hold(&"move_left", 1.5)
	await _wait(0.8)
	_check(_gap() >= 120.0 and _gap() <= 180.0, "돌아서 걸은 뒤에도 120~180px (%.0f)" % _gap())
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
	_check(_gap() <= 180.0 + 1.0, "가져와: 하윤 곁으로 돌아와 있다")
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

	var pick := _add_interactable(PackedStringArray(), &"test_pick")
	pick.pickup_art = "prop_key"
	await _wait(0.2)
	await _press(&"interact")
	await _wait(0.3)
	var icon := pick.get_node_or_null("Pickup") as Sprite2D
	_check(icon != null and icon.texture != null and icon.modulate.a > 0.5, "주운 물건: 조사하면 그림이 위로 떠오른다")
	_check(_player.controls_enabled, "주운 물건: 떠오르는 동안에도 걸을 수 있다")
	await _wait(1.6)
	_check(pick.get_node_or_null("Pickup") == null, "주운 물건: 잠시 뒤 사라진다")
	pick.queue_free()

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
	_check(canvas.has_paper_art() == ResourceLoader.exists(map_consts["PAPER_ART"]), "지도: 지도 그림이 있으면 그림을 깐다")
	var notes_ok := true
	for n in range(1, circles.size() + 1):
		notes_ok = notes_ok and canvas.note_label(n).text == circles[n - 1]["note"]
	_check(notes_ok, "지도: 동그라미 메모 다섯이 데이터와 같다")
	var grandpa_ink: Color = canvas.note_label(1).get_theme_color("font_color")
	var child_ink: Color = canvas.note_label(5).get_theme_color("font_color")
	_check(child_ink != grandpa_ink, "지도: 다섯째 메모(하윤 글씨)만 다른 색이다")
	var grandpa_font := load("res://assets/fonts/grandpa_hand_subset.ttf")
	var hayun_font := load("res://assets/fonts/hayun_hand_subset.ttf")
	var hands_ok: bool = canvas.get_node("Header").get_theme_font("font") == grandpa_font
	for n in range(1, circles.size() + 1):
		var want: Font = hayun_font if circles[n - 1]["child"] else grandpa_font
		hands_ok = hands_ok and canvas.note_label(n).get_theme_font("font") == want
	_check(hands_ok, "지도: 맨 위·메모 1~4는 할아버지 글씨, 다섯째만 하윤 글씨 글꼴이다")
	var map_data: GDScript = load("res://scripts/game/map_data.gd")
	var places: Array = map_consts["PLACES"]
	var on_places := true
	for i in places.size():
		on_places = on_places and map_data.route_point(float(i)).distance_to(places[i]["pos"]) < 0.5
	_check(on_places, "지도: 길이 장소 점을 지난다")
	var straight: Vector2 = (places[0]["pos"] + places[1]["pos"]) * 0.5
	_check(map_data.route_point(0.5).distance_to(straight) > 20.0, "지도: 길이 직선이 아니라 휜다")
	var branches_ok := true
	for road in map_consts["SIDE_ROADS"]:
		if road.has("from_route"):
			var at: Array = road["from_route"]
			var branch_start: Vector2 = map_data.side_road_points(road)[0]
			branches_ok = branches_ok and branch_start.distance_to(map_data.segment_point(at[0], at[1])) < 0.5
	_check(branches_ok, "지도: 갈라지는 오솔길이 길 위에서 시작한다")
	_check(canvas.has_node("Side_읍내") and canvas.has_node("Side_산"), "지도: 가지 않는 길 이름(읍내, 산)")
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

	# 기억 장면: 지도를 접으면 그 동그라미의 기억이 떴다 사라진 뒤에 글이 나온다
	var memory: Node2D = load("res://scripts/game/memory_scene.gd").new()
	memory.circle = 3
	memory.art = "mem_pup"
	memory.fade_in = 0.3
	memory.hold_seconds = 0.6
	memory.fade_out = 0.3
	memory.position = Vector2(_player.global_position.x + 300.0, 890.0)
	_main.current_place().add_child(memory)
	var spot3 := _add_interactable(PackedStringArray(["하윤: 여기도."]), &"")
	spot3.map_circle = 3
	await _wait(0.2)
	await _press(&"interact")
	await _wait_until(func(): return map.is_open(), 2.0)
	await _wait(1.5)
	await _press(&"interact")
	var mem_on := await _wait_until(func(): return memory.playing, 2.0)
	_check(mem_on and not box.is_open() and _player.is_locked_by(&"memory") and memory.get_node_or_null("Sketch") != null,
			"기억 장면: 지도를 접으면 기억이 겹쳐 뜨고, 그동안 하윤이 멈추고 글은 아직 안 나온다")
	var mem_done := await _wait_until(func(): return not memory.playing, 3.0)
	var talked3 := await _wait_until(func(): return box.is_open(), 2.0)
	_check(mem_done and talked3 and box.current_text() == "여기도." and memory.get_node_or_null("Sketch") == null,
			"기억 장면: 사라진 뒤 그 자리의 글이 나온다")
	await _speak_through(box)
	_check(not _player.is_locked_by(&"memory"), "기억 장면: 끝나면 잠금이 풀린다")
	spot3.queue_free()
	memory.queue_free()
	await _wait(0.2)

	# 물수제비(5-4): 지도를 접고 나면 하윤이 돌을 던져 두 번 튀고 가라앉은 뒤에 글이 나온다(#32)
	var skip: Node2D = load("res://scripts/game/stone_skip.gd").new()
	skip.circle = 4
	skip.position = Vector2(_player.global_position.x, 810.0)
	_main.current_place().add_child(skip)
	var spot4 := _add_interactable(PackedStringArray(["하윤: …다섯 번은 어렵다."]), &"")
	spot4.map_circle = 4
	await _wait(0.2)
	await _press(&"interact")
	await _wait_until(func(): return map.is_open(), 2.0)
	await _wait(1.5)
	await _press(&"interact")
	var thrown := await _wait_until(func(): return skip.playing, 2.0)
	_check(thrown and _player.is_locked_by(&"stone_skip") and not box.is_open(),
			"물수제비: 지도를 접으면 하윤이 돌을 던지고, 그동안 멈추고 글은 아직 안 나온다")
	var flying := await _wait_until(func(): return skip.get_node_or_null("Stone") != null, 2.0)
	_check(flying, "물수제비: 돌이 날아간다")
	var skip_done := await _wait_until(func(): return not skip.playing, 6.0)
	_check(skip_done and skip.touches == skip.skips + 1 and skip.skips == 2, "물수제비: 두 번 튀고 가라앉는다")
	var talked4 := await _wait_until(func(): return box.is_open(), 2.0)
	_check(talked4 and box.current_text() == "…다섯 번은 어렵다." and skip.get_node_or_null("Stone") == null,
			"물수제비: 가라앉은 뒤 그 자리의 글이 나온다")
	await _speak_through(box)
	_check(not _player.is_locked_by(&"stone_skip"), "물수제비: 끝나면 잠금이 풀린다")
	spot4.queue_free()
	skip.queue_free()
	await _wait(0.2)

	# 장소 전환
	var place: Node2D = _main.current_place()
	_player.global_position.x = place.width - 320.0
	await _hold(&"move_right", 2.0)
	await _wait(1.3)
	_check(_state.current_place == &"field", "들판으로 넘어갔다")
	_check(_dog.visible and _gap() <= 225.0, "장소를 옮겨도 하늘이가 하윤 곁에 있다 (%.0f)" % _gap())
	await _press(&"open_map")
	await _wait(0.5)
	_check(canvas.progress >= 1.0 and canvas.progress < 2.0, "지도: 들판에 오면 지나온 길이 들판까지 늘어난다 (%.2f)" % canvas.progress)
	await _press(&"open_map")
	await _wait(0.5)

	await _check_hint()
	await _check_moment()
	await _check_sound()
	await _check_gate()
	await _check_bench()
	await _check_map_chase()
	await _check_tractor()
	await _check_shake()
	await _check_reflection()
	await _check_motes()
	await _check_shadow()
	await _check_cutout()
	await _check_portraits()
	await _check_opening()
	await _check_pause()
	await _check_save()

	if _failures == 0:
		print("게임플레이 검사 통과")
	else:
		print("게임플레이 검사 실패 %d건" % _failures)
	quit(1 if _failures > 0 else 0)


## 소리(#35): 버스, 장소 소리, 발소리 바닥, 하늘이 발톱(간이역·숲에서만).
func _check_sound() -> void:
	var names: Array = []
	for i in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	_check(&"Ambience" in names and &"Sfx" in names and &"Music" in names, "소리: 버스 Ambience·Sfx·Music이 있다 %s" % [names])
	var amb: AudioStreamPlayer = _main.current_place().get_node_or_null("Sound/Ambience")
	_check(amb != null and amb.bus == &"Ambience" and amb.playing, "소리: 장소 환경음이 Ambience 버스로 돈다")
	var bus := AudioServer.get_bus_index(&"Ambience")
	_check(absf(AudioServer.get_bus_volume_db(bus)) < 0.5, "소리: 장소에 들어온 뒤 환경음 버스가 다 켜져 있다 (%.1f dB)" % AudioServer.get_bus_volume_db(bus))

	var house: Node = load("res://scenes/places/house.tscn").instantiate()
	_check(house.surface_at(300.0) == &"wood" and house.surface_at(5200.0) == &"dirt", "소리: 집은 마루, 마당부터 흙")
	house.free()

	var steps: AudioStreamPlayer = _player.get_node("Steps")
	var claws: AudioStreamPlayer = _dog.get_node("Claws")
	var heard := {"step": "", "claw": false}
	var watch := func():
		if steps.playing and steps.stream:
			heard["step"] = steps.stream.resource_path.get_file()
		if claws.playing:
			heard["claw"] = true
	get_root().get_tree().process_frame.connect(watch)
	await _hold(&"move_left", 1.2)
	await _hold(&"move_right", 1.2)
	_check(String(heard["step"]).begins_with("step_dirt_"), "소리: 들판을 걸으면 흙길 발소리 (%s)" % heard["step"])
	_check(not heard["claw"], "소리: 들판에서는 하늘이 발톱 소리가 없다")
	var real_place: StringName = _state.current_place
	_state.current_place = &"station"
	heard["claw"] = false
	await _hold(&"move_left", 1.5)
	await _wait(0.5)
	_check(heard["claw"], "소리: 간이역에서는 하늘이 발톱 소리가 난다")
	_state.current_place = real_place
	get_root().get_tree().process_frame.disconnect(watch)


## 막는 벽(Gate, #32): 플래그가 서기 전에는 하윤만 막고, 서면 지나간다. 하늘이는 안 막는다.
func _check_gate() -> void:
	var gate: StaticBody2D = load("res://scripts/game/gate.gd").new()
	gate.opens_on_flag = &"test_gate_open"
	_main.current_place().add_child(gate)
	gate.global_position = Vector2(_player.global_position.x + 200.0, 810.0)
	await _wait(0.2)
	await _hold(&"move_right", 1.5)
	_check(_player.global_position.x < gate.global_position.x, "벽: 플래그 전에는 하윤이 막힌다")
	_check((_dog.collision_mask & 8) == 0 and (_player.collision_mask & 8) != 0, "벽: 벽 층(4)은 하윤만 부딪힌다(하늘이는 지나간다)")
	_state.set_flag(&"test_gate_open")
	await _wait(0.2)
	await _hold(&"move_right", 1.5)
	_check(_player.global_position.x > gate.global_position.x, "벽: 플래그가 서면 지나간다")
	gate.queue_free()
	await _hold(&"move_left", 1.5)
	var drawn: StaticBody2D = load("res://scripts/game/gate.gd").new()
	drawn.opens_on_flag = &"test_gate_art"
	drawn.art = "prop_thicket"
	_main.current_place().add_child(drawn)
	var art := drawn.get_node_or_null("Art") as Sprite2D
	_check(art != null and art.visible and art.z_index > 0, "벽: 그림을 주면 하윤 앞에 막는 그림이 보인다")
	_state.set_flag(&"test_gate_art")
	await _wait(0.2)
	_check(art != null and not art.visible, "벽: 열리면 막는 그림도 사라진다")
	drawn.queue_free()
	await _hold(&"move_left", 1.5)


## 벤치(BenchSit, 2-5식): [E] 앉기 → 조작이 막힌다 → 방향키로 일어난다.
func _check_bench() -> void:
	var bench: Area2D = load("res://scripts/game/bench_sit.gd").new()
	bench.prompt = "앉기"
	_main.current_place().add_child(bench)
	bench.global_position = Vector2(_player.global_position.x + 40.0, 810.0)
	await _wait(0.3)
	await _press(&"interact")
	await _wait(0.2)
	_check(bench.sitting and not _player.controls_enabled, "벤치: E로 앉는다(조작이 막힌다)")
	_check(is_equal_approx(_player.global_position.x, bench.global_position.x), "벤치: 벤치 가운데에 앉는다")
	await _press(&"move_right")
	await _wait(0.2)
	_check(not bench.sitting and _player.controls_enabled, "벤치: 방향키로 일어난다")
	bench.queue_free()
	await _wait(0.2)


## 2-3 날아간 지도(MapChase): 지나가면 바람 → 덤불 셋에 걸렸다 날아간다 → 마지막 덤불에서 줍는다.
## 들판에 B가 놓은 진짜 MapChase_2-3으로 본다(날아가는 시간만 줄인다).
func _check_map_chase() -> void:
	var place: Node2D = _main.current_place()
	var chase: Node2D = place.get_node_or_null("MapChase_2-3")
	_check(chase != null, "지도 쫓기: 들판에 MapChase_2-3이 있다")
	if chase == null:
		return
	var map: Control = _main.map_screen()
	var box: Control = _main.dialogue_box()
	var gate: Node = place.get_node("Gate_2-3")
	var hill: Node = place.get_node("Look_2-2_Hill")
	chase.flight_seconds = 0.4
	_check(chase.state == 0 and not gate.is_open(), "지도 쫓기: 줍기 전에는 Gate_2-3이 막는다")
	_player.global_position.x = chase.global_position.x + 20.0
	var started := await _wait_until(func(): return chase.state == 1 and box.is_open(), 1.5)
	_check(started and map.away and box.current_text() == "어? 기다려!" and _player.is_locked_by(&"map_chase"),
			"지도 쫓기: 지나가면 지도가 날아가고 \"하윤: 어? 기다려!\", 그동안 하윤이 멈춘다")
	await _speak_through(box)
	await _wait_until(func(): return not chase.flying, 2.0)
	_check(_player.controls_enabled and chase.stop_index == 0, "지도 쫓기: 대사가 끝나면 걸을 수 있고, 지도는 첫 덤불에 걸려 있다")
	await _press(&"open_map")
	await _wait(0.5)
	_check(not map.is_open(), "지도 쫓기: 지도가 날아가 있는 동안 M이 먹지 않는다")
	_player.global_position.x = hill.global_position.x
	await _wait(0.3)
	_check(not hill.is_offered(), "지도 쫓기: 날아가 있는 동안 동그라미 조사(지도 펼치기)도 안 뜬다")
	for k in 2:
		_player.global_position.x = chase.stop_position(k).x - 100.0
		var moved := await _wait_until(func(): return chase.stop_index == k + 1 and not chase.flying, 2.0)
		_check(moved, "지도 쫓기: 덤불 %d에 다가가면 다시 날아간다" % (k + 1))
	_check(not _state.has_flag(&"map_caught") and not gate.is_open(), "지도 쫓기: 줍기 전에는 아직 막혀 있다")
	_player.global_position.x = chase.stop_position(2).x - 60.0
	await _wait(1.0)
	_check(chase.stop_index == 2, "지도 쫓기: 마지막 덤불에서는 더 날아가지 않는다")
	await _press(&"interact")
	var got := await _wait_until(func(): return _state.has_flag(&"map_caught"), 2.0)
	_check(got and not map.away and gate.is_open(), "지도 쫓기: E로 주우면 map_caught, 지도가 돌아오고 벽이 열린다")
	await _wait(0.5)
	await _press(&"open_map")
	await _wait(0.6)
	_check(map.is_open(), "지도 쫓기: 주운 뒤에는 M이 다시 먹는다")
	await _press(&"open_map")
	await _wait(0.6)


## 2-4 경운기(TractorPass): 다가오면 하윤이 멈춰 비켜서고, 가까이 오면 "안녕하세요",
## 지나간 뒤에야 다시 걷는다. 끝나면 tractor_passed라 다시 오지 않는다. 빠르기만 올려서 본다.
func _check_tractor() -> void:
	var place: Node2D = _main.current_place()
	var tractor: Node2D = place.get_node_or_null("Tractor_2-4")
	_check(tractor != null, "경운기: 들판에 Tractor_2-4가 있다")
	if tractor == null:
		return
	var box: Control = _main.dialogue_box()
	tractor.speed = 900.0
	var passed := [false]
	tractor.passed.connect(func(): passed[0] = true)
	_player.global_position.x = tractor.global_position.x - tractor.trigger_before + 20.0
	var started := await _wait_until(func(): return tractor.running and tractor.tractor() != null, 1.0)
	_check(started and _player.is_locked_by(&"tractor"), "경운기: 그 자리에 오면 경운기가 나타나고 하윤이 멈춘다")
	_check(started and tractor.tractor().global_position.x > _player.global_position.x + 1000.0,
			"경운기: 오른쪽 멀리서 다가온다")
	var greeted := await _wait_until(func(): return box.is_open(), 3.0)
	_check(greeted and box.current_text() == "안녕하세요." and _player.facing == 1, "경운기: 가까이 오면 경운기 쪽을 보고 \"하윤: 안녕하세요.\"")
	await _wait_until(func(): return passed[0], 3.0)
	await _speak_through(box)
	var done := await _wait_until(func(): return _player.controls_enabled and _state.has_flag(&"tractor_passed"), 3.0)
	_check(done and passed[0], "경운기: 지나간 뒤 다시 걸을 수 있고 tractor_passed")
	var gone := await _wait_until(func(): return tractor.tractor() == null, 4.0)
	_check(gone and not tractor.running, "경운기: 왼쪽으로 멀어져 사라지고, 다시 오지 않는다")


## 흔들면 떨어지는 조사 대상(ShakeDrop, 1-6 감나무): E → 감이 떨어져 땅에 닿는다. 한 번만.
func _check_shake() -> void:
	var tree: Area2D = load("res://scripts/game/shake_drop.gd").new()
	tree.prompt = "감나무 흔들기"
	_main.current_place().add_child(tree)
	tree.global_position = Vector2(_player.global_position.x + 30.0, 810.0)
	var landed := [false]
	tree.dropped.connect(func(): landed[0] = true)
	await _wait(0.3)
	await _press(&"interact")
	await _wait(0.3)
	_check(tree.fallen != null and tree.fallen.position.y < -100.0, "감나무: E로 흔들면 감이 가지에 달려 있다가")
	var down := await _wait_until(func(): return landed[0], 2.0)
	await _wait(0.6)
	_check(down and is_zero_approx(tree.fallen.position.y) and _player.controls_enabled, "감나무: 땅에 떨어진다(조작은 막지 않는다)")
	_check(not tree.is_offered(), "감나무: 한 번만 흔든다")
	tree.queue_free()
	await _wait(0.2)


## 5-2 물그림자(WaterReflection): 물가에서 하윤은 흐리게 비치고 하늘이는 비치지 않는다. 카메라가 살짝 내려간다.
func _check_reflection() -> void:
	var water: Node2D = load("res://scripts/game/water_reflection.gd").new()
	water.camera_seconds = 0.3
	_main.current_place().add_child(water)
	water.global_position = Vector2(_player.global_position.x + 30.0, 810.0)
	var camera: Camera2D = _player.get_node("Camera")
	await _wait(0.6)
	var copy: Node2D = water.player_reflection()
	_check(water.inside and copy != null and copy.get_parent().visible, "물그림자: 물가에 서면 하윤이 물에 비친다")
	if copy:
		var holder: Node2D = copy.get_parent()
		_check(holder.global_position.y > _player.global_position.y and holder.scale.y < 0.0, "물그림자: 물 위 선 아래로 뒤집혀 비친다")
		var mat: ShaderMaterial = holder.material
		_check(mat != null and mat.get_shader_parameter("clarity") < 0.5, "물그림자: 하윤은 흐리게 비친다")
		_check(holder.get_child_count() == 1 and water.get_child_count() == 1, "물그림자: 하늘이는 비치지 않는다(반사는 하윤 하나뿐)")
	_check(_dog.visible, "물그림자: (하늘이는 보이는데도 비치지 않는다)")
	_check(camera.zoom.x > 1.01 and camera.offset.y > 1.0, "물그림자: 카메라가 살짝 내려가 물을 보여 준다")
	_player.global_position.x = water.global_position.x + water.half_width + 400.0
	await _wait(0.6)
	_check(not water.inside and not copy.get_parent().visible and is_equal_approx(camera.zoom.x, 1.0) and is_zero_approx(camera.offset.y),
			"물그림자: 물가를 벗어나면 반사가 사라지고 카메라가 돌아온다")
	water.queue_free()
	_player.global_position.x = water.global_position.x - 30.0
## 4-1·4-2 빛 알갱이(LightMotes): 지나가면 떠오르고, 갈림길 구간에서는 하늘이 발밑에만 모인다.
func _check_motes() -> void:
	var motes: Node2D = load("res://scripts/game/light_motes.gd").new()
	var px := _player.global_position.x
	motes.gather_from = px + 2000.0
	motes.gather_to = px + 4000.0
	_main.current_place().add_child(motes)
	motes.global_position = Vector2(px + 300.0, 810.0)
	await _wait(0.3)
	_check(not motes.started and motes.motes.is_empty(), "빛 알갱이: 그 자리를 지나기 전에는 없다")
	_player.global_position.x = px + 400.0
	await _wait(0.5)
	_check(motes.started and motes.motes.size() == motes.count and not motes.gathering, "빛 알갱이: 지나가면 떠오른다")
	_player.global_position.x = px + 2600.0
	await _wait(0.3)
	_check(motes.gathering, "빛 알갱이: 갈림길 구간에 들어서면 하늘이 발밑에 모으기 시작한다")
	await _wait(6.0)
	var near: float = motes.share_near(_dog.global_position.x, motes.gather_spread * 2.0 + 40.0)
	_check(near > 0.9, "빛 알갱이: 잠시 뒤 알갱이가 하늘이 발밑에만 있다 (%.0f%%)" % (near * 100.0))
	motes.queue_free()
	_player.global_position.x = px
	await _wait(0.5)
## 하윤 그림자(PlayerShadow): 하윤 모습을 따라 땅에 눕고, 장소를 지날수록 옅어져 숲부터는 거의 없다.
func _check_shadow() -> void:
	var shadow: Node2D = _player.get_node_or_null("Shadow")
	_check(shadow != null, "그림자: 하윤에게 그림자가 있다")
	if shadow == null:
		return
	var settings: Dictionary = shadow.get_script().get_script_constant_map()["SETTINGS"]
	var a := func(pid: StringName) -> float: return settings[pid][0]
	var fading: bool = a.call(&"house") > a.call(&"field") and a.call(&"field") > a.call(&"station") \
			and a.call(&"station") > a.call(&"forest") and a.call(&"forest") <= 0.05 and a.call(&"ferry") == 0.0
	_check(fading,
			"그림자: 장소를 지날수록 옅어지고 숲부터는 거의 없다")
	var here: StringName = _main.current_place().place_id
	await _wait(1.6)
	_check(is_equal_approx(shadow.self_modulate.a, settings.get(here, [0.2])[0]), "그림자: 지금 장소(%s)의 진하기" % here)
	_check(shadow.transform.y.x > 0.5 and shadow.transform.y.y < 0.2, "그림자: 들판에서는 해가 오른쪽 낮게 있어 왼쪽으로 길게 눕는다")
	_player.face(-1)
	await _wait(0.1)
	var copy: Node2D = shadow.get_node("Visual")
	_check(copy.transform.x.x < 0.0, "그림자: 하윤이 돌아서면 그림자도 돈다")
	_player.face(1)
## 컷아웃 조립(Cutout): psd_split.py가 만드는 JSON·조각을 읽어 PSD 모습 그대로 맞추고,
## 눈·입은 상태 하나만 보이고, 자세 조각은 그 자세만, 눈 깜빡임은 감았다가 원래 눈으로 돌아온다.
func _check_cutout() -> void:
	var dir := "user://cutout_test/test"
	DirAccess.make_dir_recursive_absolute(dir)
	var parts := {
		"body": [40, 100, 120, 200], "head": [50, 20, 100, 90],
		"eye_open": [70, 50, 20, 10], "eye_half": [70, 54, 20, 6], "eye_closed": [70, 57, 20, 3],
		"mouth_neutral": [80, 80, 20, 4], "mouth_smile": [78, 78, 24, 8],
		"stand_leg": [60, 280, 30, 20], "sit_leg": [60, 270, 60, 30],
	}
	var meta := {"canvas": [200, 300], "parts": {}}
	var z := 0
	for part in parts:
		var r: Array = parts[part]
		var img := Image.create(r[2], r[3], false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		img.save_png(dir.path_join("char_test_%s.png" % part))
		meta.parts[part] = {"x": r[0], "y": r[1], "w": r[2], "h": r[3], "z": z}
		z += 1
	var f := FileAccess.open(dir.path_join("char_test.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()

	var cut: Node2D = load("res://scripts/game/cutout.gd").new()
	cut.character = "test"
	cut.art_dir = dir
	cut.art_scale = 0.5
	cut.poses = PackedStringArray(["stand", "sit"])
	cut.blink = false
	_main.current_place().add_child(cut)
	await _wait(0.1)
	_check(cut.parts.size() == parts.size(), "컷아웃: 조각을 다 붙인다 (%d)" % cut.parts.size())
	var head: Sprite2D = cut.parts["head"]
	_check(head.position.is_equal_approx(Vector2(50 - 100, 20 - 300) * 0.5) and head.get_index() < cut.parts["eye_open"].get_index(),
			"컷아웃: PSD 자리대로(캔버스 아래 가운데 = 발밑, 크기 맞춤), 그리는 순서대로")
	var vis := func(n: String) -> bool: return cut.parts[n].visible
	_check(vis.call("eye_open") and not vis.call("eye_half") and not vis.call("eye_closed") and vis.call("mouth_neutral") and not vis.call("mouth_smile"),
			"컷아웃: 눈·입은 처음 상태(open, neutral) 하나만 보인다")
	_check(vis.call("stand_leg") and not vis.call("sit_leg"), "컷아웃: 자세 조각은 첫 자세(stand)만 보인다")
	cut.set_state("mouth", "smile")
	cut.set_pose("sit")
	_check(vis.call("mouth_smile") and not vis.call("mouth_neutral") and vis.call("sit_leg") and not vis.call("stand_leg"),
			"컷아웃: 입 상태·자세를 바꿔 끼운다")
	var seen_closed := [false]
	cut.parts["eye_closed"].visibility_changed.connect(func(): if cut.parts["eye_closed"].visible: seen_closed[0] = true)
	cut.do_blink()
	var done := await _wait_until(func(): return not cut._blinking, 1.0)
	_check(done and seen_closed[0] and vis.call("eye_open") and not vis.call("eye_closed"), "컷아웃: 눈을 깜빡이면 감았다가 원래 눈으로 돌아온다")
	cut.queue_free()
	_check(not load("res://scripts/game/cutout.gd").has_art("nobody"), "컷아웃: 그림이 없는 인물은 has_art가 false")


## 1-2 영정사진(FuneralPortraits): 할아버지는 또렷하고 하윤 사진만 흐리다. 조사 대상이 아니다.
func _check_portraits() -> void:
	var pics: Node2D = load("res://scripts/game/funeral_portraits.gd").new()
	_main.current_place().add_child(pics)
	pics.global_position = Vector2(_player.global_position.x, 810.0)
	await _wait(0.1)
	_check(pics.grandpa.texture != null and pics.hayun.texture != null, "영정사진: 두 장이 걸려 있다")
	_check(pics.grandpa.material == null and is_equal_approx(pics.hayun_blur(), 1.0), "영정사진: 할아버지는 또렷하고 옆 사진(하윤)만 흐리다")
	_check(not pics is Area2D and pics.find_children("*", "Area2D", true, false).is_empty(), "영정사진: 조사할 수 없는 배경이다")
	pics.queue_free()


## 0-1 오프닝(OpeningScene): "처음부터"일 때만 컷신 0이 나오고 그동안 하윤이 멈춘다. 끝나면 일어나 걸을 수 있다.
func _check_opening() -> void:
	var script: GDScript = load("res://scripts/game/opening.gd")
	var skip: Node = script.new()
	_main.current_place().add_child(skip)
	await _wait(0.2)
	_check(not skip.playing and _player.controls_enabled, "오프닝: 이어하기·검사(처음부터가 아님)에는 나오지 않는다")
	skip.queue_free()
	_state.opening_pending = true
	var op: Node = script.new()
	op.seconds = 0.5
	op.rain_sound = ""
	var done := [false]
	op.finished.connect(func(): done[0] = true)
	_main.current_place().add_child(op)
	await _wait(0.5)
	_check(op.playing and not _state.opening_pending and _player.is_locked_by(&"opening") and _player.crouching,
			"오프닝: 처음부터면 컷신 0이 나오고, 하윤은 누운 채 멈춰 있다")
	var ok := await _wait_until(func(): return done[0], 10.0)
	_check(ok and _player.controls_enabled and not _player.crouching and _state.has_flag(&"opening_seen"),
			"오프닝: 끝나면 어둠이 걷히고 하윤이 일어나 걸을 수 있다")
	op.queue_free()


## 저장·이어하기·타이틀. 실제 저장 파일(user://save.cfg)은 건드리지 않는다.
## 장소 이름 카드·처음 걷기 안내(#87): 늘 떠 있던 개발용 글 대신.
func _check_place_card() -> void:
	_check(_main.get_node_or_null("Overlay/Hint") == null and _main.get_node_or_null("Overlay/PlaceLabel") == null,
			"화면에 늘 떠 있던 개발용 안내 글이 없다")
	var card: Control = _main.get_node("Overlay/PlaceCard")
	var hint: Label = _main.get_node("Overlay/WalkHint")
	_check(card.shown_name == _main.current_place().display_name, "장소 카드: 들어선 장소 이름이다")
	_check(card.get_node("Title").get_theme_font("font").resource_path.ends_with("title_subset.ttf"), "장소 카드: 제목 글꼴")
	await _wait(0.8)
	_check(card.visible and card.modulate.a > 0.3, "장소 카드: 들어서면 뜬다")
	_check(hint.visible, "처음 집에서는 걷기 안내가 뜬다")
	await _hold(&"move_right", 1.0)
	_check(not hint.visible and _state.has_flag(&"walked_once"), "걷기 안내: 조금 걸으면 사라진다")
	await _hold(&"move_left", 1.0)
	var faded := await _wait_until(func(): return not card.visible, 6.0)
	_check(faded, "장소 카드: 잠시 뒤 사라진다")
	# 조작이 막혀 있는 동안(오프닝·연출)에는 뜨지 않고 기다린다
	_player.lock(&"test_card")
	card.show_place("시험 장소", _player)
	await _wait(0.6)
	_check(not card.visible, "장소 카드: 조작이 막혀 있으면 기다린다")
	_player.unlock(&"test_card")
	await _wait(0.6)
	_check(card.visible and card.get_node("Title").text == "시험 장소", "장소 카드: 조작이 풀리면 뜬다")
	card.show_place("", _player)
	await _wait(0.2)
	_check(not card.visible, "장소 카드: 이름 없는 장소(강 위)는 안 뜬다")
	await _check_screen_polish()
	await _check_hayun_rig()


## 하윤 컷아웃(#94): PSB 조각이 붙고, 걸으면 다리·팔이 흔들리고, 멈추면 선다. 그림자도 같은 조각을 따른다.
func _check_hayun_rig() -> void:
	var rig: Node2D = _player.get_node_or_null("Visual/Rig")
	_check(rig != null and rig.cutout != null and rig.cutout.parts.has("ponytail") and rig.cutout.parts.has("far_leg_upper"),
			"하윤 컷아웃: 조각과 먼 쪽 팔다리가 붙는다")
	if rig == null:
		return
	var cut: Node2D = rig.cutout
	_check(cut.get_child(0).name.begins_with("far_"), "하윤 컷아웃: 먼 쪽 팔다리는 맨 뒤에 그린다")
	var shadow_cut := _player.get_node_or_null("Shadow/Visual/Rig/Cutout")
	_check(shadow_cut != null and shadow_cut.get_child_count() == cut.get_child_count(), "하윤 컷아웃: 그림자가 같은 조각을 복사한다")
	await _wait(0.6)
	_check(rig.walk_amount() < 0.05, "하윤 컷아웃: 가만히 있으면 서 있는 자세")
	var leg: Node2D = cut.parts["leg_upper"]
	var seen := {}
	for i in 8:
		await _hold(&"move_right", 0.12)
		seen[snappedf(leg.rotation, 0.05)] = true
	_check(rig.walk_amount() > 0.9 and seen.size() >= 3, "하윤 컷아웃: 걸으면 다리가 흔들린다 (%d가지 각도)" % seen.size())
	var a: Dictionary = rig.joint_angles()
	_check(signf(a["hip"]) == -signf(a["far_hip"]) or is_zero_approx(a["hip"]), "하윤 컷아웃: 두 다리가 반대로 움직인다")
	await _wait(0.8)
	_check(rig.walk_amount() < 0.05 and absf(leg.rotation) < 0.01, "하윤 컷아웃: 멈추면 다시 선다")
	await _hold(&"move_left", 0.96)
	await _wait(0.5)
	# 자세(#98): 쪼그려 앉으면 관절이 접히고 몸이 내려가며(그림은 찌그러지지 않는다), 일어서면 돌아온다.
	var head: Node2D = cut.parts["head"]
	var head_y := head.position.y
	_player.set_pose(&"crouch")
	await _wait(0.8)
	var ca: Dictionary = rig.joint_angles()
	_check(rig.pose == &"crouch" and float(ca["hip"]) < -80.0 and float(ca["knee"]) > 90.0 and head.position.y > head_y + 20.0
			and is_equal_approx(_player.get_node("Visual").scale.y, 1.0),
			"하윤 자세: 쪼그려 앉으면 무릎이 접히고 몸이 내려간다 (머리 %.0f → %.0f)" % [head_y, head.position.y])
	_player.set_pose(&"sit_floor")
	await _wait(0.8)
	_check(float(rig.joint_angles()["knee"]) < 30.0 and head.position.y > head_y + 20.0, "하윤 자세: 바닥에 앉으면 다리를 뻗는다")
	_player.set_pose(&"stand")
	await _wait(0.8)
	_check(absf(float(rig.joint_angles()["hip"])) < 2.0 and absf(head.position.y - head_y) < 3.0, "하윤 자세: 일어서면 서 있는 자세로 돌아온다")
	var t0 := Time.get_ticks_msec()
	await _player.play_throw()
	var released := Time.get_ticks_msec() - t0
	var sa := float(rig.joint_angles()["shoulder"])
	var ha := float(rig.joint_angles()["far_hip"])
	_check(released >= 600 and released < 950 and sa < -15.0 and sa > -60.0 and ha < -25.0,
			"하윤 자세: 옆으로 낮게 던진다 — 먼 발을 내딛고 손이 몸 앞 허리 높이에 올 때 놓는다 (%d ms, 어깨 %.0f도, 먼 허벅지 %.0f도)" % [released, sa, ha])
	await _wait(1.0)


## 화면 다듬기(#90): 카메라가 걷는 쪽을 앞서 보고, 장소마다 떠다니는 알갱이, 가장자리 비네트.
func _check_screen_polish() -> void:
	var camera: Camera2D = _player.get_node("Camera")
	await _hold(&"move_right", 1.2)
	_check(camera.offset.x > 40.0, "카메라: 오른쪽으로 걸으면 오른쪽을 앞서 본다 (%.0f)" % camera.offset.x)
	await _hold(&"move_left", 1.6)
	_check(camera.offset.x < -40.0, "카메라: 돌아서 걸으면 반대쪽을 앞서 본다 (%.0f)" % camera.offset.x)
	await _wait(5.0)
	_check(absf(camera.offset.x) < 25.0, "카메라: 멈추면 천천히 가운데로 돌아온다 (%.0f)" % camera.offset.x)
	var dust: CPUParticles2D = camera.get_node("Dust")
	_check(dust.emitting and dust.place_id == &"house", "알갱이: 집 안에서는 햇빛 속 먼지가 떠다닌다")
	dust.set_place(&"forest")
	_check(not dust.emitting, "알갱이: 숲(빛 알갱이가 따로 있는 곳)에서는 안 나온다")
	dust.set_place(_main.current_place().place_id)
	var vignette: ColorRect = _main.get_node("Overlay/Vignette")
	_check(vignette.visible and vignette.material != null and vignette.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"비네트: 화면 가장자리를 살짝 어둡게 하고 마우스를 막지 않는다")
	_check(vignette.get_index() < _main.get_node("Overlay/DialogueBox").get_index(), "비네트: 대사 상자보다 아래에 깔린다")


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
	_check(title.get_node("Menu/Quit").visible, "타이틀: 데스크톱에서는 끝내기가 보인다")
	_check(title.get_node("Background").get_child_count() >= 6, "타이틀: 배경 층·그늘·걷는 실루엣·빛 알갱이가 있다")
	var title_font: Font = title.get_node("Title").get_theme_font("font")
	_check(title_font != null and title_font.resource_path.ends_with("title_subset.ttf"), "타이틀: 제목은 제목 글꼴(송명)")

	_main.queue_free()
	_state.set_flag(&"test_leftover")
	_state.autosave = false
	title.start_new()
	await process_frame
	_check(_state.flags.is_empty() and not _state.has_save(), "타이틀: 처음부터는 진행과 저장을 지운다")
	_check(current_scene == null or current_scene.scene_file_path != "res://scenes/main.tscn", "타이틀: 고르면 바로 넘어가지 않고 어두워진다")
	await _wait(1.3)
	var started: Node = current_scene
	_check(started != null and started.scene_file_path == "res://scenes/main.tscn", "타이틀: 처음부터를 누르면 본편이 시작된다")
	if started != null:
		started.pause_menu().open()
		await process_frame
		started.pause_menu().go_to_title()
		await _wait(0.3)
		_check(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/title_screen.tscn" and not paused,
				"일시정지: 타이틀로 가면 멈춤이 풀린 채 타이틀이 뜬다")
	_state.delete_save()
	_state.save_path = _state.SAVE_PATH


## 일시정지 메뉴(Esc).
func _check_pause() -> void:
	var menu: Control = _main.pause_menu()
	var map: Control = _main.map_screen()
	var player: CharacterBody2D = _main.player()
	await _press(&"pause")
	_check(menu.is_open() and paused, "일시정지: Esc로 메뉴가 뜨고 게임이 멈춘다")
	_check(menu.get_node("Menu/Resume").has_focus(), "일시정지: 계속하기에 초점이 있다")
	var x0 := player.global_position.x
	Input.action_press(&"move_right")
	await _wait(0.4)
	Input.action_release(&"move_right")
	_check(is_equal_approx(player.global_position.x, x0), "일시정지: 멈춘 동안 하윤이 걷지 않는다")
	await _press(&"pause")
	_check(not menu.is_open() and not paused, "일시정지: Esc를 다시 누르면 풀린다")
	await _press(&"pause")
	menu.get_node("Menu/Resume").emit_signal("pressed")
	await process_frame
	_check(not menu.is_open() and not paused, "일시정지: 계속하기로 풀린다")

	await _press(&"open_map")
	await _wait(0.5)
	await _press(&"pause")
	await _wait(0.5)
	_check(not map.is_open() and not menu.is_open() and not paused, "일시정지: 지도가 펼쳐져 있으면 Esc는 지도만 접는다")


## 하늘이 힌트: 하윤이 오래 서 있으면 다음 목표 쪽으로.
func _check_hint() -> void:
	var dog: CharacterBody2D = _main.dog()
	var player: CharacterBody2D = _main.player()
	var place: Node2D = _main.current_place()
	var hints: Array = []
	dog.hinted.connect(func(x): hints.append(x))
	await _hold(&"move_left", 0.3)
	await _wait(0.5)
	var target := _add_spot(_actions["FETCH"], 200.0, &"test_hint")
	target.position.x = player.global_position.x + 700.0
	await _wait(_dog_consts["HINT_DELAY"] - 1.5)
	_check(hints.is_empty(), "힌트: 금방은 알려 주지 않는다")
	var got := await _wait_until(func(): return hints.size() == 1, 3.0)
	_check(got and is_equal_approx(hints[0], target.global_position.x), "힌트: 오래 서 있으면 다음 부탁 자리 쪽을 알려 준다")
	await _wait(1.2)
	_check(dog.global_position.x > player.global_position.x + 100.0, "힌트: 하늘이가 목표 쪽으로 앞서 간다 (%.0f)" % (dog.global_position.x - player.global_position.x))
	await _wait(3.0)
	_check(hints.size() == 1 and dog.state != _states["HINT"], "힌트: 같은 정지 동안에는 한 번만")
	await _hold(&"move_right", 0.3)
	_check(dog.state != _states["HINT"], "힌트: 하윤이 움직이면 그만두고 따라온다")
	target.queue_free()
	# 장소에 B가 놓은 진짜 목표(지도 동그라미 등)가 있으니, 잠깐 다 쓴 것으로 해 두고 본다(#31).
	var real_targets: Array = []
	for group in [&"interactable", &"ask_spot"]:
		for node in get_nodes_in_group(group):
			if place.is_ancestor_of(node) and not node.used and not node.is_queued_for_deletion():
				node.used = true
				real_targets.append(node)
	await _wait(0.3)
	var got_exit := await _wait_until(func(): return hints.size() == 2, _dog_consts["HINT_DELAY"] + 2.0)
	_check(got_exit and is_equal_approx(hints[1], place.width - 120.0), "힌트: 목표가 없으면 장소 끝 지점 쪽")
	for node in real_targets:
		node.used = false
	await _hold(&"move_left", 0.3)
	await _wait(1.0)


## 작은 순간(Moment): 지나가면 한 번 일어난다. 하늘이가 가서 머물다 돌아오고, 하윤은 잠깐 멈추고, 그림이 지나간다.
func _check_moment() -> void:
	var dog: CharacterBody2D = _main.dog()
	var player: CharacterBody2D = _main.player()
	await _wait(0.5)
	var m: Node2D = load("res://scripts/game/moment.gd").new()
	m.trigger_before = 200.0
	m.dog_to = 160.0
	m.dog_hold = 0.6
	m.dog_look = -1
	m.player_pause = 0.8
	m.art = "prop_deer"
	m.art_from = Vector2(300.0, -120.0)
	m.art_to = Vector2(-100.0, -120.0)
	m.art_seconds = 1.0
	var done := [false]
	m.finished.connect(func(): done[0] = true)
	_main.current_place().add_child(m)
	m.global_position = Vector2(player.global_position.x + 40.0, 810.0)
	await _wait(0.3)
	_check(m.triggered, "작은 순간: 하윤이 지나가면 일어난다")
	_check(not player.controls_enabled, "작은 순간: 하윤이 잠깐 멈춘다")
	_check(m.get_node_or_null("Art0") != null, "작은 순간: 그림이 지나간다")
	_check(dog.state == _states["SCRIPTED"], "작은 순간: 하늘이가 그 자리로 간다")
	var ask := _add_spot(_actions["FETCH"], 260.0, &"test_moment_ask")
	await _wait(0.1)
	_check(dog.available_spot() == null, "작은 순간: 하늘이가 연출 중이면 부탁을 받지 않는다")
	ask.queue_free()
	var ok := await _wait_until(func(): return done[0], 6.0)
	_check(ok, "작은 순간: 끝난다")
	_check(player.controls_enabled, "작은 순간: 끝나면 하윤이 다시 걷는다")
	_check(dog.state != _states["SCRIPTED"], "작은 순간: 끝나면 하늘이가 다시 따라온다")
	_check(m.get_node_or_null("Art0") == null, "작은 순간: 그림이 사라진다")
	m.queue_free()
	await _wait(0.5)
	# 그림을 못 찾아도 다른 일(하윤 멈춤)이 끝날 때까지 finished가 나가지 않는다(#85).
	var lost: Node2D = load("res://scripts/game/moment.gd").new()
	lost.art = "no_such_art_for_test"
	lost.player_pause = 0.8
	var lost_done := [false]
	lost.finished.connect(func(): lost_done[0] = true)
	_main.current_place().add_child(lost)
	lost.global_position = Vector2(player.global_position.x - 10.0, 810.0)
	await _wait(0.3)
	_check(lost.triggered and not lost_done[0], "작은 순간: 그림이 없어도 남은 일이 끝나기 전엔 끝나지 않는다")
	var lost_ok := await _wait_until(func(): return lost_done[0], 3.0)
	_check(lost_ok and player.controls_enabled, "작은 순간: 그림이 없어도 남은 일이 끝나면 끝난다")
	lost.queue_free()
	await _wait(0.3)
	# 이미 멀리 지나간 하윤(옮겨 가기·순간이동)은 멈추지 않는다(#85).
	var passed: Node2D = load("res://scripts/game/moment.gd").new()
	passed.player_pause = 1.0
	_main.current_place().add_child(passed)
	passed.global_position = Vector2(player.global_position.x - 900.0, 810.0)
	await _wait(0.2)
	_check(passed.triggered and player.controls_enabled, "작은 순간: 멀리 지나간 뒤에 알아채면 건너뛴다")
	passed.queue_free()
