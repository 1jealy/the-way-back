extends RefCounted
## 그림 가져오기. assets/art/의 배경 그림을 장소 씬의 층에 넣는다.
## 실행은 tools/art_import.gd, 규칙은 assets/art/README.md.
##
## bg_<place_id>_<layer>[_NN].png
##   → scenes/places/<place_id>.tscn 의 Layers/<Layer>/Art 아래 Sprite2D
##   _NN 번호 순서대로 왼쪽(x = 0)부터 이어 붙인다. 위 끝은 y = 0.
## 그림이 하나라도 있는 장소는 greybox를 끈다. 하나도 없으면 켠다.
## Art 노드는 이 도구가 통째로 다시 만든다. 손으로 놓는 조각은 Art 밖(층 바로 아래)에 둔다.

const ART_DIR := "res://assets/art"
const PLACES_DIR := "res://scenes/places"
const TEMPLATE := "place_template.tscn"
const ART_NODE := "Art"
const LAYERS := {
	"sky": "Sky", "far": "Far", "mid": "Mid",
	"ground": "Ground", "props": "Props", "front": "Front",
}
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0
## 이보다 넓은 한 장은 일부 웹 GPU에서 안 뜬다. _01, _02로 나눈다.
const MAX_TILE_W := 8192
## Godot 이미지 가져오기 compress/mode. 0 = Lossless. 그라데이션은 손실·VRAM 압축에서 색 띠가 생긴다.
const COMPRESS_LOSSLESS := 0

var errors: PackedStringArray = []
var warnings: PackedStringArray = []
## 그림과 맞지 않는(write면 고친) 씬 경로.
var out_of_sync: PackedStringArray = []
## write 모드에서 .import를 고쳐 다시 --import가 필요한 그림.
var reimport_needed: PackedStringArray = []

var _name_re := RegEx.create_from_string(
		"^bg_([a-z0-9]+)_(sky|far|mid|ground|props|front)(?:_(\\d+))?\\.png$")


## write = true면 씬과 .import를 고쳐 저장한다. false면 보기만 한다(--check).
func run(write: bool) -> void:
	var places := _place_scenes()
	var art := _collect_art(places)
	for place_id in places:
		_sync_place(places[place_id], art.get(place_id, {}), write)


func ok() -> bool:
	return errors.is_empty() and out_of_sync.is_empty() and reimport_needed.is_empty()


## place_id → 씬 경로
func _place_scenes() -> Dictionary:
	var result := {}
	for file in DirAccess.get_files_at(PLACES_DIR):
		if not file.ends_with(".tscn") or file == TEMPLATE:
			continue
		result[file.get_basename()] = PLACES_DIR.path_join(file)
	return result


func _png_files(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension().to_lower() == "png":
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_png_files(dir.path_join(sub)))
	return found


## place_id → layer → [{path, index}] (번호 순)
func _collect_art(places: Dictionary) -> Dictionary:
	var art := {}
	for path in _png_files(ART_DIR):
		var file := path.get_file()
		if not file.begins_with("bg_"):
			continue  # char_, cut_, mem_ 은 다른 도구가 맡는다
		var m := _name_re.search(file)
		if m == null:
			errors.append("%s: 이름이 규칙과 다르다 (bg_<장소>_<층>[_번호].png, 층은 %s, 모두 소문자)"
					% [path, " ".join(LAYERS.keys())])
			continue
		var place_id := m.get_string(1)
		if not places.has(place_id):
			errors.append("%s: '%s' 장소가 없다 (있는 장소: %s)" % [path, place_id, ", ".join(places.keys())])
			continue
		var index := m.get_string(3).to_int() if m.get_string(3) != "" else 0
		var layer := m.get_string(2)
		var list: Array = art.get_or_add(place_id, {}).get_or_add(layer, [])
		for other in list:
			if other.index == index:
				errors.append("%s: %s와 번호가 겹친다" % [path, other.path])
		list.append({"path": path, "index": index})
	for place_id in art:
		for layer in art[place_id]:
			art[place_id][layer].sort_custom(func(a, b): return a.index < b.index)
	return art


func _sync_place(scene_path: String, art: Dictionary, write: bool) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		errors.append("%s: 씬을 불러오지 못했다" % scene_path)
		return
	var root: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var width: float = root.get("width")
	var changed := false

	for layer_key in LAYERS:
		var layer: Node = root.get_node_or_null("Layers/" + LAYERS[layer_key])
		if layer == null:
			errors.append("%s: Layers/%s 층이 없다" % [scene_path, LAYERS[layer_key]])
			continue
		var want := _plan_layer(scene_path, layer, layer_key, art.get(layer_key, []), width, write)
		if _layer_matches(layer, want):
			continue
		changed = true
		if write:
			_rebuild_layer(root, layer, want)

	var want_greybox := art.is_empty()
	if root.get("greybox") != want_greybox:
		changed = true
		if write:
			root.set("greybox", want_greybox)

	if changed:
		out_of_sync.append(scene_path)
		if write:
			var out := PackedScene.new()
			var err := out.pack(root)
			if err == OK:
				err = ResourceSaver.save(out, scene_path)
			if err != OK:
				errors.append("%s: 저장 실패 (%s)" % [scene_path, error_string(err)])
	root.free()


## 층에 들어갈 [{path, texture, position}]. 경고·오류도 여기서 모은다.
func _plan_layer(scene_path: String, layer: Node, layer_key: String, files: Array,
		width: float, write: bool) -> Array:
	var want := []
	var x := 0.0
	for f in files:
		var path: String = f.path
		_check_import(path, write)
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if tex == null:
			errors.append("%s: 불러오지 못했다. 먼저 godot --headless --path . --import" % path)
			continue
		var size := tex.get_size()
		if not is_equal_approx(size.y, SCREEN_H):
			warnings.append("%s: 높이 %d px — 1080을 기준으로 그린다 (위 끝을 y = 0에 둔다)" % [path, size.y])
		if size.x > MAX_TILE_W:
			warnings.append("%s: 폭 %d px — %d보다 넓으면 웹에서 안 뜰 수 있다. _01, _02로 나눈다"
					% [path, size.x, MAX_TILE_W])
		want.append({"path": path, "texture": tex, "position": Vector2(x, 0.0)})
		x += size.x
	if not want.is_empty():
		var scroll := 1.0
		if layer is Parallax2D:
			scroll = (layer as Parallax2D).scroll_scale.x
		var need := SCREEN_W + maxf(width - SCREEN_W, 0.0) * scroll
		if x + 1.0 < need:  # scroll_scale은 float32라 0.1 같은 값에 끝자리 오차가 있다
			warnings.append("%s %s 층: 그림 폭 합 %d px < 필요한 폭 %d px (1920 + (%d - 1920) × %.2f). 오른쪽 끝이 빈다"
					% [scene_path.get_file(), layer_key, x, roundi(need), width, scroll])
	return want


func _layer_matches(layer: Node, want: Array) -> bool:
	var art := layer.get_node_or_null(ART_NODE)
	if art == null:
		return want.is_empty()
	if art.get_child_count() != want.size():
		return false
	for i in want.size():
		var sprite := art.get_child(i) as Sprite2D
		if sprite == null or sprite.texture == null:
			return false
		if sprite.texture.resource_path != want[i].path:
			return false
		if not sprite.position.is_equal_approx(want[i].position) or sprite.centered:
			return false
	return true


func _rebuild_layer(root: Node, layer: Node, want: Array) -> void:
	var old := layer.get_node_or_null(ART_NODE)
	if old:
		layer.remove_child(old)
		old.free()
	if want.is_empty():
		return
	var art := Node2D.new()
	art.name = ART_NODE
	layer.add_child(art)
	layer.move_child(art, 0)  # 손으로 놓은 조각보다 뒤에 그린다
	art.owner = root
	for w in want:
		var sprite := Sprite2D.new()
		sprite.name = String(w.path).get_file().get_basename()
		sprite.texture = w.texture
		sprite.centered = false
		sprite.position = w.position
		art.add_child(sprite)
		sprite.owner = root


## 손실·VRAM 압축, 밉맵을 막는다. write면 .import를 고친다(다시 --import 필요).
func _check_import(path: String, write: bool) -> void:
	var import_path := path + ".import"
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		return  # 아직 가져오지 않았다. 불러오기에서 오류로 잡힌다.
	var bad: PackedStringArray = []
	if int(cfg.get_value("params", "compress/mode", COMPRESS_LOSSLESS)) != COMPRESS_LOSSLESS:
		bad.append("compress/mode(무손실이어야 한다)")
	if bool(cfg.get_value("params", "mipmaps/generate", false)):
		bad.append("mipmaps/generate(꺼야 한다)")
	if bad.is_empty():
		return
	if not write:
		errors.append("%s: 가져오기 설정이 틀렸다: %s. 도구를 --check 없이 돌려 고친다"
				% [import_path, ", ".join(bad)])
		return
	cfg.set_value("params", "compress/mode", COMPRESS_LOSSLESS)
	cfg.set_value("params", "mipmaps/generate", false)
	cfg.save(import_path)
	reimport_needed.append(path)
