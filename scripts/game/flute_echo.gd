class_name FluteEcho
extends PhraseGame
## 숲 4-2 둘째 갈림길: 할아버지 휘파람을 버들피리로 따라 불기(#111 → #145에서 PhraseGame 위로 옮김).
## [E] 피리 불기로 시작(#119). 소절은 WhistleTune "forest" — 앞 세 음은 들판에서 연으로 따라 한 그 소절이고,
## 맞추면 한 음 더 긴 숲 소절 전부가 메아리친다.
## 둘째 갈림길에서는 하늘이도 냄새를 못 맡는다. 맞는 입구에서 할아버지 휘파람이 메아리로 들리고,
## 빛 알갱이가 그 음의 높낮이를 그리며 하윤 쪽으로 흘러와 공중에 줄지어 선다. 하윤이 피리로 같은 음을 분다.
## 맞으면 하윤의 알갱이가 그 자리에 겹쳐 흰 테가 생긴다. 틀리면 헛바람 소리, 알갱이가 흩어진 뒤 메아리가 다시 들린다.
## 다 맞으면 할아버지 휘파람이 받아 불고, 입구가 환해지고 하늘이가 그 입구 앞으로 달려가 앉는다.
## grants_flag(flute_echo_done)가 서야 맞는 입구(Passage.fallback_until_flag)가 다음으로 이어진다.
## 도움(세 번 어긋나면): 메아리가 크고 느려지고, 공중의 알갱이가 흐려지지 않고, 하늘이가 다음 음마다 짖는다.

const NOTE_Y := [650.0, 585.0, 520.0]      # 알갱이 높이(y): 낮음·가운데·높음

## 맞는 입구의 자리(x, 장소 좌표). 메아리가 여기서 온다.
@export var entrance_x: float = 5600.0

var _glow: Sprite2D
var _slots: Array[Sprite2D] = []
var _rings: Array[Line2D] = []
var _flute: Sprite2D
var _t: float = 0.0
## 음을 불 때 몸이 살짝 앞으로 밀리는 것(1 → 0), 틀렸을 때 어깨가 처지는 것.
var _kick: float = 0.0
var _slump: float = 0.0


func _init() -> void:
	trigger_flag = &"item_willow_flute"
	phrase_id = &"forest"
	first_round_notes = 3


func _process(delta: float) -> void:
	if not running and not done and not starts_on_prompt() and GameState.has_flag(trigger_flag):
		var player := get_tree().get_first_node_in_group("player") as Player
		if player and player.controls_enabled and player.global_position.x >= global_position.x:
			play()
	super._process(delta)


func echo_position() -> Vector2:
	return Vector2(entrance_x, 600.0)


func _setup() -> void:
	if _player:
		_player.face(1)
		_player.set_pose(&"flute")
	var mote := CutscenePlayer.find_art("fx_light_mote")
	var tex: Texture2D = load(mote) if not mote.is_empty() else null
	if _glow == null:
		_glow = Sprite2D.new()
		_glow.name = "EntranceGlow"
		_glow.texture = tex
		_glow.z_index = -4
		_glow.z_as_relative = false
		_glow.scale = Vector2(7.0, 9.0)
		_glow.modulate.a = 0.0
		add_child(_glow)
		_glow.global_position = Vector2(entrance_x, 640.0)
	_slots.clear()
	_rings.clear()
	for i in melody.size():
		var s := Sprite2D.new()
		s.name = "Note%d" % i
		s.texture = tex
		s.z_index = 6
		s.z_as_relative = false
		s.scale = Vector2(1.7, 1.7)
		s.modulate.a = 0.0
		add_child(s)
		_slots.append(s)
		var r := Line2D.new()
		r.name = "Ring%d" % i
		r.width = 3.0
		r.default_color = Color(1.0, 0.97, 0.88, 0.0)
		r.z_index = 7
		r.z_as_relative = false
		var pts := PackedVector2Array()
		for k in 25:
			pts.append(Vector2.from_angle(TAU * k / 24.0) * 22.0)
		r.points = pts
		add_child(r)
		_rings.append(r)
	_flute = Sprite2D.new()
	_flute.name = "HeldFlute"
	var fp := CutscenePlayer.find_art("prop_willow_flute")
	if not fp.is_empty():
		_flute.texture = load(fp)
	_flute.scale = Vector2(0.6, 0.6)
	_flute.z_index = 1
	_flute.z_as_relative = false
	add_child(_flute)


## 공중에 줄지어 설 i번째 음 자리(하윤과 입구 사이).
func slot_position(i: int) -> Vector2:
	var px := _player.global_position.x if _player else global_position.x
	var x0 := px + 260.0
	var x1 := entrance_x - 220.0
	var u := float(i) / maxf(1.0, melody.size() - 1)
	return Vector2(lerpf(x0, x1, u), NOTE_Y[melody[i]])


func _on_listen(_retry: bool) -> void:
	create_tween().tween_property(_glow, "modulate:a", 0.75 if help else 0.4, 0.6)
	for i in _slots.size():
		_slots[i].modulate.a = 0.0
		_rings[i].default_color.a = 0.0


## 메아리 한 음: 입구에서 알갱이가 날아와 자리에 선다.
func _on_echo(i: int, _level: int, gap: float) -> void:
	var s := _slots[i]
	s.global_position = Vector2(entrance_x, 620.0)
	var t := create_tween().set_parallel()
	t.tween_property(s, "global_position", slot_position(i), gap * 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 1.0, gap * 0.5)


## 하윤 차례. 도움 전에는 알갱이가 조금 흐려진다(외워서 따라 불기).
func _on_play() -> void:
	if not help:
		for s in _slots:
			create_tween().tween_property(s, "modulate:a", 0.35, 0.8)


func _on_note(i: int, _level: int, correct: bool) -> void:
	var mote := _slots[i].duplicate() as Sprite2D
	mote.name = "Blown"
	add_child(mote)
	mote.global_position = _flute.global_position
	mote.modulate.a = 1.0
	_kick = 1.0
	if correct:
		var t := create_tween().set_parallel()
		t.tween_property(mote, "global_position", slot_position(i), 0.4).set_trans(Tween.TRANS_SINE)
		t.chain().tween_callback(mote.queue_free)
		_slots[i].modulate.a = 1.0
		_rings[i].global_position = slot_position(i)
		create_tween().tween_property(_rings[i], "default_color:a", 0.95, 0.3)
	else:
		_slump = 1.0
		var t := create_tween().set_parallel()
		t.tween_property(mote, "global_position", _flute.global_position + Vector2(randf_range(40, 120), randf_range(-140, -60)), 0.6)
		t.tween_property(mote, "modulate:a", 0.0, 0.6)
		t.chain().tween_callback(mote.queue_free)
		for k in _slots.size():
			create_tween().tween_property(_slots[k], "modulate:a", 0.0, 0.5)
			create_tween().tween_property(_rings[k], "default_color:a", 0.0, 0.5)


## 첫 소절을 맞췄다: 흰 테가 한 번 환해진다(#119).
func _on_round() -> void:
	for k in round_length():
		var t := create_tween()
		t.tween_property(_rings[k], "default_color:a", 1.0, 0.15)
		t.tween_property(_rings[k], "scale", Vector2(1.5, 1.5), 0.35)
		t.parallel().tween_property(_rings[k], "default_color:a", 0.0, 0.35)
		t.tween_property(_rings[k], "scale", Vector2.ONE, 0.0)
	await _wait(0.3)


## 다 맞았다(할아버지가 받아 분 뒤): 입구가 환해지고 하늘이가 그 입구 앞으로 달려가 앉는다.
func _on_finish() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_glow, "modulate:a", 0.95, 0.8)
	t.tween_property(_glow, "scale", Vector2(8.5, 11.0), 0.8)
	for k in _slots.size():
		t.tween_property(_slots[k], "global_position", Vector2(entrance_x, 620.0 - k * 18.0), 1.2).set_trans(Tween.TRANS_SINE)
		t.tween_property(_slots[k], "modulate:a", 0.0, 1.2)
		t.tween_property(_rings[k], "default_color:a", 0.0, 0.6)
	await t.finished
	if _player:
		_player.set_motion({})
		_player.set_pose(&"stand")
	_flute.queue_free()
	_flute = null
	var dog := get_tree().get_first_node_in_group("dog") as Dog
	if dog and dog.is_joined():
		dog.script_move_to(entrance_x - 50.0)
		dog.look(1)
	clear()
	# 입구 빛은 남긴다(어느 입구인지 잊어도 보이게). 하늘이는 잠시 앉아 있다가 다시 따라온다.
	await _wait(2.5)
	if dog and is_instance_valid(dog):
		dog.release_script()


func _update(delta: float) -> void:
	_t += delta
	_kick = move_toward(_kick, 0.0, delta * 3.5)
	_slump = move_toward(_slump, 0.0, delta * 1.2)
	_pose_player()
	_place_flute()
	_place_hint()


## 피리 부는 몸(#114): 숨 쉬듯 천천히 오르내리고, 들을 때는 입구 쪽으로 고개를 기울인다.
## 음을 불 때마다 몸이 살짝 앞으로 밀리고(높은 음일수록 고개를 든다), 틀리면 어깨가 처진다.
func _pose_player() -> void:
	if _player == null:
		return
	var breath := sin(_t * TAU * 0.45)
	var m := {
		"torso": breath * 1.6 - _kick * 3.0 + _slump * 6.0,
		"head": -breath * 1.2 + _slump * 9.0,
		"shoulder": breath * 2.0 - _kick * 5.0 + _slump * 6.0,
		"far_shoulder": breath * 2.0 - _kick * 5.0 + _slump * 6.0,
		"elbow": -_kick * 5.0,
		"far_elbow": -_kick * 5.0,
	}
	if phase == &"listen" or phase == &"answer":
		m["head"] = float(m["head"]) - 7.0  # 메아리 쪽으로 귀를 기울인다
		m["torso"] = float(m["torso"]) - 2.0
	elif phase == &"play" and played < melody.size() and _kick > 0.0:
		m["head"] = float(m["head"]) - (melody[maxi(0, played - 1)] - 1) * 4.0 * _kick
	_player.set_motion(m)


func _place_flute() -> void:
	if _flute and _player:
		_flute.global_position = _player.hand_point() + Vector2(10.0, -10.0)
		_flute.rotation = -0.35
