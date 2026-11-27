class_name StoneSkip
extends MiniGame
## 장면표 5-4 물수제비: 동그라미 4를 체크하고 기억 장면(할아버지의 돌이 다섯 번 튄다)이 지나간 뒤에 나온다.
## 같은 동그라미의 조사 대상(Interactable.map_circle)이 기억 장면 다음에 play()를 기다린다(#32).
## - 돌 주머니(item_stone_pouch, #115)가 없으면: 하윤이 납작한 돌 하나를 주워 던진다. 두 번 튀고 가라앉는다.
## - 있으면: **선택 미니게임**(안 해도 된다). 물 위에 할아버지가 낸 물결 다섯 자리가 희미하게 남아 있고,
##   E를 누르고 있으면 몸을 낮추며 던질 각도가 오르내린다(손에서 나간 점선 궤적이 기울어진다, 20도 근처면 금빛).
##   떼는 순간 던진다. 각도가 맞을수록 많이 튀고, 튄 자리마다 할아버지의 물결 자리가 하나씩 채워진다.
##   발밑 돌무더기(다섯)가 남은 돌이다. 다 쓰면 하늘이가 물가에서 다시 물어 온다. ← →로 그만둔다.
##   다섯 번을 튀기면 하늘이가 짖고 할아버지 기억이 한 번 더 빛난다(skip_five). 점수·실패 화면은 없다.
##   도움(세 번 셋 미만): 각도가 천천히 오르내린다.
## 장소 씬에 놓는다(Skip_5-4, 원점은 동그라미 조사 대상과 같은 땅 위). 담당: A(게임플레이).

signal finished

const DEMO_LOCK := &"stone_skip"  # 주머니 없이 던지는 연출의 잠금(미니게임은 MiniGame.LOCK)
const SWEET := 20.0  # 물과 약 20도로 닿아야 잘 튄다(Clanet 외, Nature 2004)
const GOLD := Color(0.95, 0.81, 0.48, 0.95)
const PALE := Color(0.95, 0.97, 1.0, 0.55)

## 어느 동그라미 다음에 나오나.
@export_range(1, 5) var circle: int = 4
## 주머니 없이 던질 때 튀는 횟수. 이다음 닿을 때 가라앉는다.
@export var skips: int = 2
## 돌 그림 이름(assets/art). 없으면 회색 납작한 타원을 그린다.
@export var art: String = "prop_stone_flat"
## 물 위 선(화면 y). 강가의 앞 물은 조약돌 길(792~864) 아래부터다.
@export var water_y: float = 930.0
## 하윤 손에서 처음 물에 닿는 곳까지(오른쪽으로, px).
@export var first_reach: float = 330.0
## 튈 때마다 날아가는 거리와 높이. 앞에서부터 쓴다.
@export var hop_lengths: PackedFloat32Array = PackedFloat32Array([210.0, 150.0, 110.0, 80.0, 60.0])
@export var hop_heights: PackedFloat32Array = PackedFloat32Array([70.0, 46.0, 30.0, 20.0, 12.0])
## 미니게임: 이 물건이 있어야 한다.
@export var pouch_flag: StringName = &"item_stone_pouch"
## 주머니 속 돌 수.
@export var stones: int = 5
## 각도가 오르내리는 빠르기(라디안/초, 도움이면 0.55배).
@export var swing_speed: float = 2.6
@export var five_flag: StringName = &"skip_five"

var playing: bool = false
## 이번에 물에 닿은 횟수(튄 것 + 가라앉은 것). 검사용.
var touches: int = 0
## 미니게임에서 가장 많이 튀긴 횟수.
var best: int = 0
var stones_left: int = 0
## 지금 각도(도)와 누르고 있는지.
var angle: float = 40.0
var charging: bool = false

var _stone: Node2D
var _ghosts: Array[Line2D] = []
var _pile: Array[Sprite2D] = []
var _aim: Line2D
var _t: float = 0.0
var _busy: bool = false


func _ready() -> void:
	add_to_group("stone_skip")
	super._ready()


static func find(tree: SceneTree, n: int) -> StoneSkip:
	for node in tree.get_nodes_in_group("stone_skip"):
		if node is StoneSkip and node.circle == n:
			return node
	return null


## 주머니가 있으면 미니게임(그만둘 때까지), 없으면 돌 하나를 던지는 연출.
func play() -> void:
	if playing:
		return
	playing = true
	touches = 0
	if GameState.has_flag(pouch_flag):
		done = false
		await super.play()
	else:
		await _demo()
	playing = false
	finished.emit()


func _demo() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.lock(DEMO_LOCK)
		player.face(1)
		player.set_pose(&"crouch")
		await _pause(0.6)
		player.set_pose(&"stand")
		await _pause(0.2)
		await player.play_throw()
	var hand := player.hand_point() if player else global_position + Vector2(36.0, -120.0)
	await _throw_from(hand, skips, false)
	await _pause(0.4)
	if player:
		player.unlock(DEMO_LOCK)


# --- 미니게임 -----------------------------------------------------------------

func _begin() -> void:
	best = 0
	stones_left = stones
	angle = 40.0
	charging = false
	_busy = false
	if _player:
		_player.face(1)
	_build()
	show_key_hint(["E"], "꾹 눌렀다 금빛에서 떼기 · ← → 그만")


func _build() -> void:
	var hand := _hand()
	var at := Vector2(hand.x + first_reach, water_y)
	_ghosts.clear()
	for i in 5:
		var g := _ring(Color(0.92, 0.95, 1.0, 0.0), 2.5, Vector2(64.0 - i * 6.0, 11.0 - i))
		g.name = "Ghost%d" % i
		add_child(g)
		g.global_position = at
		create_tween().tween_property(g, "default_color:a", 0.3, 0.8)
		_ghosts.append(g)
		if i < hop_lengths.size():
			at += Vector2(hop_lengths[i], 0.0)
	_aim = Line2D.new()
	_aim.name = "Aim"
	_aim.width = 6.0
	# 점선: 동그란 점 하나와 빈칸을 되풀이하는 작은 그림을 줄을 따라 늘어놓는다(낚싯줄처럼 보이지 않게)
	var dot := Image.create(24, 12, false, Image.FORMAT_RGBA8)
	for x in 24:
		for y in 12:
			var d := Vector2(x - 6.0, y - 6.0).length()
			dot.set_pixel(x, y, Color(1, 1, 1, clampf(5.5 - d, 0.0, 1.0)))
	_aim.texture = ImageTexture.create_from_image(dot)
	_aim.texture_mode = Line2D.LINE_TEXTURE_TILE
	_aim.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_aim.default_color = Color(PALE, 0.0)
	_aim.z_index = 6
	_aim.z_as_relative = false
	add_child(_aim)
	_refill_pile()


func _refill_pile() -> void:
	for s in _pile:
		if is_instance_valid(s):
			s.queue_free()
	_pile.clear()
	var path := CutscenePlayer.find_art(art)
	if path.is_empty() or _player == null:
		return
	for i in stones_left:
		var s := Sprite2D.new()
		s.texture = load(path)
		s.scale = Vector2(0.8, 0.8)
		s.z_index = 2
		s.z_as_relative = false
		add_child(s)
		s.global_position = _player.global_position + Vector2(48.0 + (i % 3) * 26.0, -8.0 - (i / 3) * 12.0)
		_pile.append(s)


func _hand() -> Vector2:
	return _player.hand_point() if _player else global_position + Vector2(36.0, -120.0)


func _tick(delta: float) -> void:
	_t += delta
	_place_hint()
	if _busy:
		return
	if not MiniGame.autoplay and (Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right")):
		_end()
		return
	var hold := _auto_hold() if MiniGame.autoplay else Input.is_action_pressed("interact")
	if hold:
		if not charging:
			charging = true
			_t = 0.0
			hide_key_hint()
		var speed := swing_speed * (0.55 if help else 1.0)
		angle = 22.0 - 24.0 * cos(_t * speed)  # -2 ~ 46도, 처음엔 낮게
		_draw_aim()
		if _player:
			_player.set_motion({"hip": -18.0, "knee": 34.0, "ankle": -14.0, "far_hip": -14.0, "far_knee": 30.0,
					"far_ankle": -14.0, "torso": 14.0 + (angle - SWEET) * 0.2, "shoulder": 40.0, "elbow": -16.0})
	elif charging:
		charging = false
		_release()


## 검사용: 금빛(20도)에 가장 가까울 때 뗀다.
func _auto_hold() -> bool:
	if not charging:
		return true
	return absf(angle - SWEET) > 1.5 or _t < 0.2


func _draw_aim() -> void:
	var hand := _hand()
	var reach := first_reach
	var rad := deg_to_rad(angle)
	var pts := PackedVector2Array()
	for k in 17:
		var u := k / 16.0
		var x := reach * u
		var y := -tan(rad) * x * (1.0 - u) * 0.5 + (water_y - hand.y) * u * u
		pts.append(to_local(hand + Vector2(x, y)))
	_aim.points = pts
	var good := absf(angle - SWEET) < 6.0
	_aim.default_color = _aim.default_color.lerp(GOLD if good else PALE, 0.35)


static func skips_for(a: float) -> int:
	var err := absf(a - SWEET)
	if err < 4.0:
		return 5
	if err < 8.0:
		return 4
	if err < 13.0:
		return 3
	if err < 19.0:
		return 2
	if err < 26.0:
		return 1
	return 0


func _release() -> void:
	_busy = true
	var n := skips_for(angle)
	create_tween().tween_property(_aim, "default_color:a", 0.0, 0.2)
	if _player:
		_player.set_motion({})
		await _player.play_throw()
	stones_left -= 1
	if not _pile.is_empty():
		var s: Sprite2D = _pile.pop_back()
		if is_instance_valid(s):
			s.queue_free()
	await _throw_from(_hand(), n, true)
	best = maxi(best, n)
	if n < 3:
		miss()
	if n >= 5:
		await _five()
		_end()
		return
	if stones_left <= 0:
		await _fetch_more()
	_busy = false
	if running and not has_key_hint() and misses == 1:
		show_key_hint(["E"], "꾹 눌렀다 금빛에서 떼기 · ← → 그만")


## 다섯 번: 하늘이가 짖고, 할아버지의 물결 다섯 자리가 한꺼번에 환해진다.
func _five() -> void:
	GameState.set_flag(five_flag)
	var dog := get_tree().get_first_node_in_group("dog") as Node
	var rig := dog.get_node_or_null("Visual/Rig") if dog else null
	if rig and rig.has_method("bark"):
		rig.bark()
	for g in _ghosts:
		var t := create_tween()
		t.tween_property(g, "default_color", GOLD, 0.3)
		t.tween_property(g, "scale", Vector2(1.4, 1.4), 0.6)
	var memory := MemoryScene.find(get_tree(), circle)
	if memory:
		await memory.play()
	else:
		await _wait(1.2)


## 돌을 다 썼다: 하늘이가 물가에서 납작한 돌을 물어 온다.
func _fetch_more() -> void:
	var dog := get_tree().get_first_node_in_group("dog") as Node2D
	if dog and dog.has_method("script_move_to") and dog.has_method("is_joined") and dog.is_joined():
		dog.script_move_to(global_position.x + 240.0)
		await _wait(1.6)
		dog.script_move_to(_player.global_position.x - 120.0 if _player else global_position.x)
		await _wait(1.6)
		dog.release_script()
	else:
		await _wait(0.8)
	stones_left = stones
	_refill_pile()


func _end() -> void:
	if _player:
		_player.set_motion({})
	hide_key_hint()
	var fade := create_tween().set_parallel()
	for g in _ghosts:
		fade.tween_property(g, "default_color:a", 0.0, 0.8)
	for s in _pile:
		if is_instance_valid(s):
			fade.tween_property(s, "modulate:a", 0.0, 0.6)
	if _aim:
		fade.tween_property(_aim, "modulate:a", 0.0, 0.3)
	await fade.finished
	for g in _ghosts:
		g.queue_free()
	_ghosts.clear()
	for s in _pile:
		if is_instance_valid(s):
			s.queue_free()
	_pile.clear()
	if _aim:
		_aim.queue_free()
		_aim = null
	clear()


# --- 던지기 -------------------------------------------------------------------

## 손에서 던져 n번 튀고 가라앉는다. fill이면 튄 자리마다 할아버지 물결 자리를 채운다.
func _throw_from(hand: Vector2, n: int, fill: bool) -> void:
	_stone = _make_stone()
	_stone.global_position = hand
	var at := Vector2(hand.x + first_reach, water_y)
	# 카메라가 돌을 살짝 따라간다(#119). 미니게임에서만(연출 던지기는 그대로).
	if fill and _player:
		var reach := first_reach
		for k in n:
			reach += hop_lengths[mini(k, hop_lengths.size() - 1)]
		pan_camera(clampf(reach * 0.45, 0.0, 520.0), 0.4 + 0.25 * n)
	await _fly(hand, at, 18.0, 0.42)
	for i in n:
		touches += 1
		# 미니게임에서는 튈수록 물보라가 커지고 소리가 높아진다(#119)
		_ripple(at, (0.7 + 0.18 * i) if fill else (1.0 - 0.15 * i))
		if fill and i >= 2:
			_spray(at, i)
		if fill and i < _ghosts.size():
			var t := create_tween()
			t.tween_property(_ghosts[i], "default_color", Color(0.97, 0.98, 1.0, 0.95), 0.15)
			t.tween_property(_ghosts[i], "default_color", Color(0.92, 0.95, 1.0, 0.3), 1.6)
		_play_sound("sfx_stone_skip_", (1.0 + 0.07 * i) if fill else 1.0)
		var length := hop_lengths[mini(i, hop_lengths.size() - 1)]
		var height := hop_heights[mini(i, hop_heights.size() - 1)]
		var next := at + Vector2(length, 0.0)
		await _fly(at, next, height, 0.22 + 0.0012 * length)
		at = next
	touches += 1
	_ripple(at, 0.6)
	_play_sound("sfx_stone_sink_")
	var sink := create_tween()
	sink.tween_property(_stone, "position:y", _stone.position.y + 22.0, 0.5)
	sink.parallel().tween_property(_stone, "modulate:a", 0.0, 0.5)
	await sink.finished
	_stone.queue_free()
	_stone = null
	if fill:
		pan_camera(0.0, 0.8)


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


func _ring(color: Color, width: float, radius: Vector2) -> Line2D:
	var ring := Line2D.new()
	ring.width = width
	ring.default_color = color
	ring.closed = true
	for k in 28:
		var a := TAU * k / 28.0
		ring.add_point(Vector2(cos(a) * radius.x, sin(a) * radius.y))
	ring.z_index = 5
	ring.z_as_relative = false
	return ring


## 물을 스친 자리에 퍼지는 동그란 물결.
func _ripple(at: Vector2, strength: float) -> void:
	var ring := _ring(Color(0.93, 0.96, 1.0, 0.95 * strength), 4.0, Vector2(10.0, 3.0))
	ring.name = "Ripple"
	add_child(ring)
	ring.global_position = at
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(5.0, 5.0) * (0.6 + 0.4 * strength), 1.1)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 1.1)
	tween.tween_callback(ring.queue_free)


## 튈수록 커지는 물보라(셋째 튀기부터): 물방울 몇 개가 튀어 올랐다 떨어진다.
func _spray(at: Vector2, i: int) -> void:
	var count := 2 + i
	for k in count:
		var drop := _ring(Color(0.95, 0.97, 1.0, 0.9), 3.0, Vector2(3.0, 3.0))
		drop.name = "Drop"
		add_child(drop)
		drop.global_position = at
		var dx := randf_range(-30.0, 30.0) * (0.6 + 0.2 * i)
		var up := randf_range(30.0, 55.0) * (0.7 + 0.15 * i)
		var tw := drop.create_tween()
		tw.tween_property(drop, "global_position", at + Vector2(dx * 0.5, -up), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(drop, "global_position", at + Vector2(dx, 0.0), 0.26).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(drop, "modulate:a", 0.0, 0.26)
		tw.tween_callback(drop.queue_free)
