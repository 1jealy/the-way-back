class_name Cutout
extends Node2D
## 인물 컷아웃 조립(기획서 "PNG 조각을 이름 규칙으로 조립하는 도구"). tools/psd_split.py가 만든
## assets/art/char/<인물>/char_<인물>.json과 조각 PNG를 읽어, PSD에서 본 모습 그대로 Sprite2D로 맞춘다.
## - 원점(이 노드 자리) = PSD 캔버스 아래 가운데 = 발밑. art_scale로 게임 크기에 맞춘다.
## - 바꿔 끼우는 조각: 이름이 <무리>_<상태>이고 무리가 SWAP_GROUPS에 있으면(eye_open, eye_closed …)
##   한 번에 하나만 보인다. set_state("eye", "closed"). 처음에는 DEFAULT_STATES 또는 첫 조각.
## - 자세: 맨 앞 이름이 poses에 있으면(stand_body, sit_body …) set_pose("sit")로 그 자세 조각만 보인다.
## - 눈 깜빡임: blink가 켜져 있고 eye_closed가 있으면 가끔 eye_half → eye_closed → eye_half → 원래 눈.
## 관절(Skeleton2D)·움직임(AnimationPlayer)은 그림 담당과 관절 자리를 정한 뒤 이 위에 더한다.
## 담당: A(인물). (A 세션이 쉬는 동안 B 세션이 만듦)

signal built
signal blinked

const ART_DIR := "res://assets/art/char"
const SWAP_GROUPS := ["eye", "mouth", "brow"]
const DEFAULT_STATES := {"eye": "open", "mouth": "neutral", "brow": "neutral"}

## 인물 이름(PSD 맨 위 폴더 이름: hayun, dog, grandpa).
@export var character: String = ""
## 조각 폴더. 비우면 ART_DIR/<character>.
@export var art_dir: String = ""
## PSD 1px이 게임에서 몇 px인가.
@export var art_scale: float = 1.0
## 이 이름들로 시작하는 조각은 자세 조각이다(stand_, sit_ …). 비우면 자세 없음.
@export var poses: PackedStringArray = PackedStringArray()
@export var blink: bool = true
## 눈 깜빡임 사이(초, 무작위).
@export var blink_every: Vector2 = Vector2(2.5, 6.0)

## 부위 이름 → Sprite2D
var parts: Dictionary = {}
var canvas: Vector2 = Vector2.ZERO
var pose: String = ""
## 무리 → 지금 상태
var states: Dictionary = {}
var _blink_left: float = 0.0
var _blinking: bool = false


func _ready() -> void:
	if not character.is_empty():
		build()
	_blink_left = randf_range(blink_every.x, blink_every.y)


## 그 인물의 조각이 들어 있나(진짜 그림이 왔나).
static func has_art(who: String, dir: String = "") -> bool:
	var d := dir if not dir.is_empty() else ART_DIR.path_join(who)
	return FileAccess.file_exists(d.path_join("char_%s.json" % who))


## JSON을 읽어 조각을 붙인다. 이미 붙어 있으면 다시 만든다. 성공하면 true.
func build() -> bool:
	for s in parts.values():
		(s as Node).queue_free()
	parts.clear()
	var dir := art_dir if not art_dir.is_empty() else ART_DIR.path_join(character)
	var json_path := dir.path_join("char_%s.json" % character)
	if not FileAccess.file_exists(json_path):
		push_warning("컷아웃 조각이 없다: %s" % json_path)
		return false
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(meta) != TYPE_DICTIONARY or not meta.has("parts"):
		push_warning("컷아웃 JSON을 읽을 수 없다: %s" % json_path)
		return false
	canvas = Vector2(meta.canvas[0], meta.canvas[1])
	var origin := Vector2(canvas.x * 0.5, canvas.y)  # 캔버스 아래 가운데 = 발밑
	var names: Array = meta.parts.keys()
	names.sort_custom(func(a, b): return meta.parts[a].z < meta.parts[b].z)
	for part in names:
		var m: Dictionary = meta.parts[part]
		var tex := _load_texture(dir.path_join("char_%s_%s.png" % [character, part]))
		if tex == null:
			push_warning("컷아웃 조각 그림이 없다: %s/%s" % [character, part])
			continue
		var s := Sprite2D.new()
		s.name = part
		s.texture = tex
		s.centered = false
		s.position = (Vector2(m.x, m.y) - origin) * art_scale
		s.scale = Vector2(art_scale, art_scale)
		add_child(s)
		parts[part] = s
	# 바꿔 끼우는 무리는 처음 상태 하나만
	for group in SWAP_GROUPS:
		var choices := group_states(group)
		if choices.is_empty():
			continue
		var want: String = DEFAULT_STATES.get(group, "")
		set_state(group, want if want in choices else choices[0])
	if not poses.is_empty():
		set_pose(poses[0])
	built.emit()
	return not parts.is_empty()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):  # 가져오기 전(user:// 검사 등)
		var img := Image.load_from_file(path)
		return ImageTexture.create_from_image(img) if img else null
	return null


## 무리(eye 등)의 상태 이름들. 자세가 있으면 지금 자세의 것만.
func group_states(group: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part: String in parts:
		var base := _without_pose(part)
		if base.begins_with(group + "_"):
			var state := base.substr(group.length() + 1)
			if state not in out:
				out.append(state)
	return out


func set_state(group: String, state: String) -> void:
	states[group] = state
	_refresh()


func set_pose(p: String) -> void:
	pose = p
	_refresh()


func _without_pose(part: String) -> String:
	for p in poses:
		if part.begins_with(p + "_"):
			return part.substr(p.length() + 1)
	return part


func _pose_of(part: String) -> String:
	for p in poses:
		if part.begins_with(p + "_"):
			return p
	return ""


func _refresh() -> void:
	for part: String in parts:
		var show := true
		var part_pose := _pose_of(part)
		if not part_pose.is_empty() and part_pose != pose:
			show = false
		var base := _without_pose(part)
		for group in SWAP_GROUPS:
			if base.begins_with(group + "_") and states.has(group):
				show = show and base == "%s_%s" % [group, states[group]]
		(parts[part] as CanvasItem).visible = show


func _process(delta: float) -> void:
	if not blink or _blinking or parts.is_empty():
		return
	_blink_left -= delta
	if _blink_left <= 0.0:
		_blink_left = randf_range(blink_every.x, blink_every.y)
		do_blink()


## 눈을 한 번 깜빡인다(eye_closed가 없으면 아무것도 안 한다).
func do_blink() -> void:
	var choices := group_states("eye")
	if _blinking or "closed" not in choices:
		return
	_blinking = true
	var was: String = states.get("eye", "open")
	var steps: Array = ["half", "closed", "half"] if "half" in choices else ["closed"]
	for st in steps:
		set_state("eye", st)
		await get_tree().create_timer(0.05, false).timeout
	set_state("eye", was)
	_blinking = false
	blinked.emit()
