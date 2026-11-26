class_name BenchSit
extends Interactable
## 벤치에 앉기. 장소 씬에 B가 놓는다(이름 Sit_<장면>). 원점은 땅 위, 벤치 가운데.
##
## - auto_sit = true(장면표 3-3): 하윤이 이 안에 들어오면 저절로 앉아 sit_seconds 동안 있다.
##   그동안 장소가 tint 색으로 천천히 물들고(노을이 짙어진다) 환경음이 줄고, 끝 무렵 end_sound가 난다.
##   다 앉고 나면 grants_flag를 세우고 일어난다. 안내 글은 뜨지 않는다.
## - auto_sit = false(2-5, 4-3): "[E] 앉기" → 방향키나 E로 일어난다. 몇 번이든 앉을 수 있다.
##   4-3 빈터는 바닥에 앉고(pose sit_floor), 앉으면 ClearingLight가 빛을 쏟는다.
## 담당: A(게임플레이). (A 세션이 쉬는 동안 B 세션이 만듦, #32)

signal sat_down
signal stood_up

const LOCK := &"sit"

@export var auto_sit: bool = false
## 자동으로 앉아 있는 시간(초). 장면표 3-3: 15초.
@export var sit_seconds: float = 15.0
## 자동 앉기 동안 장소 층을 이 색으로 천천히 물들인다. 흰색이면 그대로.
@export var tint: Color = Color.WHITE
## 자동 앉기 끝 무렵에 낼 소리(이름 앞머리, 예: "sfx_dog_bark_far_").
@export var end_sound: String = ""
## 자동 앉기 동안 장소 환경음을 이만큼 줄인다(dB, 0이면 그대로).
@export var ambience_duck_db: float = 0.0
## 앉는 자세(sit = 벤치, sit_floor = 바닥, 4-3 빈터).
@export var pose: StringName = &"sit"

var sitting: bool = false
var _player: Player


func _ready() -> void:
	super._ready()
	if auto_sit:
		one_shot = true
		body_entered.connect(_on_auto_enter)


## 자동 앉기는 안내 글을 띄우지 않는다. 앉아 있는 동안에도.
func is_offered() -> bool:
	if auto_sit or sitting:
		return false
	return super.is_offered()


func interact() -> void:
	if auto_sit or sitting or not is_available():
		return
	_sit_down()


func _unhandled_input(event: InputEvent) -> void:
	if not sitting or auto_sit:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_stand_up()


func _on_auto_enter(body: Node2D) -> void:
	if used or not body.is_in_group("player"):
		return
	used = true
	_sit_auto()


func _sit_down() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return
	sitting = true
	_player.lock(LOCK)
	_player.global_position.x = global_position.x
	_player.velocity = Vector2.ZERO
	_player.set_pose(pose)
	sat_down.emit()


func _stand_up() -> void:
	sitting = false
	if _player:
		_player.set_pose(&"stand")
		_player.unlock(LOCK)
	stood_up.emit()


func _sit_auto() -> void:
	_sit_down()
	if _player == null:
		return
	var place := get_tree().get_first_node_in_group("place") as Node
	var layers := place.get_node_or_null("Layers") as CanvasItem if place else null
	if layers and tint != Color.WHITE:
		create_tween().tween_property(layers, "modulate", tint, sit_seconds)
	var amb := place.get_node_or_null("Sound/Ambience") as AudioStreamPlayer if place else null
	var amb_db := amb.volume_db if amb else 0.0
	if amb and ambience_duck_db != 0.0:
		create_tween().tween_property(amb, "volume_db", amb_db + ambience_duck_db, sit_seconds * 0.6)
	# 멈춤(일시정지) 동안에는 흐르지 않는 타이머
	await get_tree().create_timer(sit_seconds * 0.75, false).timeout
	_play_sound(end_sound)
	await get_tree().create_timer(sit_seconds * 0.25, false).timeout
	if amb and ambience_duck_db != 0.0:
		create_tween().tween_property(amb, "volume_db", amb_db, 2.0)
	if not grants_flag.is_empty():
		GameState.set_flag(grants_flag)
	_stand_up()
