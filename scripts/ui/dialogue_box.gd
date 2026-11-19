class_name DialogueBox
extends Control
## 화면 아래 대사 상자. 줄을 하나씩 글자가 찍히듯 보여 주고, E로 넘긴다.
## 열려 있는 동안 하윤은 걷지 않는다. 담당: A(게임플레이).
##
## 줄 형식
##   "하윤: 고마워."       → 대사. 이름이 위에 뜬다.
##   "막차 놓치지 말 것"    → 글·지문. 이름 없이 종이 색으로.
## 콜론 앞이 띄어쓰기 없는 8자 이하일 때만 이름으로 본다.

signal finished

const LOCK := &"dialogue"
const CHARS_PER_SECOND := 30.0
const SPEAKER_MAX_LEN := 8
const SPEECH_COLOR := Color(1, 1, 1, 1)
const WRITING_COLOR := Color(0.9, 0.84, 0.72, 1)

var _lines: Array[Dictionary] = []
var _index: int = -1
var _typed: float = 0.0

@onready var _speaker: Label = $Panel/Speaker
@onready var _text: Label = $Panel/Text
@onready var _next: Label = $Panel/Next


func _ready() -> void:
	add_to_group("dialogue_box")
	hide()


static func parse_line(line: String) -> Dictionary:
	var colon := line.find(": ")
	if colon > 0 and colon <= SPEAKER_MAX_LEN:
		var name := line.substr(0, colon)
		if not name.contains(" "):
			return {"speaker": name, "text": line.substr(colon + 2)}
	return {"speaker": "", "text": line}


func is_open() -> bool:
	return visible


func current_speaker() -> String:
	return _speaker.text if _speaker.visible else ""


func current_text() -> String:
	return _text.text


func is_line_complete() -> bool:
	return _text.visible_characters < 0 or _text.visible_characters >= _text.text.length()


## 줄들을 보여 준다. 다 넘기면 finished가 온다.
func play(lines: PackedStringArray) -> void:
	_lines.clear()
	for line in lines:
		_lines.append(parse_line(line))
	if _lines.is_empty():
		finished.emit()
		return
	_lock_player(true)
	show()
	_show_line(0)


## E 한 번: 찍히는 중이면 다 보이게, 다 보이면 다음 줄, 마지막이면 닫는다.
func advance() -> void:
	if not is_line_complete():
		_text.visible_characters = -1
		_typed = float(_text.text.length())
	elif _index + 1 < _lines.size():
		_show_line(_index + 1)
	else:
		_close()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance()


func _process(delta: float) -> void:
	if not visible or is_line_complete():
		_next.visible = visible
		return
	_typed += delta * CHARS_PER_SECOND
	_text.visible_characters = int(_typed)
	_next.visible = is_line_complete()


func _show_line(i: int) -> void:
	_index = i
	var line: Dictionary = _lines[i]
	_speaker.text = line["speaker"]
	_speaker.visible = not String(line["speaker"]).is_empty()
	_text.text = line["text"]
	_text.add_theme_color_override("font_color", SPEECH_COLOR if _speaker.visible else WRITING_COLOR)
	_typed = 0.0
	_text.visible_characters = 0
	_next.visible = false


func _close() -> void:
	hide()
	_lines.clear()
	_index = -1
	_lock_player(false)
	finished.emit()


func _lock_player(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if on:
		player.lock(LOCK)
	else:
		player.unlock(LOCK)
