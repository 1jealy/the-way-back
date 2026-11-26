class_name AlbumView
extends CanvasLayer
## 장면표 1-3 "앨범": 마루의 사진 앨범을 세 쪽 넘긴다. 펼친 앨범 그림 한 장(쪽 수만큼 가로로 나뉜)을
## 화면 가운데에 크게 띄우고, 한 쪽씩 가운데로 옮겨 보여 준다. 옆 쪽은 어둡게 살짝 보인다.
## E 또는 → 로 다음 쪽, ← 로 앞 쪽. 마지막 쪽에서 E(→)를 누르면 덮는다(신호 finished).
## Esc도 덮는다(일시정지 메뉴보다 먼저 가져간다 — 지도와 같은 방식).
## 조사 대상(Interactable)의 album_art가 있으면 조사할 때 이걸 띄우고, 덮은 뒤에 lines가 나온다.
## 대사 상자(Overlay, 층 10)보다 아래 층. 담당: A(게임플레이). (A 대신 B 세션이 만듦)

signal page_changed(i: int)
signal finished

const LAYER := 5
const LOCK := &"album"
## 쪽 하나가 화면에서 차지하는 높이(px).
const PAGE_HEIGHT := 900.0

## 펼친 앨범 그림의 쪽 수(그림 폭을 이만큼으로 나눈다).
var pages: int = 3
var page: int = 0
var is_open: bool = false

var _root: Control
var _art: TextureRect
var _page_w: float = 0.0
var _player: Node


func play(art: String, page_count: int = 3) -> void:
	layer = LAYER
	pages = maxi(1, page_count)
	var path := CutscenePlayer.find_art(art)
	if path.is_empty():
		push_warning("앨범 그림이 없다: %s" % art)
		finished.emit.call_deferred()
		queue_free.call_deferred()
		return
	var tex: Texture2D = load(path)
	var s := PAGE_HEIGHT / float(tex.get_height())
	var size := Vector2(tex.get_width(), tex.get_height()) * s
	_page_w = size.x / pages

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)
	var back := ColorRect.new()
	back.color = Color(0.06, 0.05, 0.04, 0.82)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	_art = TextureRect.new()
	_art.texture = tex
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.size = size
	_art.position = Vector2(_x_for(0), (1080.0 - size.y) * 0.5)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art)
	# 가운데 쪽만 밝게: 양옆을 어둡게 덮는다(쪽 경계에 맞춰 고정)
	for side in [-1, 1]:
		var shade := ColorRect.new()
		shade.color = Color(0.0, 0.0, 0.0, 0.5)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.size = Vector2((1920.0 - _page_w) * 0.5, 1080.0)
		shade.position = Vector2(0.0 if side < 0 else (1920.0 + _page_w) * 0.5, 0.0)
		_root.add_child(shade)

	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.has_method("lock"):
		_player.lock(LOCK)
	page = 0
	is_open = true
	_play_sound("sfx_paper_")
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.5)
	page_changed.emit(page)


## 쪽 i가 화면 가운데에 오는 그림 x.
func _x_for(i: int) -> float:
	return 960.0 - _page_w * (i + 0.5)


func turn(delta: int) -> void:
	if not is_open:
		return
	var next := page + delta
	if next < 0:
		return
	if next >= pages:
		close()
		return
	page = next
	_play_sound("sfx_paper_")
	create_tween().tween_property(_art, "position:x", _x_for(page), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	page_changed.emit(page)


func close() -> void:
	if not is_open:
		return
	is_open = false
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.4)
	await tween.finished
	if _player and is_instance_valid(_player):
		_player.unlock(LOCK)
	finished.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		turn(1)
	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		turn(-1)
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _exit_tree() -> void:
	if is_open and _player and is_instance_valid(_player):
		_player.unlock(LOCK)


func _play_sound(prefix: String) -> void:
	var stream := SoundBank.pick(prefix)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = SoundBank.BUS_SFX
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
