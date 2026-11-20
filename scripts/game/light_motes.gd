class_name LightMotes
extends Node2D
## 장면표 4-1·4-2 빛 알갱이. 숲에 들어서면 금빛 알갱이가 땅에서 천천히 떠오른다(4-1).
## 빛 갈림길(4-2, gather_from~gather_to)에서는 **하늘이 발밑에만 모인다**(복선: 하늘이는 이 빛 쪽 존재다).
## 장소 씬에 B가 놓는다(Motes_4-1, 숲 입구 땅 위). 하윤이 원점을 지나면 시작한다.
## 알갱이는 화면에 보이는 둘레에서만 만들고 지운다(숲 전체에 깔지 않는다). 담당: B(빛 알갱이).
## (A 세션이 쉬는 동안 B 세션이 만듦)

@export var count: int = 70
@export var color: Color = Color(1.0, 0.86, 0.5, 1.0)
## 4-2 구간(땅 x). 이 안에서는 새 알갱이가 하늘이 발밑에서만 생긴다.
@export var gather_from: float = 3000.0
@export var gather_to: float = 5900.0
## 발밑에 모이는 폭(px, 하늘이 기준 ±).
@export var gather_spread: float = 70.0
## 떠오르는 빠르기(px/초)와 사는 시간(초).
@export var rise_speed: Vector2 = Vector2(12.0, 30.0)
@export var life: Vector2 = Vector2(4.0, 8.0)

## 지금 하늘이 발밑에 모으는 중인가.
var gathering: bool = false
var started: bool = false
## 알갱이: {pos, vel, age, life, size, phase}
var motes: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("light_motes")
	z_index = 5  # 하윤 앞, 앞 층(10) 뒤
	z_as_relative = false


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if not started:
		if player.global_position.x < global_position.x:
			return
		started = true
		for i in count:  # 들어서는 순간: 땅에서 한꺼번에 떠오른다
			motes.append(_new_mote(player, true))
	var dog := get_tree().get_first_node_in_group("dog") as Node2D
	var px := player.global_position.x
	gathering = dog != null and dog.visible and px >= gather_from and px <= gather_to
	var i := motes.size() - 1
	while i >= 0:
		var m: Dictionary = motes[i]
		m.age += delta
		var sway := sin(m.age * 1.3 + m.phase) * 10.0
		m.pos += m.vel * delta + Vector2(sway * delta, 0.0)
		if gathering:  # 모으는 동안 하늘이에게서 먼 알갱이는 빨리 사그라든다
			if absf(m.pos.x - dog.global_position.x) > gather_spread * 2.0:
				m.age += delta * 3.0
			else:  # 발밑 알갱이는 하늘이를 따라간다
				m.pos.x = lerpf(m.pos.x, dog.global_position.x + m.offset, delta * 3.0)
		if m.age >= m.life or absf(m.pos.x - px) > 1400.0:
			motes.remove_at(i)
		i -= 1
	while motes.size() < count:
		motes.append(_new_mote(player, false, dog if gathering else null))
	queue_redraw()


func _new_mote(player: Node2D, from_ground: bool, dog: Node2D = null) -> Dictionary:
	var m := {
		"vel": Vector2(randf_range(-6.0, 6.0), -randf_range(rise_speed.x, rise_speed.y)),
		"age": 0.0,
		"life": randf_range(life.x, life.y),
		"size": randf_range(2.0, 4.5),
		"phase": randf() * TAU,
		"offset": 0.0,
	}
	if dog:  # 하늘이 발밑: 낮게, 천천히
		m.offset = randf_range(-gather_spread, gather_spread)
		m.pos = Vector2(dog.global_position.x + m.offset, Place.GROUND_Y - randf_range(0.0, 30.0))
		m.vel.y *= 0.5
		m.life *= 0.6
	elif from_ground:
		m.pos = Vector2(player.global_position.x + randf_range(-1000.0, 1000.0), Place.GROUND_Y - randf_range(0.0, 40.0))
		m.age = -randf() * 2.0  # 조금씩 늦게 떠오른다
	else:
		m.pos = Vector2(player.global_position.x + randf_range(-1050.0, 1050.0), randf_range(380.0, Place.GROUND_Y))
	return m


## 하늘이 x에서 within px 안에 있는 알갱이 비율(검사용).
func share_near(x: float, within: float) -> float:
	if motes.is_empty():
		return 0.0
	var n := 0
	for m in motes:
		if absf(m.pos.x - x) <= within:
			n += 1
	return float(n) / motes.size()


func _draw() -> void:
	var inv := get_global_transform().affine_inverse()
	for m in motes:
		if m.age < 0.0:
			continue
		var t: float = m.age / m.life
		var a := sin(clampf(t, 0.0, 1.0) * PI) * (0.6 + 0.4 * sin(m.age * 3.0 + m.phase))
		var p: Vector2 = inv * m.pos
		draw_circle(p, m.size * 3.0, Color(color.r, color.g, color.b, a * 0.12))
		draw_circle(p, m.size, Color(color.r, color.g, color.b, a * 0.85))
