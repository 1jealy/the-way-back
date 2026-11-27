class_name KiteFly
extends PhraseGame
## 들판 2-3 연 날리기(#111 → #146에서 "휘파람 따라 하기"로). 지도가 바람에 날아가 억새 속으로 사라진 뒤,
## 길가에서 방패연(할아버지가 하윤 몸에 맞게 만들어 준 작은 연)을 줍고 [E] 연 띄우기로 그 자리에서 띄운다.
## 연이 떠 있으면 바람 너머에서 할아버지 휘파람이 한 소절(들판, 세 음) 들린다. 음마다 하늘의 그 높이에 빛이 반짝인다.
## 하윤이 ← 낮게 · E 가운데 · → 높게로 연을 그 높이로 옮기면 연줄이 바람에 그 높이의 음으로 운다.
## 맞으면 꼬리 리본 하나가 붉게 물든다(셋 = 세 음). 틀리면 연이 휘청 내려앉고 리본이 다시 하얘진 뒤 휘파람이 다시 들린다.
## 다 맞으면 할아버지가 받아 불고, 연이 높이 올라 억새 속 지도가 보인다(grants_flag kite_flown) — 카메라가 지도 쪽으로 갔다 온다.
## 도움(세 번 어긋나면): 휘파람이 크고 느리고, 반짝임이 하윤 차례에도 남고, 하늘이가 다음 음마다 짖는다.
## 이 소절(세 음)이 숲 소절의 앞 세 음이다 — 숲에서 피리로 이어 분다.
## 장소 씬에 B가 놓는다(KiteFly_2-3, 물건 Keepsake_2-3_Kite와 같은 자리). 원점은 땅 위.

const KITE_LOW := 640.0   # h = 0일 때 연 높이(y)
const KITE_HIGH := 120.0  # h = 1일 때
## 높이(0 낮음 · 1 가운데 · 2 높음)마다 연이 가는 자리(h).
const LEVEL_H := [0.3, 0.55, 0.8]
const RED := Color(0.78, 0.27, 0.23)
const CREAM := Color(0.96, 0.91, 0.8)
const GOLD := Color(1.0, 0.86, 0.56)

## 연이 하윤 앞으로 떠 있는 거리(px).
@export var kite_ahead: float = 430.0

## 연 높이(0~1)와 속도.
var h: float = 0.0
var vh: float = 0.0

var _t: float = 0.0
var _goal_h: float = 0.42
var _anchor: Vector2
var _kick: float = 0.0
var _slump: float = 0.0

var _kite_root: Node2D
var _kite: Sprite2D
var _glow: Sprite2D
var _ribbons: Array[Line2D] = []
var _ribbon_held: Array[float] = []
var _string: Line2D
var _tail: Line2D
var _streaks: Array[Line2D] = []
## 하늘에 반짝이는 음 자리(메아리 음마다 하나).
var _marks: Array[Sprite2D] = []


func _init() -> void:
	trigger_flag = &"item_kite"
	phrase_id = &"field"
	first_round_notes = 0
	echo_gap = 0.85  # 배우는 자리라 가장 느리다


static func y_of(height: float) -> float:
	return lerpf(KITE_LOW, KITE_HIGH, height)


## 높이(0·1·2)에서 연이 있는 자리.
func level_position(level: int) -> Vector2:
	return Vector2(_anchor.x + kite_ahead, y_of(LEVEL_H[level]))


func echo_position() -> Vector2:
	# 바람 너머(연 쪽 먼 하늘)에서 들려온다.
	var x := (_anchor.x if _anchor != Vector2.ZERO else global_position.x) + 1200.0
	return Vector2(x, 400.0)


func _setup() -> void:
	_anchor = _player.global_position if _player else global_position
	_echo_player.global_position = echo_position()
	if _player:
		_player.face(1)
		_player.set_pose(&"kite")
	h = 0.0
	vh = 0.0
	_goal_h = 0.42
	_build()


func _build() -> void:
	_string = Line2D.new()
	_string.name = "String"
	_string.width = 2.5
	_string.default_color = Color(0.24, 0.22, 0.2, 0.85)
	_string.z_index = -1  # 하윤 뒤: 줄이 주먹 안에서 나오는 것처럼 손이 줄 끝을 덮는다(#114)
	_string.z_as_relative = false
	add_child(_string)

	_tail = Line2D.new()
	_tail.name = "StringTail"
	_tail.width = 2.5
	_tail.default_color = Color(0.24, 0.22, 0.2, 0.85)
	_tail.z_index = -1
	_tail.z_as_relative = false
	add_child(_tail)

	var mote := CutscenePlayer.find_art("fx_light_mote")
	var mote_tex: Texture2D = load(mote) if not mote.is_empty() else null
	_marks.clear()
	for i in melody.size():
		var s := Sprite2D.new()
		s.name = "Mark%d" % i
		s.texture = mote_tex
		s.scale = Vector2(2.2, 2.2)
		s.modulate = Color(GOLD, 0.0)
		s.z_index = 5
		s.z_as_relative = false
		add_child(s)
		_marks.append(s)

	_kite_root = Node2D.new()
	_kite_root.name = "Kite"
	_kite_root.z_index = 6
	_kite_root.z_as_relative = false
	add_child(_kite_root)
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = mote_tex
	_glow.scale = Vector2(4.5, 4.5)
	_glow.modulate.a = 0.0
	_kite_root.add_child(_glow)
	_ribbons.clear()
	_ribbon_held.clear()
	for i in melody.size():
		var r := Line2D.new()
		r.name = "Ribbon%d" % i
		r.width = 7.0
		r.default_color = CREAM
		r.begin_cap_mode = Line2D.LINE_CAP_ROUND
		r.end_cap_mode = Line2D.LINE_CAP_ROUND
		_kite_root.add_child(r)
		_ribbons.append(r)
		_ribbon_held.append(0.0)
	_kite = Sprite2D.new()
	_kite.name = "Body"
	var path := CutscenePlayer.find_art("prop_kite_body")
	if not path.is_empty():
		_kite.texture = load(path)
	_kite.scale = Vector2(0.85, 0.85)  # 하윤 몸에 맞는 작은 연
	_kite_root.add_child(_kite)

	_streaks.clear()
	for i in 3:
		var s := Line2D.new()
		s.name = "Wind%d" % i
		s.width = 4.0 - i
		s.default_color = Color(1.0, 0.98, 0.93, 0.0)
		s.z_index = 9
		s.z_as_relative = false
		add_child(s)
		_streaks.append(s)
	_place_kite(0.0)


# ---- 휘파람 따라 하기 ----

func _on_listen(_retry: bool) -> void:
	for m in _marks:
		create_tween().tween_property(m, "modulate:a", 0.0, 0.3)


## 메아리 한 음: 하늘의 그 높이에 빛이 반짝인다.
func _on_echo(i: int, level: int, gap: float) -> void:
	var m := _marks[i]
	m.global_position = level_position(level) + Vector2(120.0 + i * 70.0, 0.0)
	m.scale = Vector2(3.4, 3.4)
	var t := create_tween().set_parallel()
	t.tween_property(m, "modulate:a", 0.95, gap * 0.3)
	t.tween_property(m, "scale", Vector2(2.2, 2.2), gap * 0.8).set_trans(Tween.TRANS_SINE)


## 하윤 차례. 도움 전에는 반짝임이 옅어진다(들은 것을 기억해서 띄운다).
func _on_play() -> void:
	for m in _marks:
		create_tween().tween_property(m, "modulate:a", 0.55 if help else 0.12, 0.8)


func _on_note(i: int, level: int, correct: bool) -> void:
	_goal_h = LEVEL_H[level]
	_kick = 1.0
	if correct:
		_ribbon_held[i] = 1.0
		create_tween().tween_property(_marks[i], "modulate:a", 0.0, 0.6)
	else:
		# 연이 휘청 내려앉는다. 리본은 다시 하얘진다(그 소절을 다시 듣는다).
		_slump = 1.0
		_goal_h = 0.25
		vh = -0.8
		for k in _ribbon_held.size():
			_ribbon_held[k] = 0.0


## 다 맞추고 할아버지가 받아 분 뒤: 연이 높이 올라가고(지도가 걸린 자리가 보인다), 줄을 감아 거둔다.
func _on_finish() -> void:
	dog_react(1.0, 1.2)
	_goal_h = 1.08
	await _wait(1.4)
	if not grants_flag.is_empty():
		GameState.set_flag(grants_flag)  # 지도 자리가 보인다(MapChase.reveal_flag)
	# 보상(#119): 카메라가 억새 속에서 반짝이는 지도 쪽으로 옮겨 갔다가 돌아온다
	var chase := get_tree().get_first_node_in_group("map_chase") as Node2D
	if chase and chase.has_method("stop_position") and _player:
		pan_camera(clampf(chase.stop_position(chase.stop_index).x - _player.global_position.x, -700.0, 700.0), 1.1)
		await _wait(2.2)
		pan_camera(0.0, 0.9)
	else:
		await _wait(1.6)
	var fade := create_tween().set_parallel()
	for n in [_kite_root, _string, _tail]:
		fade.tween_property(n, "modulate:a", 0.0, 0.8)
	await fade.finished
	for n in [_kite_root, _string, _tail]:
		n.queue_free()
	for s in _streaks:
		s.queue_free()
	for m in _marks:
		m.queue_free()
	_streaks.clear()
	_marks.clear()
	_kite_root = null
	if _player:
		_player.set_motion({})
		_player.set_pose(&"stand")
	clear()


## 연줄이 바람에 우는 소리: 줄을 퉁긴 듯한 배음 + 바람에 떨리는 꼬리(진짜 소리는 #122).
func _make_tone(hz: float) -> AudioStreamWAV:
	var seconds := 0.7
	return PhraseGame._synth(seconds, func(t: float) -> float:
		var f := hz * (1.0 + 0.012 * sin(TAU * 6.5 * t))
		var env := minf(1.0, t / 0.02) * exp(-t * 3.2) * clampf((seconds - t) / 0.15, 0.0, 1.0)
		var v := sin(TAU * f * t) + 0.35 * sin(TAU * 2.0 * f * t) + 0.15 * sin(TAU * 3.0 * f * t)
		return (v + 0.05 * (randf() - 0.5)) * env * 0.36)


# ---- 매 프레임 ----

func _update(delta: float) -> void:
	_t += delta
	_kick = move_toward(_kick, 0.0, delta * 2.5)
	_slump = move_toward(_slump, 0.0, delta * 1.2)
	# 연은 목표 높이로 용수철처럼 따라가고, 바람에 조금 흔들린다.
	var goal := _goal_h + sin(_t * 1.1) * 0.015
	vh += ((goal - h) * 14.0 - vh * 5.0) * delta
	h = clampf(h + vh * delta, 0.0, 1.1)
	_place_kite(delta)
	_place_hint()
	_pose_player()


## 연 날리는 몸(#114): 연을 옮길 때 두 손을 번갈아 당기고(올릴 때) 풀고(내릴 때), 고개는 연 높이를 따라간다.
## 들을 때는 바람 쪽으로 고개를 기울이고, 틀리면 어깨가 처진다.
func _pose_player() -> void:
	if _player == null:
		return
	var pulling := vh > 0.05
	var reel := sin(_t * TAU * 2.2) * _kick
	var m := {}
	m["shoulder"] = reel * 9.0 + (-6.0 if pulling else 4.0) + _slump * 6.0
	m["elbow"] = -reel * 16.0 + (-12.0 if pulling else 6.0)
	m["far_shoulder"] = -reel * 9.0 + (-6.0 if pulling else 4.0) + _slump * 6.0
	m["far_elbow"] = reel * 16.0 + (-12.0 if pulling else 6.0)
	m["torso"] = (-4.0 if pulling else 1.0) + _slump * 5.0
	m["head"] = -(h - 0.35) * 26.0 + _slump * 6.0
	m["ponytail"] = 6.0 + sin(_t * 3.0) * 4.0
	if phase == &"listen" or phase == &"answer":
		m["head"] = float(m["head"]) - 5.0  # 바람 너머 휘파람 쪽으로
	_player.set_motion(m)


func _place_kite(delta: float) -> void:
	if _kite_root == null:
		return
	var pos := Vector2(_anchor.x + kite_ahead + sin(_t * 0.7) * 30.0, y_of(h))
	_kite_root.global_position = pos
	_kite.rotation = sin(_t * 1.3) * 0.08 - clampf(vh, -1.0, 1.0) * 0.12 + sin(_t * 23.0) * 0.04 * _slump
	var glow_goal := 0.85 if _kick > 0.2 and _slump < 0.1 else 0.0
	if phase == &"answer" or phase == &"done":
		glow_goal = 0.9
	_glow.modulate.a = move_toward(_glow.modulate.a, glow_goal, delta * 3.0)
	# 꼬리 리본: 연 아래에서 바람 반대쪽(왼쪽)으로 물결친다. 맞힌 음만큼 붉게 물든다.
	for i in _ribbons.size():
		var r := _ribbons[i]
		var base := Vector2(-34.0 + 34.0 * i, 60.0)
		var pts := PackedVector2Array()
		for k in 9:
			var u := k / 8.0
			pts.append(base + Vector2(-u * 55.0 + sin(_t * 5.0 + u * 6.0 + i) * 10.0 * u, u * 95.0))
		r.points = pts
		var goal := RED if _ribbon_held[i] > 0.0 else CREAM
		r.default_color = r.default_color.lerp(goal, minf(1.0, delta * 4.0))
	# 연줄: 손에서 연까지 살짝 처진다.
	# 줄은 주먹 가운데를 지나간다: 하윤 뒤(z -1)에 그려 손이 덮고, 주먹 아래로 남은 줄이 조금 늘어진다(#114).
	var hand := (_player.hand_point() + Vector2(6.0, 6.0)) if _player else _anchor + Vector2(30.0, -150.0)
	if _tail:
		var sway := sin(_t * 2.3) * 4.0
		_tail.points = PackedVector2Array([to_local(hand), to_local(hand + Vector2(-4.0 + sway * 0.3, 26.0)),
				to_local(hand + Vector2(-12.0 + sway, 52.0))])
	var pts := PackedVector2Array()
	for k in 13:
		var u := k / 12.0
		var p := hand.lerp(pos, u)
		p.y += sin(u * PI) * (40.0 - _kick * 20.0)  # 음을 낼 때 줄이 팽팽해진다
		pts.append(to_local(p))
	_string.points = pts
	# 바람 줄기: 늘 옅게 흘러간다. 휘파람이 들릴 때 조금 짙다.
	var wind := 0.45 if phase == &"listen" or phase == &"answer" else 0.22
	for i in _streaks.size():
		var s := _streaks[i]
		var y := pos.y + 60.0 + i * 48.0
		var x := _anchor.x - 700.0 + fmod(_t * 700.0 + i * 260.0, 1600.0)
		s.points = PackedVector2Array([to_local(Vector2(x, y)), to_local(Vector2(x + 120.0, y - 10.0)), to_local(Vector2(x + 260.0, y - 6.0))])
		s.default_color.a = move_toward(s.default_color.a, wind, delta * 2.0)
