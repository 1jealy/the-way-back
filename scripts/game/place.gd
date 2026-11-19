class_name Place
extends Node2D
## 장소 씬의 루트. 노드 이름과 층 규칙은 CLAUDE.md의 "장소 씬 약속"을 따른다.
## 바닥·벽·끝 지점은 width에 맞춰 여기서 자리를 잡는다.
## 담당: 이 스크립트는 A, 장소 씬의 배치는 B.

signal exit_reached

## 하윤이 걷는 땅의 높이(y). 모든 장소에서 같다.
const GROUND_Y := 810.0
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

@export var place_id: StringName = &""
@export var display_name: String = ""
## 다음 장소 씬. 비어 있으면 끝 지점에 닿아도 아무 일이 없다.
@export_file("*.tscn") var next_place: String = ""
## 장소의 가로 길이(px). 장면표의 "화면 길이" × 1920.
@export var width: float = SCREEN_W
## 그림이 들어오기 전까지 회색 네모 배경을 만든다.
@export var greybox: bool = true
## 하윤 발소리 바닥(assets/audio의 step_<바닥>_NN). wood dirt grass concrete soil pebble metal deck.
@export var footstep_surface: StringName = &"dirt"
## x에서 바닥이 바뀌는 곳. {x: 바닥} — 그 x부터 오른쪽은 그 바닥(예: 집 마루 → 마당 흙).
@export var footstep_changes: Dictionary = {}

@onready var _spawn: Marker2D = $Spawn
@onready var _exit: Area2D = $Exit
@onready var _floor_shape: CollisionShape2D = $Bounds/Floor/Shape
@onready var _left_wall_shape: CollisionShape2D = $Bounds/LeftWall/Shape
@onready var _right_wall_shape: CollisionShape2D = $Bounds/RightWall/Shape
@onready var _exit_shape: CollisionShape2D = $Exit/Shape


func _ready() -> void:
	add_to_group("place")
	_layout_bounds()
	_exit.body_entered.connect(_on_exit_body_entered)
	if greybox:
		_build_greybox()


## x 자리의 발소리 바닥.
func surface_at(x: float) -> StringName:
	var surface := footstep_surface
	var best := -INF
	for at in footstep_changes:
		if float(at) <= x and float(at) > best:
			best = float(at)
			surface = StringName(footstep_changes[at])
	return surface


func spawn_position() -> Vector2:
	return _spawn.global_position


func _layout_bounds() -> void:
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(width + 400.0, 200.0)
	_floor_shape.shape = floor_rect
	_floor_shape.position = Vector2(width * 0.5, GROUND_Y + 100.0)

	var wall := RectangleShape2D.new()
	wall.size = Vector2(40.0, SCREEN_H * 2.0)
	_left_wall_shape.shape = wall
	_left_wall_shape.position = Vector2(-20.0, GROUND_Y - SCREEN_H)
	_right_wall_shape.shape = wall.duplicate()
	_right_wall_shape.position = Vector2(width + 20.0, GROUND_Y - SCREEN_H)

	var exit_rect := RectangleShape2D.new()
	exit_rect.size = Vector2(80.0, 400.0)
	_exit_shape.shape = exit_rect
	_exit.position = Vector2(width - 120.0, GROUND_Y - 200.0)


func _on_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		exit_reached.emit()


## 층마다 회색 네모를 깐다. 같은 place_id면 늘 같은 모양이 나온다.
func _build_greybox() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(place_id)
	_greybox_layer($Layers/Sky, Color(0.32, 0.36, 0.44), 0.0, 0.0, SCREEN_H, rng, 0)
	_greybox_layer($Layers/Far, Color(0.27, 0.30, 0.37), 380.0, 160.0, 380.0, rng, 9)
	_greybox_layer($Layers/Mid, Color(0.22, 0.24, 0.30), 560.0, 220.0, 360.0, rng, 14)
	var ground := ColorRect.new()
	ground.color = Color(0.17, 0.18, 0.22)
	ground.position = Vector2(-200.0, GROUND_Y)
	ground.size = Vector2(width + 400.0, SCREEN_H - GROUND_Y)
	$Layers/Ground.add_child(ground)
	_greybox_front($Layers/Front, rng)


func _layer_span(layer: Parallax2D) -> float:
	return SCREEN_W + maxf(width - SCREEN_W, 0.0) * layer.scroll_scale.x + 400.0


## top: 언덕 띠의 위 끝 기준, height: 띠 높이, bumps: 언덕 개수(0이면 한 장).
func _greybox_layer(layer: Parallax2D, color: Color, top: float, bump_h: float,
		height: float, rng: RandomNumberGenerator, bumps: int) -> void:
	var span := _layer_span(layer)
	var base := ColorRect.new()
	base.color = color
	base.position = Vector2(-200.0, top + bump_h)
	base.size = Vector2(span, height)
	layer.add_child(base)
	for i in bumps:
		var w := rng.randf_range(260.0, 620.0)
		var h := rng.randf_range(bump_h * 0.4, bump_h)
		var x := span * float(i) / float(bumps) + rng.randf_range(-80.0, 80.0)
		var hill := Polygon2D.new()
		hill.color = color
		hill.polygon = PackedVector2Array([
			Vector2(x, top + bump_h), Vector2(x + w * 0.5, top + bump_h - h),
			Vector2(x + w, top + bump_h)])
		layer.add_child(hill)


func _greybox_front(layer: Parallax2D, rng: RandomNumberGenerator) -> void:
	var span := _layer_span(layer)
	var x := 900.0
	while x < span:
		var post := ColorRect.new()
		post.color = Color(0.09, 0.10, 0.12)
		var w := rng.randf_range(40.0, 90.0)
		post.size = Vector2(w, SCREEN_H)
		post.position = Vector2(x, rng.randf_range(-200.0, 300.0))
		layer.add_child(post)
		x += rng.randf_range(1100.0, 2000.0)
