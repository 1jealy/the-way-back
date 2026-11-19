extends SceneTree
## 장소에 놓은 부품을 실제로 써 본다: 간이역 하늘이 만남 → 열쇠 가져와 → 대합실 문,
## 숲·강가·철교의 부탁 자리. 하윤을 걸리고 E·F를 눌러서, 세워져야 할 플래그를 본다.
## godot --headless --path . --script res://tools/parts_flow_test.gd   # 종료 코드 0이면 통과 (약 2분)
##
## 부품 자리·속성만 보는 빠른 검사는 smoke_test.gd에 있다. 이건 A의 동작이 바뀌어도
## B가 놓은 자리가 여전히 풀리는지를 본다.

var _failures := 0
var _state: Node
var _main: Node
var _player: CharacterBody2D
var _dog: CharacterBody2D


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	print("  ok    " if ok else "  FAIL  ", what)
	if not ok:
		_failures += 1


func _wait(s: float) -> void:
	await create_timer(s).timeout


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


## 하윤을 걸려서 x까지 간다(최대 40초).
func _walk_to(x: float) -> void:
	var act := &"move_right" if x > _player.global_position.x else &"move_left"
	Input.action_press(act)
	for i in 2400:
		await physics_frame
		if absf(_player.global_position.x - x) < 12.0:
			break
	Input.action_release(act)


func _wait_flag(flag: StringName, seconds: float) -> bool:
	for i in int(seconds / 0.25):
		if _state.has_flag(flag):
			return true
		await _wait(0.25)
	return _state.has_flag(flag)


func _go(place_id: String) -> Node:
	_main.go_to("res://scenes/places/%s.tscn" % place_id)
	await _wait(2.0)
	return _main.current_place()


func _run() -> void:
	print("부품 흐름 검사 시작")
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await _wait(1.0)
	_state = root.get_node("GameState")
	_player = _main.get_node("World/Player")
	_dog = _main.get_node("World/Dog")

	# 간이역: 만남(3-4)
	var station: Node = await _go("station")
	var meeting: Node2D = station.get_node("DogMeeting_3-4")
	await _walk_to(station.get_node("Markers/3-3").position.x)
	_check(not _state.has_flag(&"dog_joined") and _dog.visible, "간이역: 3-3 벤치에서는 하늘이가 아직 물러나지 않았다")
	_check(is_equal_approx(_dog.global_position.x, meeting.global_position.x), "간이역: 하늘이가 3-4 자리에 앉아 있다")
	for k in 6:
		await _walk_to(_dog.global_position.x - 300.0)
		await _wait(1.5)
		if station.get_node_or_null("DogMeeting_3-4/Crouch") != null:
			break
	_check(station.get_node_or_null("DogMeeting_3-4/Crouch") != null, "간이역: 두 번 물러난 뒤 쪼그려 앉기가 뜬다")
	await _press(&"interact")
	for i in 8:  # 다가오기 + 대사 넘기기
		await _wait(0.7)
		await _press(&"interact")
	_check(await _wait_flag(&"dog_joined", 3.0), "간이역: 하늘이가 합류한다")

	# 간이역: 열쇠 가져와(3-5) → 대합실 문(3-6)
	await _walk_to(station.get_node("AskSpot_3-5").global_position.x)
	await _wait(2.5)
	await _press(&"ask_dog")
	_check(await _wait_flag(&"station_key", 20.0), "간이역: 하늘이가 벤치 밑 열쇠를 물어 온다(station_key)")
	await _wait(8.0)  # 돌아올 때까지
	await _walk_to(station.get_node("Look_3-6_Door").global_position.x)
	await _wait(0.4)
	await _press(&"interact")
	_check(await _wait_flag(&"station_door_open", 2.0), "간이역: 열쇠로 대합실 문을 연다")

	# 숲·강가·철교의 부탁 자리
	for pid in ["forest", "riverside", "bridge"]:
		var place: Node = await _go(pid)
		for spot in place.get_children():
			if not String(spot.name).begins_with("AskSpot_"):
				continue
			await _walk_to(spot.global_position.x)
			await _wait(3.0)
			await _press(&"ask_dog")
			_check(await _wait_flag(spot.grants_flag, 20.0), "%s: %s 부탁이 된다(%s)" % [pid, spot.name, spot.grants_flag])
			if spot.action == 2:  # 기다려: 하윤이 건너가면 따라온다
				await _walk_to(spot.global_position.x + spot.target_offset.x + spot.release_offset + 300.0)
				await _wait(3.0)
				_check(absf(_dog.global_position.x - _player.global_position.x) < 250.0, "%s: 건너간 뒤 하늘이가 따라온다" % pid)
			await _wait(6.0)

	if _failures == 0:
		print("부품 흐름 검사 통과")
	else:
		print("부품 흐름 검사 실패 %d건" % _failures)
	quit(1 if _failures > 0 else 0)
