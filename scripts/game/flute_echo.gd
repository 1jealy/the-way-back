class_name FluteEcho
extends MiniGame
## 숲 4-2 둘째 갈림길 선율 따라 불기(#111, 기획서 "미니게임"). 첫 갈림길을 지나 주운 할아버지 버들피리로 한다.
## 둘째 갈림길에서는 하늘이도 냄새를 못 맡는다. 맞는 입구에서 할아버지 휘파람 네 음이 메아리로 들리고,
## 빛 알갱이가 그 음의 높낮이를 그리며 하윤 쪽으로 흘러와 공중에 줄지어 선다. 하윤이 피리로 같은 음을 분다.
## 조작: ← 낮게 · E 가운데 · → 높게. 맞으면 하윤의 알갱이가 그 자리에 겹쳐 흰 테가 생긴다.
## 틀리면 피리가 헛바람 소리를 내고 알갱이가 흩어진 뒤 메아리가 다시 들린다(한 번 어긋남).
## 다 맞으면 입구가 환해지고 하늘이가 그 입구 앞으로 달려가 앉는다. grants_flag(flute_echo_done)가 서야
## 맞는 입구(Passage.fallback_until_flag)가 다음으로 이어진다.
## 도움(세 번 어긋나면): 메아리가 두 배로 크고 느려지고, 공중의 알갱이가 흐려지지 않는다.
## 장소 씬에 B가 놓는다(FluteEcho_4-2). 원점은 땅 위, 하윤이 피리를 가진 채 원점을 지나면 시작한다.

const NOTE_HZ := [523.25, 659.25, 783.99]  # 낮음·가운데·높음 (도·미·솔)
const NOTE_Y := [650.0, 585.0, 520.0]      # 알갱이 높이(y)
const MIX_RATE := 22050

## 이 플래그(물건)가 서 있어야 시작한다.
@export var trigger_flag: StringName = &"item_willow_flute"
## 맞는 입구의 자리(x, 장소 좌표). 메아리가 여기서 온다.
@export var entrance_x: float = 5600.0
## 할아버지 휘파람의 앞 네 음(0 낮음 · 1 가운데 · 2 높음). 나루터 배 위 휘파람의 첫 소절.
@export var melody: PackedInt32Array = PackedInt32Array([1, 2, 1, 0])
## 메아리 음 사이 간격(초).
@export var echo_gap: float = 0.75

## 지금까지 맞게 분 음 수.
var played: int = 0
## listen(메아리가 들린다) / play(하윤 차례) / done
var phase: StringName = &"idle"

var _tones: Array[AudioStreamWAV] = []
var _breath: AudioStreamWAV
var _echo_player: AudioStreamPlayer2D
var _note_player: AudioStreamPlayer
var _glow: Sprite2D
var _slots: Array[Sprite2D] = []
var _rings: Array[Line2D] = []
var _flute: Sprite2D
var _gen: int = 0
var _t: float = 0.0
## 음을 불 때 몸이 살짝 앞으로 밀리는 것(1 → 0), 틀렸을 때 어깨가 처지는 것.
var _kick: float = 0.0
var _slump: float = 0.0


func _process(delta: float) -> void:
	if not running and not done and GameState.has_flag(trigger_flag):
		var player := get_tree().get_first_node_in_group("player") as Player
		if player and player.controls_enabled and player.global_position.x >= global_position.x:
			play()
	super._process(delta)


func _begin() -> void:
	if _tones.is_empty():
		for hz in NOTE_HZ:
			_tones.append(_make_tone(hz, 0.45))
		_breath = _make_breath(0.35)
	if _player:
		_player.face(1)
		_player.set_pose(&"flute")
	_build()
	_listen()


func _build() -> void:
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
	_echo_player = AudioStreamPlayer2D.new()
	_echo_player.name = "Echo"
	_echo_player.bus = SoundBank.BUS_SFX
	_echo_player.max_distance = 3000.0
	add_child(_echo_player)
	_echo_player.global_position = Vector2(entrance_x, 600.0)
	_note_player = AudioStreamPlayer.new()
	_note_player.name = "Flute"
	_note_player.bus = SoundBank.BUS_SFX
	add_child(_note_player)
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


## 메아리가 들린다: 입구에서 알갱이가 하나씩 날아와 자리에 선다.
func _listen() -> void:
	_gen += 1
	var gen := _gen
	phase = &"listen"
	played = 0
	hide_key_hint()
	var tw := create_tween()
	tw.tween_property(_glow, "modulate:a", 0.75 if help else 0.4, 0.6)
	for i in _slots.size():
		_slots[i].modulate.a = 0.0
		_rings[i].default_color.a = 0.0
	await _wait(0.6)
	var gap := echo_gap * (1.5 if help else 1.0)
	for i in melody.size():
		if gen != _gen or not running:
			return
		_echo(melody[i])
		var s := _slots[i]
		s.global_position = Vector2(entrance_x, 620.0)
		var t := create_tween().set_parallel()
		t.tween_property(s, "global_position", slot_position(i), gap * 1.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "modulate:a", 1.0, gap * 0.5)
		await _wait(gap)
	await _wait(gap * 0.8)
	if gen != _gen or not running:
		return
	# 하윤 차례. 도움 전에는 알갱이가 조금 흐려진다(외워서 따라 불기).
	if not help:
		for s in _slots:
			create_tween().tween_property(s, "modulate:a", 0.35, 0.8)
	phase = &"play"
	show_key_hint(["←", "E", "→"], "낮게 · 가운데 · 높게")


func _echo(note: int) -> void:
	_echo_player.stream = _tones[note]
	_echo_player.volume_db = 0.0 if help else -6.0
	_echo_player.play()
	# 하늘이가 메아리에 귀를 쫑긋하고 고개를 갸웃한다(높은 음일수록 고개를 든다, #120)
	var dog := get_tree().get_first_node_in_group("dog")
	if dog and dog.has_method("perk"):
		dog.perk(0.55, -4.0 - note * 4.0)


func _tick(delta: float) -> void:
	_t += delta
	_kick = move_toward(_kick, 0.0, delta * 3.5)
	_slump = move_toward(_slump, 0.0, delta * 1.2)
	_pose_player()
	_place_flute()
	_place_hint()
	if phase != &"play":
		return
	var note := -1
	if MiniGame.autoplay:
		note = melody[played]
	elif Input.is_action_just_pressed("move_left"):
		note = 0
	elif Input.is_action_just_pressed("interact"):
		note = 1
	elif Input.is_action_just_pressed("move_right"):
		note = 2
	if note >= 0:
		hide_key_hint()
		_blow(note)


func _blow(note: int) -> void:
	var i := played
	var mote := _slots[i].duplicate() as Sprite2D
	mote.name = "Blown"
	add_child(mote)
	mote.global_position = _flute.global_position
	mote.modulate.a = 1.0
	_kick = 1.0
	if note == melody[i]:
		_note_player.stream = _tones[note]
		_note_player.play()
		played += 1
		var t := create_tween().set_parallel()
		t.tween_property(mote, "global_position", slot_position(i), 0.4).set_trans(Tween.TRANS_SINE)
		t.chain().tween_callback(mote.queue_free)
		_slots[i].modulate.a = 1.0
		_rings[i].global_position = slot_position(i)
		create_tween().tween_property(_rings[i], "default_color:a", 0.95, 0.3)
		if played >= melody.size():
			_finish()
	else:
		_note_player.stream = _breath
		_note_player.play()
		_slump = 1.0
		phase = &"listen"
		var t := create_tween().set_parallel()
		t.tween_property(mote, "global_position", _flute.global_position + Vector2(randf_range(40, 120), randf_range(-140, -60)), 0.6)
		t.tween_property(mote, "modulate:a", 0.0, 0.6)
		t.chain().tween_callback(mote.queue_free)
		for k in _slots.size():
			create_tween().tween_property(_slots[k], "modulate:a", 0.0, 0.5)
			create_tween().tween_property(_rings[k], "default_color:a", 0.0, 0.5)
		miss()
		await _wait(1.0)
		if running:
			_listen()


## 다 맞았다: 입구가 환해지고 하늘이가 그 입구 앞으로 달려가 앉는다.
func _finish() -> void:
	phase = &"done"
	_gen += 1
	hide_key_hint()
	await _wait(0.5)
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
	if phase == &"listen":
		m["head"] = float(m["head"]) - 7.0  # 메아리 쪽으로 귀를 기울인다
		m["torso"] = float(m["torso"]) - 2.0
	elif phase == &"play" and played < melody.size() and _kick > 0.0:
		m["head"] = float(m["head"]) - (melody[maxi(0, played - 1)] - 1) * 4.0 * _kick
	_player.set_motion(m)


func _place_flute() -> void:
	if _flute and _player:
		_flute.global_position = _player.hand_point() + Vector2(10.0, -10.0)
		_flute.rotation = -0.35


## 피리 소리: 사인파 + 약한 배음, 살짝 떨림, 부드러운 들어가기·끝.
func _make_tone(hz: float, seconds: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		var t := float(k) / MIX_RATE
		var env := minf(1.0, t / 0.04) * clampf((seconds - t) / 0.18, 0.0, 1.0)
		var f := hz * (1.0 + 0.006 * sin(TAU * 5.5 * t))
		var v := sin(TAU * f * t) + 0.18 * sin(TAU * 2.0 * f * t) + 0.04 * (randf() - 0.5)
		data.encode_s16(k * 2, int(clampf(v * env * 0.45, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.data = data
	return w


## 헛바람: 거른 잡음.
func _make_breath(seconds: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var y := 0.0
	for k in n:
		var t := float(k) / MIX_RATE
		var env := minf(1.0, t / 0.03) * clampf((seconds - t) / 0.2, 0.0, 1.0)
		y = lerpf(y, randf() * 2.0 - 1.0, 0.25)
		data.encode_s16(k * 2, int(clampf(y * env * 0.5, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.data = data
	return w
