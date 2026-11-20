class_name MapData
extends RefCounted
## 할아버지 지도에 올라가는 것: 장소 자리, 동그라미, 메모.
## 문구를 고칠 때는 docs/design.md "지도의 다섯 동그라미" 표도 같이 고친다(글꼴 도구가 거기서도 글자를 모은다).
## 좌표는 지도 화면 기준(1920x1080). 그림이 오면 그림에 맞춰 이 숫자만 고친다. 담당: A(게임플레이).

## 1-5에서 지도를 얻으면 세운다. 그 전에는 M이 먹지 않는다.
const HAS_MAP_FLAG := &"has_map"

## 종이가 놓이는 자리(화면 좌표). 지도 그림(16:9)이 이 크기로 깔린다.
const PAPER_RECT := Rect2(90.0, 50.0, 1740.0, 980.0)
## 일러스트레이터의 지도 그림. 있으면 종이·강·철교·장소 그림은 이것으로 그리고, 아래 좌표는 이 그림에 맞춘다.
## 지금은 미리보기(1080x608 JPEG). 최종본은 1920x1080 이상 PNG로 바꾼다.
const PAPER_ART := "res://assets/art/map/map_paper_preview.jpg"

const HEADER := "하윤이랑 같이 갈 데"
const HEADER_POS := Vector2(560.0, 92.0)

## 걷는 순서(왼쪽 → 오른쪽). 길은 이 점들을 잇는다. label_offset은 장소 이름 자리(기본은 점 아래).
## bend: 앞 장소에서 여기까지 길이 옆으로 휘는 정도(px, 부호는 방향). wiggle: 그 위에 얹는 꼬불꼬불함(px).
## dotted: 앞 장소에서 여기까지를 점선으로(철교 → 나루터: 하늘이가 찾아 주는 강둑 아래 좁은 길).
const PLACES := [
	{"id": &"house", "label": "집", "pos": Vector2(265.0, 245.0)},
	{"id": &"field", "label": "들판", "pos": Vector2(420.0, 640.0), "bend": -60.0},
	{"id": &"station", "label": "간이역", "pos": Vector2(770.0, 870.0), "bend": 40.0},
	{"id": &"forest", "label": "숲", "pos": Vector2(830.0, 610.0), "label_offset": Vector2(-150.0, -20.0), "bend": -30.0, "wiggle": 10.0},
	{"id": &"riverside", "label": "강가", "pos": Vector2(1190.0, 700.0), "bend": 40.0},
	{"id": &"bridge", "label": "철교", "pos": Vector2(1500.0, 500.0), "label_offset": Vector2(-60.0, -62.0), "bend": -30.0},
	{"id": &"ferry", "label": "나루터", "pos": Vector2(1490.0, 880.0), "label_offset": Vector2(-170.0, -20.0), "dotted": true, "bend": 30.0},
]

## 하윤이 가지 않는 길. 지도가 노선도가 아니라 동네 지도로 보이게 한다.
## kind: "road" 큰길 / "trail" 점선 오솔길 / "rail" 철길(사다리 무늬).
## from_route: [구간, t] — 길 위 그 자리에서 갈라져 나온다(첫 점 앞에 붙는다).
const SIDE_ROADS := [
	{"kind": "road", "points": [Vector2(265.0, 245.0), Vector2(215.0, 185.0), Vector2(170.0, 145.0), Vector2(135.0, 120.0)],
		"label": "읍내", "label_pos": Vector2(140.0, 82.0)},
	{"kind": "trail", "from_route": [0, 0.55], "points": [Vector2(430.0, 420.0), Vector2(500.0, 360.0), Vector2(540.0, 320.0)],
		"label": "산", "label_pos": Vector2(550.0, 270.0)},
	{"kind": "rail", "points": [Vector2(640.0, 955.0), Vector2(770.0, 900.0), Vector2(930.0, 850.0)],
		"label": "", "label_pos": Vector2.ZERO},
]

## 작은 그림 표시(코드로 그리는 기호). 그림이 오면 지운다.
const HOUSE_ICON := Vector2(260.0, 618.0)
const MOUNTAINS := [Vector2(290.0, 290.0), Vector2(345.0, 300.0), Vector2(400.0, 285.0)]
const POLES := [Vector2(330.0, 600.0), Vector2(410.0, 560.0), Vector2(590.0, 575.0), Vector2(680.0, 615.0)]
const TREES := [Vector2(940.0, 480.0), Vector2(965.0, 610.0), Vector2(1160.0, 470.0), Vector2(1100.0, 590.0), Vector2(1135.0, 530.0)]
const REEDS := [Vector2(1180.0, 600.0), Vector2(1330.0, 690.0), Vector2(1360.0, 670.0)]

## 동그라미 다섯. 번호는 1부터. child = 하윤 글씨.
const CIRCLES := [
	{"place": &"field", "note": "바람 셈. 지도 꽉 잡아라.", "note_pos": Vector2(120.0, 455.0), "child": false},
	{"place": &"station", "note": "기차 안 와도 여기 앉아 있으면 좋다.", "note_pos": Vector2(300.0, 975.0), "child": false},
	{"place": &"forest", "note": "해 지고 조금만 기다려. 금방 환해진다.", "note_pos": Vector2(560.0, 740.0), "child": false},
	{"place": &"riverside", "note": "물수제비. 할아버지 다섯 번, 하윤이는?", "note_pos": Vector2(900.0, 975.0), "child": false},
	{"place": &"ferry", "note": "다나으면 여기 꼭!", "note_pos": Vector2(1530.0, 790.0), "child": true},
]

## 강(세로 띠)과 그 너머 빈 종이. 철교는 강을 건너 빈 종이 쪽으로 이어진다.
const RIVER_X := 1580.0
const RIVER_W := 70.0
const BRIDGE_END_X := 1720.0
## 나루터에 매인 작은 배. 뱃머리는 강 건너(빈 종이) 쪽.
const BOAT_POS := Vector2(1630.0, 870.0)


static func circle_flag(n: int) -> StringName:
	return StringName("map_circle_%d" % n)


static func place_index(place_id: StringName) -> int:
	for i in PLACES.size():
		if PLACES[i]["id"] == place_id:
			return i
	return -1


static func place_pos(place_id: StringName) -> Vector2:
	var i := place_index(place_id)
	return PLACES[i]["pos"] if i >= 0 else Vector2.ZERO


static func circle_pos(n: int) -> Vector2:
	return place_pos(CIRCLES[n - 1]["place"])


## 장소 i에서 i+1까지 길 위의 한 점(t: 0~1). 지도 길과 지나온 길이 같은 곡선을 쓴다.
static func segment_point(i: int, t: float) -> Vector2:
	var a: Vector2 = PLACES[i]["pos"]
	var b: Vector2 = PLACES[i + 1]["pos"]
	var to: Dictionary = PLACES[i + 1]
	var normal := (b - a).orthogonal().normalized()
	var control := (a + b) * 0.5 + normal * float(to.get("bend", 0.0))
	var u := 1.0 - t
	var p := a * u * u + control * 2.0 * u * t + b * t * t
	var wiggle := float(to.get("wiggle", 0.0))
	if wiggle > 0.0:
		p += normal * sin(t * TAU * 2.0) * sin(t * PI) * wiggle
	return p


## 가지 않는 길의 점들. from_route가 있으면 길 위 갈림 자리를 앞에 붙인다.
static func side_road_points(road: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array(road["points"])
	if road.has("from_route"):
		var at: Array = road["from_route"]
		pts.insert(0, segment_point(int(at[0]), float(at[1])))
	return pts


static func is_dotted(i: int) -> bool:
	return PLACES[i + 1].get("dotted", false)


## 길 위의 한 점. progress는 0(집) ~ PLACES.size() - 1(나루터), 소수는 다음 장소까지의 비율.
static func route_point(progress: float) -> Vector2:
	var last := PLACES.size() - 1
	var p := clampf(progress, 0.0, float(last))
	var i := mini(int(floor(p)), last - 1)
	return segment_point(i, p - float(i))
