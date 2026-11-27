class_name AskSpot
extends Area2D
## 부탁 자리. 하윤이 이 안에 있을 때만 F(ask_dog)가 먹고, 하늘이가 정해진 행동을 한다.
## 장소 씬에 B가 놓는다. 노드 하나(이 스크립트를 붙인 Area2D)면 되고, 충돌 모양은 size로 여기서 만든다.
## 약속은 CLAUDE.md "부탁 자리" 참고. 담당: A(게임플레이).

## 하늘이가 행동을 시작할 때.
signal started
## 행동의 핵심 순간: 물건을 물었을 때 / 짖을 때 / 버티기 시작할 때.
signal acted
## 하늘이가 하윤에게 돌아와 부탁이 끝났을 때.
signal completed

enum Action {
	FETCH,  ## 가져와: target까지 가서 물어 오고 돌아온다.
	SNIFF,  ## 냄새: target 쪽으로 가서 짖고 돌아온다.
	HOLD,   ## 기다려: target에서 버티다가 하윤이 release_offset만큼 지나가면 따라온다.
}

@export var action: Action = Action.FETCH
## 하윤이 이 안에 들어오면 F가 먹는다. 원점은 땅(발밑) 가운데.
@export var size: Vector2 = Vector2(320.0, 300.0)
## 하늘이가 가는 곳(이 노드 기준). x만 쓴다.
@export var target_offset: Vector2 = Vector2(240.0, 0.0)
## 행동의 핵심 순간(acted)에 세우는 GameState 플래그.
@export var grants_flag: StringName = &""
## HOLD에서, 하윤이 target보다 이만큼 오른쪽으로 가면 하늘이가 놓고 따라온다.
@export var release_offset: float = 300.0
@export var one_shot: bool = true
## 하늘이가 돌아와 부탁이 끝났을 때 대사 상자에 띄울 줄(예: 3-5 "하윤: 고마워.").
@export var lines: PackedStringArray = PackedStringArray()
## 안 해도 되는 부탁(5-4 조약돌, #148). 하늘이 힌트가 가리키지 않는다.
@export var optional: bool = false

var used: bool = false
var player_inside: bool = false


func _ready() -> void:
	add_to_group("ask_spot")
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_available() -> bool:
	return player_inside and not (one_shot and used)


func target_position() -> Vector2:
	return global_position + target_offset


func release_x() -> float:
	return target_position().x + release_offset


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
