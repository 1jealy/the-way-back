class_name PerspectivePlane
extends Polygon2D
## 화면 안쪽으로 뻗은 세로 벽(#151, 옆벽·문간). 평면 x = p, 깊이 s_from ~ s_to.
## 그림(texture)은 가로 = 깊이(s_from → s_to), 세로 = 천장(0) → 바닥(1). RoomPerspective가 매 프레임 모양을 맞춘다.
## 깊이를 strips 조각으로 나눠 이어 붙인다(조각마다 평평하게 늘여서, 조각이 많을수록 원근이 바르다).
## 하윤보다 앞(s > 1)과 뒤(s < 1)는 z가 달라야 하므로 노드를 둘로 나눈다(tex_from/tex_to로 그림 한 장을 나눠 쓴다).
## 담당: B(연출).

@export var p := 0.0
@export var s_from := 0.8
@export var s_to := 1.0
## 그림 가로에서 이 노드가 쓰는 몫(0~1).
@export var tex_from := 0.0
@export var tex_to := 1.0
@export var strips := 10


func _ready() -> void:
	z_as_relative = false


func update_view(room: RoomPerspective) -> void:
	if texture == null:
		return
	var size := texture.get_size()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in strips + 1:
		var t := float(i) / strips
		# 깊이는 1/s로 고르게(가까운 쪽 조각이 넓다)
		var inv := lerpf(1.0 / s_from, 1.0 / s_to, t)
		var s := 1.0 / inv
		var x := room.world_x(p, s)
		var u := lerpf(tex_from, tex_to, t) * size.x
		pts.append(Vector2(x, room.ceil_y(s)))
		uvs.append(Vector2(u, 0.0))
		pts.append(Vector2(x, room.floor_y(s)))
		uvs.append(Vector2(u, size.y))
	var polys := []
	for i in strips:
		var a := i * 2
		polys.append(PackedInt32Array([a, a + 2, a + 3, a + 1]))
	polygon = pts
	uv = uvs
	polygons = polys
