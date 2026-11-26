class_name MiniGame
extends Node2D
## 미니게임 공통 부품(#111, 기획서 "미니게임"). 들판 연 날리기·숲 피리·강가 물수제비·철교 손전등이 이어 쓴다.
## UI는 화면 안에 녹인다: 띠·게이지·숫자 없이, 맞춰야 할 것·남은 것·해낸 것은 그 장소의 물건이 보여 준다.
## 여기서 주는 것은 넷뿐이다.
## - 하윤 잠금(이유 minigame)과 풀기
## - 손 옆 작은 키 안내(show_key_hint). 처음 한 번 누르면 사라진다
## - 어긋난 횟수(miss) → help_after번이면 도움(help = true, _on_help). 실패 화면은 없다
## - 끝나면 grants_flag를 세우고 cleared
## 하위 부품은 _begin / _tick / _on_help만 쓴다. 연출 대기는 create_timer(t, false)(일시정지 중에 흐르지 않게).
## 검사는 MiniGame.autoplay를 켜면 하위 부품이 스스로 잘 해낸다. 담당: A(게임플레이).

signal started
signal missed(count: int)
signal helped
signal cleared

const LOCK := &"minigame"
const KEY_BG := Color(1.0, 0.97, 0.9, 0.92)
const KEY_INK := Color(0.24, 0.22, 0.2)
const HINT_BG := Color(0.08, 0.07, 0.06, 0.45)
const HINT_INK := Color(1.0, 0.97, 0.9)

## 검사용: 켜면 하위 부품이 사람 대신 잘 해낸다.
static var autoplay: bool = false

## 다 해내면 세우는 플래그. 서 있으면 이미 한 것으로 본다(이어하기).
@export var grants_flag: StringName = &""
## 이만큼 어긋나면 도움이 켜진다(빛이 넓어지거나 하늘이가 먼저 움직인다).
@export var help_after: int = 3
## 비우지 않으면 저절로 시작하지 않고, 그 자리에 "[E] <start_prompt>"를 띄워 하윤이 직접 시작한다
## (#119 — 지나가면 조작을 빼앗고 시작해서 물건을 꺼내 쓴다는 느낌이 약했다). 검사(autoplay)는 바로 시작.
@export var start_prompt: String = ""

var running: bool = false
var done: bool = false
var misses: int = 0
var help: bool = false

var _player: Player
var _hint: Node2D
var _starter: Interactable
## [E]로 시작했으면 그 E를 한 번 뗄 때까지는 놀이 입력으로 치지 않는다(시작하자마자 연이 감기지 않게).
var _wait_release: bool = false


func _ready() -> void:
	add_to_group("minigame")
	if not grants_flag.is_empty() and GameState.has_flag(grants_flag):
		done = true


## 미니게임 한 판. 다 해낼 때까지 기다린다.
func play() -> void:
	if running or done:
		return
	_player = get_tree().get_first_node_in_group("player") as Player
	running = true
	misses = 0
	help = false
	if _player:
		_player.lock(LOCK)
	started.emit()
	_begin()
	await cleared


## 하위 부품의 시작 조건이 맞을 때 부른다. start_prompt가 있으면 [E] 안내를 띄워 기다리고, 없으면 바로 시작.
func request_start() -> void:
	if running or done:
		return
	if start_prompt.is_empty() or MiniGame.autoplay:
		play()
		return
	if _starter != null:
		return
	_starter = Interactable.new()
	_starter.name = "Starter"
	_starter.prompt = start_prompt
	_starter.size = Vector2(420.0, 300.0)
	_starter.one_shot = true  # 진행에 필요한 대상이라 하늘이 힌트가 가리킨다
	add_child(_starter)
	_starter.global_position = Vector2(global_position.x, 810.0)
	_starter.interacted.connect(_on_starter)


## [E]로 시작 안내를 눌렀다.
func _on_starter() -> void:
	if _starter:
		_starter.queue_free()
		_starter = null
	_wait_release = true
	play()


## 놀이가 E(꾹 누르기)를 읽을 때 쓴다. 시작한 E를 뗀 뒤부터 참이 될 수 있다.
func e_held() -> bool:
	if _wait_release:
		if Input.is_action_pressed("interact"):
			return false
		_wait_release = false
	return Input.is_action_pressed("interact")


## 시작 안내가 떠 있나(검사용).
func is_offering() -> bool:
	return _starter != null


## 하위 부품: 시작할 때.
func _begin() -> void:
	pass


## 하위 부품: 도는 동안 매 프레임.
func _tick(_delta: float) -> void:
	pass


## 하위 부품: 도움이 켜졌을 때.
func _on_help() -> void:
	pass


func _process(delta: float) -> void:
	if running:
		_tick(delta)


## 한 번 어긋났다. 벌은 없고, help_after번이면 도움이 켜진다.
func miss() -> void:
	misses += 1
	missed.emit(misses)
	if not help and misses >= help_after:
		help = true
		_on_help()
		helped.emit()


## 다 해냈다.
func clear() -> void:
	if not running:
		return
	running = false
	done = true
	hide_key_hint()
	if not grants_flag.is_empty():
		GameState.set_flag(grants_flag)
	if _player:
		_player.unlock(LOCK)
	cleared.emit()


func _exit_tree() -> void:
	if running and _player and is_instance_valid(_player):
		_player.unlock(LOCK)


## 하윤 손 옆에 작은 키 안내를 띄운다(처음 한 번). keys = ["E"] / ["←", "E", "→"], text = 짧은 동사.
func show_key_hint(keys: Array, text: String) -> void:
	hide_key_hint()
	_hint = make_key_hint(keys, text)
	_hint.name = "KeyHint"
	add_child(_hint)
	_place_hint()


func hide_key_hint() -> void:
	if _hint and is_instance_valid(_hint):
		var h := _hint
		_hint = null
		var tween := h.create_tween()
		tween.tween_property(h, "modulate:a", 0.0, 0.25)
		tween.tween_callback(h.queue_free)


func has_key_hint() -> bool:
	return _hint != null and is_instance_valid(_hint)


func _place_hint() -> void:
	if _hint and _player:
		# 손 옆, 단 손이 몸 뒤로 가 있어도(던지려고 젖힘) 몸에 겹치지 않게 늘 하윤 앞쪽에
		var hand := _player.hand_point()
		_hint.global_position = Vector2(maxf(hand.x + 40.0, _player.global_position.x + 80.0), hand.y - 30.0)


## 키 안내 한 줄(키 모양 + 동사). 화면 안 손 옆에 두는 작은 것.
static func make_key_hint(keys: Array, text: String) -> Node2D:
	var root := Node2D.new()
	root.z_index = 25
	root.z_as_relative = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var bg := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = HINT_BG
	bg_style.set_corner_radius_all(20)
	bg_style.content_margin_left = 6
	bg_style.content_margin_right = 12
	bg_style.content_margin_top = 5
	bg_style.content_margin_bottom = 5
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.add_child(row)
	for k in keys:
		var cap := Label.new()
		cap.text = String(k)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.custom_minimum_size = Vector2(32, 32)
		cap.add_theme_font_size_override("font_size", 18)
		cap.add_theme_color_override("font_color", KEY_INK)
		var cap_style := StyleBoxFlat.new()
		cap_style.bg_color = KEY_BG
		cap_style.set_corner_radius_all(7)
		cap.add_theme_stylebox_override("normal", cap_style)
		row.add_child(cap)
	if not text.is_empty():
		var label := Label.new()
		label.text = text
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", HINT_INK)
		row.add_child(label)
	root.add_child(bg)
	return root


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _play_sound(prefix: String) -> void:
	if prefix.is_empty():
		return
	var stream := SoundBank.pick(prefix)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = SoundBank.BUS_SFX
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
