class_name WhistleTune
extends RefCounted
## 할아버지 휘파람 선율(#145, 기획서 "할아버지 휘파람 따라 하기"). 게임 전체에서 이 한 곳에만 적는다.
## 장소마다 한 소절을 따라 하고, 배 위(7-6)에서 소절을 이어 붙인 전체 선율이 나온다.
## 소절 하나는 높이가 셋뿐이다(← 낮은 음 · E 가운데 음 · → 높은 음). 소절 안에서 가장 낮은 음이 0, 가장 높은 음이 2.
## 들판 소절은 숲 소절의 앞 세 음이다(들판에서 배운 것을 숲에서 이어 분다).
##
## 임시 소리 도구(tools/placeholder_sound.py)가 아래 TUNE BEGIN ~ TUNE END 사이를 JSON으로 읽어
## 기억 장면 소절(mus_phrase_N)·배 위 전체 선율(mus_theme_full)·집 라디오를 만든다. 고치면 그 도구를 다시 돌린다.

# TUNE BEGIN
const PHRASES := {
	"field": [[67, 0.6], [69, 0.6], [72, 1.2]],
	"forest": [[67, 0.6], [69, 0.6], [72, 0.9], [69, 1.2]],
	"riverside": [[74, 0.6], [72, 0.6], [69, 0.9], [72, 1.2]],
	"bridge": [[72, 0.6], [69, 0.6], [67, 0.9], [69, 0.6], [67, 1.6]]
}
# TUNE END

## 배 위 전체 선율의 순서. 들판 소절은 숲 소절 안에 들어 있다.
const FULL := ["forest", "riverside", "bridge"]


static func notes(id: StringName) -> Array:
	return PHRASES.get(String(id), [])


## 소절의 음 높이(MIDI)를 낮은 것부터, 겹치지 않게.
static func pitches(id: StringName) -> Array:
	var out: Array = []
	for n in notes(id):
		if not out.has(int(n[0])):
			out.append(int(n[0]))
	out.sort()
	return out


## 소절을 ← E → 높이(0·1·2)로. 높이가 둘뿐인 소절은 0·2를 쓴다.
static func levels(id: StringName) -> PackedInt32Array:
	var ps := pitches(id)
	var out := PackedInt32Array()
	for n in notes(id):
		var k := ps.find(int(n[0]))
		out.append(1 if ps.size() == 1 else (k if ps.size() == 3 else k * 2))
	return out


## 높이(0·1·2)의 주파수.
static func level_hz(id: StringName, level: int) -> float:
	var ps := pitches(id)
	if ps.is_empty():
		return 440.0
	var midi: int = ps[clampi(level, 0, 2)] if ps.size() == 3 else (ps[0] if level < 1 else ps[ps.size() - 1])
	return midi_hz(midi)


static func midi_hz(midi: int) -> float:
	# 휘파람은 적힌 음보다 한 옥타브 위로 분다(임시 소리 도구와 같다).
	return 440.0 * pow(2.0, float(midi + 12 - 69) / 12.0)
