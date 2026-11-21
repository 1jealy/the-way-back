class_name Moment
extends Node2D
## 작은 순간: 걷기만 하는 빈 구간에 대사 없이 지나가는 연출(하늘이가 멈춰 냄새 맡기, 사슴이 지나가기 등).
## 하윤이 원점 - trigger_before를 지나면 한 번 일어난다. 진행에 필요 없고 플래그도 세우지 않는다(이어하기 뒤엔 다시 일어난다).
## 장소 씬에 B가 놓는다. 이름은 장면표 번호와 내용으로: Moment_3-6_Sniff. 원점은 땅 위(y = 810).
## 아래 셋 중 필요한 것만 채운다. 담당: A(연출 흐름). (A 세션이 쉬는 동안 B 세션이 만듦)
##   하늘이: dog_to(원점 기준 x)까지 가서 dog_hold초 머문다. dog_look이 있으면 그쪽을 본다. 합류 전이면 건너뛴다.
##   하윤:   player_pause초 멈춘다(player_look 쪽을 본다). 조작을 그동안만 막는다.
##   그림:   art가 art_from에서 art_to로(원점 기준) art_seconds 동안 지나가며 나타났다 사라진다. art_count개면 조금씩 흩어서.

## 연출이 다 끝났다.
signal finished

const LOCK := &"moment"

@export var trigger_before: float = 0.0
## 처음 알아챘을 때 하윤이 원점보다 이만큼 넘게 지나 있으면 건너뛴다(옮겨 가기·검사의 순간이동).
## 이미 멀리 간 하윤을 멈추거나 하늘이를 한참 뒤로 돌려보내지 않는다(#85).
@export var trigger_window: float = 600.0

@export_group("하늘이")
@export var dog_to: float = INF
@export var dog_hold: float = 1.5
## 1 = 오른쪽, -1 = 왼쪽, 0 = 그대로.
@export var dog_look: int = 0

@export_group("하윤")
@export var player_pause: float = 0.0
@export var player_look: int = 0

@export_group("그림")
@export var art: String = ""
@export var art_from: Vector2 = Vector2.ZERO
@export var art_to: Vector2 = Vector2.ZERO
@export var art_seconds: float = 3.0
## 하윤은 0. 뒤로 지나가면 음수(땅 -10보다 크면 땅 위), 앞이면 양수.
@export var art_z: int = -8
@export var art_scale: float = 1.0
@export var art_count: int = 1
## 지나가는 동안 위아래로 흔들리는 폭(px). 날갯짓·잠자리.
@export var art_bob: float = 0.0

@export_group("")
## 낼 소리(assets/audio 이름 앞머리). 비우면 없음.
@export var sound: String = ""

var triggered: bool = false


func _ready() -> void:
	add_to_group("moment")


func _process(_delta: float) -> void:
	if triggered:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.global_position.x >= global_position.x - trigger_before:
		triggered = true
		if player.global_position.x > global_position.x + trigger_window:
			return
		_run(player)


func _run(player: Player) -> void:
	if not sound.is_empty():
		_play_sound()
	var dog := get_tree().get_first_node_in_group("dog") as Dog
	var do_art := not art.is_empty()
	var do_player := player_pause > 0.0
	var do_dog := dog_to != INF and dog != null and dog.is_joined() and not dog.is_busy()
	# 일을 시작하기 전에 센다. 그림을 못 찾으면 _run_art가 곧바로 _done()을 불러서,
	# 나중에 세면 다른 일이 남았는데도 finished가 나간다(#85).
	_left = int(do_art) + int(do_player) + int(do_dog)
	if _left == 0:
		finished.emit()
		return
	if do_art:
		_run_art()
	if do_player:
		_run_player(player)
	if do_dog:
		_run_dog(dog)


var _left: int = 0


func _done() -> void:
	_left -= 1
	if _left <= 0:
		finished.emit()


func _run_dog(dog: Dog) -> void:
	dog.script_move_to(global_position.x + dog_to)
	await dog.script_arrived
	if dog_look != 0:
		dog.look(dog_look)
	await get_tree().create_timer(dog_hold, false).timeout
	dog.release_script()
	_done()


func _run_player(player: Player) -> void:
	player.lock(LOCK)
	if player_look != 0:
		player.face(player_look)
	await get_tree().create_timer(player_pause, false).timeout
	player.unlock(LOCK)
	_done()


func _run_art() -> void:
	var path := CutscenePlayer.find_art(art)
	if path.is_empty():
		push_warning("작은 순간 %s: 그림 '%s'이 없다" % [name, art])
		_done()
		return
	var tex: Texture2D = load(path)
	var last: Tween = null
	for i in art_count:
		var s := Sprite2D.new()
		s.name = "Art%d" % i
		s.texture = tex
		s.z_index = art_z
		s.z_as_relative = false
		s.scale = Vector2(art_scale, art_scale)
		if art_to.x < art_from.x:
			s.flip_h = true  # 그림은 오른쪽을 보고 그린다. 왼쪽으로 가면 뒤집는다.
		var spread := Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 40.0)) if art_count > 1 else Vector2.ZERO
		s.position = art_from + spread
		s.modulate.a = 0.0
		add_child(s)
		var t := s.create_tween()
		t.tween_property(s, "modulate:a", 1.0, 0.4)
		t.parallel().tween_property(s, "position:x", art_to.x + spread.x, art_seconds)
		if art_bob > 0.0:
			var y0 := art_from.y + spread.y
			var y1 := art_to.y + spread.y
			var bob := art_bob
			t.parallel().tween_method(func(k: float): s.position.y = lerpf(y0, y1, k) + sin(k * TAU * 3.0 + i) * bob, 0.0, 1.0, art_seconds)
		else:
			t.parallel().tween_property(s, "position:y", art_to.y + spread.y, art_seconds)
		t.parallel().tween_property(s, "modulate:a", 0.0, 0.5).set_delay(maxf(art_seconds - 0.5, 0.0))
		t.tween_callback(s.queue_free)
		last = t
	if last:
		await last.finished
	_done()


func _play_sound() -> void:
	var stream := SoundBank.pick(sound)
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = SoundBank.BUS_SFX
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
