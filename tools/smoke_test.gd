extends SceneTree
## 헤드리스 스모크 검사. 실패가 하나라도 있으면 종료 코드 1.
## godot --headless --path . --script res://tools/smoke_test.gd
##
## _init()이 아니라 _initialize()에서 시작한다 — --script로 넘긴 MainLoop는
## 오토로드(GameState)보다 먼저 만들어진다.

var _failures: int = 0

## 장면표(docs/story.md)의 장소 순서, 화면 길이, 장면 번호.
const PLACES := [
	[&"house", 3, ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6"]],
	[&"field", 6, ["2-1", "2-2", "2-3", "2-4", "2-5", "2-6"]],
	[&"station", 5, ["3-1", "3-2", "3-3", "3-4", "3-5", "3-6"]],
	[&"forest", 5, ["4-1", "4-2", "4-3", "4-4"]],
	[&"riverside", 4, ["5-1", "5-2", "5-3", "5-4"]],
	[&"bridge", 4, ["6-1", "6-2", "6-3"]],
	[&"ferry", 2, ["7-1", "7-2", "7-3", "7-4", "7-5", "7-6", "7-7"]],
]
const LAYERS := ["Sky", "Far", "Mid", "Ground", "Props", "Front"]


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


## 장소 씬을 하나씩 따로 불러 약속을 지키는지 본다.
func _check_places() -> void:
	for i in PLACES.size():
		var want: Array = PLACES[i]
		var path := "res://scenes/places/%s.tscn" % want[0]
		var scene: PackedScene = load(path)
		_check(scene != null, "%s 씬을 불러온다" % path)
		if scene == null:
			continue
		var place: Node2D = scene.instantiate()
		_check(place is Place, "%s 루트가 Place다" % want[0])
		if not place is Place:
			place.free()
			continue
		_check(place.place_id == want[0], "%s place_id" % want[0])
		_check(is_equal_approx(place.width, want[1] * 1920.0), "%s 폭이 화면 %d개" % [want[0], want[1]])
		var layers_ok := true
		for layer in LAYERS:
			layers_ok = layers_ok and place.has_node("Layers/" + layer)
		_check(layers_ok, "%s 층 이름이 약속대로다" % want[0])
		var names: Array = []
		var inside := true
		var prev_x := -INF
		var ordered := true
		for m in place.get_node("Markers").get_children():
			names.append(String(m.name))
			inside = inside and m.position.x > 0.0 and m.position.x < place.width \
					and is_equal_approx(m.position.y, Place.GROUND_Y)
			ordered = ordered and m.position.x > prev_x
			prev_x = m.position.x
		_check(names == want[2], "%s 장면 표시 %s" % [want[0], ", ".join(want[2])])
		_check(inside, "%s 장면 표시가 장소 안, 땅 높이에 있다" % want[0])
		_check(ordered, "%s 장면 표시가 장면 순서대로 왼쪽에서 오른쪽" % want[0])
		var want_next := ""
		if i + 1 < PLACES.size():
			want_next = "res://scenes/places/%s.tscn" % PLACES[i + 1][0]
		_check(place.next_place == want_next, "%s 다음 장소가 %s" % [want[0], want_next if want_next else "없음"])
		place.free()


func _run() -> void:
	print("스모크 검사 시작")
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

	_check_places()

	# 집에서 나루터까지 끝 지점을 차례로 밟아 7곳을 잇는다.
	for i in range(1, PLACES.size()):
		var here: Node2D = main.current_place()
		player.global_position.x = here.width - 320.0
		await _hold(&"move_right", 2.0)
		await _wait(1.2)
		var want: Array = PLACES[i]
		_check(state.current_place == want[0], "%s 끝에 닿으면 %s(으)로 넘어간다" % [PLACES[i - 1][0], want[0]])
		_check(is_equal_approx(main.current_place().width, want[1] * 1920.0),
				"%s 폭은 화면 %d개" % [want[0], want[1]])
		_check(player.global_position.x < 400.0, "%s 시작 지점에 선다" % want[0])
		_check(player.is_on_floor(), "%s에서 바닥에 서 있다" % want[0])

	var last: Node2D = main.current_place()
	player.global_position.x = last.width - 320.0
	await _hold(&"move_right", 2.0)
	await _wait(1.2)
	_check(state.current_place == &"ferry", "나루터는 끝이라 그 자리에 머문다")

	if _failures == 0:
		print("스모크 검사 통과")
	else:
		print("스모크 검사 실패 %d건" % _failures)
	quit(1 if _failures > 0 else 0)
