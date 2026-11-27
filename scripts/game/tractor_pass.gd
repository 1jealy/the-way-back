class_name TractorPass
extends Node2D
## 장면표 2-4 "경운기": 흙길로 경운기가 다가온다. 하윤이 비켜서서 인사한다.
## 농부는 고개를 돌리지 않고 지나간다. 엔진 소리가 점점 멀어진다.
## 장소 씬에 B가 놓는다(Tractor_2-4). 원점은 땅 위, 하윤이 원점 - trigger_before를 지나면 시작한다.
## 끝나면 done_flag를 세워 이어하기 뒤에는 다시 오지 않는다. 담당: A(연출 흐름). (A 세션이 쉬는 동안 B 세션이 만듦)

## 경운기가 하윤 곁을 지나갔다(하윤 왼쪽으로 넘어갔다).
signal passed
## 연출이 끝나 하윤이 다시 걸을 수 있다.
signal finished

const LOCK := &"tractor"

@export var trigger_before: float = 250.0
## 경운기가 나타나는 곳(하윤 기준 오른쪽, px)과 사라지는 곳(왼쪽).
@export var spawn_ahead: float = 1300.0
@export var vanish_behind: float = 1500.0
## 경운기 빠르기(px/초). 하윤 걷기(250)보다 느리다.
@export var speed: float = 240.0
## 이만큼 다가오면 인사한다.
@export var greet_distance: float = 300.0
## 하윤이 비켜서는 거리(왼쪽으로, px).
@export var step_aside: float = 80.0
## 경운기는 하윤보다 뒤쪽(먼 길가)으로 지나간다. 그만큼 위·작게.
@export var lane_y: float = -14.0
@export var lane_scale: float = 0.92
@export var art: String = "prop_tractor"
@export var engine_sound: String = "sfx_tractor_"
@export var lines: PackedStringArray = PackedStringArray(["하윤: 안녕하세요."])
@export var done_flag: StringName = &"tractor_passed"

var running: bool = false
var has_passed: bool = false
var _tractor: Sprite2D
var _engine: AudioStreamPlayer2D
var _greeted: bool = false


func _ready() -> void:
	add_to_group("tractor_pass")


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if not running and _tractor == null:
		if player.global_position.x >= global_position.x - trigger_before \
				and (done_flag.is_empty() or not GameState.has_flag(done_flag)):
			_start(player)
		return
	if _tractor == null:
		return
	_tractor.global_position.x -= speed * delta
	var gap := _tractor.global_position.x - player.global_position.x
	if not _greeted and gap < greet_distance:
		_greeted = true
		_greet()
	if not has_passed and gap < -greet_distance:
		has_passed = true
		passed.emit()
	if gap < -vanish_behind:
		_tractor.queue_free()
		_tractor = null


func tractor() -> Sprite2D:
	return _tractor


func _start(player: Player) -> void:
	running = true
	player.lock(LOCK)
	_tractor = Sprite2D.new()
	_tractor.name = "Tractor"
	var path := CutscenePlayer.find_art(art)
	if not path.is_empty():
		_tractor.texture = load(path)
		_tractor.offset = Vector2(0.0, -_tractor.texture.get_height() * 0.5)
	_tractor.scale = Vector2(lane_scale, lane_scale)
	_tractor.z_index = -3  # 땅·물건 위, 하윤 뒤(먼 길가)
	_tractor.z_as_relative = false
	add_child(_tractor)
	_tractor.global_position = Vector2(player.global_position.x + spawn_ahead, global_position.y + lane_y)
	_engine = AudioStreamPlayer2D.new()
	_engine.name = "Engine"
	_engine.stream = SoundBank.pick(engine_sound) if not engine_sound.is_empty() else null
	_engine.bus = SoundBank.BUS_SFX
	_engine.max_distance = 2600.0
	_tractor.add_child(_engine)
	if _engine.stream:
		_engine.play()
	# 비켜선다: 길가로 몇 걸음 물러났다가 경운기 쪽을 본다.
	player.auto_move_to(player.global_position.x - step_aside, 140.0)
	await player.auto_arrived
	player.face(1)


func _greet() -> void:
	var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if box and not lines.is_empty():
		box.play(lines)
		await box.finished
	# 인사가 끝나면 바로 걷게 한다(#118). 경운기는 하윤 뒤 길가로 마저 지나간다.
	if not done_flag.is_empty():
		GameState.set_flag(done_flag)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.unlock(LOCK)
	running = false
	finished.emit()
