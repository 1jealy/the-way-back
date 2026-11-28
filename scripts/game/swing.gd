class_name Swing
extends Node2D
## 추·풍경처럼 매달려 흔들리는 것(#151). 노드의 원점(매달린 자리)을 축으로 degrees만큼 period초에 한 번 오간다.
## Sprite2D 등에 붙인다(그림의 매달린 자리를 offset으로 원점에 맞춘다). 담당: B(연출).

@export var degrees := 6.0
@export var period := 2.0
@export var phase := 0.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	rotation = deg_to_rad(degrees) * sin(TAU * _t / period + phase)
