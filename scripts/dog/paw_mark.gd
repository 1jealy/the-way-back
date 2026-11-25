class_name PawMark
extends Node2D
## 부탁할 수 있을 때 하늘이 머리 위에 뜨는 표시: 발바닥 그림 + "[F] 가져와" 같은 안내(장면표 3-5 "F 안내").
## 예전에는 "F" 글자 하나뿐이라 무엇을 하는 키인지 몰랐다(#109). 조사 대상의 "[E] …" 안내와 같은 모양으로 맞춘다.

const PAD_COLOR := Color(1.0, 0.93, 0.7, 1.0)
const EDGE_COLOR := Color(0.12, 0.1, 0.09, 0.85)
const BOB_PX := 4.0
const BOB_SPEED := 3.2
const FADE_SPEED := 6.0

var _label: Label
var _shown: bool = false
var _t: float = 0.0
var _base: float = NAN


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	_label = Label.new()
	_label.name = "Text"
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.82, 1))
	_label.add_theme_color_override("font_outline_color", EDGE_COLOR)
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(240.0, 34.0)
	_label.position = Vector2(-120.0, 6.0)
	add_child(_label)


## 표시를 켜고 끈다. 켤 때 안내 문구를 바꾼다(부탁 자리마다 행동이 다르다).
func show_hint(on: bool, text: String = "") -> void:
	if on and text != "":
		_label.text = "[F] " + text
	_shown = on


func text() -> String:
	return _label.text


## 지금 보이는가(서서히 사라지는 중이면 거짓).
func is_shown() -> bool:
	return _shown


func _process(delta: float) -> void:
	var goal := 1.0 if _shown else 0.0
	modulate.a = move_toward(modulate.a, goal, delta * FADE_SPEED)
	visible = modulate.a > 0.0
	if visible:
		_t += delta
		position.y = _base_y() + sin(_t * BOB_SPEED) * BOB_PX
	else:
		_t = 0.0


func _base_y() -> float:
	if is_nan(_base):
		_base = position.y
	return _base


func _draw() -> void:
	# 발바닥: 큰 패드 하나 + 발가락 넷. 테두리를 먼저 크게 깔아 어떤 배경에서도 보이게.
	var pads: Array = [
		[Vector2(0, -8), Vector2(13, 10)],
		[Vector2(-15, -24), Vector2(5, 6.5)],
		[Vector2(-5.5, -31), Vector2(5, 6.5)],
		[Vector2(5.5, -31), Vector2(5, 6.5)],
		[Vector2(15, -24), Vector2(5, 6.5)],
	]
	for edge in [true, false]:
		for p in pads:
			var r: Vector2 = p[1] + (Vector2(3, 3) if edge else Vector2.ZERO)
			_ellipse(p[0], r, EDGE_COLOR if edge else PAD_COLOR)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)
