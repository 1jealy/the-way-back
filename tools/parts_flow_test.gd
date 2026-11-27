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


## 대사 상자가 열려 있으면 E로 끝까지 넘긴다.
func _close_dialogue() -> void:
	var box: Node = _main.dialogue_box()
	for i in 12:
		await _wait(0.5)
		if not box.visible:
			return
		await _press(&"interact")


func _wait_flag(flag: StringName, seconds: float) -> bool:
	for i in int(seconds / 0.25):
		if _state.has_flag(flag):
			return true
		await _wait(0.25)
	return _state.has_flag(flag)


func _wait_until(cond: Callable, seconds: float) -> bool:
	for i in int(seconds * 20.0):
		if cond.call():
			return true
		await _wait(0.05)
	return cond.call()


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

	# 집: 잠긴 서랍(덜컹) → 액자 뒤 열쇠 → 서랍에서 지도. 지도 없이는 대문에서 막힌다.
	var house: Node = _main.current_place()
	var gate: Node2D = house.get_node("Gate_1-6")
	await _walk_to(gate.global_position.x + 200.0)
	_check(_player.global_position.x < gate.global_position.x, "집: 지도 없이는 대문(Gate_1-6)에서 막힌다")
	var drawer: Node = house.get_node("Look_1-5_Drawer")
	var rattled := [false]
	drawer.locked.connect(func(): rattled[0] = true)
	await _walk_to(drawer.global_position.x)
	await _press(&"interact")
	await _wait(0.3)
	_check(rattled[0] and not _state.has_flag(&"has_map"), "집: 열쇠 없이 서랍을 열면 덜컹(잠김)")
	await _walk_to(house.get_node("Look_1-4_Frame").global_position.x)
	await _press(&"interact")
	await _walk_to(drawer.global_position.x)
	await _press(&"interact")
	await _close_dialogue()
	_check(_state.has_flag(&"has_map"), "집: 서랍에서 지도를 얻는다")
	var hint: Label = _main.get_node("Overlay/MapHint")
	_check(hint.visible, "집: 지도를 얻으면 [M] 지도 안내가 뜬다")
	var torch: Node2D = house.get_node("Keepsake_1-6_Flashlight")  # #116
	await _walk_to(torch.global_position.x)
	await _press(&"interact")
	_check(await _wait_flag(&"item_flashlight", 3.0), "집: 마당에서 할아버지 손전등을 줍는다(item_flashlight)")
	await _wait(1.5)
	await _walk_to(gate.global_position.x + 200.0)
	_check(_player.global_position.x > gate.global_position.x, "집: 지도를 얻으면 대문을 지나간다")

	# 들판: 2-3 날아간 지도(#111). 지나가면 바람 → 지도가 억새 속으로 사라진다 → 방패연을 줍고 띄운다 →
	# 높이 올린 연에서 지도가 보인다 → 줍는다. 그 전에는 Gate_2-3.
	var field: Node = await _go("field")
	var chase: Node2D = field.get_node("MapChase_2-3")
	var field_gate: Node2D = field.get_node("Gate_2-3")
	var kite_item: Node2D = field.get_node("Keepsake_2-3_Kite")
	var kite_game: Node2D = field.get_node("KiteFly_2-3")
	await _walk_to(chase.global_position.x + 60.0)
	await _wait(0.5)
	_check(chase.state == 1 and _main.dialogue_box().visible, "들판: 지나가면 바람에 지도가 날아가고 대사가 뜬다")
	await _close_dialogue()
	await _wait(3.0)
	_check(chase.buried and not _state.has_flag(&"map_caught"), "들판: 지도가 억새 속으로 사라진다")
	await _walk_to(chase.stop_position(0).x)
	await _press(&"interact")
	_check(not _state.has_flag(&"map_caught"), "들판: 연을 띄우기 전에는 지도를 못 줍는다")
	await _walk_to(field_gate.global_position.x + 200.0)
	_check(_player.global_position.x < field_gate.global_position.x, "들판: 줍기 전에는 Gate_2-3에서 막힌다")
	await _walk_to(kite_item.global_position.x)
	await _press(&"interact")
	_check(await _wait_flag(&"item_kite", 2.0), "들판: 방패연을 줍는다(item_kite)")
	kite_game.calm_seconds = 0.6
	kite_game.warn_seconds = 0.3
	kite_game.gust_seconds = 0.8
	var autoplay_script: Script = load("res://scripts/game/minigame.gd")
	autoplay_script.autoplay = true
	await _wait_until(func(): return _player.controls_enabled, 4.0)
	await _wait(0.3)
	await _press(&"interact")
	_check(await _wait_until(func(): return kite_game.running, 4.0), "들판: 연을 주우고 [E] 연 띄우기로 그 자리에서 띄운다")
	_check(not _player.controls_enabled, "들판: 연을 날리는 동안 하윤은 걷지 않는다")
	_check(await _wait_flag(&"kite_flown", 20.0), "들판: 돌풍 세 번을 버티면 연이 높이 오른다(kite_flown)")
	_check(not chase.buried, "들판: 연이 오르면 지도가 다시 보인다")
	_check(await _wait_until(func(): return _player.controls_enabled, 8.0), "들판: 연을 거두면 다시 걷는다")
	autoplay_script.autoplay = false
	await _walk_to(chase.stop_position(0).x)
	await _press(&"interact")
	_check(await _wait_flag(&"map_caught", 2.0), "들판: 보인 지도를 E로 줍는다(map_caught)")
	await _walk_to(field_gate.global_position.x + 200.0)
	_check(_player.global_position.x > field_gate.global_position.x, "들판: 지도를 주우면 지나간다")
	# 들판: 2-4 경운기. 다가오면 비켜서서 인사하고, 지나간 뒤에 다시 걷는다.
	var tractor: Node2D = field.get_node("Tractor_2-4")
	await _walk_to(tractor.global_position.x)
	await _wait(1.0)
	_check(tractor.running and not _player.controls_enabled, "들판: 경운기가 다가오면 하윤이 멈춘다")
	for i in 40:
		await _wait(0.5)
		if _main.dialogue_box().visible:
			break
	_check(_main.dialogue_box().visible, "들판: 경운기가 가까이 오면 인사한다")
	await _close_dialogue()
	_check(await _wait_flag(&"tractor_passed", 15.0), "들판: 경운기가 지나가면 끝난다(tractor_passed)")
	await _wait(0.3)
	_check(_player.controls_enabled, "들판: 경운기가 지나간 뒤 다시 걷는다")

	# 간이역: 만남(3-4)
	var station: Node = await _go("station")
	var meeting: Node2D = station.get_node("DogMeeting_3-4")
	_check(not _dog.visible, "간이역: 3-3 벤치에 앉기 전에는 하늘이가 보이지 않는다")
	var bench: Node2D = station.get_node("Sit_3-3")
	await _walk_to(bench.global_position.x - 250.0)
	Input.action_press(&"move_right")  # 벤치 쪽으로 몇 걸음
	await _wait(1.0)
	Input.action_release(&"move_right")
	_check(bench.sitting and not _player.controls_enabled, "간이역: 3-3 벤치에 닿으면 저절로 앉는다")
	_check(await _wait_flag(&"station_sat", 9.0), "간이역: 6초 앉아 있다가 일어난다(station_sat)")
	await _wait(0.5)
	_check(_player.controls_enabled and _dog.visible, "간이역: 일어나면 하늘이가 나타난다")
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
	var box: Node = _main.dialogue_box()
	var thanked := false
	for i in 60:  # 돌아올 때까지
		await _wait(0.25)
		if box.visible:
			thanked = true
			break
	_check(thanked, "간이역: 하늘이가 돌아오면 \"하윤: 고마워.\"")
	await _close_dialogue()
	var door_gate: Node2D = station.get_node("Gate_3-6")
	await _walk_to(door_gate.global_position.x + 200.0)
	_check(_player.global_position.x < door_gate.global_position.x, "간이역: 문을 열기 전에는 대합실 문에서 막힌다")
	await _walk_to(station.get_node("Look_3-6_Door").global_position.x)
	await _wait(0.4)
	await _press(&"interact")
	_check(await _wait_flag(&"station_door_open", 2.0), "간이역: 열쇠로 대합실 문을 연다")
	await _walk_to(door_gate.global_position.x + 200.0)
	_check(_player.global_position.x > door_gate.global_position.x, "간이역: 문을 열면 대합실로 지나간다")

	# 숲 4-2: 빛 갈림길 두 번. 첫째는 냄새 → 틀린 빛(이끼 바위 앞으로) → 맞는 빛(다음으로).
	# 둘째(#111)는 버들피리를 줍고 메아리를 따라 불어야 맞는 빛이 다음으로 이어진다.
	var forest: Node = await _go("forest")
	var ask: Node2D = forest.get_node("AskSpot_4-2_1")
	var fork_gate: Node2D = forest.get_node("Gate_4-2_1")
	await _walk_to(fork_gate.global_position.x + 200.0)
	_check(_player.global_position.x < fork_gate.global_position.x, "숲: 갈림길 1은 걸어서는 못 지나간다")
	await _walk_to(ask.global_position.x)
	await _wait(1.0)
	await _press(&"ask_dog")
	_check(await _wait_flag(ask.grants_flag, 20.0), "숲: 갈림길 1에서 냄새 → 맞는 빛 쪽으로 짖는다")
	await _wait(6.0)
	var right_x: float = ask.global_position.x + ask.target_offset.x
	var wrong: Node2D = null
	var right: Node2D = null
	for i in 3:
		var light: Node2D = forest.get_node("Look_4-2_Light1%d" % (i + 1))
		if is_equal_approx(light.global_position.x, right_x):
			right = light
		elif wrong == null:
			wrong = light
	await _walk_to(wrong.global_position.x)
	await _press(&"interact")
	await _wait(2.0)
	_check(absf(_player.global_position.x - wrong.to_x) < 5.0 and _player.global_position.x < ask.global_position.x,
			"숲: 갈림길 1 틀린 빛을 따라가면 이끼 바위 앞으로 돌아온다")
	await _walk_to(right.global_position.x)
	await _press(&"interact")
	await _wait(2.0)
	_check(_player.global_position.x > fork_gate.global_position.x, "숲: 갈림길 1 맞는 빛을 따라가면 지나간다")

	var flute_item: Node2D = forest.get_node("Keepsake_4-2_Flute")
	var flute_game: Node2D = forest.get_node("FluteEcho_4-2")
	var gate2: Node2D = forest.get_node("Gate_4-2_2")
	var right2: Node2D = forest.get_node("Look_4-2_Light23")
	await _walk_to(right2.global_position.x)
	await _press(&"interact")
	await _wait(2.0)
	_check(_player.global_position.x < gate2.global_position.x and not flute_game.running,
			"숲: 피리 없이는 맞는 빛도 이끼 바위 앞으로 돌아온다")
	await _walk_to(flute_item.global_position.x)
	await _press(&"interact")
	_check(await _wait_flag(&"item_willow_flute", 2.0), "숲: 버들피리를 줍는다(item_willow_flute)")
	flute_game.echo_gap = 0.25
	var auto: Script = load("res://scripts/game/minigame.gd")
	auto.autoplay = true
	await _walk_to(flute_game.global_position.x)
	await _press(&"interact")
	_check(await _wait_until(func(): return flute_game.running or flute_game.done, 3.0), "숲: [E] 피리 불기로 메아리가 들린다")
	_check(await _wait_flag(&"flute_echo_done", 15.0), "숲: 메아리를 따라 불면 flute_echo_done")
	auto.autoplay = false
	_check(await _wait_until(func(): return _player.controls_enabled, 6.0), "숲: 따라 불고 나면 다시 걷는다")
	await _walk_to(right2.global_position.x)
	await _press(&"interact")
	await _wait(2.0)
	_check(_player.global_position.x > gate2.global_position.x, "숲: 따라 분 뒤에는 맞는 빛을 따라가면 지나간다")

	# 강가·철교의 부탁 자리
	for pid in ["riverside", "bridge"]:
		var place: Node = await _go(pid)
		for spot in place.get_children():
			if not String(spot.name).begins_with("AskSpot_"):
				continue
			if pid == "bridge":  # 손전등이 있으면 냄새 부탁 자리는 닫힌다(#116). 없을 때는 gameplay_test가 본다
				_check(spot.used, "철교: 손전등을 가져왔으면 냄새 부탁(AskSpot_6-3)은 닫힌다")
				continue
			var stones: Node2D = place.get_node_or_null("Gate_5-3")
			if stones:
				await _walk_to(stones.global_position.x + 200.0)
				_check(_player.global_position.x < stones.global_position.x, "강가: 하늘이가 버티기 전에는 징검다리에서 막힌다")
			await _walk_to(spot.global_position.x)
			await _wait(3.0)
			await _press(&"ask_dog")
			_check(await _wait_flag(spot.grants_flag, 20.0), "%s: %s 부탁이 된다(%s)" % [pid, spot.name, spot.grants_flag])
			if spot.action == 2:  # 기다려: 하윤이 건너가면 따라온다
				await _walk_to(spot.global_position.x + spot.target_offset.x + spot.release_offset + 300.0)
				await _wait(3.0)
				_check(absf(_dog.global_position.x - _player.global_position.x) < 250.0, "%s: 건너간 뒤 하늘이가 따라온다" % pid)
			await _wait(6.0)
			if pid == "riverside":  # 5-4 돌 주머니(#115) → 동그라미 4 → 기억 장면 4 → 물수제비 미니게임(선택)
				var pouch: Node2D = place.get_node("Keepsake_5-4_Pouch")
				var shallows: Node2D = place.get_node("Look_5-4_Shallows")
				var memory: Node = place.get_node("Memory_5-4")
				await _walk_to(pouch.global_position.x)
				await _press(&"interact")
				_check(await _wait_flag(&"item_stone_pouch", 3.0), "강가: 돌 주머니를 줍는다(item_stone_pouch)")
				await _wait(2.0)
				await _walk_to(shallows.global_position.x)
				await _press(&"interact")
				await _wait(2.5)
				await _press(&"open_map")  # 지도 접기
				await _wait(1.0)
				_check(memory.playing and not _main.dialogue_box().visible, "강가: 동그라미 4를 접으면 기억 장면 4가 겹쳐 뜬다")
				await memory.ended
				var skip: Node = place.get_node("Skip_5-4")
				await _wait(0.3)
				_check(skip.playing and skip.running and not _main.dialogue_box().visible,
						"강가: 기억 장면 뒤 돌 주머니로 물수제비(미니게임)를 한다")
				var auto_skip: Script = load("res://scripts/game/minigame.gd")
				auto_skip.autoplay = true
				await skip.finished
				auto_skip.autoplay = false
				await _wait(0.8)
				_check(skip.best >= 5 and _state.has_flag(&"skip_five") and not _main.dialogue_box().visible,
						"강가: 다섯 번을 튀기면 skip_five, \"다섯 번은 어렵다\" 글은 안 나온다")
				_check(_player.controls_enabled, "강가: 물수제비가 끝나면 다시 걷는다")
		if pid == "bridge":
			var slope: Node2D = place.get_node("Look_6-3_Slope")
			var edge: Node2D = place.get_node("Gate_6-2")
			var lamp: Node = place.get_node("BankLight_6-3")
			var auto_lamp: Script = load("res://scripts/game/minigame.gd")
			auto_lamp.autoplay = true
			await _walk_to(edge.global_position.x + 200.0)
			_check(_player.global_position.x < edge.global_position.x, "철교: 끊긴 끝(Gate_6-2)에서 막힌다")
			await _press(&"interact")
			_check(await _wait_until(func(): return lamp.running or lamp.done, 3.0), "철교: 끊긴 끝에서 [E] 강둑 비추기로 강둑 아래를 비춘다")
			_check(await _wait_flag(&"bridge_bank_path", 20.0), "철교: 디딤돌 다섯을 찾으면 bridge_bank_path")
			auto_lamp.autoplay = false
			_check(await _wait_until(func(): return _player.controls_enabled, 6.0), "철교: 다 비추면 다시 걷는다")
			await _walk_to(slope.global_position.x)
			await _press(&"interact")
			await _wait(2.0)
			_check(absf(_player.global_position.x - slope.to_x) < 5.0, "철교: 디딤돌을 찾은 뒤 강둑으로 내려가면 강둑 길에 선다 (%.0f)" % _player.global_position.x)

	# 나루터 엔딩(7-2 ~ 7-5, 지금은 사진 뒤 바로 제목)
	var ferry: Node = await _go("ferry")
	var ending: Node = ferry.get_node("Ending_7-3")
	_check(_main.music_playing(), "나루터: 들어서면 휘파람 선율이 시작된다(7-1)")
	var grandpa: Node2D = ferry.get_node("Grandpa_7-3")
	var end_gate: Node2D = ferry.get_node("Gate_7-3")
	_check(not grandpa.visible, "나루터: 다섯째 동그라미 전에는 할아버지가 안 보인다")
	await _walk_to(end_gate.global_position.x + 200.0)
	_check(_player.global_position.x < end_gate.global_position.x, "나루터: 다섯째 동그라미 전에는 할아버지 쪽으로 못 간다")
	await _walk_to(ferry.get_node("Look_7-2_Map").global_position.x)
	await _press(&"interact")
	await _wait(2.5)
	await _press(&"open_map")  # 지도 접기
	await _wait(1.0)
	_check(_state.has_flag(&"map_circle_5") and grandpa.visible, "나루터: 다섯째 동그라미를 체크하면 할아버지가 나타난다")
	await _walk_to(end_gate.global_position.x + 150.0)
	await _wait(0.5)
	_check(ending.started and not _player.controls_enabled, "나루터: 할아버지에게 다가가면 엔딩이 시작되고 조작이 멈춘다")
	var greeted := false
	for i in 40:
		await _wait(0.25)
		if _main.dialogue_box().visible:
			greeted = true
			break
	_check(greeted and absf(_dog.global_position.x - (grandpa.global_position.x - 80.0)) < 10.0,
			"나루터: 하늘이가 먼저 할아버지에게 가고 \"왔니.\"")
	await _close_dialogue()
	var cut_seen := false
	for i in 80:  # 컷신이 끝나고 대사가 나올 때까지
		await _wait(0.25)
		for c in ending.get_children():
			if c is CanvasLayer and c.get_child_count() > 0:
				cut_seen = true
		if _main.dialogue_box().visible:
			break
	_check(cut_seen, "나루터: 팔찌 컷신이 나온다")
	await _close_dialogue()
	_check(await _wait_flag(&"ending_photo", 15.0), "나루터: 마지막 사진(셔터)")
	# 7-6 강 위: 배가 저절로 흘러간다(검사는 4배 빠르게)
	for i in 40:
		await _wait(0.25)
		if _state.current_place == &"crossing":
			break
	_check(_state.current_place == &"crossing", "강 위: 사진 뒤 셋이 배를 타고 강 위 구간으로")
	await _wait(0.5)
	var ride: Node = _main.current_place().get_node("BoatRide_7-6")
	ride.return_to_title = false
	_check(not _player.controls_enabled and _main.music_playing(), "강 위: 조작 없이 휘파람 선율이 흐른다")
	_check(ride.get_node_or_null("Boat/Reflections") != null and ride.get_node("Boat/Reflections").get_child_count() >= 3,
			"강 위: 물에 비친 셋(하윤·할아버지·하늘이)과 배")
	var x0 := _player.global_position.x
	Engine.time_scale = 4.0
	var done := await _wait_flag(&"ending_seen", 120.0)  # 게임 시간(배 70초 + 컷신 2 + 제목)
	Engine.time_scale = 1.0
	_check(_player.global_position.x > x0 + 4000.0, "강 위: 배가 오른쪽으로 흘러갔다 (%.0f px)" % (_player.global_position.x - x0))
	_check(ride.ghosts_shown == 5, "강 위: 지나온 장소 다섯이 차례로 비쳤다 (%d)" % ride.ghosts_shown)
	_check(ride.touched, "강 위: 하윤이 물을 한 번 만진다")
	_check(done, "강 위: 컷신 2(빛 속으로) 뒤 하얀 화면에 제목으로 끝난다")
	_check(ride.portraits_revealed, "강 위: 제목 뒤 영정사진 두 개가 비치고 하윤 사진이 또렷해진다(7-8)")

	if _failures == 0:
		print("부품 흐름 검사 통과")
	else:
		print("부품 흐름 검사 실패 %d건" % _failures)
	quit(1 if _failures > 0 else 0)
