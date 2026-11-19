class_name SoundBank
extends RefCounted
## 소리를 이름으로 찾고, 오디오 버스를 만든다. 이름 규칙은 assets/audio/README.md.
## 같은 이름이 진짜 소리와 placeholder/ 둘 다에 있으면 진짜 소리를 쓴다.
## 담당: A(게임플레이). (A 세션이 쉬는 동안 B 세션이 만듦, #35)

const AUDIO_DIR := "res://assets/audio"
const BUS_AMBIENCE := &"Ambience"  ## 장소 환경음·자리 소리(장소 씬 Sound/ 아래)
const BUS_SFX := &"Sfx"            ## 발소리·효과음
const BUS_MUSIC := &"Music"        ## 음악

static var _index: Dictionary = {}  # 이름(확장자 뺀 것) → 경로
static var _cache: Dictionary = {}  # 앞머리 → [AudioStream]
static var _last: Dictionary = {}   # 앞머리 → 마지막으로 고른 번호


## 버스를 만든다. AudioServer.add_bus()는 4.7.2 웹에서도 출력을 끊는다(#877, #34) — bus_count로 만든다.
static func setup_buses() -> void:
	if AudioServer.get_bus_index(BUS_AMBIENCE) != -1:
		return
	var names := [BUS_AMBIENCE, BUS_SFX, BUS_MUSIC]
	var start := AudioServer.bus_count
	AudioServer.bus_count = start + names.size()
	for i in names.size():
		AudioServer.set_bus_name(start + i, names[i])
		AudioServer.set_bus_send(start + i, &"Master")


## 이름이 prefix로 시작하는 소리들(예: "step_wood_" → step_wood_01~03). 없으면 빈 배열.
static func variants(prefix: String) -> Array:
	if _cache.has(prefix):
		return _cache[prefix]
	_build_index()
	var names: Array = []
	for stem in _index:
		if String(stem).begins_with(prefix):
			names.append(stem)
	names.sort()
	var streams: Array = []
	for stem in names:
		var s := load(_index[stem]) as AudioStream
		if s:
			streams.append(s)
	_cache[prefix] = streams
	return streams


## prefix 소리 중 하나. 바로 앞에 고른 것은 피한다.
static func pick(prefix: String) -> AudioStream:
	var list := variants(prefix)
	if list.is_empty():
		return null
	var i := randi() % list.size()
	if list.size() > 1 and i == _last.get(prefix, -1):
		i = (i + 1) % list.size()
	_last[prefix] = i
	return list[i]


static func _build_index() -> void:
	if not _index.is_empty():
		return
	_scan(AUDIO_DIR)


static func _scan(dir: String) -> void:
	for file in DirAccess.get_files_at(dir):
		# 내보낸 빌드에는 원본 대신 .import/.remap만 남는다.
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension() not in ["ogg", "wav", "mp3"]:
			continue
		var stem := name.get_basename()
		var path := dir.path_join(name)
		if _index.has(stem) and not String(_index[stem]).contains("/placeholder/"):
			continue  # 진짜 소리가 이미 있다
		_index[stem] = path
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub))
