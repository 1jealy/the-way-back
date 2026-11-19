class_name MapData
extends RefCounted
## 할아버지 지도에 올라가는 것: 장소 자리, 동그라미, 메모.
## 문구를 고칠 때는 docs/design.md "지도의 다섯 동그라미" 표도 같이 고친다(글꼴 도구가 거기서도 글자를 모은다).
## 좌표는 지도 화면 기준(1920x1080). 그림이 오면 그림에 맞춰 이 숫자만 고친다. 담당: A(게임플레이).

## 1-5에서 지도를 얻으면 세운다. 그 전에는 M이 먹지 않는다.
const HAS_MAP_FLAG := &"has_map"

## 종이가 놓이는 자리(화면 좌표). 접힌 자국·강도 이 안에 그린다.
const PAPER_RECT := Rect2(90.0, 70.0, 1740.0, 940.0)

const HEADER := "하윤이랑 같이 갈 데"
const HEADER_POS := Vector2(190.0, 150.0)

## 걷는 순서(왼쪽 → 오른쪽). 길은 이 점들을 잇는다. label_offset은 장소 이름 자리(기본은 점 아래).
## dotted: 앞 장소에서 여기까지를 점선으로(철교 → 나루터: 하늘이가 찾아 주는 강둑 아래 좁은 길).
const PLACES := [
	{"id": &"house", "label": "집", "pos": Vector2(260.0, 660.0)},
	{"id": &"field", "label": "들판", "pos": Vector2(500.0, 560.0)},
	{"id": &"station", "label": "간이역", "pos": Vector2(760.0, 660.0)},
	{"id": &"forest", "label": "숲", "pos": Vector2(1020.0, 520.0)},
	{"id": &"riverside", "label": "강가", "pos": Vector2(1260.0, 640.0)},
	{"id": &"bridge", "label": "철교", "pos": Vector2(1450.0, 540.0), "label_offset": Vector2(-60.0, -62.0)},
	{"id": &"ferry", "label": "나루터", "pos": Vector2(1540.0, 800.0), "label_offset": Vector2(-150.0, -20.0), "dotted": true},
]

## 동그라미 다섯. 번호는 1부터. child = 하윤 글씨.
const CIRCLES := [
	{"place": &"field", "note": "바람 셈. 지도 꽉 잡아라.", "note_pos": Vector2(330.0, 420.0), "child": false},
	{"place": &"station", "note": "기차 안 와도 여기 앉아 있으면 좋다.", "note_pos": Vector2(560.0, 760.0), "child": false},
	{"place": &"forest", "note": "해 지고 조금만 기다려. 금방 환해진다.", "note_pos": Vector2(840.0, 380.0), "child": false},
	{"place": &"riverside", "note": "물수제비. 할아버지 다섯 번, 하윤이는?", "note_pos": Vector2(880.0, 830.0), "child": false},
	{"place": &"ferry", "note": "다나으면 여기 꼭!", "note_pos": Vector2(1300.0, 900.0), "child": true},
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


## 길 위의 한 점. progress는 0(집) ~ PLACES.size() - 1(나루터), 소수는 다음 장소까지의 비율.
static func route_point(progress: float) -> Vector2:
	var last := PLACES.size() - 1
	var p := clampf(progress, 0.0, float(last))
	var i := mini(int(floor(p)), last - 1)
	var a: Vector2 = PLACES[i]["pos"]
	var b: Vector2 = PLACES[i + 1]["pos"]
	return a.lerp(b, p - float(i))
