class_name BridgeWhistle
extends PhraseGame
## 철교 6-2~6-3 끊긴 끝: 호루라기로 하늘이에게 디딤돌 길을 알려 주기(#147, 기획서 "할아버지 휘파람 따라 하기").
## 끊긴 끝 아래 강은 안개에 묻혀 있다. 안개 속에 디딤돌이 줄마다 셋(가까이·가운데·멀리)씩 다섯 줄 있는데,
## 그중 하나만 진짜 돌이고 나머지는 물그림자다. 강둑 쪽 안개 너머에서 할아버지 휘파람이 다섯 음(철교 소절) 들리고,
## 음마다 그 줄의 진짜 돌이 잠깐 비친다. 하윤이 ← 가까이 · E 가운데 · → 멀리로 호루라기를 불면
## 하늘이가 그 소리를 듣고 그 높이의 돌로 뛴다. 맞으면 돌이 빛을 머금고, 틀리면 물그림자가 흩어지고
## 하늘이가 끊긴 끝으로 돌아온다(한 번 어긋남, 그 소절을 다시 듣는다).
## 다 맞으면 할아버지가 받아 불고, 하늘이가 강둑에 뛰어올라 짖는다. grants_flag(bridge_bank_path) → 강둑으로 내려가기가 열린다.
## 호루라기 없이 왔으면 시작하지 않는다 — 하늘이 냄새 부탁(ask_spot)으로 간다. 호루라기가 있으면 그 부탁 자리는 닫는다.
## 장소 씬에 B가 놓는다(BridgeWhistle_6-3, 끊긴 끝). 원점은 땅 위.

const ROW_Y := [1040.0, 1000.0, 962.0]  # 높이(0 가까이 · 1 가운데 · 2 멀리)마다 돌 자리(y)
const GOLD := Color(1.0, 0.88, 0.6)

## 끊긴 끝에서 하늘이가 기다리는 자리(x)와 디딤돌 줄들의 x(가까운 것부터).
@export var dog_start_x: float = 3600.0
@export var columns: PackedFloat32Array = PackedFloat32Array([3725.0, 3830.0, 3935.0, 4040.0, 4145.0])
## 다 건너면 하늘이가 뛰어오르는 강둑(x, 땅 위). 강둑으로 내려가기(Passage)의 to_x와 같다.
@export var bank_x: float = 4300.0
## 호루라기 없이 왔을 때 쓰는 냄새 부탁 자리.
@export var ask_spot: NodePath

var _stones: Array[Sprite2D] = []   # 줄마다 셋: index = 열 * 3 + 높이
var _glows: Array[Sprite2D] = []
var _fog: Polygon2D
var _whistle: Sprite2D
var _dog: Dog
var _t: float = 0.0
var _kick: float = 0.0
var _slump: float = 0.0


func _init() -> void:
	trigger_flag = &"item_whistle"
	phrase_id = &"bridge"
	first_round_notes = 0
	echo_gap = 0.7


func _ready() -> void:
	super._ready()
	if GameState.has_flag(trigger_flag):
		_close_ask_spot.call_deferred()
	GameState.flag_changed.connect(_on_flag_changed)


func _on_flag_changed(flag: StringName) -> void:
	if flag == trigger_flag and GameState.has_flag(flag):
		_close_ask_spot()


## 호루라기가 있으면 냄새 부탁 자리는 쓰지 않는다(힌트도 거기를 안 가리키게).
func _close_ask_spot() -> void:
	if ask_spot.is_empty() or done:
		return
	var spot := get_node_or_null(ask_spot)
	if spot and "used" in spot and not GameState.has_flag(grants_flag):
		spot.used = true


func echo_position() -> Vector2:
	return Vector2(bank_x + 300.0, 760.0)


## i번째 줄, 높이 level의 돌 자리.
func stone_position(i: int, level: int) -> Vector2:
	return Vector2(columns[i] + (level - 1) * 14.0, ROW_Y[level])


func _process(delta: float) -> void:
	super._process(delta)
	# 다 건넌 하늘이는 강둑에서 기다리다가, 하윤이 내려오면 다시 따라온다.
	if done and _dog and is_instance_valid(_dog) and _dog.state == Dog.State.SCRIPTED and not _dog.hopping:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and absf(player.global_position.x - bank_x) < 400.0:
			_dog.release_script()
			_dog = null


func _setup() -> void:
	if _player:
		_player.face(1)
		_player.set_pose(&"flute")
	_dog = get_tree().get_first_node_in_group("dog") as Dog
	if _dog and not _dog.is_joined():
		_dog = null
	if _dog:
		_dog.script_move_to(dog_start_x)
	_build()


func _build() -> void:
	var mote := CutscenePlayer.find_art("fx_light_mote")
	var glow_tex: Texture2D = load(mote) if not mote.is_empty() else null
	var stone_path := CutscenePlayer.find_art("prop_step_stone")
	var stone_tex: Texture2D = load(stone_path) if not stone_path.is_empty() else null
	_fog = Polygon2D.new()
	_fog.name = "Fog"
	_fog.z_index = 3
	_fog.z_as_relative = false
	var x0 := columns[0] - 200.0
	var x1 := columns[columns.size() - 1] + 220.0
	var xs := [x0, x0 + 180.0, x1 - 180.0, x1]
	var ys := [870.0, 950.0, 1090.0]
	var col_a := [0.0, 1.0, 1.0, 0.0]
	var row_a := [0.0, 0.8, 1.0]
	var fc := Color(0.55, 0.51, 0.69)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for r in 3:
		for c in 4:
			pts.append(to_local(Vector2(xs[c], ys[r])))
			cols.append(Color(fc, 0.55 * col_a[c] * row_a[r]))
	_fog.polygon = pts
	_fog.vertex_colors = cols
	var polys := []
	for r in 2:
		for c in 3:
			var k := r * 4 + c
			polys.append(PackedInt32Array([k, k + 1, k + 5, k + 4]))
	_fog.polygons = polys
	add_child(_fog)
	_stones.clear()
	_glows.clear()
	for i in columns.size():
		for level in 3:
			var g := Sprite2D.new()
			g.name = "Glow%d_%d" % [i, level]
			g.texture = glow_tex
			g.scale = Vector2(2.6, 1.3)
			g.modulate = Color(GOLD, 0.0)
			g.z_index = 4
			g.z_as_relative = false
			add_child(g)
			g.global_position = stone_position(i, level) + Vector2(0.0, -6.0)
			_glows.append(g)
			var s := Sprite2D.new()
			s.name = "Stone%d_%d" % [i, level]
			s.texture = stone_tex
			s.scale = Vector2(0.62, 0.62) * (0.9 + level * 0.06)
			s.modulate = Color(1.0, 1.0, 1.0, 0.32)  # 안개 속이라 다 흐리다. 진짜인지는 모른다.
			s.z_index = 4
			s.z_as_relative = false
			add_child(s)
			s.global_position = stone_position(i, level)
			_stones.append(s)
	_whistle = Sprite2D.new()
	_whistle.name = "HeldWhistle"
	var wp := CutscenePlayer.find_art("prop_whistle")
	if not wp.is_empty():
		_whistle.texture = load(wp)
	_whistle.scale = Vector2(0.55, 0.55)
	_whistle.z_index = 1
	_whistle.z_as_relative = false
	add_child(_whistle)


func _stone(i: int, level: int) -> Sprite2D:
	return _stones[i * 3 + level]


func _glow(i: int, level: int) -> Sprite2D:
	return _glows[i * 3 + level]


# ---- 휘파람 따라 하기 ----

func _on_listen(_retry: bool) -> void:
	for i in columns.size():
		for level in 3:
			if i >= played:
				create_tween().tween_property(_glow(i, level), "modulate:a", 0.0, 0.3)


## 메아리 한 음: 그 줄의 진짜 돌이 안개 속에서 잠깐 비친다.
func _on_echo(i: int, level: int, gap: float) -> void:
	var g := _glow(i, level)
	var t := create_tween()
	t.tween_property(g, "modulate:a", 0.7, gap * 0.3)
	t.tween_property(g, "modulate:a", 0.25 if help else 0.0, gap * 0.9)


func _on_note(i: int, level: int, correct: bool) -> void:
	_kick = 1.0
	if correct:
		_glow(i, level).modulate.a = 0.85
		_stone(i, level).modulate.a = 1.0
		if _dog:
			_dog.hop_to(stone_position(i, level) + Vector2(0.0, -14.0), 0.42, 70.0)
	else:
		_slump = 1.0
		# 그 줄의 물그림자가 흩어진다. 하늘이는 멈칫하고 끊긴 끝으로 돌아온다.
		var s := _stone(i, level)
		var t := create_tween()
		t.tween_property(s, "scale", s.scale * Vector2(1.6, 0.3), 0.4)
		t.parallel().tween_property(s, "modulate:a", 0.0, 0.4)
		t.tween_property(s, "scale", s.scale, 0.01)
		t.tween_property(s, "modulate:a", 0.32, 0.8)
		for k in columns.size():
			for lv in 3:
				_stone(k, lv).modulate.a = 0.32 if not (k == i and lv == level) else 0.0
				create_tween().tween_property(_glow(k, lv), "modulate:a", 0.0, 0.4)
		if _dog:
			_dog.perk(1.0)
			if _dog.hopping or absf(_dog.global_position.x - dog_start_x) > 5.0:
				_dog.hop_to(Vector2(dog_start_x, Place.GROUND_Y), 0.55, 110.0)


## 다 건넜다(할아버지가 받아 분 뒤): 하늘이가 강둑에 뛰어올라 짖고, 강둑으로 내려가는 길이 열린다.
func _on_finish() -> void:
	if _dog:
		await _dog.hop_to(Vector2(bank_x, Place.GROUND_Y), 0.6, 140.0)
		_dog.land_hops()
		_dog.look(-1)
		_dog.bark()
	await _wait(0.6)
	if _player:
		_player.set_motion({})
		_player.set_pose(&"stand")
	if _whistle:
		_whistle.queue_free()
		_whistle = null
	create_tween().tween_property(_fog, "modulate:a", 0.45, 1.5)
	clear()


## 호루라기: 짧고 높은 숨소리 섞인 소리(진짜 소리는 #122).
func _make_tone(hz: float) -> AudioStreamWAV:
	var seconds := 0.42
	return PhraseGame._synth(seconds, func(t: float) -> float:
		var f := hz * (1.0 + 0.02 * sin(TAU * 28.0 * t))  # 호루라기 구슬 떨림
		var env := minf(1.0, t / 0.015) * clampf((seconds - t) / 0.1, 0.0, 1.0)
		return (sin(TAU * f * t) + 0.25 * sin(TAU * 2.0 * f * t) + 0.18 * (randf() - 0.5)) * env * 0.4)


# ---- 매 프레임 ----

func _update(delta: float) -> void:
	_t += delta
	_kick = move_toward(_kick, 0.0, delta * 3.5)
	_slump = move_toward(_slump, 0.0, delta * 1.2)
	if _player:
		var m := {
			"torso": -_kick * 3.0 + _slump * 6.0,
			"head": _slump * 8.0 + (6.0 if phase == &"play" else 2.0),  # 아래 안개를 내려다본다
			"shoulder": -_kick * 4.0 + _slump * 5.0,
			"far_shoulder": -_kick * 4.0 + _slump * 5.0,
		}
		_player.set_motion(m)
		if _whistle:
			_whistle.global_position = _player.hand_point() + Vector2(8.0, -8.0)
			_whistle.rotation = -0.3
	_place_hint()
	# 안개가 천천히 일렁인다
	if _fog:
		_fog.position.x = sin(_t * 0.4) * 12.0
