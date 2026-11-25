extends Node
## 조립 씬. 장소를 갈아 끼우고 하윤과 카메라를 옮긴다.
## 담당: A(게임플레이).

signal place_changed(place_id: StringName)

const FIRST_PLACE := "res://scenes/places/house.tscn"
const FADE_SECONDS := 0.6

var _place: Place
var _changing: bool = false

@onready var _place_slot: Node2D = $World/PlaceSlot
@onready var _player: Player = $World/Player
@onready var _dog: Dog = $World/Dog
@onready var _camera: Camera2D = $World/Player/Camera
@onready var _fade: ColorRect = $Overlay/Fade
@onready var _place_card: PlaceCard = $Overlay/PlaceCard
@onready var _walk_hint: Label = $Overlay/WalkHint
@onready var _dust: AmbientDust = $World/Player/Camera/Dust

## 카메라가 걷는 쪽을 이만큼 앞서 본다(#90). 걸을 때 빨리 따라가고, 멈추면 천천히 돌아온다.
const LOOK_AHEAD := 150.0
const LOOK_RATE_WALK := 1.4
const LOOK_RATE_REST := 0.5
var _look: float = 0.0

## 처음 걷기 안내(집에서만): 하윤이 이만큼 걸으면 사라지고 플래그를 세운다(#87).
const WALK_HINT_FLAG := &"walked_once"
const WALK_HINT_DISTANCE := 240.0
var _walk_hint_from: float = NAN


var _map_hint: Label
## 음악(휘파람 주제 선율). 장소를 옮겨도 끊기지 않게 main이 들고 있다.
var _music: AudioStreamPlayer
var _music_tween: Tween


func _ready() -> void:
	add_to_group("main")
	_fade.modulate.a = 1.0
	_set_ambience_volume(0.0)
	_setup_map_hint()
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = SoundBank.BUS_MUSIC
	add_child(_music)
	_swap_place(GameState.take_start_place(FIRST_PLACE))
	if GameState.has_flag(Dog.JOIN_FLAG):
		_dog.join(_player)
	await _fade_to(0.0)


func current_place() -> Place:
	return _place


func player() -> Player:
	return _player


func dog() -> Dog:
	return _dog


func dialogue_box() -> DialogueBox:
	return $Overlay/DialogueBox


func map_screen() -> MapScreen:
	return $Overlay/MapScreen


func pause_menu() -> PauseMenu:
	return $MenuLayer/PauseMenu


func go_to(path: String) -> void:
	if _changing:
		return
	_changing = true
	_player.lock(&"place_change")
	await _fade_to(1.0)
	_swap_place(path)
	await _fade_to(0.0)
	_player.unlock(&"place_change")
	_changing = false


func _swap_place(path: String) -> void:
	if _place:
		_place_slot.remove_child(_place)
		_place.queue_free()
	var scene: PackedScene = load(path)
	_place = scene.instantiate()
	_place_slot.add_child(_place)
	_place.exit_reached.connect(_on_exit_reached)
	# 장소 소리(Sound/ 아래)는 환경음 버스로. 씬 파일에 버스 이름을 적어 두면 에디터에는
	# 그 버스가 없어서(코드로 만든다) Master로 바뀌어 버린다 — 그래서 여기서 정한다.
	var sound := _place.get_node_or_null("Sound")
	if sound:
		for node in sound.find_children("*", "", true, false):
			if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
				node.bus = SoundBank.BUS_AMBIENCE

	_player.global_position = _place.spawn_position()
	_player.velocity = Vector2.ZERO
	_camera.limit_left = 0
	_camera.limit_right = int(_place.width)
	_camera.limit_top = 0
	_camera.limit_bottom = int(Place.SCREEN_H)
	_camera.reset_smoothing()
	_dog.place_behind(_player)

	GameState.current_place = _place.place_id
	# 강 위 구간(엔딩)은 저장하지 않는다: 저장하면 엔딩 뒤 이어하기가 배 장면부터 다시 틀었다(#107).
	if _place.place_id != &"crossing":
		GameState.save_game(path)
	_look = 0.0
	_camera.offset.x = 0.0
	_dust.set_place(_place.place_id)
	_place_card.show_place(_place.display_name, _player)
	_walk_hint.visible = false
	_walk_hint_from = NAN
	place_changed.emit(_place.place_id)


func _process(delta: float) -> void:
	_update_look(delta)
	_update_walk_hint()


## 걷는 쪽을 앞서 본다. 조작이 막혀 있으면(대사·연출) 천천히 가운데로 돌아온다.
func _update_look(delta: float) -> void:
	var walking := _player.controls_enabled and absf(_player.velocity.x) > 10.0
	var target := signf(_player.velocity.x) * LOOK_AHEAD if walking else 0.0
	var rate := LOOK_RATE_WALK if walking else LOOK_RATE_REST
	_look = lerpf(_look, target, 1.0 - exp(-rate * delta))
	_camera.offset.x = _look


## 처음 시작한 집에서만 "A D / ← →  걷기"를 띄우고, 조금 걸으면 사라진다(#87).
## 조작이 풀린 뒤에 뜬다(오프닝 위에 겹치지 않게). 한 번 걸었으면 이어하기 뒤에도 안 뜬다.
func _update_walk_hint() -> void:
	if GameState.has_flag(WALK_HINT_FLAG) or _place == null or _place.place_id != &"house":
		return
	if is_nan(_walk_hint_from):
		if _player.controls_enabled:
			_walk_hint_from = _player.global_position.x
			_walk_hint.visible = true
		return
	if absf(_player.global_position.x - _walk_hint_from) >= WALK_HINT_DISTANCE:
		_walk_hint.visible = false
		GameState.set_flag(WALK_HINT_FLAG)


## 음악을 튼다(이름 앞머리, 예: "mus_theme_full"). fade초에 걸쳐 volume_db까지 커진다.
## 이미 같은 음악이 돌고 있으면 크기만 바꾼다(restart면 처음부터 다시).
func play_music(prefix: String, volume_db: float = 0.0, fade: float = 2.0, restart: bool = false) -> void:
	var stream := SoundBank.pick(prefix)
	if stream == null:
		return
	if _music.playing and _music.stream == stream and not restart:
		fade_music(volume_db, fade)
		return
	_music.stream = stream
	_music.volume_db = -60.0
	_music.play()
	fade_music(volume_db, fade)


func fade_music(volume_db: float, seconds: float) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", volume_db, maxf(seconds, 0.01))


func stop_music(seconds: float = 2.0) -> void:
	if not _music.playing:
		return
	fade_music(-60.0, seconds)
	await _music_tween.finished
	_music.stop()


func music_playing() -> bool:
	return _music.playing


## 같은 장소 안 다른 자리로 옮긴다(화면이 어두워졌다 밝아진다). Passage가 부른다.
func move_player_to(x: float) -> void:
	if _changing:
		return
	_changing = true
	_player.lock(&"place_change")
	await _fade_to(1.0)
	_player.global_position.x = x
	_player.velocity = Vector2.ZERO
	_camera.reset_smoothing()
	_dog.place_behind(_player)
	await _fade_to(0.0)
	_player.unlock(&"place_change")
	_changing = false


## 지도를 처음 얻으면 "[M] 지도"를 띄우고, 처음 펼칠 때까지 둔다(장면표 1-5 "M 안내").
func _setup_map_hint() -> void:
	_map_hint = Label.new()
	_map_hint.name = "MapHint"
	_map_hint.text = "[M] 지도"
	_map_hint.add_theme_font_size_override("font_size", 28)
	_map_hint.add_theme_color_override("font_color", Color(1, 0.95, 0.82, 1))
	_map_hint.add_theme_color_override("font_outline_color", Color(0.12, 0.1, 0.09, 0.85))
	_map_hint.add_theme_constant_override("outline_size", 6)
	_map_hint.position = Vector2(48.0, 130.0)
	_map_hint.visible = false
	$Overlay.add_child(_map_hint)
	$Overlay.move_child(_map_hint, _fade.get_index())  # 페이드보다 아래
	GameState.flag_changed.connect(func(flag: StringName):
		if flag == &"has_map" and not GameState.has_flag(&"map_opened"):
			_map_hint.visible = true)
	map_screen().opened.connect(func():
		GameState.set_flag(&"map_opened")
		_map_hint.visible = false)


func _on_exit_reached() -> void:
	if _place.next_place.is_empty():
		return
	go_to(_place.next_place)


## 화면이 어두워지는 만큼 장소 소리도 줄인다(장소를 옮길 때 소리가 뚝 끊기지 않게).
func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_SECONDS)
	tween.parallel().tween_method(_set_ambience_volume, 1.0 - _fade.modulate.a, 1.0 - alpha, FADE_SECONDS)
	await tween.finished


func _set_ambience_volume(linear: float) -> void:
	var bus := AudioServer.get_bus_index(SoundBank.BUS_AMBIENCE)
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))
