class_name RoomPerspective
extends Node2D
## 방 안 원근(#151). 장소 씬 루트에 두고(원점 0,0), 자식으로 바닥·천장(room_plane 셰이더를 건 Polygon2D),
## 옆벽(PerspectivePlane), 창 빛줄기(LightShaft)를 둔다. 매 프레임 카메라 왼쪽 끝(cam_left)을 구해 넘긴다.
##
## 깊이 s = 그 자리의 스크롤 빠르기(하윤이 걷는 줄 = 1). 평면 좌표 p는 세계 x와 같은 단위다.
##   화면 x = (p - 960)·s + 960 - cam_left·s       (Parallax2D와 같은 셈, placeholder_art.layer_x)
##   바닥 y = vp_y + floor_k·s,  천장 y = vp_y - ceil_k·s
## 집: 뒷벽은 Near 층(0.8) — 바닥 y 690, 천장 y 120. 하윤 줄(1) — 바닥 y 810.
## 그림(tools/painters/house.py)도 같은 수를 쓴다. 바꾸면 둘 다 고친다.
## 담당: B(연출). (A 영역 scripts/에 둠 — A 대신 B 세션이 작업)

@export var vp_y := 210.0
@export var floor_k := 600.0
@export var ceil_k := 112.5
## 이 x보다 왼쪽 카메라 구역(집 다락)에서는 방 원근을 감춘다(다락은 정면 그림이라 옆벽이 비쳤다).
@export var room_left := 0.0

var cam_left := 0.0


static func screen_x(p: float, s: float, cam: float) -> float:
	return (p - 960.0) * s + 960.0 - cam * s


func floor_y(s: float) -> float:
	return vp_y + floor_k * s


func ceil_y(s: float) -> float:
	return vp_y - ceil_k * s


## 평면 좌표(p, 깊이 s)가 지금 화면에 보이는 세계 자리(x는 하윤 줄의 세계 x).
func world_x(p: float, s: float) -> float:
	return screen_x(p, s, cam_left) + cam_left


func _ready() -> void:
	z_as_relative = false
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var xf := get_viewport().get_canvas_transform()
	cam_left = -xf.origin.x / maxf(xf.x.x, 0.001)
	visible = cam_left >= room_left - 1.0
	for child in get_children():
		var mat := (child as CanvasItem).material if child is CanvasItem else null
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("cam_left", cam_left)
		if child.has_method("update_view"):
			child.update_view(self)
