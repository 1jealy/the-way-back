class_name Interactable
extends Area2D
## 조사 대상. 하윤이 이 안에 있으면 머리 위에 "[E] 살펴보기"가 뜨고, E로 조사한다.
## 장소 씬에 B가 놓는다. 노드 하나(이 스크립트를 붙인 Area2D)면 되고, 충돌 모양·안내 글은 여기서 만든다.
## 약속은 CLAUDE.md "조사 대상" 참고. 담당: A(게임플레이).

## 조사를 시작할 때(대사 상자가 열리기 전).
signal interacted
## 대사를 다 넘겼을 때. 줄이 없으면 interacted 바로 뒤에 온다.
signal finished
## show_locked인데 아직 requires_flag가 없을 때 조사했다(덜컹).
signal locked

## 안내 문구. 앞에 "[E] "가 붙는다.
@export var prompt: String = "살펴보기"
## 하윤이 이 안에 들어오면 조사할 수 있다. 원점은 땅(발밑) 가운데.
@export var size: Vector2 = Vector2(200.0, 300.0)
## 대사 상자에 띄울 줄. 형식은 DialogueBox 참고("하윤: …" / 글).
@export var lines: PackedStringArray = PackedStringArray()
## 조사하면 세우는 플래그.
@export var grants_flag: StringName = &""
## 이 플래그가 서 있을 때만 조사할 수 있다(비우면 늘).
@export var requires_flag: StringName = &""
## 한 번 조사하면 다시 안 된다.
@export var one_shot: bool = false
## requires_flag가 서기 전에도 안내가 뜨고, 조사하면 잠겨 있다는 소리만 난다(잠긴 서랍·문).
@export var show_locked: bool = false
## 조사할 때 낼 소리(assets/audio 이름 앞머리, 예: "sfx_pickup_"). 비우면 없음.
@export var sound: String = ""
## 1~5면 조사할 때 지도를 펼치고 그 동그라미에 체크한다(장면 2-2, 3-1, 4-3, 5-4, 7-2).
## 하윤이 지도를 접은 뒤에 lines가 나온다.
@export_range(0, 5) var map_circle: int = 0

var used: bool = false
var player_inside: bool = false
var _busy: bool = false
var _prompt_label: Label


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)

	_prompt_label = Label.new()
	_prompt_label.name = "Prompt"
	_prompt_label.text = "[E] " + prompt
	_prompt_label.add_theme_font_size_override("font_size", 24)
	_prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.82, 1))
	# 밝은 벽 앞에서도 읽히게 테두리(#32)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.12, 0.1, 0.09, 0.85))
	_prompt_label.add_theme_constant_override("outline_size", 6)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.size = Vector2(320.0, 34.0)
	_prompt_label.position = Vector2(-160.0, -330.0)
	_prompt_label.z_index = 20
	_prompt_label.visible = false
	add_child(_prompt_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_available() -> bool:
	if not player_inside or _busy:
		return false
	if one_shot and used:
		return false
	return _unlocked()


func _unlocked() -> bool:
	return requires_flag.is_empty() or GameState.has_flag(requires_flag)


## 안내를 띄우고 E를 받는가. 잠겨 있어도 show_locked면 받는다(덜컹).
func is_offered() -> bool:
	if not player_inside or _busy or (one_shot and used):
		return false
	return _unlocked() or show_locked


## 하윤 발밑에서 가장 가까운, 지금 조사할 수 있는 대상. 없으면 null.
static func nearest_available(tree: SceneTree, from: Vector2) -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for node in tree.get_nodes_in_group("interactable"):
		var it := node as Interactable
		if it == null or not it.is_inside_tree() or not it.is_offered():
			continue
		var d := absf(it.global_position.x - from.x)
		if d < best_d:
			best = it
			best_d = d
	return best


func interact() -> void:
	if is_offered() and not _unlocked():
		_play_sound("sfx_locked_")
		_shake_prompt()
		locked.emit()
		return
	if not is_available():
		return
	_play_sound(sound)
	_busy = true
	used = true
	if not grants_flag.is_empty():
		GameState.set_flag(grants_flag)
	interacted.emit()
	if map_circle > 0:
		var map := get_tree().get_first_node_in_group("map_screen") as MapScreen
		if map:
			map.open(map_circle)
			await map.closed
	if not lines.is_empty():
		var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
		if box:
			box.play(lines)
			await box.finished
	_busy = false
	finished.emit()


func _process(_delta: float) -> void:
	var show := false
	if is_offered():
		var player := get_tree().get_first_node_in_group("player") as Player
		show = player != null and player.controls_enabled \
				and nearest_available(get_tree(), player.global_position) == self
	_prompt_label.visible = show


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false


func _play_sound(prefix: String) -> void:
	if prefix.is_empty():
		return
	var stream := SoundBank.pick(prefix)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = SoundBank.BUS_SFX
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _shake_prompt() -> void:
	var base := _prompt_label.position
	var tween := create_tween()
	for dx in [-8.0, 7.0, -5.0, 3.0, 0.0]:
		tween.tween_property(_prompt_label, "position", base + Vector2(dx, 0.0), 0.04)
