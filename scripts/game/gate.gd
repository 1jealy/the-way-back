class_name Gate
extends StaticBody2D
## 길을 막는 벽. opens_on_flag가 서면 열린다(사라진다). 비워 두면 늘 막는다.
## 하윤만 막는다(물리 층 4 "gate", 하윤의 마스크에만 있다) — 하늘이는 지나간다(징검다리 첫 돌 등).
## 장소 씬에 B가 놓는다. 이름은 장면표 번호로: Gate_3-6. 원점은 땅(발밑) 가운데.
## 담당: A(게임플레이). (A 세션이 쉬는 동안 B 세션이 만듦, #32)

const LAYER_GATE := 8  # 물리 층 4

@export var opens_on_flag: StringName = &""
@export var size: Vector2 = Vector2(40.0, 600.0)

var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("gate")
	collision_layer = LAYER_GATE
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(_shape)
	GameState.flag_changed.connect(_on_flag_changed)
	_refresh()


func is_open() -> bool:
	return not opens_on_flag.is_empty() and GameState.has_flag(opens_on_flag)


func _on_flag_changed(flag: StringName) -> void:
	if flag == opens_on_flag:
		_refresh()


func _refresh() -> void:
	_shape.set_deferred("disabled", is_open())
