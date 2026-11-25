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


## assets/art/의 배경 그림이 장소 씬에 다 들어가 있는지 (tools/art_import.gd --check와 같다).
func _check_art() -> void:
	var lib: RefCounted = load("res://tools/art_import_lib.gd").new()
	lib.run(false)
	for w in lib.warnings:
		print("  경고  ", w)
	for e in lib.errors:
		print("        ", e)
	for s in lib.out_of_sync:
		print("        %s: 그림과 맞지 않는다" % s)
	_check(lib.ok(), "배경 그림이 장소 씬과 맞다 (아니면 tools/art_import.gd를 돌린다)")


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
	_check_art()
	_check_audio(main)

	var x0 := player.global_position.x
	await _hold(&"move_right", 0.5)
	_check(player.global_position.x > x0 + 50.0, "오른쪽으로 걷는다")
	var x1 := player.global_position.x
	await _hold(&"move_left", 0.3)
	_check(player.global_position.x < x1, "왼쪽으로 걷는다")

	var front: Node2D = place.get_node("Layers/Front")
	_check(front.z_index > player.z_index, "앞 층이 하윤보다 앞에 그려진다")
	if place.greybox:  # 그림이 들어오면 회색 네모가 꺼진다
		_check(front.get_child_count() > 0, "회색 네모 앞 층 물체가 있다")

	_check_places()
	_check_parts()
	await _check_house_puzzle(main, player)

	# 집에서 나루터까지 끝 지점을 차례로 밟아 7곳을 잇는다.
	# 들판 2-3 날아간 지도는 푼 것으로 둔다(풀기 전이면 지나갈 때 바람이 불어 조작이 멈춘다. 흐름은 게임플레이 검사).
	state.set_flag(&"map_caught")
	state.set_flag(&"tractor_passed")  # 2-4 경운기도 지나간 것으로(지나가는 동안 조작이 멈춘다)
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
	# 지도 손글씨(할아버지·하윤): 지도 문구 글자가 다 있는지
	var map_texts: Array[String] = []
	var map_consts: Dictionary = load("res://scripts/game/map_data.gd").get_script_constant_map()
	map_texts.append(map_consts["HEADER"])
	for place in map_consts["PLACES"]:
		map_texts.append(place["label"])
	for road in map_consts["SIDE_ROADS"]:
		map_texts.append(road["label"])
	for c in map_consts["CIRCLES"]:
		map_texts.append(c["note"])
	for hand in ["grandpa_hand_subset", "hayun_hand_subset"]:
		var hand_font: FontFile = load("res://assets/fonts/%s.ttf" % hand)
		if hand_font == null:
			_check(false, "지도 글꼴을 불러온다: %s" % hand)
			continue
		var hand_missing := ""
		for text in map_texts:
			for i in text.length():
				if not hand_font.has_char(text.unicode_at(i)) and not hand_missing.contains(text[i]):
					hand_missing += text[i]
		_check(not hand_font.allow_system_fallback and hand_missing.is_empty(),
				"지도 글꼴 %s: OS 글꼴로 대신하지 않고 지도 문구 글자가 다 있다%s" % [hand, "" if hand_missing.is_empty() else " (빠짐: %s)" % hand_missing])


## 장소에 놓은 부품(조사 대상·부탁 자리·하늘이 만남)이 약속을 지키는지 본다. CLAUDE.md 참고.
## 지도 동그라미는 장면 2-2, 3-1, 4-3, 5-4, 7-2.
const CIRCLE_SCENES := {1: ["field", "2-2"], 2: ["station", "3-1"], 3: ["forest", "4-3"], 4: ["riverside", "5-4"], 5: ["ferry", "7-2"]}
const INTERACTABLE := "res://scripts/game/interactable.gd"
const ASK_SPOT := "res://scripts/dog/ask_spot.gd"
const DOG_MEETING := "res://scripts/dog/dog_meeting.gd"
const GATE := "res://scripts/game/gate.gd"
const PASSAGE := "res://scripts/game/passage.gd"
const BENCH := "res://scripts/game/bench_sit.gd"
const MEMORY := "res://scripts/game/memory_scene.gd"
const MAP_CHASE := "res://scripts/game/map_chase.gd"
const SHAKE := "res://scripts/game/shake_drop.gd"


func _script_path(node: Node) -> String:
	var s: Script = node.get_script()
	return s.resource_path if s else ""


func _check_parts() -> void:
	var granted := {}  # 플래그 → 처음 세우는 [장소 순서, x]
	var required := []  # [장소 순서, x, 플래그, 이름]
	var circles := {}
	var memories := {}  # 동그라미 → [장소, 장면, 그림 있나, 소절 있나]
	var chases := []  # [장소, 덤불 땅 x들, 지도 그림 있나]
	var meeting_x := -1.0
	var fetch_x := -1.0
	var station_end := 0.0
	var all_ok := true
	for i in PLACES.size():
		var place_id: String = PLACES[i][0]
		var place: Node2D = load("res://scenes/places/%s.tscn" % place_id).instantiate()
		var markers := {}
		for m in place.get_node("Markers").get_children():
			markers[String(m.name)] = m.position.x
		for node in place.get_children():
			var path := _script_path(node)
			if path == MEMORY:
				var find_art: Callable = load("res://scripts/ui/cutscene_player.gd").find_art
				var pick: Callable = load("res://scripts/game/sound_bank.gd").pick
				memories[node.get("circle")] = [place_id, String(node.name).get_slice("_", 1),
						not find_art.call(node.get("art")).is_empty(), pick.call(node.get("phrase")) != null]
				continue
			if path == MAP_CHASE:  # 2-3 날아간 지도: 마지막 덤불에서 줍고 grants_flag를 세운다
				var stops: PackedFloat32Array = node.get("stops")
				var xs := []
				for sx in stops:
					xs.append(node.position.x + sx)
				chases.append([place_id, xs, not load("res://scripts/ui/cutscene_player.gd").find_art.call(node.get("art")).is_empty()])
				var chase_flag: StringName = node.get("grants_flag")
				if not xs.is_empty() and not chase_flag.is_empty() and not granted.has(chase_flag):
					granted[chase_flag] = [i, xs[-1]]
				var chase_req: StringName = node.get("requires_flag")
				if not chase_req.is_empty():
					required.append([i, node.position.x, chase_req, "%s/%s" % [place_id, node.name]])
				continue
			if path not in [INTERACTABLE, ASK_SPOT, DOG_MEETING, GATE, PASSAGE, BENCH, SHAKE]:
				continue
			var x: float = node.position.x
			var on_ground: bool = is_equal_approx(node.position.y, 810.0) and x > 0.0 and x < place.width
			if not on_ground:
				all_ok = false
				print("        %s/%s: 땅 위·장소 안이 아니다 %s" % [place_id, node.name, node.position])
			var scene_id := String(node.name).get_slice("_", 1)
			if not markers.has(scene_id):
				all_ok = false
				print("        %s/%s: 이름의 장면 번호 '%s'가 Markers에 없다" % [place_id, node.name, scene_id])
			if path == DOG_MEETING:
				meeting_x = x
				station_end = place.width - 120.0
				var appears: StringName = node.get("appears_on_flag")
				if not appears.is_empty():
					required.append([i, x, appears, "%s/%s" % [place_id, node.name]])
				continue
			if path == GATE:
				var opens: StringName = node.get("opens_on_flag")
				if not opens.is_empty():
					required.append([i, x, opens, "%s/%s" % [place_id, node.name]])
				continue
			var flag: StringName = node.get("grants_flag")
			if not flag.is_empty() and not granted.has(flag):
				granted[flag] = [i, x]
			if path in [INTERACTABLE, PASSAGE, BENCH, SHAKE]:
				var req: StringName = node.get("requires_flag")
				if not req.is_empty():
					required.append([i, x, req, "%s/%s" % [place_id, node.name]])
				var n: int = node.get("map_circle")
				if n > 0:
					circles[n] = [place_id, scene_id]
					var circle_flag := StringName("map_circle_%d" % n)
					if not granted.has(circle_flag):
						granted[circle_flag] = [i, x]
			elif String(node.name) == "AskSpot_3-5":
				fetch_x = x
		place.free()
	_check(all_ok, "부품: 모두 땅 위(y = 810), 장소 안, 이름에 장면 번호")
	var circles_ok := circles.size() == 5
	for n in CIRCLE_SCENES:
		circles_ok = circles_ok and circles.get(n, []) == CIRCLE_SCENES[n]
	_check(circles_ok, "부품: 지도 동그라미 1~5가 장면 2-2, 3-1, 4-3, 5-4, 7-2에 하나씩 %s" % [circles])
	var mem_ok := memories.size() == 4
	for n in range(1, 5):
		var m: Array = memories.get(n, [])
		mem_ok = mem_ok and m.size() == 4 and [m[0], m[1]] == CIRCLE_SCENES[n] and m[2] and m[3]
	_check(mem_ok, "부품: 기억 장면 1~4가 동그라미 1~4와 같은 장소·장면에 하나씩, 그림·휘파람 소절이 있다 %s" % [memories])
	_check(granted.has(&"has_map") and granted[&"has_map"][0] == 0, "부품: 집에서 지도(has_map)를 얻는다")
	var snags := _placeholder_list("FIELD_SNAGS")
	var chase_ok: bool = chases.size() == 1 and chases[0][0] == "field" and chases[0][2] and chases[0][1].size() == 3
	if chase_ok:
		for k in 3:
			chase_ok = chase_ok and k < snags.size() and is_equal_approx(chases[0][1][k], snags[k])
	var tractor := _find_by_script("field", "res://scripts/game/tractor_pass.gd")
	_check(tractor.size() == 1 and String(tractor[0][0]) == "Tractor_2-4" and chases.size() == 1 and tractor[0][1] > 7000.0,
			"부품: 들판 2-4에 경운기(Tractor_2-4) 하나, 2-3 벽(Gate_2-3) 오른쪽 %s" % [tractor])
	var opening := _find_by_script("house", "res://scripts/game/opening.gd")
	var portraits := _find_by_script("house", "res://scripts/game/funeral_portraits.gd")
	var find_art: Callable = load("res://scripts/ui/cutscene_player.gd").find_art
	var art_ok := true
	for art in ["cut_accident", "prop_portrait_grandpa", "prop_portrait_hayun"]:
		art_ok = art_ok and not find_art.call(art).is_empty()
	_check(opening.size() == 1 and portraits.size() == 1 and String(portraits[0][0]) == "Portraits_1-2" and art_ok,
			"부품: 집에 오프닝(0-1)과 영정사진 두 개(1-2), 그림(컷신 0·영정 2장)이 있다 %s %s" % [opening, portraits])
	var forest_scene: Node = load("res://scenes/places/forest.tscn").instantiate()
	var clear_sit: Node = forest_scene.get_node_or_null("Sit_4-3")
	var clear_light: Node = forest_scene.get_node_or_null("Light_4-3")
	var clear_look: Node = forest_scene.get_node_or_null("Look_4-3_Clearing")
	var clear_ok: bool = clear_sit != null and clear_light != null and clear_look != null \
			and clear_light.get_node_or_null(clear_light.get("sit")) == clear_sit \
			and clear_sit.get("pose") == &"sit_floor" and clear_sit.get("requires_flag") == &"map_circle_3" \
			and absf(clear_sit.position.x - clear_look.position.x) < 400.0
	_check(clear_ok, "부품: 숲 4-3 빈터에 바닥 앉기(동그라미 3 뒤)와 빛 쏟아지기가 이어져 있다")
	forest_scene.free()
	var shakes := _find_by_script("house", SHAKE)
	_check(shakes.size() == 1 and String(shakes[0][0]) == "Shake_1-6_Persimmon" and shakes[0][1] < 5300.0,
			"부품: 집 마당 1-6에 감나무 흔들기 하나, 대문 안쪽 %s" % [shakes])
	_check(chase_ok, "부품: 들판에 날아간 지도(2-3) 하나, 덤불 셋이 임시 배경 FIELD_SNAGS와 같은 자리, 지도 그림이 있다 %s / %s" % [chases, snags])
	var chain_ok := true
	for r in required:
		var g: Array = granted.get(r[2], [])
		if g.is_empty() or g[0] > r[0] or (g[0] == r[0] and g[1] > r[1] + 400.0):
			chain_ok = false
			print("        %s: requires_flag '%s'를 세우는 곳이 앞에 없다" % [r[3], r[2]])
	_check(chain_ok, "부품: requires_flag·막는 벽(Gate)의 플래그마다 그 앞(왼쪽·앞 장소)에서 세운다")
	_check(meeting_x > 0.0, "부품: 간이역에 하늘이 만남(3-4)")
	_check(meeting_x > 0.0 and meeting_x + 600.0 < station_end, "부품: 만남 자리 + 물러날 거리 600px가 끝 지점보다 왼쪽")
	_check(fetch_x > meeting_x and meeting_x > 0.0, "부품: 첫 부탁(3-5)이 만남 자리보다 오른쪽")


## 장소 씬에서 그 스크립트를 붙인 자식들: [[이름, x], ...]
func _find_by_script(place_id: String, script_path: String) -> Array:
	var place: Node = load("res://scenes/places/%s.tscn" % place_id).instantiate()
	var out := []
	for node in place.get_children():
		if _script_path(node) == script_path:
			out.append([node.name, node.position.x if node is Node2D else 0.0])
	place.free()
	return out


## tools/placeholder_art.py의 숫자 목록 상수(예: FIELD_SNAGS = [5000, 5900, 6800]).
func _placeholder_list(name: String) -> Array:
	var text := FileAccess.get_file_as_string("res://tools/placeholder_art.py")
	var re := RegEx.create_from_string("(?m)^" + name + r" = \[([^\]]*)\]")
	var m := re.search(text)
	var out := []
	if m:
		for part in m.get_string(1).split(","):
			if not part.strip_edges().is_empty():
				out.append(float(part))
	return out


## 키를 한 번 누른다. _unhandled_input으로 받는 동작은 Input.action_press로는 안 오고 이벤트여야 한다.
func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


## 집 퍼즐: 액자 뒤 열쇠 → 서랍 → 지도. 실제로 E를 눌러 본다.
func _check_house_puzzle(main: Node, player: CharacterBody2D) -> void:
	var state: Node = root.get_node("GameState")
	main.go_to("res://scenes/places/house.tscn")
	await _wait(2.0)
	var place: Node = main.current_place()
	var frame: Node = place.get_node("Look_1-4_Frame")
	var drawer: Node = place.get_node("Look_1-5_Drawer")
	player.global_position.x = drawer.global_position.x
	await _wait(0.3)
	_check(not drawer.is_available(), "집: 열쇠 없이는 서랍을 열 수 없다")
	player.global_position.x = frame.global_position.x
	await _wait(0.3)
	await _press(&"interact")
	await _wait(0.3)
	_check(state.has_flag(&"house_drawer_key"), "집: 액자를 살펴보면 열쇠를 얻는다")
	player.global_position.x = drawer.global_position.x
	await _wait(0.3)
	await _press(&"interact")
	for i in 6:  # 대사 넘기기
		await _wait(0.6)
		await _press(&"interact")
	await _wait(0.3)
	_check(state.has_flag(&"has_map"), "집: 서랍을 열면 지도를 얻는다(has_map)")


## assets/audio/ 소리 규칙(이름·반복)과 장소 환경음. 지금 장소의 환경음이 실제로 돌고 있는지도 본다.
func _check_audio(main: Node) -> void:
	var lib: RefCounted = load("res://tools/audio_import_lib.gd").new()
	lib.run(false)
	for w in lib.warnings:
		print("  경고  ", w)
	for e in lib.errors:
		print("        ", e)
	for s in lib.out_of_sync:
		print("        %s: 소리와 맞지 않는다" % s)
	_check(lib.ok(), "소리가 규칙과 장소 씬에 맞다 (아니면 tools/audio_import.gd를 돌린다)")
	var amb: AudioStreamPlayer = main.current_place().get_node_or_null("Sound/Ambience")
	_check(amb != null and amb.playing, "장소에 들어오면 환경음이 돈다")
