class_name PlaceCard
extends Control
## 장소 이름 카드. 장소에 들어서면 화면 가운데 위에 이름이 천천히 떴다가 사라진다(#87).
## 늘 떠 있던 장소 이름 글을 대신한다. 하윤이 조작할 수 있게 된 뒤에 뜬다(0-1 오프닝·장소 전환 페이드 위에 겹치지 않게).
## main이 장소를 갈아 끼울 때 show_place()를 부른다. 이름이 비어 있으면(강 위 구간) 안 뜬다.
## 담당: A(게임플레이).

const FADE_IN := 1.0
const HOLD := 2.4
const FADE_OUT := 1.4
## 하윤이 이만큼 기다려도 조작이 안 풀리면(긴 연출) 그냥 접는다.
const WAIT_LIMIT := 60.0

## 지금 떠 있는(또는 뜰 차례인) 장소 이름.
var shown_name: String = ""

var _title: Label
var _line: ColorRect
var _tween: Tween
## 새 장소가 오면 늘어난다. 기다리던 이전 카드는 이 값이 바뀌면 그만둔다.
var _serial: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = $Title
	_line = $Line
	modulate.a = 0.0
	visible = false


func show_place(display_name: String, player: Player) -> void:
	_serial += 1
	var serial := _serial
	if _tween:
		_tween.kill()
	visible = false
	modulate.a = 0.0
	shown_name = display_name
	if display_name.is_empty():
		return
	_title.text = display_name
	# 조작이 풀릴 때까지(페이드·오프닝) 기다린다
	var waited := 0.0
	while player and not player.controls_enabled:
		await get_tree().process_frame
		if serial != _serial or not is_inside_tree():
			return
		waited += get_process_delta_time()
		if waited > WAIT_LIMIT:
			return
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func(): visible = false)
