class_name MapChase
extends Node2D
## 장면표 2-3 "날아간 지도"(퍼즐 2): 바람이 세게 불어 지도가 하윤 손에서 날아간다.
## 억새 덤불 세 곳에 걸렸다 다시 날아가는 지도를 쫓고, 마지막 덤불에서 E로 줍는다.
## 장소 씬에 B가 놓는다(MapChase_2-3). 원점은 땅 위, 하윤이 여기를 지나면 바람이 분다.
## stops는 덤불 자리(이 노드 기준 x). 임시 배경의 덤불과 같다(tools/placeholder_art.py FIELD_SNAGS).
## 지도가 날아가 있는 동안에는 M이 먹지 않고(MapScreen.away), 마지막 덤불 오른쪽의 Gate_2-3이 막는다.
## 줍으면 grants_flag(map_caught)를 세운다. 이어하기는 장소 처음부터라 줍기 전이면 처음부터 다시 쫓는다.
## 담당: A(퍼즐 로직). (A 세션이 쉬는 동안 B 세션이 만듦)

## 바람이 불어 지도가 날아갔다.
signal blown_away
## 지도가 덤불 i(0부터)에 걸렸다.
signal snagged(i: int)
## 하윤이 지도를 주웠다.
signal caught

const LOCK := &"map_chase"

## 덤불 자리(이 노드 기준 x, 오른쪽으로). 마지막 덤불에서 줍는다.
@export var stops: PackedFloat32Array = PackedFloat32Array([700.0, 1600.0, 2500.0])
## 지도가 걸리는 높이(땅에서 위로, px). 억새 덤불 중간쯤.
@export var snag_height: float = 120.0
## 하윤이 덤불에 이만큼 다가가면 다시 날아간다(마지막 덤불 빼고).
@export var catch_distance: float = 260.0
## 한 번 날아가는 시간(초).
@export var flight_seconds: float = 1.8
## 지도 그림(assets/art 아래 이름). 접힌 지도 소품, 날아가는 지도도 이 그림이다(장면표 그림 목록).
@export var art: String = "prop_map_folded"
## 처음 날아갈 때 대사(장면표 2-3 "대사 3").
@export var lines: PackedStringArray = PackedStringArray(["하윤: 어? 기다려!"])
@export var grants_flag: StringName = &"map_caught"
## 지도를 가진 뒤에만 분다.
@export var requires_flag: StringName = &"has_map"
@export var gust_sound: String = "sfx_wind_gust_"
## 이 플래그가 서기 전에는 마지막 자리에 내려앉은 지도가 억새 속에 묻혀 안 보이고 줍지도 못한다(#111).
## 들판에서는 연 날리기(KiteFly)가 끝나면 서서(kite_flown) 지도가 반짝이며 보인다. 비우면 예전처럼 바로 줍는다.
@export var reveal_flag: StringName = &""
@export var pickup_sound: String = "sfx_paper_"

## 0 = 아직, 1 = 날아다니는 중, 2 = 주웠다(또는 이미 주운 채로 들어왔다).
enum State { WAITING, CHASING, DONE }
var state: State = State.WAITING
## 지금 지도가 걸려 있는(또는 날아가는) 덤불 번호. -1 = 하윤 손.
var stop_index: int = -1
var flying: bool = false
## 억새 속에 묻혀 안 보이는 중(reveal_flag 전).
var buried: bool = false

var _map: Sprite2D
var _pickup: Interactable
var _time: float = 0.0


func _ready() -> void:
	add_to_group("map_chase")
	if GameState.has_flag(grants_flag):
		state = State.DONE


## 지도가 걸릴 덤불의 전역 자리(땅 높이).
func stop_position(i: int) -> Vector2:
	return global_position + Vector2(stops[i], 0.0)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	match state:
		State.WAITING:
			if player.global_position.x >= global_position.x and _can_start():
				_start(player)
		State.CHASING:
			_time += delta
			if _map and not flying:  # 걸린 지도가 바람에 파르르 떤다
				_map.rotation = sin(_time * 7.0) * 0.12 + sin(_time * 2.3) * 0.08
			var last := stops.size() - 1
			if not flying and stop_index >= 0 and stop_index < last \
					and absf(player.global_position.x - stop_position(stop_index).x) < catch_distance:
				_fly_to(stop_index + 1)


func _can_start() -> bool:
	return requires_flag.is_empty() or GameState.has_flag(requires_flag)


func _map_screen() -> MapScreen:
	return get_tree().get_first_node_in_group("map_screen") as MapScreen


func _start(player: Player) -> void:
	state = State.CHASING
	var map := _map_screen()
	if map:
		map.away = true
	player.lock(LOCK)
	_map = Sprite2D.new()
	_map.name = "FlyingMap"
	var path := CutscenePlayer.find_art(art)
	if not path.is_empty():
		_map.texture = load(path)
	_map.z_index = 5  # 하윤 앞(날아오를 때 손에서 떠나는 게 보이게), 앞 층(억새) 뒤
	_map.z_as_relative = false
	add_child(_map)
	_map.global_position = player.global_position + Vector2(40.0 * player.facing, -150.0)
	blown_away.emit()
	_fly_to(0)
	var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if box and not lines.is_empty():
		box.play(lines)
		await box.finished
	player.unlock(LOCK)


func _fly_to(i: int) -> void:
	flying = true
	stop_index = i
	_play_sound(gust_sound)
	var from := _map.global_position
	var to := stop_position(i) + Vector2(0.0, -snag_height)
	# 바람에 높이 떴다가 덤불로 내려앉는다. 가는 동안 빙글빙글.
	var peak := minf(from.y, to.y) - 260.0
	var tween := create_tween()
	tween.tween_method(func(t: float):
		var u := 1.0 - t
		var ctrl := Vector2((from.x + to.x) * 0.5, peak)
		_map.global_position = from * u * u + ctrl * 2.0 * u * t + to * t * t \
				+ Vector2(0.0, sin(t * TAU * 2.0) * 18.0 * u)
		_map.rotation = t * TAU * 1.5 + sin(t * TAU * 3.0) * 0.4,
		0.0, 1.0, flight_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	flying = false
	snagged.emit(i)
	if i == stops.size() - 1:
		if reveal_flag.is_empty() or GameState.has_flag(reveal_flag):
			_offer_pickup()
		else:
			_hide_in_reeds()


## 억새 속으로 사라진다. reveal_flag가 서면 반짝이며 다시 보이고 줍을 수 있다.
func _hide_in_reeds() -> void:
	buried = true
	var tween := create_tween()
	tween.tween_property(_map, "modulate:a", 0.0, 0.6)
	if not GameState.flag_changed.is_connected(_on_flag_changed):
		GameState.flag_changed.connect(_on_flag_changed)


func _on_flag_changed(flag: StringName) -> void:
	if flag != reveal_flag or not buried or _map == null:
		return
	buried = false
	GameState.flag_changed.disconnect(_on_flag_changed)
	var glint := Sprite2D.new()
	glint.name = "Glint"
	var mote := CutscenePlayer.find_art("fx_light_mote")
	if not mote.is_empty():
		glint.texture = load(mote)
	glint.scale = Vector2(3.5, 3.5)
	glint.show_behind_parent = true
	_map.add_child(glint)
	var tween := create_tween()
	tween.tween_property(_map, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_property(glint, "scale", Vector2(2.2, 2.2), 1.2).set_trans(Tween.TRANS_SINE)
	_offer_pickup()


## 마지막 덤불: "[E] 지도 줍기". 조사 대상(Interactable)을 그 자리에 둔다.
func _offer_pickup() -> void:
	_pickup = Interactable.new()
	_pickup.name = "Pickup"
	_pickup.prompt = "지도 줍기"
	_pickup.one_shot = true
	_pickup.size = Vector2(320.0, 300.0)
	_pickup.sound = pickup_sound
	add_child(_pickup)
	_pickup.global_position = stop_position(stops.size() - 1)
	_pickup.interacted.connect(_on_picked)


func _on_picked() -> void:
	state = State.DONE
	if not grants_flag.is_empty():
		GameState.set_flag(grants_flag)
	var map := _map_screen()
	if map:
		map.away = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and _map:
		var tween := create_tween().set_parallel()
		tween.tween_property(_map, "global_position", player.global_position + Vector2(0.0, -150.0), 0.35)
		tween.tween_property(_map, "rotation", 0.0, 0.35)
		tween.tween_property(_map, "scale", Vector2(0.4, 0.4), 0.35)
		tween.chain().tween_callback(_map.queue_free)
	caught.emit()


func _exit_tree() -> void:
	# 쫓는 중에 장소를 떠나면(타이틀로 등) 지도 화면을 돌려 둔다.
	if state == State.CHASING:
		var map := _map_screen()
		if map:
			map.away = false


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
