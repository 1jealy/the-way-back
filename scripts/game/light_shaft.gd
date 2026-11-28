class_name LightShaft
extends Polygon2D
## 창으로 드는 빛줄기(#151). 뒷벽(깊이 wall_s)의 창 [win_from, win_to](평면 x)·[win_top, win_bottom](화면 y)에서
## 바닥 깊이 floor_s의 빛 웅덩이(창 x + reach)까지. 걸으면 벽과 바닥이 다른 빠르기로 흐르니 빛줄기도 따라 기운다.
## 더하기 섞기, 위가 진하고 아래로 옅어지며, 천천히 숨 쉬듯 밝아졌다 어두워진다. 안에서 먼지가 떠다닌다.
## RoomPerspective의 자식으로 둔다. 담당: B(연출).

@export var win_from := 0.0
@export var win_to := 100.0
@export var win_top := 300.0
@export var win_bottom := 500.0
@export var wall_s := 0.8
@export var reach := 300.0
@export var floor_s := 1.15
@export var strength := 0.32
@export var light_color := Color(1.0, 0.85, 0.6)
@export var dust := 18

var _t := 0.0
var _phase := 0.0
var _dust: CPUParticles2D


func _ready() -> void:
	z_as_relative = false
	_phase = randf() * TAU
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if dust > 0:
		_dust = CPUParticles2D.new()
		_dust.amount = dust
		_dust.lifetime = 7.0
		_dust.preprocess = 7.0
		_dust.local_coords = false
		_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_dust.direction = Vector2(0.4, 1.0)
		_dust.spread = 60.0
		_dust.gravity = Vector2(0.0, 3.0)
		_dust.initial_velocity_min = 3.0
		_dust.initial_velocity_max = 9.0
		_dust.scale_amount_min = 1.4
		_dust.scale_amount_max = 3.0
		_dust.color = Color(1.0, 0.94, 0.78, 0.7)
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.0))
		curve.add_point(Vector2(0.3, 1.0))
		curve.add_point(Vector2(0.7, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		_dust.scale_amount_curve = curve
		_dust.z_index = z_index + 1
		_dust.z_as_relative = false
		add_child(_dust)


func _process(delta: float) -> void:
	_t += delta
	var breathe := 0.86 + 0.1 * sin(_t * 0.45 + _phase) + 0.04 * sin(_t * 1.7 + _phase * 2.0)
	modulate.a = breathe


func update_view(room: RoomPerspective) -> void:
	var ta := Vector2(room.world_x(win_from, wall_s), win_top)
	var tb := Vector2(room.world_x(win_to, wall_s), win_top)
	var ba := Vector2(room.world_x(win_from + reach, floor_s), room.floor_y(floor_s))
	var bb := Vector2(room.world_x(win_to + reach, floor_s), room.floor_y(floor_s))
	polygon = PackedVector2Array([ta, tb, bb, ba])
	var top := Color(light_color, strength)
	var bottom := Color(light_color, 0.0)
	vertex_colors = PackedColorArray([top, top, bottom, bottom])
	if _dust:
		var c := (ta + tb + ba + bb) * 0.25
		_dust.position = c - global_position
		_dust.emission_rect_extents = Vector2(absf(bb.x - ta.x) * 0.3 + 40.0, absf(ba.y - ta.y) * 0.4)
