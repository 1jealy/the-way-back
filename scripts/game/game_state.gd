extends Node
## 게임 진행 상태. 오토로드(GameState)라 장소를 옮겨도 유지된다.
## 장소에 들어갈 때 자동 저장하고(main.gd), 이어하기는 그 장소 처음부터 한다.
## 담당: A(게임플레이).

const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 1

## 플래그가 바뀔 때(막는 벽 Gate 등이 듣는다).
signal flag_changed(flag: StringName)

## 지금 있는 장소의 place_id.
var current_place: StringName = &""

## 얻은 물건·본 장면 같은 진행 기록.
var flags: Dictionary = {}

## 이어하기로 시작할 장소 씬. main이 한 번 읽고 비운다.
var start_place: String = ""

## 저장 파일 자리. 검사는 다른 자리를 쓴다.
var save_path: String = SAVE_PATH
## 헤드리스(검사·CI)에서는 저장하지 않는다. 저장을 시험하는 검사만 켠다.
var autosave: bool = DisplayServer.get_name() != "headless"


func _ready() -> void:
	SoundBank.setup_buses()


func set_flag(flag: StringName, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag)


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false) == true


func reset() -> void:
	current_place = &""
	flags.clear()
	start_place = ""


## 장소에 막 들어온 순간을 저장한다. place_path는 그 장소 씬.
func save_game(place_path: String) -> void:
	if not autosave:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "version", SAVE_VERSION)
	cfg.set_value("game", "place", place_path)
	cfg.set_value("game", "flags", flags.duplicate())
	var err := cfg.save(save_path)
	if err != OK:
		push_warning("저장 실패 %s: %s" % [save_path, error_string(err)])


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## 저장을 읽어 플래그를 되돌리고 start_place를 정한다. 실패하면 false.
func load_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return false
	var place: String = cfg.get_value("game", "place", "")
	if place.is_empty() or not ResourceLoader.exists(place):
		return false
	reset()
	var saved: Dictionary = cfg.get_value("game", "flags", {})
	flags = saved.duplicate()
	start_place = place
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## main이 시작할 장소를 한 번 가져간다.
func take_start_place(default_place: String) -> String:
	var place := start_place if not start_place.is_empty() else default_place
	start_place = ""
	return place
