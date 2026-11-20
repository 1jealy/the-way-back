class_name ShakeDrop
extends Interactable
## 흔들면 무언가 떨어지는 조사 대상. 장면표 1-6 "감나무를 흔들면 감 하나가 떨어진다(선택)".
## 조사 대상(Interactable)을 이은 것이라 [E] 안내·잠금·플래그는 그대로 쓴다. 한 번만(one_shot).
## 장소 씬에 B가 놓는다(Shake_1-6_Persimmon, 나무 밑동 땅 위). 진행과 상관없다.
## 담당: A(조사 반응). (A 세션이 쉬는 동안 B 세션이 만듦)

## 떨어지는 것이 땅에 닿았다.
signal dropped

## 떨어지는 것이 매달린 자리(원점 기준).
@export var drop_from: Vector2 = Vector2(60.0, -400.0)
## 떨어진 뒤 땅에서 굴러가는 거리(px, 부호는 방향).
@export var roll: float = 46.0
@export var art: String = "prop_persimmon"
@export var shake_sound: String = "sfx_tree_shake_"
@export var drop_sound: String = "sfx_persimmon_drop_"
## 흔들 때 떨어지는 잎 수와 색.
@export var leaves: int = 9
@export var leaf_color: Color = Color(0.85, 0.48, 0.18, 1.0)

var fallen: Node2D


func _ready() -> void:
	one_shot = true
	super._ready()
	interacted.connect(_shake)


func _shake() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.face(1 if global_position.x + drop_from.x >= player.global_position.x else -1)
	_play_sound(shake_sound)
	_drop_leaves()
	var fruit := Sprite2D.new()
	fruit.name = "Fallen"
	var path := CutscenePlayer.find_art(art)
	if not path.is_empty():
		fruit.texture = load(path)
		fruit.offset = Vector2(0.0, -fruit.texture.get_height() * 0.5)  # 원점 = 땅에 닿는 곳
	fruit.z_index = -2  # 하윤 뒤, 땅·물건 위
	fruit.z_as_relative = false
	add_child(fruit)
	fruit.position = drop_from
	fallen = fruit
	# 잠깐 매달려 흔들리다(가지가 흔들리는 동안) 떨어져 한 번 튀고 구른다.
	var tween := create_tween()
	tween.tween_property(fruit, "rotation", 0.25, 0.12)
	tween.tween_property(fruit, "rotation", -0.2, 0.12)
	tween.tween_property(fruit, "rotation", 0.0, 0.1)
	tween.tween_property(fruit, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_play_sound(drop_sound)
		dropped.emit())
	tween.tween_property(fruit, "position:y", -26.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fruit, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(fruit, "position:x", drop_from.x + roll, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fruit, "rotation", roll / 18.0, 0.5).set_ease(Tween.EASE_OUT)


## 가지에서 잎 몇 장이 팔랑팔랑 떨어진다.
func _drop_leaves() -> void:
	for i in leaves:
		var leaf := Polygon2D.new()
		leaf.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(0, -4), Vector2(7, 0), Vector2(0, 4)])
		leaf.color = leaf_color.lerp(Color(0.6, 0.42, 0.2), randf() * 0.5)
		leaf.z_index = -2
		leaf.z_as_relative = false
		add_child(leaf)
		var start := drop_from + Vector2(randf_range(-170.0, 170.0), randf_range(-120.0, 60.0))
		leaf.position = start
		var t := randf_range(1.6, 2.6)
		var tween := create_tween().set_parallel()
		tween.tween_property(leaf, "position:y", -4.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_method(func(k: float): leaf.position.x = start.x + sin(k * TAU * 1.5) * 28.0 - k * 40.0, 0.0, 1.0, t)
		tween.tween_property(leaf, "rotation", randf_range(-6.0, 6.0), t)
		tween.chain().tween_property(leaf, "modulate:a", 0.0, 1.2)
		tween.chain().tween_callback(leaf.queue_free)
