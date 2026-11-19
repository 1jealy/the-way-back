class_name Interactable
extends Area2D
## 조사 대상. 하윤이 이 안에 있으면 머리 위에 "[E] 살펴보기"가 뜨고, E로 조사한다.
## 장소 씬에 B가 놓는다. 노드 하나(이 스크립트를 붙인 Area2D)면 되고, 충돌 모양·안내 글은 여기서 만든다.
## 약속은 CLAUDE.md "조사 대상" 참고. 담당: A(게임플레이).

## 조사를 시작할 때(대사 상자가 열리기 전).
signal interacted
## 대사를 다 넘겼을 때. 줄이 없으면 interacted 바로 뒤에 온다.
signal finished

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
	return requires_flag.is_empty() or GameState.has_flag(requires_flag)


## 하윤 발밑에서 가장 가까운, 지금 조사할 수 있는 대상. 없으면 null.
static func nearest_available(tree: SceneTree, from: Vector2) -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for node in tree.get_nodes_in_group("interactable"):
		var it := node as Interactable
		if it == null or not it.is_inside_tree() or not it.is_available():
			continue
		var d := absf(it.global_position.x - from.x)
		if d < best_d:
			best = it
			best_d = d
	return best


func interact() -> void:
	if not is_available():
		return
	_busy = true
	used = true
	if not grants_flag.is_empty():
		GameState.set_flag(grants_flag)
	interacted.emit()
	if not lines.is_empty():
		var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
		if box:
			box.play(lines)
			await box.finished
	_busy = false
	finished.emit()


func _process(_delta: float) -> void:
	var show := false
	if is_available():
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
