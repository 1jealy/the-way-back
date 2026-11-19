class_name DogMeeting
extends Node2D
## 하늘이 만남 장면(장면표 3-4). B가 간이역 씬의 3-4 자리(땅 위)에 놓는다.
##
## 1. 하늘이가 이 자리에 앉아 있다. 하윤이 notice_distance 안으로 오면 retreat_distance만큼 물러나 다시 앉는다.
## 2. retreats번 물러난 뒤에는 물러나지 않고 "[E] 쪼그려 앉기"가 뜬다.
## 3. E → 하윤이 쪼그려 앉고, 하늘이가 다가와 냄새를 맡는다 → lines(이름표 글, 하윤 대사) → 합류.
## 이미 합류했으면 아무 일도 하지 않고 사라진다. 담당: A(게임플레이).

signal met

const LOCK := &"meeting"

@export var retreats: int = 2
@export var retreat_distance: float = 300.0
@export var notice_distance: float = 360.0
## 하늘이가 다가와 서는 거리(하윤 앞).
@export var sniff_gap: float = 90.0
@export var prompt: String = "쪼그려 앉기"
## 이 플래그가 서야 하늘이가 나타난다(3-3 벤치에 앉은 뒤: station_sat). 비우면 처음부터.
@export var appears_on_flag: StringName = &""
@export var lines: PackedStringArray = PackedStringArray(["하늘", "하윤: 하늘이…?"])

var _retreats_left: int = 0
var _dog: Dog
var _player: Player
var _crouch: Interactable
var _done: bool = false


func _ready() -> void:
	_retreats_left = retreats
	# 장소 씬이 붙고 하윤 위치가 정해진 뒤에 시작한다.
	_begin.call_deferred()


func _begin() -> void:
	if GameState.has_flag(Dog.JOIN_FLAG):
		queue_free()
		return
	if not appears_on_flag.is_empty() and not GameState.has_flag(appears_on_flag):
		if not GameState.flag_changed.is_connected(_on_flag_changed):
			GameState.flag_changed.connect(_on_flag_changed)
		return
	_dog = get_tree().get_first_node_in_group("dog") as Dog
	_player = get_tree().get_first_node_in_group("player") as Player
	if _dog == null or _player == null:
		return
	_dog.begin_meeting(global_position)


func _on_flag_changed(flag: StringName) -> void:
	if flag == appears_on_flag:
		GameState.flag_changed.disconnect(_on_flag_changed)
		_begin()


func retreats_left() -> int:
	return _retreats_left


func _physics_process(_delta: float) -> void:
	if _done or _dog == null or _dog.state != Dog.State.MEETING or _dog.is_meet_moving():
		return
	if _crouch != null:
		_crouch.global_position.x = _dog.global_position.x
		return
	var gap := absf(_dog.global_position.x - _player.global_position.x)
	if gap > notice_distance:
		return
	if _retreats_left > 0:
		_retreats_left -= 1
		var away := signf(_dog.global_position.x - _player.global_position.x)
		if away == 0.0:
			away = 1.0
		_dog.meet_move_to(_dog.global_position.x + away * retreat_distance)
	else:
		_offer_crouch()


func _offer_crouch() -> void:
	_crouch = Interactable.new()
	_crouch.name = "Crouch"
	_crouch.prompt = prompt
	_crouch.one_shot = true
	_crouch.size = Vector2(notice_distance * 2.0, 300.0)
	add_child(_crouch)
	_crouch.global_position = Vector2(_dog.global_position.x, global_position.y)
	_crouch.interacted.connect(_on_crouch)


func _on_crouch() -> void:
	_done = true
	_player.lock(LOCK)
	_player.set_crouching(true)
	var side := signf(_dog.global_position.x - _player.global_position.x)
	if side == 0.0:
		side = 1.0
	_dog.meet_move_to(_player.global_position.x + side * sniff_gap)
	await _dog.meet_arrived
	var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if box and not lines.is_empty():
		box.play(lines)
		await box.finished
	_player.set_crouching(false)
	_player.unlock(LOCK)
	_dog.join(_player, false)
	met.emit()
	queue_free()
