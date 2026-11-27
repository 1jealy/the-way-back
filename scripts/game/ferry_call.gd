class_name FerryCall
extends PhraseGame
## 나루터 7-2 → 7-3: 호루라기로 할아버지를 부른다(#147, 기획서 "할아버지 휘파람 따라 하기").
## 다섯째 동그라미를 체크한 뒤 강가에서 [E] 호루라기 불기. 이번에는 할아버지 휘파람이 먼저 들리지 않는다 —
## 철교에서 하늘이를 부른 그 소절(다섯 음)을 하윤이 기억해서 먼저 분다. 안개 위에 그때 돌이 있던 높이가 희미하게 떠오른다.
## 다 맞으면 안개 너머에서 할아버지가 같은 소절을 휘파람으로 받아 불고(대답), grants_flag(grandpa_called)가 서서
## 할아버지가 나타나고(Grandpa.appears_on_flag) 엔딩이 이어진다(EndingDirector.start_flag).
## 호루라기 없이 왔으면(철교에서 줍지 않고 지나왔으면) 다섯째 동그라미만으로 grandpa_called를 세운다 — 예전처럼 할아버지가 나타난다.
## 장소 씬에 B가 놓는다(FerryCall_7-3, 다섯째 동그라미와 막는 벽 사이). 원점은 땅 위.

const NOTE_Y := [700.0, 620.0, 540.0]  # 떠오르는 높이 표시(낮음·가운데·높음)
const GOLD := Color(1.0, 0.9, 0.66)

## 이 플래그(다섯째 동그라미)가 서야 부를 수 있다.
@export var circle_flag: StringName = &"map_circle_5"
## 할아버지가 서 있는 자리(x). 대답이 여기서 들린다.
@export var grandpa_x: float = 1380.0

var _marks: Array[Sprite2D] = []
var _whistle: Sprite2D
var _t: float = 0.0
var _kick: float = 0.0
var _slump: float = 0.0


func _init() -> void:
	trigger_flag = &"item_whistle"
	phrase_id = &"bridge"
	first_round_notes = 0
	echo_gap = 0.55
	echo_audible = false
	grants_flag = &"grandpa_called"


func _ready() -> void:
	super._ready()
	if _start_spot:
		_start_spot.requires_flag = circle_flag
	GameState.flag_changed.connect(func(_f: StringName) -> void: _fallback())
	_fallback.call_deferred()


## 호루라기 없이 다섯째 동그라미를 체크했으면 부르지 않고도 할아버지가 나타난다.
func _fallback() -> void:
	if done or running or grants_flag.is_empty():
		return
	if GameState.has_flag(circle_flag) and not GameState.has_flag(trigger_flag) and not GameState.has_flag(grants_flag):
		done = true
		GameState.set_flag(grants_flag)


## 시작 조사 대상은 동그라미와 호루라기가 둘 다 있어야 뜬다.
func _process(delta: float) -> void:
	if _start_spot and not running and not done:
		_start_spot.visible = GameState.has_flag(trigger_flag)
		_start_spot.monitoring = GameState.has_flag(trigger_flag)
	super._process(delta)


func echo_position() -> Vector2:
	return Vector2(grandpa_x, 700.0)


func _setup() -> void:
	if _player:
		_player.face(1)
		_player.set_pose(&"flute")
	var mote := CutscenePlayer.find_art("fx_light_mote")
	var tex: Texture2D = load(mote) if not mote.is_empty() else null
	_marks.clear()
	for i in melody.size():
		var s := Sprite2D.new()
		s.name = "Mark%d" % i
		s.texture = tex
		s.scale = Vector2(1.8, 1.8)
		s.modulate = Color(GOLD, 0.0)
		s.z_index = 6
		s.z_as_relative = false
		add_child(s)
		_marks.append(s)
	_whistle = Sprite2D.new()
	_whistle.name = "HeldWhistle"
	var wp := CutscenePlayer.find_art("prop_whistle")
	if not wp.is_empty():
		_whistle.texture = load(wp)
	_whistle.scale = Vector2(0.55, 0.55)
	_whistle.z_index = 1
	_whistle.z_as_relative = false
	add_child(_whistle)


func mark_position(i: int) -> Vector2:
	var px := _player.global_position.x if _player else global_position.x
	return Vector2(px + 220.0 + i * 70.0, NOTE_Y[melody[i]])


## 기억: 철교에서 돌이 있던 높이가 안개 위에 희미하게 떠오른다(소리는 없다).
func _on_listen(_retry: bool) -> void:
	for m in _marks:
		m.modulate.a = 0.0


func _on_echo(i: int, _level: int, gap: float) -> void:
	var m := _marks[i]
	m.global_position = mark_position(i)
	create_tween().tween_property(m, "modulate:a", 0.45 if help else 0.3, gap * 0.6)


func _on_note(i: int, _level: int, correct: bool) -> void:
	_kick = 1.0
	if correct:
		var t := create_tween()
		t.tween_property(_marks[i], "modulate:a", 1.0, 0.15)
		t.tween_property(_marks[i], "scale", Vector2(2.4, 2.4), 0.3)
	else:
		_slump = 1.0
		for m in _marks:
			create_tween().tween_property(m, "modulate:a", 0.0, 0.4)


## 할아버지가 받아 분 뒤: 빛이 할아버지 쪽으로 흘러가고, 할아버지가 나타난다(grants_flag).
func _on_finish() -> void:
	var t := create_tween().set_parallel()
	for k in _marks.size():
		t.tween_property(_marks[k], "global_position", Vector2(grandpa_x, 640.0 - k * 20.0), 1.4).set_trans(Tween.TRANS_SINE)
		t.tween_property(_marks[k], "modulate:a", 0.0, 1.4)
	await t.finished
	if _player:
		_player.set_motion({})
		_player.set_pose(&"stand")
	if _whistle:
		_whistle.queue_free()
		_whistle = null
	clear()


## 호루라기 소리(철교와 같다).
func _make_tone(hz: float) -> AudioStreamWAV:
	var seconds := 0.42
	return PhraseGame._synth(seconds, func(t: float) -> float:
		var f := hz * (1.0 + 0.02 * sin(TAU * 28.0 * t))
		var env := minf(1.0, t / 0.015) * clampf((seconds - t) / 0.1, 0.0, 1.0)
		return (sin(TAU * f * t) + 0.25 * sin(TAU * 2.0 * f * t) + 0.18 * (randf() - 0.5)) * env * 0.4)


func _update(delta: float) -> void:
	_t += delta
	_kick = move_toward(_kick, 0.0, delta * 3.5)
	_slump = move_toward(_slump, 0.0, delta * 1.2)
	if _player:
		var breath := sin(_t * TAU * 0.45)
		_player.set_motion({
			"torso": breath * 1.4 - _kick * 3.0 + _slump * 6.0,
			"head": -breath * 1.0 + _slump * 8.0 - (6.0 if phase == &"answer" else 0.0),
			"shoulder": -_kick * 4.0 + _slump * 5.0,
			"far_shoulder": -_kick * 4.0 + _slump * 5.0,
		})
		if _whistle:
			_whistle.global_position = _player.hand_point() + Vector2(8.0, -8.0)
			_whistle.rotation = -0.3
	_place_hint()
