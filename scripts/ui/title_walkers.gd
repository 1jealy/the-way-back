extends Node2D
## 타이틀 화면 멀리 길 위를 걸어가는 하윤과 하늘이 실루엣(임시 그림).
## 인물 컷아웃 그림이 오면 그 그림을 작게 줄여 쓴다. 담당: A(게임플레이).

## 걷는 속도(px/초)와 다시 나타나기까지 쉬는 시간.
@export var speed: float = 38.0
@export var rest_seconds: float = 6.0
## 실루엣 크기(하윤 키, px).
@export var height: float = 118.0
@export var color: Color = Color(0.11, 0.07, 0.13, 0.95)

var _x: float = -160.0
var _rest: float = 0.0
var _step: float = 0.0


func _process(delta: float) -> void:
	if _rest > 0.0:
		_rest -= delta
		return
	_x += speed * delta
	_step += delta * speed / 22.0
	var width := get_viewport_rect().size.x
	if _x > width + 160.0:
		_x = -160.0
		_rest = rest_seconds
	queue_redraw()


func walker_x() -> float:
	return _x


func _draw() -> void:
	if _rest > 0.0:
		return
	var s := height / 92.0
	var bob := absf(sin(_step * PI)) * 2.0 * s
	_draw_girl(Vector2(_x, -bob), s)
	_draw_dog(Vector2(_x - 70.0 * s, -absf(sin(_step * PI + 1.2)) * 1.5 * s), s)


## 단발머리에 큰 외투를 입은 아이. 원점은 발밑.
func _draw_girl(at: Vector2, s: float) -> void:
	var swing := sin(_step * PI) * 9.0 * s
	# 다리
	draw_line(at + Vector2(-4, -26) * s, at + Vector2(-4.0 * s + swing, 0.0), color, 5.0 * s, true)
	draw_line(at + Vector2(4, -26) * s, at + Vector2(4.0 * s - swing, 0.0), color, 5.0 * s, true)
	# 외투(아래로 퍼지는 사다리꼴)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-10, -64) * s, at + Vector2(10, -64) * s,
		at + Vector2(17, -24) * s, at + Vector2(-17, -24) * s]), color)
	# 팔(외투 소매, 다리와 반대로 흔든다)
	draw_line(at + Vector2(-9, -60) * s, at + Vector2(-13.0 * s - swing * 0.6, -36.0 * s), color, 5.0 * s, true)
	draw_line(at + Vector2(9, -60) * s, at + Vector2(13.0 * s + swing * 0.6, -36.0 * s), color, 5.0 * s, true)
	# 머리와 단발
	draw_circle(at + Vector2(0, -76) * s, 12.0 * s, color)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-13, -80) * s, at + Vector2(13, -80) * s,
		at + Vector2(14, -66) * s, at + Vector2(-14, -66) * s]), color)


## 귀가 선 늙은 진돗개. 원점은 발밑, 오른쪽을 본다.
func _draw_dog(at: Vector2, s: float) -> void:
	var swing := sin(_step * PI + 1.2) * 6.0 * s
	# 앞뒤 다리 쌍이 엇갈려 움직인다: [다리 x, 흔드는 방향]
	for leg in [[-18.0, 1.0], [-10.0, -1.0], [12.0, -1.0], [20.0, 1.0]]:
		var lx: float = leg[0]
		draw_line(at + Vector2(lx, -16) * s, at + Vector2(lx * s + swing * leg[1], 0.0), color, 4.0 * s, true)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-24, -30) * s, at + Vector2(22, -32) * s,
		at + Vector2(24, -16) * s, at + Vector2(-22, -14) * s]), color)
	# 머리·주둥이·선 귀
	draw_circle(at + Vector2(28, -36) * s, 8.0 * s, color)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(32, -38) * s, at + Vector2(42, -34) * s, at + Vector2(32, -30) * s]), color)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(23, -41) * s, at + Vector2(25, -52) * s, at + Vector2(29, -42) * s]), color)
	# 말린 꼬리
	draw_arc(at + Vector2(-26, -36) * s, 6.0 * s, PI * 0.2, PI * 1.6, 10, color, 4.0 * s, true)
