class_name MapScreen
extends Control
## 지도 화면. M으로 펼치고 M / E / Esc로 접는다. 펼친 동안 하윤은 멈춘다.
## 조사 대상의 map_circle로 열면 펼친 뒤 그 동그라미에 체크를 긋는다. 담당: A(게임플레이).

signal opened
signal closed
signal circle_checked(n: int)

const LOCK := &"map"
const UNFOLD_SECONDS := 0.35
const CHECK_SECONDS := 0.5

var _open: bool = false
## 펼치기·접기·체크 연출 중에는 접지 않는다.
var _busy: bool = false

@onready var _paper: Control = $Paper
@onready var _canvas: MapCanvas = $Paper/Canvas


func _ready() -> void:
	add_to_group("map_screen")
	hide()


func is_open() -> bool:
	return _open


func canvas() -> MapCanvas:
	return _canvas


func can_open() -> bool:
	if _open or not GameState.has_flag(MapData.HAS_MAP_FLAG):
		return false
	var player := _player()
	return player != null and player.controls_enabled


## 지도를 펼친다. check_circle(1~5)을 주면 펼친 뒤 그 동그라미에 체크를 긋는다.
func open(check_circle: int = 0) -> void:
	if _open:
		return
	_open = true
	_busy = true
	var player := _player()
	if player:
		player.lock(LOCK)
	_canvas.progress = _current_progress()
	for n in range(1, MapData.CIRCLES.size() + 1):
		_canvas.set_check(n, 1.0 if GameState.has_flag(MapData.circle_flag(n)) else 0.0)
	show()
	_paper.pivot_offset = _paper.size * 0.5
	_paper.scale = Vector2(0.08, 1.0)
	modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_paper, "scale:x", 1.0, UNFOLD_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, UNFOLD_SECONDS * 0.6)
	await tween.finished
	opened.emit()
	if check_circle > 0 and not GameState.has_flag(MapData.circle_flag(check_circle)):
		GameState.set_flag(MapData.circle_flag(check_circle))
		var check := create_tween()
		check.tween_method(func(t: float): _canvas.set_check(check_circle, t), 0.0, 1.0, CHECK_SECONDS)
		await check.finished
		circle_checked.emit(check_circle)
	_busy = false


func close() -> void:
	if not _open or _busy:
		return
	_busy = true
	var tween := create_tween().set_parallel()
	tween.tween_property(_paper, "scale:x", 0.08, UNFOLD_SECONDS * 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, UNFOLD_SECONDS * 0.8)
	await tween.finished
	hide()
	_open = false
	_busy = false
	var player := _player()
	if player:
		player.unlock(LOCK)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("open_map"):
		return
	if _open:
		get_viewport().set_input_as_handled()
		close()
	elif can_open():
		get_viewport().set_input_as_handled()
		open()


func _input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


## 하윤이 지나온 정도: 지금 장소의 순번 + 그 장소 안에서 간 비율.
func _current_progress() -> float:
	var player := _player()
	var place := get_tree().get_first_node_in_group("place") as Place
	if player == null or place == null:
		return 0.0
	var i := MapData.place_index(place.place_id)
	if i < 0:
		return 0.0
	if i >= MapData.PLACES.size() - 1:
		return float(i)
	return float(i) + clampf(player.global_position.x / place.width, 0.0, 1.0)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
