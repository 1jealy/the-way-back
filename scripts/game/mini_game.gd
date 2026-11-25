class_name MiniGame
extends Node2D
## 미니게임 공통 부품(들판 연 날리기, 숲 피리, 강가 물수제비, 철교 손전등). 각 놀이는 이것을 이어 만든다.
## - 시작하면 하윤 조작을 막는다(잠금 이유 minigame). 하윤은 걷지 않고 키 하나(action)만 쓴다.
## - UI는 화면 안에 녹인다: 띠·게이지·숫자를 띄우지 않고, 키 안내만 하윤 손 옆에 작게("[E] 당기기").
## - 틀린 횟수(mistakes)가 help_after에 닿으면 한 번 도와준다(_on_help: 더 쉽게). 실패해서 끝나는 일은 없다.
## - autoplay면 사람이 누르는 대신 _auto_pressing()이 누른다(검사용).
## - 끝나면 done_flag를 세운다. 이어하기 때 done_flag가 서 있으면 시작하지 않는다.
## 담당: A(퍼즐 로직). (A 대신 B 세션이 만듦)

signal started
## 한 번 틀렸다(count = 지금까지 틀린 횟수).
signal mistake(count: int)
## 많이 틀려서 도와주기 시작했다.
signal helped
signal finished

const LOCK := &"minigame"

## 쓰는 키(입력 액션).
@export var action: StringName = &"interact"
## 손 옆에 뜨는 키 안내.
@export var key_hint: String = "[E]"
## 이만큼 틀리면 도와준다(0이면 돕지 않는다).
@export var help_after: int = 2
## 끝나면 세우는 플래그.
@export var done_flag: StringName = &""
## 검사용: 사람 대신 누른다.
@export var autoplay: bool = false

var running: bool = false
var mistakes: int = 0
var helping: bool = false
var _hint: Label
var _player: Player


func _ready() -> void:
	add_to_group("mini_game")


func is_done() -> bool:
	return not done_flag.is_empty() and GameState.has_flag(done_flag)


func begin() -> void:
	if running or is_done():
		return
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return
	running = true
	mistakes = 0
	helping = false
	_player.lock(LOCK)
	_make_hint()
	started.emit()
	_on_begin()


## 지금 키를 누르고 있나(autoplay면 놀이가 정한 대로).
func pressing() -> bool:
	if autoplay:
		return _auto_pressing()
	return Input.is_action_pressed(action)


## 놀이가 한 번 틀렸을 때 부른다.
func miss() -> void:
	mistakes += 1
	mistake.emit(mistakes)
	if help_after > 0 and mistakes >= help_after and not helping:
		helping = true
		_on_help()
		helped.emit()


## 놀이가 다 끝났을 때 부른다.
func end() -> void:
	if not running:
		return
	running = false
	if _hint:
		_hint.queue_free()
		_hint = null
	if not done_flag.is_empty():
		GameState.set_flag(done_flag)
	if _player:
		_player.unlock(LOCK)
	finished.emit()


func set_hint_visible(on: bool) -> void:
	if _hint:
		_hint.visible = on


## 이어 만드는 쪽이 채운다.
func _on_begin() -> void:
	pass


func _on_help() -> void:
	pass


func _auto_pressing() -> bool:
	return false


func _process(_delta: float) -> void:
	if _hint and _player:
		# 손 옆(앞쪽 조금 아래)에 작게. 하윤과 같이 움직인다.
		_hint.global_position = _player.hand_point() + Vector2(28.0 * _player.facing, -12.0) \
				- Vector2(0.0 if _player.facing > 0 else _hint.size.x, 0.0)


func _make_hint() -> void:
	_hint = Label.new()
	_hint.name = "KeyHint"
	_hint.text = key_hint
	_hint.top_level = true
	_hint.z_index = 20
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(1, 0.95, 0.82, 0.92))
	_hint.add_theme_color_override("font_outline_color", Color(0.12, 0.1, 0.09, 0.75))
	_hint.add_theme_constant_override("outline_size", 5)
	add_child(_hint)
	_hint.size = _hint.get_minimum_size()


func _exit_tree() -> void:
	# 놀이 중에 장소를 떠나면(타이틀로 등) 잠금을 남기지 않는다.
	if running and is_instance_valid(_player):
		_player.unlock(LOCK)
