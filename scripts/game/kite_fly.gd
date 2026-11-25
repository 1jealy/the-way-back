class_name KiteFly
extends MiniGame
## 들판 2-3 연 날리기(#111, 기획서 "미니게임"). 지도가 바람에 날아가 억새 속으로 사라진 뒤,
## 길가에서 할아버지 방패연(물건)을 주우면 그 자리에서 띄운다. 높이 올린 연에서 지도가 걸린 자리가 보인다.
## 화면 안에 녹인 UI: 하늘에 비스듬한 노을빛 띠(맞춰야 할 높이), 연이 그 안이면 연 둘레가 환해진다.
## 돌풍은 바람 줄기로 1초 먼저 보인다. 돌풍을 버틸 때마다 연 꼬리 리본 하나가 붉게 물든다(셋).
## 조작: E를 누르고 있으면 줄을 감아 올라가고, 떼면 풀려 내려온다. 연이 땅까지 내려오면 한 번 어긋남.
## 도움(세 번 어긋나면): 노을빛 띠가 두 배로 넓어진다.
## 장소 씬에 B가 놓는다(KiteFly_2-3, 물건 Keepsake_2-3_Kite와 같은 자리). 원점은 땅 위.

const GROUND_Y := 810.0
const KITE_LOW := 640.0   # h = 0일 때 연 높이(y)
const KITE_HIGH := 120.0  # h = 1일 때
const LIFT := 1.4         # 감을 때 올라가는 힘(h/초²)
const SINK := 0.8         # 풀 때 내려가는 힘
const DAMP := 3.0
const RED := Color(0.78, 0.27, 0.23)
const CREAM := Color(0.96, 0.91, 0.8)

## 이 플래그(물건)가 서면 하윤이 가까이 있을 때 시작한다.
@export var trigger_flag: StringName = &"item_kite"
## 하윤이 이만큼 안에 있어야 시작한다.
@export var trigger_distance: float = 500.0
## 돌풍 수(= 꼬리 리본 수).
@export var gusts: int = 3
## 노을빛 띠 가운데 높이와 반폭(0~1, 도움이 켜지면 반폭이 두 배).
@export var zone_center: float = 0.68
@export var zone_half: float = 0.1
## 돌풍 사이 쉬는 시간, 예고 시간, 돌풍 시간(초).
@export var calm_seconds: float = 3.0
@export var warn_seconds: float = 1.0
@export var gust_seconds: float = 1.4
## 돌풍 동안 이만큼(비율) 띠 안에 있으면 버틴 것.
@export var hold_ratio: float = 0.6
## 연이 하윤 앞으로 떠 있는 거리(px).
@export var kite_ahead: float = 430.0
@export var gust_sound: String = "sfx_wind_gust_"

## 버틴 돌풍 수.
var gusts_held: int = 0
## 연 높이(0~1)와 속도.
var h: float = 0.35
var vh: float = 0.0
## calm / warn / gust / rising
var phase: StringName = &"calm"

var _t: float = 0.0
var _phase_left: float = 0.0
var _in_zone_time: float = 0.0
var _gust_dir: float = -1.0
var _anchor: Vector2
var _waiting: float = -1.0
var _pressed_once: bool = false

var _band: Polygon2D
var _kite_root: Node2D
var _kite: Sprite2D
var _glow: Sprite2D
var _ribbons: Array[Line2D] = []
var _ribbon_held: Array[float] = []
var _string: Line2D
var _streaks: Array[Line2D] = []


func _process(delta: float) -> void:
	if not running and not done and GameState.has_flag(trigger_flag):
		var player := get_tree().get_first_node_in_group("player") as Player
		if player and player.controls_enabled \
				and absf(player.global_position.x - global_position.x) < trigger_distance:
			if _waiting < 0.0:
				_waiting = 1.2  # 물건이 떠올라 사라지는 동안 기다린다
			_waiting -= delta
			if _waiting <= 0.0:
				_waiting = -1.0
				play()
	super._process(delta)


func zone_low() -> float:
	return zone_center - _half()


func zone_high() -> float:
	return zone_center + _half()


func in_zone() -> bool:
	return h >= zone_low() and h <= zone_high()


func _half() -> float:
	return zone_half * (2.0 if help else 1.0)


static func y_of(height: float) -> float:
	return lerpf(KITE_LOW, KITE_HIGH, height)


func _begin() -> void:
	_anchor = _player.global_position if _player else global_position
	if _player:
		_player.face(1)
		_player.set_pose(&"kite")
	gusts_held = 0
	h = 0.35
	vh = 0.6
	_set_phase(&"calm", calm_seconds * 0.7)
	_build()
	show_key_hint(["E"], "꾹 누르면 감기")


func _build() -> void:
	_band = Polygon2D.new()
	_band.name = "SunBand"
	_band.z_index = -25
	_band.z_as_relative = false
	add_child(_band)
	_update_band()

	_string = Line2D.new()
	_string.name = "String"
	_string.width = 2.5
	_string.default_color = Color(0.24, 0.22, 0.2, 0.85)
	_string.z_index = 5
	_string.z_as_relative = false
	add_child(_string)

	_kite_root = Node2D.new()
	_kite_root.name = "Kite"
	_kite_root.z_index = 6
	_kite_root.z_as_relative = false
	add_child(_kite_root)
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	var mote := CutscenePlayer.find_art("fx_light_mote")
	if not mote.is_empty():
		_glow.texture = load(mote)
	_glow.scale = Vector2(4.5, 4.5)
	_glow.modulate.a = 0.0
	_kite_root.add_child(_glow)
	_ribbons.clear()
	_ribbon_held.clear()
	for i in gusts:
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


func _update_band() -> void:
	if _band == null:
		return
	var top := y_of(zone_high()) - global_position.y
	var bot := y_of(zone_low()) - global_position.y
	var x0 := _anchor.x - 500.0 - global_position.x
	var x3 := _anchor.x + 1500.0 - global_position.x
	var slant := 50.0  # 왼쪽이 조금 낮다(지는 해 쪽)
	var feather := 46.0  # 위아래 가장자리를 흐리게
	var xs := [x0, lerpf(x0, x3, 0.2), lerpf(x0, x3, 0.8), x3]
	var ys := [top - feather, top, bot, bot + feather]
	var gold := Color(1.0, 0.85, 0.54)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for r in 4:
		for c in 4:
			var x: float = xs[c]
			pts.append(Vector2(x, ys[r] + (x3 - x) / (x3 - x0) * slant))
			var inner := (r == 1 or r == 2) and (c == 1 or c == 2)
			cols.append(Color(gold, 0.42 if inner else 0.0))
	_band.polygon = pts
	_band.vertex_colors = cols
	var polys := []
	for r in 3:
		for c in 3:
			var i := r * 4 + c
			polys.append(PackedInt32Array([i, i + 1, i + 5, i + 4]))
	_band.polygons = polys


func _set_phase(p: StringName, seconds: float) -> void:
	phase = p
	_phase_left = seconds
	if p == &"gust":
		_in_zone_time = 0.0
		_gust_dir = -1.0 if randf() < 0.7 else 1.0
		_play_sound(gust_sound)


func _holding() -> bool:
	if MiniGame.autoplay:
		return h < zone_center
	return Input.is_action_pressed("interact")


func _tick(delta: float) -> void:
	_t += delta
	var hold := _holding()
	if hold and not _pressed_once:
		_pressed_once = true
		hide_key_hint()
	if phase != &"rising":
		var acc := LIFT if hold else -SINK
		if phase == &"gust":
			acc += _gust_dir * 1.8 * (0.6 + 0.4 * sin(_t * 9.0))
		vh += acc * delta
		vh *= exp(-DAMP * delta)
		h = clampf(h + vh * delta, 0.0, 1.0)
		if h >= 1.0:
			vh = minf(vh, 0.0)
		if h <= 0.0:
			_dropped()
		else:
			_tick_phase(delta)
	_place_kite(delta)
	_place_hint()
	_pose_player(hold)


## 연 날리는 몸(#114): 감을 때는 두 손을 번갈아 당기고 몸을 조금 뒤로, 돌풍에는 다리를 벌려 버티고
## 꽁지머리가 날린다. 고개는 연 높이를 따라간다.
func _pose_player(hold: bool) -> void:
	if _player == null:
		return
	var m := {}
	var reel := sin(_t * TAU * 2.2) if hold and phase != &"rising" else 0.0
	m["shoulder"] = reel * 9.0 + (-6.0 if hold else 4.0)
	m["elbow"] = -reel * 16.0 + (-12.0 if hold else 6.0)
	m["far_shoulder"] = -reel * 9.0 + (-6.0 if hold else 4.0)
	m["far_elbow"] = reel * 16.0 + (-12.0 if hold else 6.0)
	m["torso"] = -4.0 if hold else 1.0
	m["head"] = -(h - 0.35) * 26.0
	if phase == &"gust":
		m["torso"] = float(m["torso"]) - 7.0
		m["hip"] = 9.0
		m["knee"] = 12.0
		m["far_hip"] = -14.0
		m["far_knee"] = 10.0
		m["ponytail"] = 14.0 + sin(_t * 17.0) * 4.0
	elif phase == &"warn":
		m["head"] = float(m["head"]) + 6.0  # 바람 오는 쪽을 흘끗
	_player.set_motion(m)


func _tick_phase(delta: float) -> void:
	_phase_left -= delta
	match phase:
		&"calm":
			if _phase_left <= 0.0:
				_set_phase(&"warn", warn_seconds)
		&"warn":
			if _phase_left <= 0.0:
				_set_phase(&"gust", gust_seconds)
		&"gust":
			if in_zone():
				_in_zone_time += delta
			if _phase_left <= 0.0:
				if _in_zone_time >= gust_seconds * hold_ratio:
					_held_gust()
				else:
					miss()
					_set_phase(&"calm", calm_seconds)


## 연이 땅까지 내려왔다: 한 번 어긋남, 다시 띄운다(버틴 돌풍은 그대로).
func _dropped() -> void:
	miss()
	h = 0.3
	vh = 0.7
	_set_phase(&"calm", calm_seconds)


func _held_gust() -> void:
	_ribbon_held[gusts_held] = 1.0
	gusts_held += 1
	if gusts_held >= gusts:
		_finish()
	else:
		_set_phase(&"calm", calm_seconds)


func _on_help() -> void:
	_update_band()


## 다 버텼다: 연이 높이 올라가고(지도가 걸린 자리가 보인다), 줄을 감아 거둔다.
func _finish() -> void:
	phase = &"rising"
	hide_key_hint()
	var tween := create_tween()
	tween.tween_property(self, "h", 1.08, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not grants_flag.is_empty():
		GameState.set_flag(grants_flag)  # 지도 자리가 보인다(MapChase.reveal_flag)
	await _wait(1.6)
	var fade := create_tween().set_parallel()
	for n in [_kite_root, _string, _band]:
		fade.tween_property(n, "modulate:a", 0.0, 0.8)
	await fade.finished
	for n in [_kite_root, _string, _band]:
		n.queue_free()
	for s in _streaks:
		s.queue_free()
	_streaks.clear()
	if _player:
		_player.set_motion({})
		_player.set_pose(&"stand")
	clear()


func _place_kite(delta: float) -> void:
	if _kite_root == null:
		return
	var pos := Vector2(_anchor.x + kite_ahead + sin(_t * 0.7) * 30.0, y_of(h))
	_kite_root.global_position = pos
	var shake := 0.0
	if phase == &"gust":
		shake = sin(_t * 23.0) * 0.06
	_kite.rotation = sin(_t * 1.3) * 0.08 - clampf(vh, -1.0, 1.0) * 0.12 + shake
	var glow_goal := 0.85 if in_zone() and phase != &"rising" else 0.0
	_glow.modulate.a = move_toward(_glow.modulate.a, glow_goal, delta * 3.0)
	if _band:
		_band.modulate.a = move_toward(_band.modulate.a, 1.0 if in_zone() else 0.75, delta * 3.0)
	# 꼬리 리본: 연 아래에서 바람 반대쪽(왼쪽)으로 물결친다. 버틴 만큼 붉게 물든다.
	for i in _ribbons.size():
		var r := _ribbons[i]
		var base := Vector2(-34.0 + 34.0 * i, 70.0)
		var pts := PackedVector2Array()
		for k in 9:
			var u := k / 8.0
			pts.append(base + Vector2(-u * 60.0 + sin(_t * 5.0 + u * 6.0 + i) * 10.0 * u, u * 110.0))
		r.points = pts
		var goal := RED if _ribbon_held[i] > 0.0 else CREAM
		r.default_color = r.default_color.lerp(goal, minf(1.0, delta * 4.0))
	# 연줄: 손에서 연까지 살짝 처진다.
	var hand := _player.hand_point() if _player else _anchor + Vector2(30.0, -150.0)
	var pts := PackedVector2Array()
	for k in 13:
		var u := k / 12.0
		var p := hand.lerp(pos, u)
		p.y += sin(u * PI) * 40.0
		pts.append(to_local(p))
	_string.points = pts
	# 바람 줄기: 예고와 돌풍 동안 왼쪽에서 흘러간다.
	var wind := 0.0
	if phase == &"warn":
		wind = 1.0 - _phase_left / maxf(warn_seconds, 0.01)
	elif phase == &"gust":
		wind = 1.0
	for i in _streaks.size():
		var s := _streaks[i]
		var y := pos.y + 60.0 + i * 48.0
		var x := _anchor.x - 700.0 + fmod(_t * 900.0 + i * 260.0, 1600.0)
		s.points = PackedVector2Array([to_local(Vector2(x, y)), to_local(Vector2(x + 120.0, y - 10.0)), to_local(Vector2(x + 260.0, y - 6.0))])
		s.default_color.a = move_toward(s.default_color.a, 0.55 * wind, delta * 2.0)
