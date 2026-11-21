class_name PlayerShadow
extends CanvasGroup
## 하윤 그림자. 장소를 지날수록 옅어진다(기획서 복선 "해가 지니까" → 이승에서 멀어진다).
## 들판(2-1)에서는 억새·전봇대 그림자보다 조금 옅고, 숲(4-1)부터는 거의 없다(장면표).
## 하윤 모습(Visual)을 복사해 땅에 눕혀(기울이고 납작하게) 그린다. CanvasGroup이라 겹친 조각도 한 장처럼 같은 진하기.
## 장소마다 해 방향·길이·진하기는 SETTINGS에 있다. 인물 컷아웃이 들어오면 복사·맞추기를 다시 본다.
## 담당: A(하윤). (A 세션이 쉬는 동안 B 세션이 만듦)

## place_id → [진하기(0~1), 길이(px, +면 왼쪽으로 눕는다), 납작함(-면 땅 앞쪽으로, 임시 배경의 전봇대 그림자와 같은 쪽)]
## 해: 집은 왼쪽 창(오른쪽으로 짧게), 들판·간이역은 오른쪽 낮게(왼쪽으로 길게). 숲부터는 해가 졌다.
const SETTINGS := {
	&"house": [0.30, -90.0, -0.13],
	&"field": [0.26, 420.0, -0.13],
	&"station": [0.20, 520.0, -0.13],
	&"forest": [0.04, 60.0, -0.13],
	&"riverside": [0.06, 80.0, -0.13],
	&"bridge": [0.03, 60.0, -0.13],
	&"ferry": [0.0, 0.0, -0.13],
	&"crossing": [0.0, 0.0, -0.13],
}
const FALLBACK := [0.2, 200.0, -0.13]
## 장소가 바뀌면 이만큼에 걸쳐 바뀐다(초).
const CHANGE_SECONDS := 1.2

var strength: float = 0.0
var _place_id: StringName = &""
var _copy: Node2D
var _tween: Tween


func _ready() -> void:
	z_index = -1  # 하윤 뒤, 땅·물건 위
	z_as_relative = false
	self_modulate = Color(0.08, 0.06, 0.08, 0.0)
	var visual := get_parent().get_node_or_null("Visual") as Node2D
	if visual:
		_copy = visual.duplicate(0) as Node2D
		_copy.name = "Visual"
		add_child(_copy)
		_blacken(_copy)


func _blacken(node: Node) -> void:
	if node is Polygon2D:
		(node as Polygon2D).color = Color.WHITE  # 색은 self_modulate 하나로
	elif node is CanvasItem:
		(node as CanvasItem).modulate = Color.WHITE
	for child in node.get_children():
		_blacken(child)


func _process(_delta: float) -> void:
	var place := get_tree().get_first_node_in_group("place") as Node
	var pid: StringName = place.get("place_id") if place else &""
	if pid != _place_id:
		_place_id = pid
		_apply(SETTINGS.get(pid, FALLBACK), not is_zero_approx(self_modulate.a))
	var visual := get_parent().get_node_or_null("Visual") as Node2D
	if visual and _copy:
		_sync(visual, _copy)


## [진하기, 길이, 납작함]을 그림자에 건다. 하윤 키(약 200px) 높이가 길이만큼 옆으로 눕는다.
func _apply(s: Array, smooth: bool) -> void:
	strength = s[0]
	var lean: float = s[1] / 200.0
	transform = Transform2D(Vector2(1.0, 0.0), Vector2(lean, float(s[2])), Vector2.ZERO)
	if _tween:
		_tween.kill()
	if smooth:
		_tween = create_tween()
		_tween.tween_property(self, "self_modulate:a", strength, CHANGE_SECONDS)
	else:
		self_modulate.a = strength


func _sync(src: Node, dst: Node) -> void:
	if src is Node2D and dst is Node2D:
		(dst as Node2D).transform = (src as Node2D).transform
		(dst as Node2D).visible = (src as Node2D).visible
	var n := mini(src.get_child_count(), dst.get_child_count())
	for i in n:
		_sync(src.get_child(i), dst.get_child(i))
