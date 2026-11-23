class_name AmbientDust
extends CPUParticles2D
## 장소마다 아주 옅게 떠다니는 알갱이(#90): 집 안 햇빛 속 먼지, 들판에 날리는 씨앗.
## 카메라에 붙어 화면 둘레에서 생기고, 알갱이는 세계에 남는다(걸어가면 뒤로 흘러간다).
## 숲은 빛 알갱이(LightMotes)가 따로 있어 뺀다. main이 장소를 갈아 끼우면 set_place()를 부른다.
## 담당: A(게임플레이).

## place_id → 설정. 없는 장소는 끈다.
const SETTINGS := {
	&"house": {"amount": 28, "color": Color(1.0, 0.92, 0.74, 0.42), "dir": Vector2(0.3, -1.0),
			"speed": Vector2(4.0, 10.0), "life": 9.0, "size": Vector2(1.6, 3.4), "gravity": Vector2(0.0, -2.0)},
	&"field": {"amount": 16, "color": Color(1.0, 0.97, 0.9, 0.55), "dir": Vector2(1.0, -0.15),
			"speed": Vector2(40.0, 75.0), "life": 7.0, "size": Vector2(2.0, 4.0), "gravity": Vector2(0.0, 6.0)},
}
const FADE_SECONDS := 1.2

var place_id: StringName = &""
var _tween: Tween


func _ready() -> void:
	local_coords = false
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(1100.0, 620.0)
	spread = 25.0
	z_index = 4  # 하윤 앞, 앞 층(10) 뒤
	z_as_relative = false
	preprocess = 4.0
	emitting = false
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	scale_amount_curve = curve


func set_place(pid: StringName) -> void:
	place_id = pid
	var s: Dictionary = SETTINGS.get(pid, {})
	if _tween:
		_tween.kill()
	if s.is_empty():
		emitting = false
		return
	amount = s["amount"]
	color = s["color"]
	direction = s["dir"]
	initial_velocity_min = s["speed"].x
	initial_velocity_max = s["speed"].y
	lifetime = s["life"]
	scale_amount_min = s["size"].x
	scale_amount_max = s["size"].y
	gravity = s["gravity"]
	restart()
	emitting = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
