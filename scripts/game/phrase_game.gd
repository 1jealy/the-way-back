class_name PhraseGame
extends MiniGame
## 할아버지 휘파람 따라 하기(#145, 기획서 "할아버지 휘파람 따라 하기"). 장소마다 같은 놀이다:
## 멀리서 할아버지 휘파람이 한 소절 들리고(메아리), 하윤이 그 장소의 물건으로 같은 소절을 따라 한다.
## 조작은 어디서나 ← 낮은 음 · E 가운데 음 · → 높은 음. 실패는 없다 — 틀리면 그 소절을 다시 들려준다.
## 세 번 어긋나면 도움: 메아리가 크고 느려지고, 하늘이가 다음 음마다 짖는다.
## 다 맞으면 할아버지 휘파람이 그 소절을 한 번 더 받아 분다(대답). 선율은 WhistleTune 한 곳에 있다.
##
## 하위 부품은 "음을 내는 방법"(그림·하윤 동작·소리 빛깔)만 바꿔 끼운다:
##   _setup()                     물건·빛을 만들고 하윤 자세를 잡는다
##   _on_listen(retry)            메아리를 듣기 시작할 때
##   _on_echo(i, level, gap)      메아리 i번째 음이 들릴 때
##   _on_play()                   하윤 차례가 될 때
##   _on_note(i, level, correct)  하윤이 음을 냈을 때(맞든 틀리든)
##   _on_round()                  앞 소절을 다 맞췄을 때(다음 소절 전, await 가능)
##   _on_finish()                 다 맞추고 할아버지가 받아 분 뒤(await 가능). 여기서 clear()를 부른다
##   _make_tone(hz)               하윤이 내는 음의 소리(기본: 피리)

## 이 플래그(물건)가 서 있어야 시작한다.
@export var trigger_flag: StringName = &""
## 따라 할 소절(WhistleTune.PHRASES의 열쇠).
@export var phrase_id: StringName = &"forest"
## 첫 소절의 음 수(0이면 한 번에 전부). 짧게 한 번 맞추고 늘려 가며 호응을 쌓는다(#119).
@export var first_round_notes: int = 0
## 메아리 음 사이 간격(초).
@export var echo_gap: float = 0.75
## 메아리(할아버지 휘파람)가 들려오는 자리(x, 장소 좌표).
@export var echo_x: float = 0.0
## 메아리가 소리로 들리나. 거짓이면 하윤이 기억해서 먼저 분다(나루터 7-3: 할아버지는 대답만 한다, #147).
@export var echo_audible: bool = true

## 소절의 높이(0 낮음 · 1 가운데 · 2 높음).
var melody: PackedInt32Array = PackedInt32Array()
## 이번 소절에서 지금까지 맞게 낸 음 수.
var played: int = 0
## 몇째 소절인가: 0은 앞 first_round_notes 음, 1은 전부.
var round_index: int = 0
## idle / listen(메아리가 들린다) / play(하윤 차례) / answer(할아버지가 받아 분다) / done
var phase: StringName = &"idle"

const MIX_RATE := 22050

var _tones: Array[AudioStreamWAV] = []
var _whistles: Array[AudioStreamWAV] = []
var _breath: AudioStreamWAV
var _echo_player: AudioStreamPlayer2D
var _note_player: AudioStreamPlayer
var _gen: int = 0


func _ready() -> void:
	melody = WhistleTune.levels(phrase_id)
	super._ready()
	if not trigger_flag.is_empty():
		setup_start(trigger_flag)


## 이번 소절에 낼 음 수.
func round_length() -> int:
	if round_index > 0 or first_round_notes <= 0:
		return melody.size()
	return mini(first_round_notes, melody.size())


## 메아리가 들려오는 자리.
func echo_position() -> Vector2:
	return Vector2(echo_x if echo_x != 0.0 else global_position.x + 900.0, 600.0)


func _begin() -> void:
	round_index = 0
	melody = WhistleTune.levels(phrase_id)
	_tones.clear()
	_whistles.clear()
	for level in 3:
		var hz := WhistleTune.level_hz(phrase_id, level)
		_tones.append(_make_tone(hz))
		_whistles.append(make_whistle(hz, 0.5))
	_breath = _make_breath(0.35)
	if _echo_player == null:
		_echo_player = AudioStreamPlayer2D.new()
		_echo_player.name = "Echo"
		_echo_player.bus = SoundBank.BUS_SFX
		_echo_player.max_distance = 3000.0
		add_child(_echo_player)
		_note_player = AudioStreamPlayer.new()
		_note_player.name = "Note"
		_note_player.bus = SoundBank.BUS_SFX
		add_child(_note_player)
	_echo_player.global_position = echo_position()
	_setup()
	_listen()


## 메아리가 들린다.
func _listen(retry: bool = false) -> void:
	_gen += 1
	var gen := _gen
	phase = &"listen"
	played = 0
	hide_key_hint()
	_on_listen(retry)
	# 틀린 뒤 다시 들을 때는 바로 시작한다(#119: 다시 듣는 대기가 길었다)
	await _wait(0.25 if retry else 0.6)
	var gap := echo_gap * (1.5 if help else 1.0)
	for i in round_length():
		if gen != _gen or not running:
			return
		_echo(melody[i])
		_on_echo(i, melody[i], gap)
		await _wait(gap)
	await _wait(gap * 0.8)
	if gen != _gen or not running:
		return
	phase = &"play"
	_on_play()
	_hint_next()
	show_key_hint(["←", "E", "→"], "낮게 · 가운데 · 높게")


func _echo(level: int) -> void:
	if not echo_audible:
		return
	dog_react(0.5 + 0.25 * level)  # 메아리에 귀를 쫑긋(#120)
	_echo_player.stream = _whistles[level]
	_echo_player.volume_db = 0.0 if help else -6.0
	_echo_player.play()


func _tick(delta: float) -> void:
	_update(delta)
	if phase != &"play":
		return
	var level := -1
	if MiniGame.autoplay:
		level = melody[played]
	elif Input.is_action_just_pressed("move_left"):
		level = 0
	elif Input.is_action_just_pressed("interact"):
		level = 1
	elif Input.is_action_just_pressed("move_right"):
		level = 2
	if level >= 0:
		hide_key_hint()
		_answer(level)


func _answer(level: int) -> void:
	var i := played
	if level == melody[i]:
		_note_player.stream = _tones[level]
		_note_player.play()
		dog_react(0.6)
		played += 1
		_on_note(i, level, true)
		if played >= round_length():
			if round_length() < melody.size():
				_next_round()
			else:
				_finish()
		else:
			_hint_next()
	else:
		_note_player.stream = _breath
		_note_player.play()
		phase = &"listen"
		_on_note(i, level, false)
		miss()
		await _wait(0.5)
		if running:
			_listen(true)


## 도움이 켜져 있으면 하늘이가 다음 음마다 짖는다(높은 음일수록 고개를 더 든다).
func _hint_next() -> void:
	if not help or played >= melody.size():
		return
	var dog := get_tree().get_first_node_in_group("dog")
	if dog and dog.has_method("bark") and dog.is_joined():
		dog.bark()
		dog.perk(0.4 + 0.3 * melody[played])


func _on_help() -> void:
	_hint_next()


## 앞 소절을 다 맞췄다: 다음 소절이 한 음 더 길게 들린다.
func _next_round() -> void:
	phase = &"listen"
	_gen += 1
	hide_key_hint()
	await _on_round()
	await _wait(0.4)
	round_index = 1
	if running:
		_listen()


## 다 맞았다: 할아버지 휘파람이 그 소절을 받아 분다(대답), 그 뒤 장소마다의 마무리.
func _finish() -> void:
	phase = &"answer"
	_gen += 1
	hide_key_hint()
	dog_react(1.0, 1.6)
	await _wait(0.5)
	var beats := WhistleTune.notes(phrase_id)
	for i in melody.size():
		if not running:
			return
		_echo_player.stream = _whistles[melody[i]]
		_echo_player.volume_db = -3.0
		_echo_player.play()
		await _wait(float(beats[i][1]) * 0.75)
	phase = &"done"
	await _on_finish()


# ---- 하위 부품이 바꿔 끼우는 것 ----

func _setup() -> void:
	pass


func _update(_delta: float) -> void:
	pass


func _on_listen(_retry: bool) -> void:
	pass


func _on_echo(_i: int, _level: int, _gap: float) -> void:
	pass


func _on_play() -> void:
	pass


func _on_note(_i: int, _level: int, _correct: bool) -> void:
	pass


func _on_round() -> void:
	pass


func _on_finish() -> void:
	clear()


## 하윤이 내는 음(기본: 피리 — 사인파 + 약한 배음, 살짝 떨림).
func _make_tone(hz: float) -> AudioStreamWAV:
	return make_flute(hz, 0.45)


# ---- 코드로 만드는 소리(진짜 소리가 오면 바꾼다, #122) ----

static func make_flute(hz: float, seconds: float) -> AudioStreamWAV:
	return _synth(seconds, func(t: float) -> float:
		var f := hz * (1.0 + 0.006 * sin(TAU * 5.5 * t))
		var env := minf(1.0, t / 0.04) * clampf((seconds - t) / 0.18, 0.0, 1.0)
		return (sin(TAU * f * t) + 0.18 * sin(TAU * 2.0 * f * t) + 0.04 * (randf() - 0.5)) * env * 0.45)


## 할아버지 휘파람: 거의 순음 + 숨소리, 느린 떨림.
static func make_whistle(hz: float, seconds: float) -> AudioStreamWAV:
	return _synth(seconds, func(t: float) -> float:
		var f := hz * (1.0 + 0.008 * sin(TAU * 5.2 * t) * minf(1.0, t / 0.25))
		var env := minf(1.0, t / 0.06) * clampf((seconds - t) / 0.16, 0.0, 1.0)
		return (sin(TAU * f * t) + 0.08 * (randf() - 0.5)) * env * 0.42)


## 헛바람: 거른 잡음.
static func _make_breath(seconds: float) -> AudioStreamWAV:
	var y := [0.0]
	return _synth(seconds, func(t: float) -> float:
		var env := minf(1.0, t / 0.03) * clampf((seconds - t) / 0.2, 0.0, 1.0)
		y[0] = lerpf(y[0], randf() * 2.0 - 1.0, 0.25)
		return y[0] * env * 0.5)


static func _synth(seconds: float, sample: Callable) -> AudioStreamWAV:
	var n := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		var v: float = sample.call(float(k) / MIX_RATE)
		data.encode_s16(k * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.data = data
	return w
