class_name MapCanvas
extends Control
## 지도 종이 위에 그리는 것: 접힌 자국, 강, 철교, 길, 동그라미, 체크, 하윤이 지나온 길, 글.
## 그림이 오기 전 임시 지도다. 그림이 오면 종이·길·장소 그림은 텍스처로 바꾸고
## 동그라미·체크·지나온 길·메모만 여기서 그린다. 담당: A(게임플레이).

const PENCIL := Color(0.24, 0.22, 0.2, 0.85)
const PENCIL_LIGHT := Color(0.24, 0.22, 0.2, 0.35)
## 하윤이 덧그리는 색연필.
const TRAIL := Color(0.72, 0.3, 0.26, 0.85)
const CHECK := Color(0.72, 0.3, 0.26, 1.0)
const RIVER := Color(0.36, 0.48, 0.58, 0.55)
const NOTE_COLOR := Color(0.2, 0.18, 0.16, 1.0)
const CHILD_COLOR := Color(0.18, 0.24, 0.42, 1.0)
const CIRCLE_RADIUS := 50.0

## 하윤이 지나온 정도(MapData.route_point 참고). 음수면 그리지 않는다.
var progress: float = -1.0:
	set(value):
		progress = value
		queue_redraw()
## 동그라미 번호 → 체크가 그어진 정도(0~1).
var checks: Dictionary = {}

var _note_labels: Array[Label] = []
var _header_label: Label
## 일러스트레이터의 지도 그림(종이·장소 그림). 있으면 접힌 자국·강·철교·기호·배는 그리지 않는다.
var _paper: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(MapData.PAPER_ART):
		_paper = load(MapData.PAPER_ART)
	_header_label = _make_label(MapData.HEADER, MapData.HEADER_POS, 40, NOTE_COLOR)
	_header_label.name = "Header"
	for i in MapData.PLACES.size():
		var place: Dictionary = MapData.PLACES[i]
		var offset: Vector2 = place.get("label_offset", Vector2(-60.0, 62.0))
		var label := _make_label(place["label"], place["pos"] + offset, 26 if _paper else 22, PENCIL)
		label.name = "Place_%s" % place["id"]
		label.custom_minimum_size.x = 120.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for road in MapData.SIDE_ROADS:
		if not String(road["label"]).is_empty():
			var side := _make_label(road["label"], road["label_pos"], 24 if _paper else 22,
					PENCIL if _paper else PENCIL_LIGHT)
			side.name = "Side_%s" % road["label"]
	for n in range(1, MapData.CIRCLES.size() + 1):
		var c: Dictionary = MapData.CIRCLES[n - 1]
		var child: bool = c["child"]
		var label := _make_label(c["note"], c["note_pos"], 36 if child else 28,
				CHILD_COLOR if child else NOTE_COLOR)
		label.name = "Note_%d" % n
		if child:
			label.rotation = -0.09
		_note_labels.append(label)


func note_label(n: int) -> Label:
	return _note_labels[n - 1]


func set_check(n: int, amount: float) -> void:
	checks[n] = clampf(amount, 0.0, 1.0)
	queue_redraw()


func _make_label(text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _paper:  # 그림 위에서도 읽히게 종이색 테두리
		label.add_theme_color_override("font_outline_color", Color(0.96, 0.86, 0.64, 0.85))
		label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


## 연필 선처럼 살짝 흔들리게. 같은 입력이면 늘 같은 모양.
func _wobble(p: Vector2, seed_value: float) -> Vector2:
	return p + Vector2(sin(p.y * 0.05 + seed_value) * 2.0, cos(p.x * 0.05 + seed_value) * 2.0)


func has_paper_art() -> bool:
	return _paper != null


func _draw() -> void:
	if _paper:
		draw_texture_rect(_paper, MapData.PAPER_RECT, false)
	else:
		_draw_folds()
		_draw_symbols()
	_draw_side_roads()
	if not _paper:
		_draw_river()
	_draw_route()
	_draw_trail()
	for n in range(1, MapData.CIRCLES.size() + 1):
		_draw_circle_mark(n)


func _draw_folds() -> void:
	var r := MapData.PAPER_RECT
	var fold := Color(0.45, 0.38, 0.28, 0.18)
	for k in [1.0 / 3.0, 2.0 / 3.0]:
		var x: float = r.position.x + r.size.x * k
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), fold, 3.0)
	var y := r.position.y + r.size.y * 0.5
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), fold, 3.0)


func _draw_river() -> void:
	for side in [0.0, MapData.RIVER_W]:
		var pts := PackedVector2Array()
		var y := MapData.PAPER_RECT.position.y + 20.0
		while y <= MapData.PAPER_RECT.end.y - 20.0:
			pts.append(Vector2(MapData.RIVER_X + side + sin(y * 0.012) * 24.0, y))
			y += 20.0
		draw_polyline(pts, RIVER, 3.0, true)
	# 철교: 강을 건너 빈 종이 쪽으로. 다리 끝 너머로는 아무것도 그리지 않는다.
	var from: Vector2 = MapData.place_pos(&"bridge")
	var to := Vector2(MapData.BRIDGE_END_X, from.y)
	draw_line(from + Vector2(0.0, -8.0), to + Vector2(0.0, -8.0), PENCIL, 2.0, true)
	draw_line(from + Vector2(0.0, 8.0), to + Vector2(0.0, 8.0), PENCIL, 2.0, true)
	var x := from.x + 10.0
	while x < to.x:
		draw_line(Vector2(x, from.y - 8.0), Vector2(x + 6.0, from.y + 8.0), PENCIL_LIGHT, 1.5, true)
		x += 18.0


func _draw_route() -> void:
	for i in MapData.PLACES.size() - 1:
		var pts := PackedVector2Array()
		for s in 41:
			pts.append(MapData.segment_point(i, s / 40.0))
		if MapData.is_dotted(i):
			_draw_dashed(pts)
		else:
			if not MapData.PLACES[i + 1].has("wiggle"):
				for k in pts.size():
					pts[k] = _wobble(pts[k], 1.3)
			draw_polyline(pts, PENCIL, 3.0, true)
	for place in MapData.PLACES:
		draw_circle(place["pos"], 6.0, PENCIL)
	if not _paper:
		_draw_boat()


## 점들을 이은 선을 일정한 간격의 짧은 선으로 그린다.
func _draw_dashed(pts: PackedVector2Array, color: Color = PENCIL, dash: float = 10.0, gap: float = 12.0) -> void:
	var drawing := true
	var left := dash
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg:
			var step := minf(left, seg - pos)
			if drawing:
				draw_line(a.lerp(b, pos / seg), a.lerp(b, (pos + step) / seg), color, 3.0, true)
			pos += step
			left -= step
			if left <= 0.0:
				drawing = not drawing
				left = dash if drawing else gap


## 하윤이 가지 않는 길: 큰길 / 점선 오솔길 / 철길.
func _draw_side_roads() -> void:
	for road in MapData.SIDE_ROADS:
		var pts := MapData.side_road_points(road)
		match road["kind"]:
			"road":
				var wobbly := PackedVector2Array()
				for k in pts.size():
					wobbly.append(_wobble(pts[k], 2.7))
				draw_polyline(wobbly, PENCIL_LIGHT, 4.0, true)
			"trail":
				_draw_dashed(pts, PENCIL_LIGHT, 8.0, 10.0)
			"rail":
				draw_polyline(pts, PENCIL_LIGHT, 2.0, true)
				for k in pts.size() - 1:
					var a := pts[k]
					var b := pts[k + 1]
					var n := (b - a).orthogonal().normalized() * 9.0
					var steps := int(a.distance_to(b) / 16.0)
					for j in steps:
						var c := a.lerp(b, float(j) / float(steps))
						draw_line(c - n, c + n, PENCIL_LIGHT, 2.0, true)


## 작은 그림 표시. 지도 그림이 오면 지운다.
func _draw_symbols() -> void:
	var h := MapData.HOUSE_ICON
	draw_polyline(PackedVector2Array([h + Vector2(-16, 12), h + Vector2(-16, -2), h + Vector2(0, -16),
			h + Vector2(16, -2), h + Vector2(16, 12), h + Vector2(-16, 12)]), PENCIL, 2.5, true)
	for m in MapData.MOUNTAINS:
		draw_polyline(PackedVector2Array([m + Vector2(-34, 20), m + Vector2(0, -26), m + Vector2(34, 20)]),
				PENCIL_LIGHT, 2.5, true)
	for pole in MapData.POLES:
		draw_line(pole + Vector2(0, 14), pole + Vector2(0, -22), PENCIL_LIGHT, 2.0, true)
		draw_line(pole + Vector2(-9, -16), pole + Vector2(9, -16), PENCIL_LIGHT, 2.0, true)
	for t in MapData.TREES:
		draw_arc(t + Vector2(0, -10), 12.0, 0.0, TAU, 14, PENCIL_LIGHT, 2.0, true)
		draw_line(t + Vector2(0, 2), t + Vector2(0, 14), PENCIL_LIGHT, 2.0, true)
	for r in MapData.REEDS:
		for dx in [-8.0, 0.0, 8.0]:
			draw_line(r + Vector2(dx * 0.4, 10), r + Vector2(dx, -10), RIVER, 2.0, true)


## 나루터에 매인 작은 배. 뱃머리가 오른쪽(강 건너)을 본다.
func _draw_boat() -> void:
	var c := MapData.BOAT_POS
	var hull := PackedVector2Array([
		c + Vector2(-34.0, -6.0), c + Vector2(-26.0, 8.0), c + Vector2(22.0, 8.0),
		c + Vector2(40.0, -10.0), c + Vector2(-34.0, -6.0)])
	draw_polyline(hull, PENCIL, 3.0, true)
	draw_line(c + Vector2(-60.0, -6.0), c + Vector2(-34.0, -6.0), PENCIL_LIGHT, 2.0, true)


func _draw_trail() -> void:
	if progress < 0.0:
		return
	var pts := PackedVector2Array()
	var p := 0.0
	while p < progress:
		pts.append(_wobble(MapData.route_point(p), 4.1) + Vector2(0.0, 6.0))
		p += 0.08
	pts.append(_wobble(MapData.route_point(progress), 4.1) + Vector2(0.0, 6.0))
	if pts.size() >= 2:
		draw_polyline(pts, TRAIL, 4.0, true)


func _draw_circle_mark(n: int) -> void:
	var c := MapData.circle_pos(n)
	var child: bool = MapData.CIRCLES[n - 1]["child"]
	var pts := PackedVector2Array()
	# 손으로 그린 동그라미: 한 바퀴를 조금 넘겨 겹치게, 반지름이 살짝 흔들린다.
	var steps := 40
	for s in steps + 4:
		var a := TAU * float(s) / float(steps) - 1.2
		var r := CIRCLE_RADIUS + sin(a * 3.0 + n) * (6.0 if child else 3.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, CHILD_COLOR if child else PENCIL, 4.0 if child else 3.0, true)
	var t: float = checks.get(n, 0.0)
	if t <= 0.0:
		return
	# 체크 표시: 짧게 내려갔다가 길게 올라간다.
	var a0 := c + Vector2(26.0, -40.0)
	var a1 := c + Vector2(42.0, -22.0)
	var a2 := c + Vector2(76.0, -78.0)
	var first := clampf(t / 0.35, 0.0, 1.0)
	draw_line(a0, a0.lerp(a1, first), CHECK, 6.0, true)
	if t > 0.35:
		var second := clampf((t - 0.35) / 0.65, 0.0, 1.0)
		draw_line(a1, a1.lerp(a2, second), CHECK, 6.0, true)
