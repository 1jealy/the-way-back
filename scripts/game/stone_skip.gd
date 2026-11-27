class_name StoneSkip
extends PhraseGame
## 장면표 5-4 물수제비: 동그라미 4를 체크하고 기억 장면(할아버지의 돌이 다섯 번 튄다)이 지나간 뒤에 나온다.
## 같은 동그라미의 조사 대상(Interactable.map_circle)이 기억 장면 다음에 play()를 기다린다(#32).
## - 조약돌(item_flat_stone)이 없으면: 하윤이 납작한 돌 하나를 주워 던진다. 두 번 튀고 가라앉는다.
## - 있으면(#148, "휘파람 따라 하기"): **선택 미니게임** — 하늘이에게 "가져와"로 물가의 납작한 조약돌을 받아 와야 한다.
##   여울 건너편에서 할아버지 휘파람이 네 음(강가 소절) 들리고, 음마다 물 위 그 거리에 할아버지 물결이 희미하게 인다.
##   하윤이 ← 가까이 · E 가운데 · → 멀리로 던지면 돌이 그 거리까지 튀어 가 물결과 함께 그 음으로 운다.
##   맞으면 물결 자리가 금빛으로 남고, 틀리면 돌이 퐁 가라앉고 한 번 어긋남(그 소절을 다시 듣는다).
##   다 맞으면 할아버지가 받아 불고, 하늘이가 짖고, 물결 자리가 한꺼번에 환해지며 기억이 한 번 더 빛난다(skip_five).
##   그때는 "…다섯 번은 어렵다."를 띄우지 않는다(Interactable이 best >= 5를 본다). 점수·실패 화면은 없다.
## 장소 씬에 놓는다(Skip_5-4, 원점은 동그라미 조사 대상과 같은 땅 위). 담당: A(게임플레이).

signal finished

const DEMO_LOCK := &"stone_skip"  # 조약돌 없이 던지는 연출의 잠금(미니게임은 MiniGame.LOCK)
const GOLD := Color(0.95, 0.81, 0.48, 0.95)
const PALE := Color(0.92, 0.95, 1.0, 0.5)
## 높이(0 가까이 · 1 가운데 · 2 멀리)마다 손에서 물에 닿는 거리(px)와 그 전에 튀는 횟수.
const REACH := [300.0, 520.0, 760.0]
const HOPS := [0, 1, 2]

## 어느 동그라미 다음에 나오나.
@export_range(1, 5) var circle: int = 4
## 조약돌 없이 던질 때 튀는 횟수. 이다음 닿을 때 가라앉는다.
@export var skips: int = 2
## 돌 그림 이름(assets/art). 없으면 회색 납작한 타원을 그린다.
@export var art: String = "prop_stone_flat"
## 물 위 선(화면 y). 강가의 앞 물은 조약돌 길(792~864) 아래부터다.
@export var water_y: float = 930.0
## 조약돌 없이 던질 때: 손에서 처음 물에 닿는 곳까지와, 튈 때마다 날아가는 거리·높이.
@export var first_reach: float = 330.0
@export var hop_lengths: PackedFloat32Array = PackedFloat32Array([210.0, 150.0, 110.0, 80.0, 60.0])
@export var hop_heights: PackedFloat32Array = PackedFloat32Array([70.0, 46.0, 30.0, 20.0, 12.0])
## 미니게임: 이 플래그(하늘이가 물어 온 조약돌)가 있어야 한다.
@export var pouch_flag: StringName = &"item_flat_stone"
@export var five_flag: StringName = &"skip_five"

var playing: bool = false
## 이번에 물에 닿은 횟수(튄 것 + 가라앉은 것). 검사용.
var touches: int = 0
## 미니게임을 끝까지 해냈으면 5(할아버지처럼 다섯 번 — Interactable이 본다).
var best: int = 0

var _stone: Node2D
var _ghosts: Array[Line2D] = []   # 음마다 할아버지 물결 자리
var _pile: Array[Sprite2D] = []
var _throwing: bool = false
var _plinks: Array[AudioStreamWAV] = []
var _plink_player: AudioStreamPlayer


func _init() -> void:
	phrase_id = &"riverside"
	first_round_notes = 0
	echo_gap = 0.75


func _ready() -> void:
	add_to_group("stone_skip")
	super._ready()


static func find(tree: SceneTree, n: int) -> StoneSkip:
	for node in tree.get_nodes_in_group("stone_skip"):
		if node is StoneSkip and node.circle == n:
			return node
	return null


## 조약돌이 있으면 미니게임, 없으면 돌 하나를 던지는 연출.
func play() -> void:
	if playing:
		return
	playing = true
	touches = 0
	if GameState.has_flag(pouch_flag):
		done = false
		await super.play()
	else:
		await _demo()
	playing = false
	finished.emit()


func _demo() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.lock(DEMO_LOCK)
		player.face(1)
		player.set_pose(&"crouch")
		await _pause(0.6)
		player.set_pose(&"stand")
		await _pause(0.2)
		await player.play_throw()
	var hand := player.hand_point() if player else global_position + Vector2(36.0, -120.0)
	await _throw_demo(hand, skips)
	await _pause(0.4)
	if player:
		player.unlock(DEMO_LOCK)


# --- 휘파람 따라 하기 -----------------------------------------------------------

func echo_position() -> Vector2:
	return Vector2(global_position.x + 1100.0, 860.0)  # 여울 건너편


func _hand() -> Vector2:
	return _player.hand_point() if _player else global_position + Vector2(36.0, -120.0)


## 높이 level에서 돌이 마지막으로 닿는 물 위 자리.
func landing(level: int) -> Vector2:
	var px := _player.global_position.x if _player else global_position.x
	return Vector2(px + 40.0 + REACH[level], water_y)


func _setup() -> void:
	best = 0
	_throwing = false
	if _player:
		_player.face(1)
		_player.set_pose(&"stand")
	if _plink_player == null:
		_plink_player = AudioStreamPlayer.new()
		_plink_player.name = "Plink"
		_plink_player.bus = SoundBank.BUS_SFX
		add_child(_plink_player)
	_plinks.clear()
	for level in 3:
		_plinks.append(_make_plink(WhistleTune.level_hz(phrase_id, level)))
	_ghosts.clear()
	for i in melody.size():
		var g := _ring(Color(PALE, 0.0), 2.5, Vector2(58.0, 10.0))
		g.name = "Ghost%d" % i
		add_child(g)
		_ghosts.append(g)
	_refill_pile()


func _refill_pile() -> void:
	for s in _pile:
		if is_instance_valid(s):
			s.queue_free()
	_pile.clear()
	var path := CutscenePlayer.find_art(art)
	if path.is_empty() or _player == null:
		return
	for i in melody.size():
		var s := Sprite2D.new()
		s.texture = load(path)
		s.scale = Vector2(0.8, 0.8)
		s.z_index = 2
		s.z_as_relative = false
		add_child(s)
		s.global_position = _player.global_position + Vector2(48.0 + (i % 3) * 26.0, -8.0 - (i / 3) * 12.0)
		_pile.append(s)


func _on_listen(_retry: bool) -> void:
	for g in _ghosts:
		create_tween().tween_property(g, "default_color", Color(PALE, 0.0), 0.3)
	if _pile.size() < melody.size():
		_refill_pile()


## 메아리 한 음: 물 위 그 거리에 할아버지 물결이 희미하게 인다.
func _on_echo(i: int, level: int, gap: float) -> void:
	var g := _ghosts[i]
	g.global_position = landing(level) + Vector2(i * 8.0, 0.0)
	g.scale = Vector2(0.4, 0.4)
	var t := create_tween().set_parallel()
	t.tween_property(g, "scale", Vector2.ONE, gap * 1.2)
	t.tween_property(g, "default_color", Color(PALE, 0.85), gap * 0.3)
	t.chain().tween_property(g, "default_color", Color(PALE, 0.35 if help else 0.12), gap)


func _on_note(i: int, level: int, correct: bool) -> void:
	_throw(i, level, correct)


## 하윤이 돌을 던진다: 그 거리까지 튀어 가 닿는 자리에서 그 음으로 운다(맞으면) / 퐁 가라앉는다(틀리면).
func _throw(i: int, level: int, correct: bool) -> void:
	_throwing = true
	if not _pile.is_empty():
		var s: Sprite2D = _pile.pop_back()
		if is_instance_valid(s):
			s.queue_free()
	if _player:
		_player.play_throw()
		await _pause(0.18)
	var hand := _hand()
	_stone = _make_stone()
	_stone.global_position = hand
	var end := landing(level)
	var hops: int = HOPS[level]
	var at := Vector2(hand.x + 260.0, water_y)
	if hops == 0:
		at = end
	await _fly(hand, at, 18.0, 0.36)
	for k in hops:
		touches += 1
		_ripple(at, 0.6)
		_play_sound("sfx_stone_skip_", 1.0 + 0.07 * k)
		var next := at.lerp(end, 1.0 / float(hops - k))
		await _fly(at, next, 40.0 - k * 12.0, 0.26)
		at = next
	touches += 1
	if correct:
		_ripple(at, 1.0)
		if level < _plinks.size():
			_plink_player.stream = _plinks[level]
			_plink_player.play()
		dog_react(0.5 + 0.2 * level)
		var g := _ghosts[i]
		g.global_position = at
		var t := create_tween()
		t.tween_property(g, "default_color", GOLD, 0.2)
		t.parallel().tween_property(g, "scale", Vector2(1.15, 1.15), 0.3)
	else:
		_ripple(at, 0.4)
		_play_sound("sfx_stone_sink_")
	var sink := create_tween()
	sink.tween_property(_stone, "position:y", _stone.position.y + 22.0, 0.45)
	sink.parallel().tween_property(_stone, "modulate:a", 0.0, 0.45)
	await sink.finished
	if _stone:
		_stone.queue_free()
		_stone = null
	_throwing = false


## 던지는 동안에는 다음 음을 받지 않는다(돌이 닿은 뒤 다음 돌).
func _tick(delta: float) -> void:
	if _throwing:
		_update(delta)
		return
	super._tick(delta)


func _update(_delta: float) -> void:
	_place_hint()


## 할아버지가 받아 분 뒤: 하늘이가 짖고, 물결 자리가 한꺼번에 환해지며 기억이 한 번 더 빛난다.
func _on_finish() -> void:
	while _throwing:
		await get_tree().process_frame
	best = 5
	GameState.set_flag(five_flag)
	var dog := get_tree().get_first_node_in_group("dog")
	if dog and dog.has_method("bark") and dog.is_joined():
		dog.bark()
	for g in _ghosts:
		var t := create_tween()
		t.tween_property(g, "default_color", GOLD, 0.3)
		t.tween_property(g, "scale", Vector2(1.4, 1.4), 0.6)
	var memory := MemoryScene.find(get_tree(), circle)
	if memory:
		await memory.play()
	else:
		await _wait(1.2)
	var fade := create_tween().set_parallel()
	for g in _ghosts:
		fade.tween_property(g, "default_color:a", 0.0, 0.8)
	for s in _pile:
		if is_instance_valid(s):
			fade.tween_property(s, "modulate:a", 0.0, 0.6)
	await fade.finished
	for g in _ghosts:
		g.queue_free()
	_ghosts.clear()
	for s in _pile:
		if is_instance_valid(s):
			s.queue_free()
	_pile.clear()
	if _player:
		_player.set_motion({})
	clear()


## 던질 때 하윤이 내는 소리는 없다(돌이 닿는 자리에서 운다). 메아리·대답은 PhraseGame의 휘파람.
func _make_tone(_hz: float) -> AudioStreamWAV:
	return PhraseGame._synth(0.05, func(_t: float) -> float: return 0.0)


## 물방울이 맑게 우는 소리(진짜 소리는 #122).
func _make_plink(hz: float) -> AudioStreamWAV:
	var seconds := 0.6
	return PhraseGame._synth(seconds, func(t: float) -> float:
		var f := hz * (1.0 + 0.3 * exp(-t * 40.0))  # 물방울처럼 위에서 살짝 떨어지는 음
		var env := minf(1.0, t / 0.005) * exp(-t * 6.0)
		return (sin(TAU * f * t) + 0.2 * sin(TAU * 2.0 * f * t)) * env * 0.45)


# --- 조약돌 없이 던지기(연출) ---------------------------------------------------

func _throw_demo(hand: Vector2, n: int) -> void:
	_stone = _make_stone()
	_stone.global_position = hand
	var at := Vector2(hand.x + first_reach, water_y)
	await _fly(hand, at, 18.0, 0.42)
	for i in n:
		touches += 1
		_ripple(at, 1.0 - 0.15 * i)
		_play_sound("sfx_stone_skip_")
		var length := hop_lengths[mini(i, hop_lengths.size() - 1)]
		var height := hop_heights[mini(i, hop_heights.size() - 1)]
		var next := at + Vector2(length, 0.0)
		await _fly(at, next, height, 0.22 + 0.0012 * length)
		at = next
	touches += 1
	_ripple(at, 0.6)
	_play_sound("sfx_stone_sink_")
	var sink := create_tween()
	sink.tween_property(_stone, "position:y", _stone.position.y + 22.0, 0.5)
	sink.parallel().tween_property(_stone, "modulate:a", 0.0, 0.5)
	await sink.finished
	_stone.queue_free()
	_stone = null


## 멈춘 동안에는 흐르지 않는 짧은 숨(동작 사이). 대사·연출 길이를 맞추는 데 쓰지 않는다.
func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _fly(from: Vector2, to: Vector2, height: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(k: float):
		if _stone:
			_stone.global_position = from.lerp(to, k) + Vector2(0.0, -4.0 * height * k * (1.0 - k))
			_stone.rotation = lerpf(-0.25, 0.25, k), 0.0, 1.0, seconds)
	await tween.finished


func _make_stone() -> Node2D:
	var path := CutscenePlayer.find_art(art)
	var node: Node2D
	if not path.is_empty():
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		node = sprite
	else:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			pts.append(Vector2(cos(a) * 18.0, sin(a) * 7.0))
		poly.polygon = pts
		poly.color = Color(0.74, 0.74, 0.78)
		node = poly
	node.name = "Stone"
	node.z_index = 6
	node.z_as_relative = false
	add_child(node)
	return node


func _ring(color: Color, width: float, radius: Vector2) -> Line2D:
	var ring := Line2D.new()
	ring.width = width
	ring.default_color = color
	ring.closed = true
	for k in 28:
		var a := TAU * k / 28.0
		ring.add_point(Vector2(cos(a) * radius.x, sin(a) * radius.y))
	ring.z_index = 5
	ring.z_as_relative = false
	return ring


## 물을 스친 자리에 퍼지는 동그란 물결.
func _ripple(at: Vector2, strength: float) -> void:
	var ring := _ring(Color(0.93, 0.96, 1.0, 0.95 * strength), 4.0, Vector2(10.0, 3.0))
	ring.name = "Ripple"
	add_child(ring)
	ring.global_position = at
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(5.0, 5.0) * (0.6 + 0.4 * strength), 1.1)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 1.1)
	tween.tween_callback(ring.queue_free)
