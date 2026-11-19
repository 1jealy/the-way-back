extends SceneTree
## 헤드리스 스모크 검사. 실패가 하나라도 있으면 종료 코드 1.
## godot --headless --path . --script res://tools/smoke_test.gd
##
## _init()이 아니라 _initialize()에서 시작한다 — --script로 넘긴 MainLoop는
## 오토로드(GameState)보다 먼저 만들어진다.

var _failures: int = 0


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


func _run() -> void:
	print("스모크 검사 시작")
	_check_font()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)

	var state: Node = root.get_node("GameState")
	var player: CharacterBody2D = main.get_node("World/Player")
	var place: Node2D = main.current_place()

	_check(state.current_place == &"house", "첫 장소는 할아버지 집")
	_check(player.is_on_floor(), "하윤이 바닥에 서 있다")
	_check(absf(player.global_position.y - 810.0) < 4.0, "하윤의 발이 땅 높이(810)에 있다")

	var x0 := player.global_position.x
	await _hold(&"move_right", 0.5)
	_check(player.global_position.x > x0 + 50.0, "오른쪽으로 걷는다")
	var x1 := player.global_position.x
	await _hold(&"move_left", 0.3)
	_check(player.global_position.x < x1, "왼쪽으로 걷는다")

	var front: Node2D = place.get_node("Layers/Front")
	_check(front.z_index > player.z_index, "앞 층이 하윤보다 앞에 그려진다")
	_check(front.get_child_count() > 0, "회색 네모 앞 층 물체가 있다")

	player.global_position.x = place.width - 320.0
	await _hold(&"move_right", 2.0)
	await _wait(1.2)
	_check(state.current_place == &"field", "집 끝에 닿으면 들판으로 넘어간다")
	_check(is_equal_approx(main.current_place().width, 11520.0), "들판 폭은 화면 6개")
	_check(player.global_position.x < 400.0, "들판 시작 지점에 선다")

	var main_place: Node2D = main.current_place()
	player.global_position.x = main_place.width - 320.0
	await _hold(&"move_right", 2.0)
	await _wait(1.2)
	_check(state.current_place == &"field", "다음 장소가 없으면 그 자리에 머문다")

	if _failures == 0:
		print("스모크 검사 통과")
	else:
		print("스모크 검사 실패 %d건" % _failures)
	quit(1 if _failures > 0 else 0)


## 웹에는 OS 글꼴이 없다. 장소 이름과 화면 문구의 글자가 한글 글꼴에 다 있는지 본다.
## 글자를 모으는 전체 검사는 tools/font_subset.py --check (CI).
func _check_font() -> void:
	var font: FontFile = load("res://assets/fonts/noto_sans_kr_regular_subset.ttf")
	_check(font != null, "한글 글꼴을 불러온다")
	if font == null:
		return
	_check(not font.allow_system_fallback, "글꼴이 OS 글꼴로 대신하지 않는다(웹과 같게)")
	var texts: Array[String] = []
	for file in DirAccess.get_files_at("res://scenes/places"):
		if file.ends_with(".tscn") and file != "place_template.tscn":
			var place: Node = load("res://scenes/places/" + file).instantiate()
			texts.append(place.display_name)
			place.free()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	for label in main.find_children("*", "Label", true, false):
		texts.append(label.text)
	main.free()
	var missing := ""
	for text in texts:
		for i in text.length():
			if not font.has_char(text.unicode_at(i)) and not missing.contains(text[i]):
				missing += text[i]
	_check(missing.is_empty(), "장소 이름·화면 문구 글자가 글꼴에 있다" + ("" if missing.is_empty() else " (빠짐: %s)" % missing))
