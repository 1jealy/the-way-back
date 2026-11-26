class_name SteppingStones
extends Node2D
## 장면표 5-3 징검다리: "흔들리는 징검다리. 하늘이에게 부탁(기다려)하면 한쪽 돌을 버틴다. 하윤이 건너고 하늘이가 뛰어 따라온다."
## 돌을 배경에 그리지 않고 여기서 그린다(움직이려고). 진짜 그림이 오면 art로 돌 한 개 그림을 받는다.
## - 첫 돌(하늘이가 버티는 돌)은 버티기 전까지 기우뚱 흔들리고 둘레에 물결이 인다.
## - 하늘이가 버티는 동안(hold_flag) 그 돌은 가라앉아 멈추고, 발밑에 잔물결이 이따금 퍼진다.
## - 하윤이 돌을 밟으면 그 돌이 살짝 가라앉았다 올라오고(통통) 물결이 한 번 퍼지며 찰랑 소리가 난다.
## 장소 씬에 B가 놓는다(Stones_5-3, 원점은 징검다리 가운데 땅 위). 담당: B(연출).

signal stepped(i: int)

## 돌 자리(이 노드 기준 x). 첫 돌이 하늘이가 버티는 돌이다(AskSpot_5-3의 target과 같은 자리, 스모크 검사).
@export var stones: PackedFloat32Array = PackedFloat32Array([-420.0, -280.0, -140.0, 0.0, 140.0, 280.0, 420.0])
## 이 플래그가 서 있으면 첫 돌을 하늘이가 버티고 있다(AskSpot_5-3 grants_flag).
@export var hold_flag: StringName = &"river_stone_held"
## 돌 그림(assets/art 이름). 비우면 코드로 그린 회색 돌.
@export var art: String = ""
## 밟으면 가라앉는 깊이(px), 첫 돌이 흔들리는 각도(도).
@export var sink_depth: float = 7.0
@export var wobble_degrees: float = 6.0
@export var step_sound: String = "sfx_stone_skip_"
@export var step_volume_db: float = -14.0

const STONE_COLOR := Color(0.57, 0.565, 0.59)
const STONE_SHADE := Color(0.43, 0.42, 0.455)
const RIPPLE_COLOR := Color(0.86, 0.9, 0.96, 0.7)

var _stones: Array[Node2D] = []
var _sink: PackedFloat32Array = PackedFloat32Array()
var _on: int = -1
var _time: float = 0.0
var _ripple_left: float = 0.0


func _ready() -> void:
	add_to_group("stepping_stones")
	_sink.resize(stones.size())
	for i in stones.size():
		var s := _make_stone()
		s.name = "Stone%d" % i
		s.position = Vector2(stones[i], 0.0)
		add_child(s)
		_stones.append(s)


func is_held() -> bool:
	return not hold_flag.is_empty() and GameState.has_flag(hold_flag)


## 하윤이 지금 밟고 있는 돌 번호(없으면 -1).
func stone_under(x: float) -> int:
	for i in stones.size():
		if absf(x - (global_position.x + stones[i])) < 58.0:
			return i
	return -1


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var under := stone_under(player.global_position.x) if player else -1
	if under != _on:
		_on = under
		if under >= 0:
			_sink[under] = 1.0
			_ripple(_stones[under].position, 1.0)
			_play_sound(step_sound)
			stepped.emit(under)
	var held := is_held()
	for i in _stones.size():
		var s := _stones[i]
		# 밟힌 돌은 통통 가라앉았다 올라온다(밟고 서 있으면 조금 가라앉은 채로)
		var rest := 0.35 if i == _on else 0.0
		_sink[i] = move_toward(_sink[i], rest, delta * 2.2)
		var y := sink_depth * _sink[i]
		var rot := 0.0
		if i == 0:
			if held:
				y += sink_depth * 0.5  # 하늘이 무게로 가라앉아 멈춘다
			else:
				rot = deg_to_rad(wobble_degrees) * sin(_time * 3.1) * (0.7 + 0.3 * sin(_time * 1.3))
				y += 2.0 * sin(_time * 6.2)
		s.position.y = y
		s.rotation = rot
	# 첫 돌 둘레 물결: 흔들릴 때는 자주, 버틸 때는 이따금 작게(하늘이 발밑)
	_ripple_left -= delta
	if _ripple_left <= 0.0:
		_ripple(_stones[0].position, 0.5 if held else 0.8)
		_ripple_left = 2.4 if held else 0.9


## 돌 둘레로 퍼지며 옅어지는 물결 고리 하나.
func _ripple(at: Vector2, strength: float) -> void:
	var ring := Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(RIPPLE_COLOR, RIPPLE_COLOR.a * strength)
	ring.closed = true
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(Vector2(cos(a) * 58.0, sin(a) * 9.0))
	ring.points = pts
	ring.position = Vector2(at.x, 2.0)
	ring.z_index = -1
	add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector2(1.9, 1.9), 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 1.1)
	tween.chain().tween_callback(ring.queue_free)


func _make_stone() -> Node2D:
	var root := Node2D.new()
	root.z_index = -2  # 땅·물 위, 하윤·하늘이 뒤
	var path := CutscenePlayer.find_art(art) if not art.is_empty() else ""
	if not path.is_empty():
		var sp := Sprite2D.new()
		sp.texture = load(path)
		sp.offset = Vector2(0.0, -sp.texture.get_height() * 0.5 + 12.0)
		root.add_child(sp)
		return root
	root.add_child(_ellipse(Vector2(0.0, -3.0), Vector2(56.0, 15.0), STONE_SHADE))
	root.add_child(_ellipse(Vector2(0.0, -10.0), Vector2(50.0, 10.0), STONE_COLOR))
	return root


static func _ellipse(center: Vector2, radius: Vector2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	poly.polygon = pts
	poly.color = color
	return poly


func _play_sound(prefix: String) -> void:
	var stream := SoundBank.pick(prefix) if not prefix.is_empty() else null
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = SoundBank.BUS_SFX
	p.volume_db = step_volume_db
	p.pitch_scale = randf_range(0.75, 0.9)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
