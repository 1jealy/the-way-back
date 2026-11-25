class_name MapChase
extends Node2D
## 장면표 2-3 "날아간 지도"(퍼즐 2). 바람이 세게 불어 지도가 하윤 손에서 날아가 멀리 억새 속으로 사라진다.
## 어디 떨어졌는지 보이지 않는다. 할아버지 방패연을 주워 날리면(KiteFlight, reveal_flag kite_flown)
## 지도가 떨어진 억새 위로 빛이 내리고, 거기서 E로 지도를 줍는다.
## 장소 씬에 B가 놓는다(MapChase_2-3). 원점은 땅 위, 하윤이 여기를 지나면 바람이 분다.
## lost_at은 지도가 떨어지는 억새 덤불 자리(이 노드 기준 x). 임시 배경의 덤불과 같다(tools/placeholder_art.py FIELD_SNAGS).
## 지도가 없는 동안에는 M이 먹지 않고(MapScreen.away), 덤불 오른쪽의 Gate_2-3이 막는다.
## 주우면 grants_flag(map_caught). 이어하기는 장소 처음부터라 줍기 전이면 처음부터 다시 날아간다.
## 담당: A(퍼즐 로직). (A 대신 B 세션이 만듦)

## 바람이 불어 지도가 날아갔다.
signal blown_away
## 지도가 억새 속으로 사라졌다.
signal lost
## 연을 날려 지도 자리가 보인다.
signal revealed
## 하윤이 지도를 주웠다.
signal caught

const LOCK := &"map_chase"

## 지도가 떨어지는 억새 덤불 자리(이 노드 기준 x). 하윤이 연을 날리는 자리에서 화면 안에 보여야 한다.
@export var lost_at: float = 2000.0
## 한 번 날아가는 시간(초).
@export var flight_seconds: float = 2.4
## 지도 그림(assets/art 아래 이름). 접힌 지도 소품.
@export var art: String = "prop_map_folded"
## 처음 날아갈 때 대사(장면표 2-3 "대사 3").
@export var lines: PackedStringArray = PackedStringArray(["하윤: 어? 기다려!"])
@export var grants_flag: StringName = &"map_caught"
## 지도를 가진 뒤에만 분다.
@export var requires_flag: StringName = &"has_map"
## 이 플래그가 서면 지도 자리가 빛으로 보인다(연 날리기 KiteFlight가 세운다).
@export var reveal_flag: StringName = &"kite_flown"
@export var gust_sound: String = "sfx_wind_gust_"
@export var pickup_sound: String = "sfx_paper_"

enum State { WAITING, FLYING, LOST, REVEALED, DONE }
var state: State = State.WAITING

var _map: Sprite2D
var _beam: Sprite2D
var _pickup: Interactable


func _ready() -> void:
	add_to_group("map_chase")
	if GameState.has_flag(grants_flag):
		state = State.DONE
	GameState.flag_changed.connect(_on_flag_changed)


## 지도가 떨어진 자리(전역, 땅 높이).
func lost_position() -> Vector2:
	return global_position + Vector2(lost_at, 0.0)


func _process(_delta: float) -> void:
	if state != State.WAITING:
		if _beam:
			_beam.modulate.a = 0.75 + 0.2 * sin(Time.get_ticks_msec() / 1000.0 * 1.8)
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.global_position.x >= global_position.x and _can_start():
		_start(player)


func _can_start() -> bool:
	return requires_flag.is_empty() or GameState.has_flag(requires_flag)


func _map_screen() -> MapScreen:
	return get_tree().get_first_node_in_group("map_screen") as MapScreen


func _start(player: Player) -> void:
	state = State.FLYING
	var map := _map_screen()
	if map:
		map.away = true
	player.lock(LOCK)
	_map = Sprite2D.new()
	_map.name = "FlyingMap"
	var path := CutscenePlayer.find_art(art)
	if not path.is_empty():
		_map.texture = load(path)
	_map.z_index = 5  # 하윤 앞(손에서 떠나는 게 보이게), 앞 층(억새) 뒤
	_map.z_as_relative = false
	add_child(_map)
	_map.global_position = player.global_position + Vector2(40.0 * player.facing, -150.0)
	blown_away.emit()
	_play_sound(gust_sound)
	_fly_away()
	var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if box and not lines.is_empty():
		box.play(lines)
		await box.finished
	player.unlock(LOCK)


## 높이 떠올라 오른쪽으로 멀리 날아가다 억새 속으로 내려앉으며 사라진다.
func _fly_away() -> void:
	var from := _map.global_position
	var to := lost_position() + Vector2(0.0, -40.0)
	var peak := minf(from.y, to.y) - 380.0
	var tween := create_tween()
	tween.tween_method(func(t: float):
		var u := 1.0 - t
		var ctrl := Vector2((from.x + to.x) * 0.5, peak)
		_map.global_position = from * u * u + ctrl * 2.0 * u * t + to * t * t \
				+ Vector2(0.0, sin(t * TAU * 2.0) * 22.0 * u)
		_map.rotation = t * TAU * 2.0 + sin(t * TAU * 3.0) * 0.4,
		0.0, 1.0, flight_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_map, "scale", Vector2(0.7, 0.7), flight_seconds)
	tween.tween_property(_map, "modulate:a", 0.0, 0.5)
	await tween.finished
	_map.visible = false
	if state == State.FLYING:
		state = State.LOST
	lost.emit()
	if GameState.has_flag(reveal_flag):
		_reveal()


func _on_flag_changed(flag: StringName) -> void:
	if flag == reveal_flag and state == State.LOST:
		_reveal()


## 연을 날렸다: 지도가 떨어진 억새 위로 빛이 내리고 종이 끝이 보인다. "[E] 지도 줍기".
func _reveal() -> void:
	if state != State.LOST:
		return
	state = State.REVEALED
	_beam = Sprite2D.new()
	_beam.name = "Beam"
	_beam.texture = _beam_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = mat
	_beam.z_index = 6
	_beam.z_as_relative = false
	_beam.scale = Vector2(240.0 / 64.0, 1000.0 / 64.0)  # 화면 위 바깥에서 억새까지
	add_child(_beam)
	_beam.global_position = lost_position() + Vector2(0.0, -490.0)
	_beam.modulate = Color(1.0, 0.9, 0.7, 0.0)
	create_tween().tween_property(_beam, "modulate:a", 0.85, 1.2)
	# 억새 사이로 종이 끝이 살짝 보인다
	_map.visible = true
	_map.global_position = lost_position() + Vector2(0.0, -30.0)
	_map.rotation = -0.5
	_map.scale = Vector2(0.75, 0.75)
	_map.z_index = 6
	create_tween().tween_property(_map, "modulate:a", 1.0, 1.2)
	revealed.emit()
	_offer_pickup()


func _offer_pickup() -> void:
	_pickup = Interactable.new()
	_pickup.name = "Pickup"
	_pickup.prompt = "지도 줍기"
	_pickup.one_shot = true
	_pickup.size = Vector2(320.0, 300.0)
	_pickup.sound = pickup_sound
	add_child(_pickup)
	_pickup.global_position = lost_position()
	_pickup.interacted.connect(_on_picked)


func _on_picked() -> void:
	state = State.DONE
	if not grants_flag.is_empty():
		GameState.set_flag(grants_flag)
	var map := _map_screen()
	if map:
		map.away = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if _beam:
		var fade := create_tween()
		fade.tween_property(_beam, "modulate:a", 0.0, 0.8)
		fade.tween_callback(_beam.queue_free)
		_beam = null
	if player and _map:
		var tween := create_tween().set_parallel()
		tween.tween_property(_map, "global_position", player.global_position + Vector2(0.0, -150.0), 0.35)
		tween.tween_property(_map, "rotation", 0.0, 0.35)
		tween.tween_property(_map, "scale", Vector2(0.4, 0.4), 0.35)
		tween.chain().tween_callback(_map.queue_free)
	caught.emit()


func _exit_tree() -> void:
	# 지도가 없는 채로 장소를 떠나면(타이틀로 등) 지도 화면을 돌려 둔다.
	if state in [State.FLYING, State.LOST, State.REVEALED]:
		var map := _map_screen()
		if map:
			map.away = false


## 위에서 내리는 빛기둥(가운데가 밝고 양옆·위로 사라진다).
static func _beam_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _play_sound(prefix: String) -> void:
	var stream := SoundBank.pick(prefix) if not prefix.is_empty() else null
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = SoundBank.BUS_SFX
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
