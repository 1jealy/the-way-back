class_name StoneSkip
extends Node2D
## 장면표 5-4 물수제비: 동그라미 4를 체크하고 기억 장면(할아버지의 돌이 다섯 번 튄다)이 지나간 뒤,
## 하윤이 납작한 돌을 주워 던진다. 두 번 튀고 가라앉는다. 그다음에 그 자리의 글("…다섯 번은 어렵다.")이 나온다.
## 같은 동그라미의 조사 대상(Interactable.map_circle)이 기억 장면 다음에 play()를 기다린다(#32).
## 장소 씬에 놓는다(Skip_5-4, 원점은 동그라미 조사 대상과 같은 땅 위). 담당: A(게임플레이).

signal finished

const LOCK := &"stone_skip"

## 어느 동그라미 다음에 나오나.
@export_range(1, 5) var circle: int = 4
## 돌이 물을 스치고 튀는 횟수. 이다음 닿을 때 가라앉는다.
@export var skips: int = 2
## 돌 그림 이름(assets/art). 없으면 회색 납작한 타원을 그린다.
@export var art: String = "prop_stone_flat"
## 물 위 선(화면 y). 강가의 앞 물은 조약돌 길(792~864) 아래부터다.
@export var water_y: float = 930.0
## 하윤 손에서 처음 물에 닿는 곳까지(오른쪽으로, px).
@export var first_reach: float = 330.0
## 튈 때마다 날아가는 거리와 높이. skips개만큼 앞에서부터 쓴다.
@export var hop_lengths: PackedFloat32Array = PackedFloat32Array([210.0, 130.0, 80.0])
@export var hop_heights: PackedFloat32Array = PackedFloat32Array([70.0, 36.0, 18.0])

var playing: bool = false
## 이번에 물에 닿은 횟수(튄 것 + 가라앉은 것). 검사용.
var touches: int = 0

var _stone: Node2D


func _ready() -> void:
	add_to_group("stone_skip")


static func find(tree: SceneTree, n: int) -> StoneSkip:
	for node in tree.get_nodes_in_group("stone_skip"):
		if node is StoneSkip and node.circle == n:
			return node
	return null


func play() -> void:
	if playing:
		return
	playing = true
	touches = 0
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.lock(LOCK)
		player.face(1)
		# 납작한 돌을 줍는다
		player.set_pose(&"crouch")
		await _pause(0.6)
		player.set_pose(&"stand")
		await _pause(0.35)
		# 팔을 뒤로 젖혔다 앞으로 휘두른다. 손을 놓는 순간 돌이 손에서 날아간다.
		await player.play_throw()
	var hand := player.hand_point() if player else global_position + Vector2(36.0, -120.0)
	_stone = _make_stone()
	_stone.global_position = hand
	# 던진다: 손에서 첫 물까지 낮게 날아간다
	var at := Vector2(hand.x + first_reach, water_y)
	await _fly(hand, at, 60.0, 0.55)
	for i in skips:
		touches += 1
		_ripple(at, 1.0 - 0.25 * i)
		_play_sound("sfx_stone_skip_")
		var length := hop_lengths[mini(i, hop_lengths.size() - 1)]
		var height := hop_heights[mini(i, hop_heights.size() - 1)]
		var next := at + Vector2(length, 0.0)
		await _fly(at, next, height, 0.22 + 0.0012 * length)
		at = next
	# 가라앉는다
	touches += 1
	_ripple(at, 0.6)
	_play_sound("sfx_stone_sink_")
	var sink := create_tween()
	sink.tween_property(_stone, "position:y", _stone.position.y + 22.0, 0.5)
	sink.parallel().tween_property(_stone, "modulate:a", 0.0, 0.5)
	await sink.finished
	_stone.queue_free()
	_stone = null
	await _pause(0.4)
	if player:
		player.unlock(LOCK)
	playing = false
	finished.emit()


## 멈춘 동안에는 흐르지 않는 짧은 숨(동작 사이). 대사·연출 길이를 맞추는 데 쓰지 않는다.
func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _fly(from: Vector2, to: Vector2, height: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(k: float):
		if _stone:
			_stone.global_position = from.lerp(to, k) + Vector2(0.0, -4.0 * height * k * (1.0 - k))
			_stone.rotation = lerpf(-0.25, 0.25, k), 0.0, 1.0, seconds)
	await tween.finished


func _make_stone() -> Node2D:
	var path := CutscenePlayer.find_art(art)
	var node: Node2D
	if not path.is_empty():
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		node = sprite
	else:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			pts.append(Vector2(cos(a) * 18.0, sin(a) * 7.0))
		poly.polygon = pts
		poly.color = Color(0.74, 0.74, 0.78)
		node = poly
	node.name = "Stone"
	node.z_index = 6
	node.z_as_relative = false
	add_child(node)
	return node


## 물을 스친 자리에 퍼지는 동그란 물결.
func _ripple(at: Vector2, strength: float) -> void:
	var ring := Line2D.new()
	ring.name = "Ripple"
	ring.width = 4.0
	ring.default_color = Color(0.93, 0.96, 1.0, 0.95 * strength)
	ring.closed = true
	for k in 24:
		var a := TAU * k / 24.0
		ring.add_point(Vector2(cos(a) * 10.0, sin(a) * 3.0))
	ring.z_index = 5
	ring.z_as_relative = false
	add_child(ring)
	ring.global_position = at
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(5.0, 5.0) * (0.6 + 0.4 * strength), 1.1)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 1.1)
	tween.tween_callback(ring.queue_free)


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
