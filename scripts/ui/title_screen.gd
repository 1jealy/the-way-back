extends Control
## 타이틀 화면. "이어하기"(저장이 없으면 비활성) / "처음부터". 담당: A(게임플레이).

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var _continue: Button = $Menu/Continue
@onready var _new: Button = $Menu/New


func _ready() -> void:
	_continue.disabled = not GameState.has_save()
	_continue.pressed.connect(start_continue)
	_new.pressed.connect(start_new)
	(_new if _continue.disabled else _continue).grab_focus.call_deferred()


func start_continue() -> void:
	if not GameState.load_game():
		_continue.disabled = true
		_new.grab_focus()
		return
	get_tree().change_scene_to_file(MAIN_SCENE)


func start_new() -> void:
	GameState.delete_save()
	GameState.reset()
	get_tree().change_scene_to_file(MAIN_SCENE)
