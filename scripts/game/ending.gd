class_name EndingDirector
extends Node2D
## 나루터 엔딩 연출(장면표 7-3 ~ 7-5). 사진 뒤 강 위 구간으로 넘긴다.
## 나루터 씬에 B가 할아버지(Grandpa) 옆에 놓는다(이름 Ending_7-3). 하윤이 다섯째 동그라미를 체크한 뒤
## 할아버지에게 trigger_distance만큼 다가오면 시작한다. 시작하면 끝까지 하윤 조작을 막는다(잠금 이유 ending).
##
## 7-3 하윤이 달려가다 멈춘다 → 하늘이가 먼저 할아버지에게 간다 → "할아버지: 왔니."
## 7-4 손그림 컷신 1(팔찌): 팔찌 글씨 "이하윤 / 9세" → "하윤: …다섯 군데 다 봤어." "할아버지: 그래."
## 7-5 할아버지가 카메라를 든다, 하늘이가 하윤 발치에 앉는다, 셔터
## 7-6 배 건너기·7-7 컷신 2·제목은 강 위 구간 씬의 BoatRide(scripts/game/boat_ride.gd)가 이어서 한다.
## 담당: A(게임플레이). (A 세션이 쉬는 동안 B 세션이 만듦)

signal photo_taken
signal ended

const LOCK := &"ending"

@export var start_flag: StringName = &"map_circle_5"
## 하윤이 할아버지에게 이만큼 다가오면 시작한다(px).
@export var trigger_distance: float = 380.0
## 달려가다 멈추는 자리: 할아버지 앞 이만큼(px).
@export var run_stop_gap: float = 300.0
@export var greeting: PackedStringArray = PackedStringArray(["할아버지: 왔니."])
@export var cut1_art: String = "cut_bracelet"
@export var cut1_lines: PackedStringArray = PackedStringArray(["하윤: …다섯 군데 다 봤어.", "할아버지: 그래."])
@export var bracelet_text: String = "이하윤 / 9세"
## 팔찌 글씨 자리(컷신 그림 좌표 1920x1080).
@export var bracelet_text_pos: Vector2 = Vector2(852.0, 616.0)
## 사진 뒤 넘어가는 강 위 구간(7-6). 그다음(컷신 2·제목·타이틀)은 그 씬의 BoatRide가 한다.
@export_file("*.tscn") var crossing_scene: String = "res://scenes/places/crossing.tscn"

var started: bool = false
var _player: Player
var _dog: Dog
var _grandpa: Grandpa


func _ready() -> void:
	add_to_group("ending")


func _physics_process(_delta: float) -> void:
	if started or not GameState.has_flag(start_flag):
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		_dog = get_tree().get_first_node_in_group("dog") as Dog
		_grandpa = get_tree().get_first_node_in_group("grandpa") as Grandpa
	if _player == null or _grandpa == null or not _player.controls_enabled:
		return
	if absf(_player.global_position.x - _grandpa.global_position.x) <= trigger_distance:
		started = true
		_run()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _run() -> void:
	_player.lock(LOCK)
	var main := get_tree().get_first_node_in_group("main")
	for hud in ["Overlay/PlaceCard", "Overlay/WalkHint", "Overlay/MapHint"]:
		var n := main.get_node_or_null(hud) as CanvasItem if main else null
		if n:
			n.visible = false
	var gx := _grandpa.global_position.x
	# 7-3 달려가다 멈춘다
	_player.auto_move_to(gx - run_stop_gap, _player.walk_speed * 1.8)
	await _player.auto_arrived
	await _wait(0.8)
	# 하늘이가 먼저 할아버지에게
	if _dog and _dog.is_joined():
		_dog.script_move_to(gx - 80.0)
		await _dog.script_arrived
	await _say(greeting)
	# 7-4 손그림 컷신 1
	var cut := CutscenePlayer.new()
	add_child(cut)
	cut.play({
		"art": cut1_art, "seconds": 7.0, "zoom": Vector2(1.0, 1.12),
		"pan": [Vector2(40, 10), Vector2(-30, -20)],
		"texts": [{"text": bracelet_text, "pos": bracelet_text_pos, "size": 27, "color": Color(0.25, 0.27, 0.35), "rotation": -0.12}],
		"lines": cut1_lines,
	})
	await cut.finished
	# 7-5 마지막 사진
	if _dog and _dog.is_joined():
		_dog.script_move_to(_player.global_position.x + 70.0)
		await _dog.script_arrived
	_grandpa.raise_camera()
	await _wait(1.2)
	await _shutter()
	GameState.set_flag(&"ending_photo")
	photo_taken.emit()
	await _wait(1.5)
	_grandpa.lower_camera()
	# 7-6 셋이 나룻배에 오른다 → 강 위 구간(crossing)의 BoatRide가 이어받는다.
	ended.emit()
	if main and not crossing_scene.is_empty():
		main.go_to(crossing_scene)


func _say(lines: PackedStringArray) -> void:
	var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if box and not lines.is_empty():
		box.play(lines)
		await box.finished


func _shutter() -> void:
	var stream := SoundBank.pick("sfx_shutter_")
	if stream:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = SoundBank.BUS_SFX
		add_child(p)
		p.play()
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	await create_tween().tween_property(flash, "color:a", 0.0, 0.7).finished
	layer.queue_free()
