class_name Flicker
extends Node2D
## 촛불처럼 일렁이는 것(#151): 세로 크기와 밝기가 잔잔히 흔들리고 가끔 크게 흔들린다. 담당: B(연출).

@export var amount := 0.12
@export var speed := 9.0

var _t := 0.0
var _seed := 0.0
var _base := Vector2.ONE


func _ready() -> void:
	_seed = randf() * 100.0
	_base = scale


func _process(delta: float) -> void:
	_t += delta
	var n := sin(_t * speed + _seed) * 0.5 + sin(_t * speed * 2.7 + _seed * 3.0) * 0.3 + sin(_t * speed * 0.43) * 0.2
	scale = Vector2(_base.x * (1.0 - n * amount * 0.4), _base.y * (1.0 + n * amount))
	modulate.a = 0.85 + n * amount
	skew = n * amount * 0.6
