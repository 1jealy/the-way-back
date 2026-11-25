class_name KiteFlight
extends MiniGame
## 장면표 2-3 연 날리기(퍼즐 2). 할아버지 방패연을 주우면(Keepsake) 그 자리에서 연을 띄운다.
## 하늘에 노을빛 띠가 걸린다. E를 누르고 있으면 실을 당겨 연이 오르고, 놓으면 내려온다.
## 돌풍이 세 번 분다. 돌풍 동안 연을 띠 안에 붙잡아 두면 꼬리 리본이 하나씩 붉게 물든다
## (붙잡아 둔 만큼 그 리본이 서서히 붉어진다 — 게이지 대신). 놓치면 같은 돌풍이 다시 온다.
## 셋 다 붉어지면 연이 높이 올라 억새 속 지도 자리가 빛으로 보인다(done_flag kite_flown → MapChase가 듣는다).
## 장소 씬에 B가 놓는다(KiteFlight_2-3, 줍는 연 Keepsake 옆 땅 위). 담당: A. (A 대신 B 세션이 만듦)

## 리본 하나가 붉게 물들었다(i = 0부터).
signal ribbon_done(i: int)

## 시작 신호를 줄 할아버지 물건(Keepsake). taken 뒤에 연을 띄운다.
@export var keepsake: NodePath
@export var art: String = "prop_kite"
@export var reel_art: String = "prop_kite_reel"
## 연이 하윤보다 이만큼 앞(오른쪽)에 뜬다.
@export var kite_offset_x: float = 320.0
## 연이 갈 수 있는 높이(화면 y). 땅은 810.
@export var y_high: float = 130.0
@export var y_low: float = 560.0
## 돌풍마다 띠 가운데 높이(화면 y). 개수 = 돌풍 수.
@export var band_heights: PackedFloat32Array = PackedFloat32Array([300.0, 210.0, 340.0])
## 돌풍마다 미는 힘(px/초, +는 아래로, -는 위로). 띠 높이와 짝.
@export var gust_push: PackedFloat32Array = PackedFloat32Array([190.0, -170.0, 210.0])
## 띠 두께의 절반(px). 도와줄 때는 help_band_half.
@export var band_half: float = 70.0
@export var help_band_half: float = 115.0
## 도와줄 때 돌풍 힘 배율.
@export var help_push_scale: float = 0.5
## 실을 당길 때 오르는 빠르기, 놓을 때 내려오는 빠르기(px/초).
@export var rise_speed: float = 230.0
@export var fall_speed: float = 150.0
@export var launch_seconds: float = 1.6
@export var calm_seconds: float = 1.8
@export var gust_seconds: float = 3.0
## 돌풍 동안 이만큼(비율) 띠 안에 있으면 리본이 붉어진다.
@export var need_ratio: float = 0.6
@export var gust_sound: String = "sfx_wind_gust_"
@export var ribbon_sound: String = "sfx_pickup_"

enum Phase { IDLE, LAUNCH, CALM, GUST, SOAR }

const RIBBON_PLAIN := Color(0.97, 0.93, 0.84)
const RIBBON_RED := Color(0.84, 0.26, 0.2)
const BAND_COLOR := Color(1.0, 0.62, 0.4, 0.5)

var phase: Phase = Phase.IDLE
## 붉게 물든 리본 수(= 지금 기다리는 돌풍 번호).
var ribbons: int = 0
var kite_y: float = 0.0
var band_y: float = 0.0
var inside_time: float = 0.0
var _v: float = 0.0
var _t: float = 0.0
var _band_from: float = 0.0
var _half: float = 0.0
var _push_scale: float = 1.0

var _band: Sprite2D
var _kite: Sprite2D
var _reel: Sprite2D
var _string: Line2D
var _tail: Line2D
var _bows: Array[Polygon2D] = []


func _ready() -> void:
	super._ready()
	if key_hint == "[E]":
		key_hint = "[E] 당기기"
	if done_flag.is_empty():
		done_flag = &"kite_flown"
	var k := get_node_or_null(keepsake)
	if k and k.has_signal("taken"):
		k.taken.connect(begin)


func gust_count() -> int:
	return band_heights.size()


## 지금 연이 띠 안에 있나.
func kite_inside() -> bool:
	return absf(kite_y - band_y) <= _half


func band_half_now() -> float:
	return _half


func push_now() -> float:
	if phase != Phase.GUST or ribbons >= gust_push.size():
		return 0.0
	return gust_push[ribbons] * _push_scale * sin(PI * clampf(_t / gust_seconds, 0.0, 1.0))


func _on_begin() -> void:
	ribbons = 0
	_half = band_half
	_push_scale = 1.0
	_build()
	kite_y = _player.hand_point().y
	_v = 0.0
	band_y = band_heights[0]
	_band_from = band_y
	_set_phase(Phase.LAUNCH)


func _on_help() -> void:
	# 많이 놓치면 띠가 넓어지고 바람이 순해진다(실패로 끝나는 일은 없다).
	var tween := create_tween()
	tween.tween_method(func(h: float): _half = h, _half, help_band_half, 0.8)
	_push_scale = help_push_scale


func _auto_pressing() -> bool:
	var ahead := kite_y + (_v + push_now()) * 0.25
	return ahead > band_y


func _set_phase(p: Phase) -> void:
	phase = p
	_t = 0.0
	match p:
		Phase.CALM:
			_band_from = band_y
			inside_time = 0.0
		Phase.GUST:
			inside_time = 0.0
			_play_sound(gust_sound)
		Phase.SOAR:
			set_hint_visible(false)
			_soar()


func _process(delta: float) -> void:
	super._process(delta)
	if not running or _kite == null:
		return
	_t += delta
	var hand := _player.hand_point()
	var x := _player.global_position.x + kite_offset_x
	match phase:
		Phase.LAUNCH:
			# 얼레가 풀리며 연이 저절로 떠오른다.
			var u := clampf(_t / launch_seconds, 0.0, 1.0)
			kite_y = lerpf(hand.y, band_heights[0] + 90.0, 1.0 - pow(1.0 - u, 2.0))
			if u >= 1.0:
				_set_phase(Phase.CALM)
		Phase.CALM, Phase.GUST:
			if phase == Phase.CALM:
				# 바람이 잦은 동안 띠가 다음 높이로 옮겨 간다.
				var u := clampf(_t / calm_seconds, 0.0, 1.0)
				band_y = lerpf(_band_from, band_heights[ribbons], u * u * (3.0 - 2.0 * u))
			var target := -rise_speed if pressing() else fall_speed
			_v = lerpf(_v, target, minf(1.0, delta * 3.5))
			kite_y += (_v + push_now()) * delta
			if kite_y < y_high or kite_y > y_low:
				kite_y = clampf(kite_y, y_high, y_low)
				_v = 0.0
			if phase == Phase.GUST:
				if kite_inside():
					inside_time += delta
				_tint_ribbon(ribbons, clampf(inside_time / (gust_seconds * need_ratio), 0.0, 1.0))
				if _t >= gust_seconds:
					_judge()
			elif _t >= calm_seconds:
				_set_phase(Phase.GUST)
	_draw_kite(x, hand, delta)


func _judge() -> void:
	if inside_time >= gust_seconds * need_ratio:
		_tint_ribbon(ribbons, 1.0)
		_play_sound(ribbon_sound)
		ribbon_done.emit(ribbons)
		ribbons += 1
		if ribbons >= gust_count():
			_set_phase(Phase.SOAR)
			return
	else:
		# 놓쳤다: 덜 물든 리본이 다시 바래고, 같은 돌풍이 다시 온다.
		var keep := ribbons
		var bow := _bows[keep]
		create_tween().tween_property(bow, "color", RIBBON_PLAIN, 0.5)
		miss()
	_set_phase(Phase.CALM)


## 셋 다 붉다: 연이 높이 올라 지도 자리를 비춘다 → 얼레를 감아 연이 손으로 돌아온다 → 끝.
func _soar() -> void:
	var tween := create_tween()
	tween.tween_property(self, "kite_y", y_high - 40.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_band, "modulate:a", 0.0, 1.6)
	tween.tween_callback(func(): GameState.set_flag(done_flag))  # 지도 자리가 빛난다(MapChase)
	tween.tween_interval(1.4)
	tween.tween_method(func(u: float):
		kite_y = lerpf(y_high - 40.0, _player.hand_point().y, u)
		kite_offset_x = lerpf(320.0, 40.0, u), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_kite, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tween.parallel().tween_property(_string, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tween.parallel().tween_property(_tail, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tween.parallel().tween_property(_reel, "modulate:a", 0.0, 0.5).set_delay(0.9)
	await tween.finished
	_teardown()
	end()


func _tint_ribbon(i: int, amount: float) -> void:
	if i >= 0 and i < _bows.size():
		_bows[i].color = RIBBON_PLAIN.lerp(RIBBON_RED, amount)


# ------------------------------------------------------------------ 그림

func _build() -> void:
	_band = Sprite2D.new()
	_band.name = "Band"
	_band.texture = _band_texture()
	_band.top_level = true
	_band.z_index = -4  # 배경 앞, 하윤 뒤
	_band.z_as_relative = false
	add_child(_band)
	_band.modulate.a = 0.0
	create_tween().tween_property(_band, "modulate:a", 0.7, 1.0)

	_string = Line2D.new()
	_string.name = "String"
	_string.top_level = true
	_string.width = 2.0
	_string.default_color = Color(0.96, 0.93, 0.86, 0.85)
	_string.z_index = 3
	add_child(_string)

	_tail = Line2D.new()
	_tail.name = "Tail"
	_tail.top_level = true
	_tail.width = 4.0
	_tail.default_color = Color(0.95, 0.9, 0.8, 0.95)
	_tail.z_index = 3
	add_child(_tail)
	_bows.clear()
	for i in gust_count():
		var bow := Polygon2D.new()
		bow.top_level = true
		bow.z_index = 4
		bow.polygon = PackedVector2Array([Vector2(-22, -12), Vector2(0, -3), Vector2(22, -12), Vector2(22, 12), Vector2(0, 3), Vector2(-22, 12)])
		bow.color = RIBBON_PLAIN
		add_child(bow)
		_bows.append(bow)

	_kite = Sprite2D.new()
	_kite.name = "Kite"
	_kite.top_level = true
	_kite.z_index = 4
	var path := CutscenePlayer.find_art(art)
	if not path.is_empty():
		_kite.texture = load(path)
	add_child(_kite)

	_reel = Sprite2D.new()
	_reel.name = "Reel"
	_reel.top_level = true
	_reel.z_index = 6
	_reel.scale = Vector2(0.7, 0.7)
	var reel_path := CutscenePlayer.find_art(reel_art)
	if not reel_path.is_empty():
		_reel.texture = load(reel_path)
	add_child(_reel)


func _draw_kite(x: float, hand: Vector2, _delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var sway := sin(time * 1.7) * 14.0 + push_now() * 0.08
	var kite_pos := Vector2(x + sway, kite_y)
	_kite.global_position = kite_pos
	_kite.rotation = clampf(-0.18 + (_v + push_now()) * 0.0007 + sin(time * 2.3) * 0.05, -0.6, 0.4)
	_reel.global_position = hand
	_band.global_position = Vector2(x, band_y)
	var tex_h := float(_band.texture.get_height())
	_band.scale = Vector2(4400.0 / _band.texture.get_width(), (_half * 2.0 * 1.6) / tex_h)  # 화면보다 넓게(양끝이 안 보이게)
	if phase == Phase.GUST:
		_band.modulate.a = lerpf(_band.modulate.a, 1.0, 0.1)
	elif phase != Phase.SOAR:
		_band.modulate.a = lerpf(_band.modulate.a, 0.7, 0.05)
	# 실: 손에서 연 아래까지 살짝 처진 곡선
	var low := kite_pos + Vector2(0.0, 40.0).rotated(_kite.rotation)
	var pts := PackedVector2Array()
	for k in 9:
		var u := k / 8.0
		var p := hand.lerp(low, u)
		p.y += sin(u * PI) * 50.0
		pts.append(p)
	_string.points = pts
	# 꼬리: 연 아래에서 바람 반대쪽(왼쪽 아래)으로 흔들리며 늘어진다. 리본 셋이 달려 있다.
	var wind := 1.0 + absf(push_now()) / 120.0
	var tail_pts := PackedVector2Array()
	var start := kite_pos + Vector2(0.0, 110.0).rotated(_kite.rotation)
	for k in 13:
		var u := k / 12.0
		tail_pts.append(start + Vector2(-u * 150.0 * wind * 0.7, u * 170.0) \
				+ Vector2(sin(time * 5.0 * wind - u * 6.0) * 16.0 * u, 0.0))
	_tail.points = tail_pts
	for i in _bows.size():
		var idx := 4 + i * 4
		_bows[i].global_position = tail_pts[mini(idx, tail_pts.size() - 1)]
		_bows[i].rotation = sin(time * 6.0 - i) * 0.35


func _teardown() -> void:
	for n in [_band, _kite, _reel, _string, _tail]:
		if is_instance_valid(n):
			n.queue_free()
	for b in _bows:
		if is_instance_valid(b):
			b.queue_free()
	_bows.clear()
	_kite = null


## 위아래로 가운데가 진하고 가장자리가 사라지는 노을빛 띠.
static func _band_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(BAND_COLOR, 0.0))
	g.set_color(1, Color(BAND_COLOR, 0.0))
	g.add_point(0.3, Color(BAND_COLOR, 0.42))
	g.add_point(0.5, BAND_COLOR)
	g.add_point(0.7, Color(BAND_COLOR, 0.42))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 64
	tex.height = 64
	return tex


func _play_sound(prefix: String) -> void:
	var stream := SoundBank.pick(prefix) if not prefix.is_empty() else null
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = SoundBank.BUS_SFX
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
