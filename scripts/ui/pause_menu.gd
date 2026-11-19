class_name PauseMenu
extends Control
## 일시정지 메뉴. Esc로 게임 전체를 멈추고 "계속하기" / "타이틀로"를 고른다.
## 이 노드만 멈춘 동안에도 돈다(process_mode = ALWAYS). 담당: A(게임플레이).

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

@onready var _resume: Button = $Menu/Resume
@onready var _to_title: Button = $Menu/ToTitle


func _ready() -> void:
	add_to_group("pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_resume.pressed.connect(resume)
	_to_title.pressed.connect(go_to_title)


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	show()
	get_tree().paused = true
	_resume.grab_focus()


func resume() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false


func go_to_title() -> void:
	hide()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# 지도가 펼쳐져 있으면 지도가 Esc를 먼저 가져간다(_input). 여기 오는 건 그 밖의 경우뿐이다.
	get_viewport().set_input_as_handled()
	if visible:
		resume()
	else:
		open()
