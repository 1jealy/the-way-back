class_name Grandpa
extends Node2D
## 할아버지(장면표 7-3~7-6). 나루터 씬에 B가 놓는다. 원점은 발밑.
## 기획서: 서 있기·팔찌 풀기(컷신)·카메라 들기만, 걷지 않는다. 지금은 회색 네모 단계 임시 모습.
## appears_on_flag가 서면 천천히 나타난다(7-2 다섯째 동그라미 뒤).
## 담당: A(게임플레이). (A 세션이 쉬는 동안 B 세션이 만듦, 엔딩)

@export var appears_on_flag: StringName = &"map_circle_5"
@export var appear_seconds: float = 2.0

@onready var _camera: Node2D = $Visual/Camera


func _ready() -> void:
	add_to_group("grandpa")
	_camera.visible = false
	if appears_on_flag.is_empty() or GameState.has_flag(appears_on_flag):
		visible = true
	else:
		visible = false
		GameState.flag_changed.connect(_on_flag_changed)


func _on_flag_changed(flag: StringName) -> void:
	if flag == appears_on_flag and not visible:
		appear()


func appear() -> void:
	modulate.a = 0.0
	visible = true
	create_tween().tween_property(self, "modulate:a", 1.0, appear_seconds)


## 7-5: 카메라를 든다.
func raise_camera() -> void:
	_camera.visible = true


func lower_camera() -> void:
	_camera.visible = false
