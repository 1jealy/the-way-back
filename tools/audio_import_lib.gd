extends RefCounted
## 소리 가져오기. assets/audio/의 소리 이름을 보고 가져오기 설정(반복)을 맞추고,
## 장소 환경음 amb_<place_id>를 장소 씬의 Sound/Ambience에 넣는다.
## 실행은 tools/audio_import.gd, 규칙은 assets/audio/README.md.
##
##   amb_<place_id>   장소 환경음. 반복. 장소 씬 Sound/Ambience(AudioStreamPlayer, autoplay)에 자동으로 들어간다
##   pos_<…>          장소 안 한 자리 소리. 반복. 장소 씬 Sound/ 아래 AudioStreamPlayer2D로 손으로 놓는다
##   mus_<…>          음악. 반복
##   step_<…>, sfx_<…> 발소리·효과음. 한 번
## Ambience의 volume_db는 도구가 건드리지 않는다(장소마다 손으로 맞춘다).

const AUDIO_DIR := "res://assets/audio"
const PLACES_DIR := "res://scenes/places"
const TEMPLATE := "place_template.tscn"
const SOUND_NODE := "Sound"
const AMBIENCE_NODE := "Ambience"
const LOOPING := ["amb", "pos", "mus"]
## 앞머리가 반복이어도 이것으로 시작하면 한 번만 튼다(기억 장면 휘파람 한 소절).
const ONE_SHOT := ["mus_phrase_"]

var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var out_of_sync: PackedStringArray = []
var reimport_needed: PackedStringArray = []

var _name_re := RegEx.create_from_string("^(amb|pos|mus|step|sfx)_[a-z0-9_-]+\\.(ogg|wav)$")


func run(write: bool) -> void:
	var files := _collect(write)
	for file in DirAccess.get_files_at(PLACES_DIR):
		if file.ends_with(".tscn") and file != TEMPLATE:
			_sync_place(PLACES_DIR.path_join(file), files, write)


func ok() -> bool:
	return errors.is_empty() and out_of_sync.is_empty() and reimport_needed.is_empty()


func _sound_files(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["ogg", "wav", "mp3"]:
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_sound_files(dir.path_join(sub)))
	return found


## 이름(확장자 뺀 것) → 경로
func _collect(write: bool) -> Dictionary:
	var files := {}
	for path in _sound_files(AUDIO_DIR):
		var file := path.get_file()
		if _name_re.search(file) == null:
			errors.append("%s: 이름이 규칙과 다르다 (amb_ pos_ mus_ step_ sfx_ 로 시작, 소문자, .ogg/.wav)" % path)
			continue
		var stem := file.get_basename()
		if files.has(stem):
			errors.append("%s: %s와 이름이 겹친다 (진짜 소리를 넣었으면 placeholder 쪽을 지운다)" % [path, files[stem]])
			continue
		files[stem] = path
		_check_loop(path, stem.get_slice("_", 0) in LOOPING and not ONE_SHOT.any(func(p): return stem.begins_with(p)), write)
	return files


## 반복 설정. ogg는 params/loop, wav는 params/edit/loop_mode(1 끔, 2 앞으로).
func _check_loop(path: String, want_loop: bool, write: bool) -> void:
	var import_path := path + ".import"
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		errors.append("%s: 가져오지 않았다. 먼저 godot --headless --path . --import" % path)
		return
	var key := "loop" if path.get_extension() == "ogg" else "edit/loop_mode"
	var want: Variant = want_loop if key == "loop" else (2 if want_loop else 1)
	var have: Variant = cfg.get_value("params", key, null)
	if have == want:
		return
	if not write:
		errors.append("%s: 반복 설정이 %s여야 한다(지금 %s). 도구를 --check 없이 돌려 고친다" % [import_path, want, have])
		return
	cfg.set_value("params", key, want)
	cfg.save(import_path)
	reimport_needed.append(path)


func _sync_place(scene_path: String, files: Dictionary, write: bool) -> void:
	var packed: PackedScene = load(scene_path)
	var root: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var place_id := String(root.get("place_id"))
	var want_path: String = files.get("amb_" + place_id, "")
	var sound := root.get_node_or_null(SOUND_NODE)
	var amb: AudioStreamPlayer = sound.get_node_or_null(AMBIENCE_NODE) if sound else null
	var have_path := ""
	if amb and amb.stream:
		have_path = amb.stream.resource_path
	var matches := have_path == want_path and (amb == null or amb.autoplay)
	if want_path.is_empty():
		warnings.append("%s: 환경음 amb_%s 가 없다" % [scene_path.get_file(), place_id])
	if not matches:
		out_of_sync.append(scene_path)
		if write:
			if want_path.is_empty():
				if amb:
					amb.get_parent().remove_child(amb)
					amb.free()
			else:
				if sound == null:
					sound = Node2D.new()
					sound.name = SOUND_NODE
					root.add_child(sound)
					sound.owner = root
				if amb == null:
					amb = AudioStreamPlayer.new()
					amb.name = AMBIENCE_NODE
					sound.add_child(amb)
					amb.owner = root
				amb.stream = load(want_path)
				amb.autoplay = true
			var out := PackedScene.new()
			var err := out.pack(root)
			if err == OK:
				err = ResourceSaver.save(out, scene_path)
			if err != OK:
				errors.append("%s: 저장 실패 (%s)" % [scene_path, error_string(err)])
	# 손으로 놓은 자리 소리도 본다: 소리가 있고, 반복 소리인지
	if sound:
		for node in sound.get_children():
			if node == amb or not (node is AudioStreamPlayer or node is AudioStreamPlayer2D):
				continue
			var stream: AudioStream = node.get("stream")
			if stream == null:
				errors.append("%s: %s에 소리가 없다" % [scene_path.get_file(), node.name])
			elif not node.get("autoplay"):
				warnings.append("%s: %s가 autoplay가 아니다(누가 틀어 주지 않으면 안 난다)" % [scene_path.get_file(), node.name])
	root.free()
