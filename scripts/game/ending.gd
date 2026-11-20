class_name EndingDirector
extends Node2D
## 나루터 엔딩 연출(장면표 7-3 ~ 7-5, 그리고 지금은 바로 제목 7-7).
## 나루터 씬에 B가 할아버지(Grandpa) 옆에 놓는다(이름 Ending_7-3). 하윤이 다섯째 동그라미를 체크한 뒤
## 할아버지에게 trigger_distance만큼 다가오면 시작한다. 시작하면 끝까지 하윤 조작을 막는다(잠금 이유 ending).
##
## 7-3 하윤이 달려가다 멈춘다 → 하늘이가 먼저 할아버지에게 간다 → "할아버지: 왔니."
## 7-4 손그림 컷신 1(팔찌): 팔찌 글씨 "이하윤 / 9세" → "하윤: …다섯 군데 다 봤어." "할아버지: 그래."
## 7-5 할아버지가 카메라를 든다, 하늘이가 하윤 발치에 앉는다, 셔터
## 7-6(배)·7-7(컷신 2)은 다음 단계. 지금은 사진 뒤 바로 하얗게 번지며 제목 "돌아가는 길".
## 담당: A(게임플레이). (A 세션이 쉬는 동안 B 세션이 만듦)

signal photo_taken
signal ended

const LOCK := &"ending"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

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
@export var title_text: String = "돌아가는 길"
## 끝나면 타이틀로 돌아간다(검사는 끈다).
@export var return_to_title: bool = true

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
	for hud in ["Overlay/PlaceLabel", "Overlay/Hint", "Overlay/MapHint"]:
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
	# 7-6·7-7은 다음 단계. 지금은 바로 제목.
	await _title_card()
	GameState.set_flag(&"ending_seen")
	ended.emit()
	if return_to_title:
		get_tree().change_scene_to_file(TITLE_SCENE)


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


## 7-7: 화면이 하얗게 번지고 제목이 뜬다.
func _title_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var white := ColorRect.new()
	white.color = Color(1, 0.99, 0.95, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(white)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.55, 0.46, 0.3, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.modulate.a = 0.0
	layer.add_child(title)
	await create_tween().tween_property(white, "color:a", 1.0, 3.0).finished
	await create_tween().tween_property(title, "modulate:a", 1.0, 2.0).finished
	await _wait(4.0)
