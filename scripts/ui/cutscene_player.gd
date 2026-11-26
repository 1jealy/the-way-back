class_name CutscenePlayer
extends CanvasLayer
## 손그림 컷신 재생(장면표 7-4, 7-7). 한 장짜리 그림 위에 천천히 움직이는 카메라(확대·이동)와
## 글자를 얹는다(기획서 "애니메이션"). 글자는 그림에 그리지 않고 글꼴로 얹는다(팔찌 "이하윤 / 9세").
## 대사 상자(Overlay, 층 10)보다 아래 층에 둬서 컷신 위로 대사가 보인다.
## 담당: B(컷신 재생). (그림 찾기는 assets/art 아래 진짜 그림 → placeholder 순)

signal finished

const LAYER := 5
const ART_DIR := "res://assets/art"

var _holder: Control


## 그림 이름(확장자 뺀 것, 예: "cut_bracelet")으로 assets/art 아래에서 찾는다. 진짜 그림 → SVG 소품 → placeholder.
static func find_art(stem: String) -> String:
	# 진짜 그림(png·jpg·webp) → SVG 소품(#111, assets/art/prop) → placeholder 순
	var found := ""
	var vector := ""
	var stack: Array[String] = [ART_DIR]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for file in DirAccess.get_files_at(dir):
			var name := file.trim_suffix(".import").trim_suffix(".remap")
			if name.get_basename() != stem:
				continue
			var ext := name.get_extension()
			var path := dir.path_join(name)
			if ext == "svg":
				vector = path
			elif ext in ["png", "jpg", "webp"]:
				if not path.contains("/placeholder/"):
					return path
				found = path
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
	return vector if not vector.is_empty() else found


## spec: art(그림 이름), seconds(카메라가 움직이는 시간), zoom(Vector2 시작·끝 배율),
## pan(시작·끝 이동 px, Vector2 두 개), texts([{text, pos, size, color, rotation}] — 그림 좌표 1920x1080),
## lines(카메라가 멈춘 뒤 대사), white_out(true면 끝에 하얗게 번지며 사라진다).
func play(spec: Dictionary) -> void:
	layer = LAYER
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate.a = 0.0
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.pivot_offset = Vector2(960, 540)
	root.add_child(_holder)
	var path := find_art(String(spec.get("art", "")))
	if not path.is_empty():
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.size = Vector2(1920, 1080)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_holder.add_child(tex)
	for t in spec.get("texts", []):
		var label := Label.new()
		label.text = t["text"]
		label.position = t["pos"]
		label.rotation = t.get("rotation", 0.0)
		label.add_theme_font_size_override("font_size", t.get("size", 32))
		label.add_theme_color_override("font_color", t.get("color", Color(0.2, 0.2, 0.25)))
		_holder.add_child(label)
	var zoom: Vector2 = spec.get("zoom", Vector2(1.0, 1.08))
	var pan: Array = spec.get("pan", [Vector2.ZERO, Vector2.ZERO])
	var seconds: float = spec.get("seconds", 6.0)
	_holder.scale = Vector2.ONE * zoom.x
	_holder.position = pan[0]

	await create_tween().tween_property(root, "modulate:a", 1.0, 1.0).finished
	var cam := create_tween().set_parallel()
	cam.tween_property(_holder, "scale", Vector2.ONE * zoom.y, seconds).set_trans(Tween.TRANS_SINE)
	cam.tween_property(_holder, "position", pan[1], seconds).set_trans(Tween.TRANS_SINE)
	await cam.finished
	var lines: PackedStringArray = spec.get("lines", PackedStringArray())
	if not lines.is_empty():
		var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
		if box:
			box.play(lines)
			await box.finished
	if spec.get("white_out", false):
		var white := ColorRect.new()
		white.color = Color(1, 1, 1, 0)
		white.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(white)
		await create_tween().tween_property(white, "color:a", 1.0, 2.5).finished
	else:
		await create_tween().tween_property(root, "modulate:a", 0.0, 1.0).finished
	finished.emit()
	queue_free()
