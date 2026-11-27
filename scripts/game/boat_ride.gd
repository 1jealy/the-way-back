class_name BoatRide
extends Node2D
## 장면표 7-6 ~ 7-7: 셋이 탄 나룻배가 저절로 오른쪽으로 흘러간다(조작 없음).
## 강 건너 안개 속에 지나온 장소(집, 들판, 간이역, 숲, 강가)가 차례로 희미하게 비쳤다 사라지고,
## 물에 비친 셋은 이번엔 또렷하다(5-2와 짝). 하윤이 손을 뻗어 물을 한 번 만진다.
## 휘파람 선율이 처음으로 끝까지 흐른다 → 손그림 컷신 2(나룻배가 빛 속으로) → 제목 → 타이틀.
## 강 위 구간 씬(crossing)에 B가 놓는다(BoatRide_7-6). 원점 = 배가 떠나는 자리(물 위, y = 810).
## 담당: A(게임플레이). (A 세션이 쉬는 동안 B 세션이 만듦)

signal ended

const LOCK := &"ending"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const GHOST_PLACES := ["house", "field", "station", "forest", "riverside"]
const GHOST_SHADER := preload("res://shaders/ghost.gdshader")

## 배가 흘러가는 거리(px)와 시간(초). 장면표 7-6: 1:10.
@export var distance: float = 5400.0
@export var ride_seconds: float = 42.0
## 지나온 장소가 비치는 자리: 강 건너편(그림 아래 끝이 이 y, 장소 좌표)과 크기.
@export var ghost_bottom_y: float = 650.0
@export var ghost_scale: float = 0.42
## 하윤이 물을 만지는 때(0~1).
@export var touch_at: float = 0.62
@export var music: String = "mus_theme_full"
@export var cut2_art: String = "cut_boat"
@export var title_text: String = "돌아가는 길"
## 끝나면 타이틀로(검사는 끈다).
@export var return_to_title: bool = true
## 7-8 영정사진: 크기, 하윤 사진이 또렷해지는 시간(초).
@export var portrait_scale: float = 1.6
@export var portrait_reveal_seconds: float = 4.0

## 7-8 영정사진에서 하윤 사진이 다 또렷해졌다.
signal portraits_shown
var portraits_revealed: bool = false

var progress: float = 0.0
var ghosts_shown: int = 0
var touched: bool = false
var _boat: Node2D
var _player: Player
var _dog: Dog
var _grandpa: Node2D
var _started: bool = false


func _ready() -> void:
	add_to_group("boat_ride")
	_boat = _make_boat()
	add_child(_boat)
	_start.call_deferred()


func _start() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_dog = get_tree().get_first_node_in_group("dog") as Dog
	_grandpa = get_tree().get_first_node_in_group("grandpa") as Node2D
	if _player == null:
		return
	_player.lock(LOCK)
	_hide_hud()
	if _dog and _dog.is_joined():
		_dog.script_move_to(_dog.global_position.x)  # 멈춰 앉힌다(뱃머리)
	_player.set_pose(&"sit_floor")  # 배 위에 앉은 자세
	_make_reflections()
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("play_music"):
		main.play_music(music, -4.0, 3.0, true)  # 7-6: 처음으로 처음부터 끝까지
	_started = true
	_run()


## 배 위 자리(배 기준 x). 인물이 1.5배가 되어 넓혔다.
const SEAT_PLAYER := -20.0
const SEAT_GRANDPA := -190.0
const SEAT_DOG := 200.0


func _process(_delta: float) -> void:
	if not _started:
		return
	_boat.position.x = distance * progress
	var bx := _boat.global_position.x
	_player.global_position = Vector2(bx + SEAT_PLAYER, 810.0)
	_player.velocity = Vector2.ZERO
	if _grandpa:
		_grandpa.global_position = Vector2(bx + SEAT_GRANDPA, 810.0)
	if _dog and _dog.is_joined():
		_dog.global_position = Vector2(bx + SEAT_DOG, 810.0)
		_dog.velocity = Vector2.ZERO


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _run() -> void:
	var ride := create_tween()
	ride.tween_property(self, "progress", 1.0, ride_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 지나온 장소가 차례로 비친다
	for i in GHOST_PLACES.size():
		_show_ghost_later(GHOST_PLACES[i], ride_seconds * (0.08 + 0.16 * i))
	_touch_water_later(ride_seconds * touch_at)
	await ride.finished
	# 7-7 손그림 컷신 2: 나룻배가 빛 속으로, 하얗게 번진다
	var cut := CutscenePlayer.new()
	add_child(cut)
	cut.play({"art": cut2_art, "seconds": 6.0, "zoom": Vector2(1.0, 1.25), "pan": [Vector2.ZERO, Vector2(-120, 30)], "white_out": true})
	await cut.finished
	await _title_card()
	await _portraits_card()
	GameState.set_flag(&"ending_seen")
	# 끝까지 봤으면 이어하기를 지운다(남겨 두면 나루터부터 엔딩이 다시 나온다, #107).
	if GameState.autosave:
		GameState.delete_save()
	ended.emit()
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("stop_music"):
		await main.stop_music(3.0)
	if return_to_title:
		get_tree().change_scene_to_file(TITLE_SCENE)


func _show_ghost_later(place_id: String, at: float) -> void:
	await _wait(at)
	var path := CutscenePlayer.find_art("bg_%s_mid" % place_id)
	if path.is_empty():
		return
	var ghost := Sprite2D.new()
	ghost.name = "Ghost_%s" % place_id
	ghost.texture = load(path)
	ghost.centered = false
	ghost.region_enabled = true
	ghost.region_rect = Rect2(0, 0, 1920, 1080)
	ghost.scale = Vector2.ONE * ghost_scale
	var mat := ShaderMaterial.new()
	mat.shader = GHOST_SHADER
	var size := ghost.texture.get_size()
	mat.set_shader_parameter("uv_rect", Vector4(0.0, 0.0, minf(1920.0 / size.x, 1.0), minf(1080.0 / size.y, 1.0)))
	ghost.material = mat
	ghost.z_index = -25  # 먼 산(-30)과 강물(-20) 사이: 강 건너편 안개 속
	get_parent().add_child(ghost)
	# 배보다 조금 앞(오른쪽) 강 건너에 떠올라, 배가 지나가는 동안 천천히 뒤로 밀려난다
	var cam_x := _player.global_position.x
	ghost.global_position = Vector2(cam_x + 60.0, ghost_bottom_y - 1080.0 * ghost_scale)
	ghosts_shown += 1
	var t := create_tween()
	t.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 0.0, 1.0, 3.0)
	t.tween_interval(3.0)
	t.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 4.0)
	t.tween_callback(ghost.queue_free)


func _touch_water_later(at: float) -> void:
	await _wait(at)
	touched = true
	_player.set_pose(&"crouch")  # 몸을 숙여 물을 만진다
	var ripple := Line2D.new()
	ripple.width = 3.0
	ripple.default_color = Color(1, 1, 1, 0.8)
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		pts.append(Vector2(cos(a) * 30.0, sin(a) * 8.0))
	ripple.points = pts
	_boat.add_child(ripple)
	ripple.position = Vector2(60.0, 40.0)
	var t := create_tween().set_parallel()
	t.tween_property(ripple, "scale", Vector2(4.0, 4.0), 2.5)
	t.tween_property(ripple, "modulate:a", 0.0, 2.5)
	await t.finished
	ripple.queue_free()
	if _player and _player.is_inside_tree():
		_player.set_pose(&"sit_floor")



func _make_boat() -> Node2D:
	var boat := Node2D.new()
	boat.name = "Boat"
	var hull := Polygon2D.new()
	hull.color = Color(0.58, 0.45, 0.32)
	hull.polygon = PackedVector2Array([Vector2(-340, -6), Vector2(350, -12), Vector2(280, 46), Vector2(-270, 48)])
	boat.add_child(hull)
	var rim := Polygon2D.new()
	rim.color = Color(0.78, 0.66, 0.5)
	rim.polygon = PackedVector2Array([Vector2(-340, -10), Vector2(350, -16), Vector2(350, -6), Vector2(-340, 0)])
	boat.add_child(rim)
	return boat


## 물에 비친 셋(과 배): 이번엔 또렷하게. 회색 네모 단계라 모습을 아래로 뒤집어 복사한다.
func _make_reflections() -> void:
	var water := Node2D.new()
	water.name = "Reflections"
	water.position = Vector2(0, 44)
	water.scale = Vector2(1, -1)
	water.modulate = Color(0.85, 0.9, 1.0, 0.55)
	_boat.add_child(water)
	for pair in [[_player, SEAT_PLAYER], [_grandpa, SEAT_GRANDPA], [_dog, SEAT_DOG]]:
		var who: Node = pair[0]
		if who == null or not (who as CanvasItem).visible:
			continue
		var vis := who.get_node_or_null("Visual")
		if vis == null:
			continue
		var copy: Node2D = vis.duplicate(0)  # 모습만(스크립트까지 복사하면 하윤 컷아웃이 조각을 한 번 더 붙인다)
		copy.position = Vector2(pair[1], 44)
		water.add_child(copy)
	var hull_copy: Node2D = _boat.get_child(0).duplicate()
	water.add_child(hull_copy)


func _hide_hud() -> void:
	var main := get_tree().get_first_node_in_group("main")
	for hud in ["Overlay/PlaceCard", "Overlay/WalkHint", "Overlay/MapHint", "Overlay/Vignette"]:
		var n := main.get_node_or_null(hud) as CanvasItem if main else null
		if n:
			n.visible = false


## 7-8: 하얀 화면에 1-2의 영정사진 두 개가 다시 비치고, 흐렸던 하윤 사진이 천천히 또렷해진다. 소리 없이.
func _portraits_card() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Portraits"
	layer.layer = 31
	add_child(layer)
	var white := ColorRect.new()
	white.color = Color(1, 0.99, 0.95, 1)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(white)
	var row := Control.new()
	row.modulate.a = 0.0
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(row)
	var hayun_mat := FuneralPortraits.blurred_material(1.0)
	for pair in [[FuneralPortraits.ART_GRANDPA, -170.0, null], [FuneralPortraits.ART_HAYUN, 170.0, hayun_mat]]:
		var path := CutscenePlayer.find_art(pair[0])
		if path.is_empty():
			continue
		var tex := TextureRect.new()
		tex.name = pair[0]
		tex.texture = load(path)
		tex.size = tex.texture.get_size() * portrait_scale
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.position = Vector2(960.0 + pair[1], 540.0) - tex.size * 0.5
		if pair[2]:
			tex.material = pair[2]
		row.add_child(tex)
	await create_tween().tween_property(row, "modulate:a", 1.0, 2.0).finished
	await _wait(1.5)
	await create_tween().tween_method(func(v: float): hayun_mat.set_shader_parameter("amount", v), 1.0, 0.0, portrait_reveal_seconds) \
			.set_trans(Tween.TRANS_SINE).finished
	portraits_revealed = true
	portraits_shown.emit()
	await _wait(3.0)
	await create_tween().tween_property(row, "modulate:a", 0.0, 2.0).finished


## 7-7: 화면이 하얗게 번진 채 제목이 뜬다.
func _title_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var white := ColorRect.new()
	white.color = Color(1, 0.99, 0.95, 1)
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
	await create_tween().tween_property(title, "modulate:a", 1.0, 2.5).finished
	await _wait(5.0)
