class_name OpeningScene
extends Node
## 장면표 0-1 오프닝: 손그림 컷신 0(사고 뒤 비 오는 밤 길가, 떨어진 할아버지의 모자와 카메라. 사람은 없다).
## 빗소리만 들리다 어두워지고, 집(1-1)에서 하윤이 몸을 일으킨다.
## 타이틀의 "처음부터"로 시작할 때만 나온다(GameState.opening_pending). 이어하기·검사에는 없다.
## 장소 씬에 B가 놓는다(Opening_0-1, 집). 담당: B(컷신). (A 세션이 쉬는 동안 B 세션이 만듦)

signal finished

const LOCK := &"opening"

@export var art: String = "cut_accident"
@export var seconds: float = 9.0
@export var rain_sound: String = "sfx_rain_"
@export var rain_db: float = -6.0
@export var done_flag: StringName = &"opening_seen"

var playing: bool = false
var _cover: CanvasLayer


func _ready() -> void:
	if not GameState.opening_pending:
		return
	GameState.opening_pending = false
	playing = true
	# 집이 비치기 전에 바로 덮는다(main이 화면을 밝히는 동안 집이 잠깐 보이지 않게)
	_cover = CanvasLayer.new()
	_cover.layer = 4  # 컷신(5) 아래
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(black)
	add_child(_cover)
	_run.call_deferred()


func _run() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.lock(LOCK)
		player.set_crouching(true)  # 마루에 누워(앉아) 있다
	var rain := AudioStreamPlayer.new()
	rain.stream = SoundBank.pick(rain_sound) if not rain_sound.is_empty() else null
	rain.bus = SoundBank.BUS_SFX
	rain.volume_db = rain_db
	add_child(rain)
	if rain.stream:
		rain.play()
	var cut := CutscenePlayer.new()
	add_child(cut)
	cut.play({"art": art, "seconds": seconds, "zoom": Vector2(1.0, 1.06), "pan": [Vector2(0, -10), Vector2(-40, 10)]})
	await cut.finished
	if rain.playing:
		await create_tween().tween_property(rain, "volume_db", -60.0, 1.5).finished
	rain.queue_free()
	# 1-1 깨어남: 어둠이 걷히고 하윤이 몸을 일으킨다
	var black := _cover.get_node("Black") as ColorRect
	await create_tween().tween_property(black, "color:a", 0.0, 2.0).finished
	_cover.queue_free()
	if player:
		await get_tree().create_timer(0.8, false).timeout
		player.set_crouching(false)
		player.unlock(LOCK)
	if not done_flag.is_empty():
		GameState.set_flag(done_flag)
	playing = false
	finished.emit()
