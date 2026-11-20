class_name WaterReflection
extends Node2D
## 장면표 5-2 "물그림자": 얕은 물가를 걸으면 물에 비친 하윤이 보인다. 흐리게.
## **하늘이는 비치지 않는다**(복선: 둘 다 이승이 아니다. 7-6 배 위에서는 셋 다 또렷하게 비쳐 짝이 된다).
## 물가에 들어서면 카메라가 살짝 내려가 물을 보여 준다.
## 장소 씬에 B가 놓는다(Reflection_5-2, 물가 가운데 땅 위). 담당: B(물 반사). (A 세션이 쉬는 동안 B 세션이 만듦)
##
## 하윤 모습(Visual)을 한 번 복사해 물 위 선 아래로 뒤집어 두고, 매 프레임 하윤을 따라 맞춘다.
## 화면을 거울처럼 비추는 방식은 하늘이까지 비쳐서 쓰지 않는다. 인물 컷아웃이 들어오면 복사·맞추기를 다시 본다.

signal entered
signal exited

const SHADER := preload("res://shaders/reflection.gdshader")

## 물가 폭의 반(px). 원점에서 이만큼 안이면 비친다. 가장자리 edge_fade 동안 서서히.
@export var half_width: float = 420.0
@export var edge_fade: float = 140.0
## 물 위 선(발이 닿는 높이). 반사는 이 선을 기준으로 뒤집힌다.
@export var water_y: float = 816.0
## 하윤이 비치는 또렷함(0~1). 5-2는 흐리게.
@export_range(0.0, 1.0) var clarity: float = 0.3
## 카메라: 살짝 당겨서(확대) 아래쪽 물이 더 보이게. 배경이 1080에서 끝나 그냥 내릴 수는 없다.
@export var camera_zoom: float = 1.08
@export var camera_down: float = 40.0
@export var camera_seconds: float = 1.6

var inside: bool = false
var _copy: Node2D
var _holder: Node2D
var _camera_tween: Tween


func _ready() -> void:
	add_to_group("water_reflection")


## 지금 물에 비친 하윤(없으면 null). 하늘이 것은 만들지 않는다.
func player_reflection() -> Node2D:
	return _copy


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var d := absf(player.global_position.x - global_position.x)
	var now_inside := d < half_width
	if now_inside != inside:
		inside = now_inside
		_move_camera(player, inside)
		if inside:
			entered.emit()
		else:
			exited.emit()
	var strength := clampf((half_width + edge_fade * 0.5 - d) / edge_fade, 0.0, 1.0)
	if strength <= 0.0:
		if _holder:
			_holder.visible = false
		return
	if _copy == null:
		_make_copy(player)
	if _copy == null:
		return
	_holder.visible = player.visible
	_holder.modulate.a = strength
	# 물 위 선을 기준으로 뒤집는다: 발이 선 위에 있으면 반사의 발도 선 위
	_holder.global_position = Vector2(player.global_position.x, water_y * 2.0 - player.global_position.y)
	var visual := player.get_node_or_null("Visual") as Node2D
	if visual:
		_sync(visual, _copy)


func _make_copy(player: Player) -> void:
	var visual := player.get_node_or_null("Visual") as Node2D
	if visual == null:
		return
	_holder = Node2D.new()
	_holder.name = "PlayerReflection"
	_holder.scale = Vector2(1.0, -1.0)
	_holder.z_index = -1  # 하윤(0) 뒤, 땅(-10)·물건(-5) 위
	_holder.z_as_relative = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("clarity", clarity)
	mat.set_shader_parameter("water_y", water_y)
	_holder.material = mat
	add_child(_holder)
	_copy = visual.duplicate(0) as Node2D  # 스크립트·신호 없이 모습만
	_copy.name = "Visual"
	_holder.add_child(_copy)
	_use_parent_material(_copy)


func _use_parent_material(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).use_parent_material = true
	for child in node.get_children():
		_use_parent_material(child)


## 하윤이 돌아서거나 쪼그려 앉으면 반사도 같이(모습의 변환·보임을 그대로 옮긴다).
func _sync(src: Node, dst: Node) -> void:
	if src is Node2D and dst is Node2D:
		(dst as Node2D).transform = (src as Node2D).transform
		(dst as Node2D).visible = (src as Node2D).visible
	var n := mini(src.get_child_count(), dst.get_child_count())
	for i in n:
		_sync(src.get_child(i), dst.get_child(i))


func _move_camera(player: Player, down: bool) -> void:
	var camera := player.get_node_or_null("Camera") as Camera2D
	if camera == null:
		return
	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var z := camera_zoom if down else 1.0
	_camera_tween.tween_property(camera, "zoom", Vector2(z, z), camera_seconds)
	_camera_tween.tween_property(camera, "offset:y", camera_down if down else 0.0, camera_seconds)


func _exit_tree() -> void:
	# 물가에 선 채 장소를 떠나면 카메라를 돌려 둔다.
	if inside:
		var player := get_tree().get_first_node_in_group("player") as Player if get_tree() else null
		var camera := player.get_node_or_null("Camera") as Camera2D if player else null
		if camera:
			camera.zoom = Vector2.ONE
			camera.offset.y = 0.0
