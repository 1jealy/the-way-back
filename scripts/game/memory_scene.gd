class_name MemoryScene
extends Node2D
## 기억 장면(장면표 2-2, 3-1, 4-3, 5-4): 지도에 동그라미를 체크하고 접으면 할아버지와의 기억이
## 배경 위에 희미하게 겹쳐 떴다 사라진다. 대사 없음. 휘파람 한 소절.
## 장소 씬에 B가 그 동그라미 조사 대상 근처에 놓는다(이름 Memory_<장면>). 원점은 땅 위, 그림 아래 가운데.
## 조사 대상(map_circle = circle)이 지도를 접은 뒤 play()를 기다리고 나서 글을 띄운다.
## 그림은 단색 선 스케치(art 이름으로 assets/art 아래에서 찾는다. 진짜 그림이 placeholder보다 먼저).
## 담당: B(연출). (A 세션이 쉬는 동안 B 세션이 만듦)

signal started
signal ended

const LOCK := &"memory"
const SHADER := preload("res://shaders/memory.gdshader")

## 짝이 되는 지도 동그라미(1~4).
@export_range(1, 5) var circle: int = 1
@export var art: String = ""
## 화면에 보이는 그림 높이(px). 폭은 그림 비율대로.
@export var height: float = 620.0
## 떠 있는 시간(나타나기·사라지기 빼고, 초).
@export var hold_seconds: float = 4.5
@export var fade_in: float = 1.6
@export var fade_out: float = 2.0
## 휘파람 한 소절(이름 앞머리). 진짜 곡이 오면 같은 이름으로 넣는다.
@export var phrase: String = ""
@export var phrase_db: float = -6.0
## 기억이 떠 있는 동안 장소 환경음을 이만큼 줄인다(dB).
@export var ambience_duck_db: float = -8.0
## 떠 있는 동안 하윤이 천천히 걸을 수 있다(#118 — 동그라미마다 8초씩 멈춰 있었다).
## 기억 뒤에 바로 이어지는 연출이 있으면(5-4 물수제비) 끄고 예전처럼 세운다.
@export var walk_while_playing: bool = true
@export var walk_speed_scale: float = 0.55

var playing: bool = false
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("memory")


static func find(tree: SceneTree, n: int) -> MemoryScene:
	for m in tree.get_nodes_in_group("memory"):
		if m is MemoryScene and m.circle == n:
			return m
	return null


func play() -> void:
	if playing:
		return
	var path := CutscenePlayer.find_art(art)
	if path.is_empty():
		push_warning("기억 장면 그림이 없다: %s" % art)
		return
	playing = true
	var player := get_tree().get_first_node_in_group("player") as Player
	var speed_before := 0.0
	if player:
		if walk_while_playing:
			speed_before = player.walk_speed
			player.walk_speed *= walk_speed_scale
		else:
			player.lock(LOCK)
	_sprite = Sprite2D.new()
	_sprite.name = "Sketch"
	_sprite.texture = load(path)
	var s := height / float(_sprite.texture.get_height())
	_sprite.scale = Vector2(s, s)
	_sprite.offset = Vector2(0.0, -_sprite.texture.get_height() * 0.5)
	_sprite.z_index = -4  # 배경·물건 위, 하윤·하늘이 뒤
	_sprite.z_as_relative = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_sprite.material = mat
	add_child(_sprite)
	started.emit()

	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("play_music") and not phrase.is_empty():
		main.play_music(phrase, phrase_db, 0.3, true)
	var place := get_tree().get_first_node_in_group("place") as Node
	var amb := place.get_node_or_null("Sound/Ambience") as AudioStreamPlayer if place else null
	var amb_db := amb.volume_db if amb else 0.0
	if amb and ambience_duck_db != 0.0:
		create_tween().tween_property(amb, "volume_db", amb_db + ambience_duck_db, fade_in)

	# 아주 천천히 떠오른다
	create_tween().tween_property(_sprite, "position:y", -12.0, fade_in + hold_seconds + fade_out).from(10.0)
	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, fade_in).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(hold_seconds)
	tw.tween_method(_set_fade, 1.0, 0.0, fade_out).set_trans(Tween.TRANS_SINE)
	await tw.finished

	if main and main.has_method("stop_music") and not phrase.is_empty():
		main.stop_music(1.5)
	if amb and ambience_duck_db != 0.0:
		create_tween().tween_property(amb, "volume_db", amb_db, 2.0)
	_sprite.queue_free()
	_sprite = null
	if player and is_instance_valid(player):
		if walk_while_playing:
			player.walk_speed = speed_before
		else:
			player.unlock(LOCK)
	playing = false
	ended.emit()


func _set_fade(v: float) -> void:
	if _sprite:
		(_sprite.material as ShaderMaterial).set_shader_parameter("fade", v)
