class_name Keepsake
extends Interactable
## 할아버지 물건(기획서 "할아버지 물건 다섯"). 장소마다 하나씩 줍고, 그 물건으로 길을 연다.
## 땅에 놓인 물건이 은은하게 반짝이고, E로 주우면 빛에 싸여 하윤 머리 위로 떠올랐다가 손으로 들어간다.
## 주우면 플래그 item_<item>을 세운다(이어하기 뒤에도 가진 채로). 다음 연출은 taken을 기다린다.
## 장소 씬에 B가 놓는다(이름 Keepsake_<장면>_<물건>, 원점은 땅 위). 동작: A. (A 대신 B 세션이 만듦)

## 빛에 싸여 떠올랐다가 손으로 들어갔다(줍는 연출이 끝났다).
signal taken

const LOCK := &"keepsake"
const FLAG_PREFIX := "item_"

## 물건 이름(영어 소문자, 플래그 item_<item>). 예: kite, flute, pouch, flashlight, watch.
@export var item: StringName = &""
## 물건 그림(assets/art 이름). 비우면 prop_<item>.
@export var art: String = ""
## 땅에 놓인 모습의 기울기(도). 억새에 걸린 연처럼.
@export var lying_degrees: float = 0.0
## 땅에 놓인 그림의 크기 배율.
@export var lying_scale: float = 1.0
## 떠올라 머무는 높이(하윤 발밑에서 위로, px). 하윤 키 약 300px.
@export var float_height: float = 430.0

var _art: Sprite2D
var _glow: Sprite2D
var _time: float = 0.0


static func flag_for(item_name: StringName) -> StringName:
	return StringName(FLAG_PREFIX + String(item_name))


func _ready() -> void:
	one_shot = true
	if grants_flag.is_empty() and not item.is_empty():
		grants_flag = flag_for(item)
	if sound.is_empty():
		sound = "sfx_pickup_"
	super._ready()
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = _glow_texture()
	_glow.material = _additive()
	_glow.modulate = Color(1.0, 0.86, 0.6, 0.0)
	add_child(_glow)
	_art = Sprite2D.new()
	_art.name = "Art"
	var path := CutscenePlayer.find_art(art_name())
	if not path.is_empty():
		_art.texture = load(path)
	_art.rotation_degrees = lying_degrees
	_art.scale = Vector2.ONE * lying_scale
	add_child(_art)
	_place_on_ground()
	if GameState.has_flag(grants_flag):
		used = true
		_art.visible = false
		_glow.visible = false
	interacted.connect(_on_interacted)


func art_name() -> String:
	return art if not art.is_empty() else "prop_" + String(item)


func is_taken() -> bool:
	return GameState.has_flag(grants_flag)


func _place_on_ground() -> void:
	var h := 0.0
	if _art.texture:
		h = _art.texture.get_height() * lying_scale
	_art.position = Vector2(0.0, -h * 0.5 - 6.0)
	_glow.position = _art.position
	_glow.scale = Vector2.ONE * maxf(1.4, h / 90.0)


func _process(delta: float) -> void:
	super._process(delta)
	if used:
		return
	# 놓여 있는 동안 숨 쉬듯 반짝인다(눈길을 끌게). 안내 글이 뜨기 전에도 보인다.
	_time += delta
	_glow.modulate.a = 0.22 + 0.12 * sin(_time * 2.2)


func _on_interacted() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.lock(LOCK)
	_art.z_index = 20
	_art.z_as_relative = false
	_glow.z_index = 19
	_glow.z_as_relative = false
	var top := Vector2(0.0, -float_height)
	if player:
		top = to_local(player.global_position) + Vector2(0.0, -float_height)
	# 빛이 피어나며 떠오른다 → 머리 위에서 잠깐 머문다 → 작아지며 손으로 들어간다
	var tween := create_tween()
	tween.tween_property(_glow, "modulate:a", 0.9, 0.35)
	tween.parallel().tween_property(_glow, "scale", _glow.scale * 2.2, 0.9).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_art, "position", top, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_art, "rotation", 0.0, 1.1)
	tween.parallel().tween_property(_art, "scale", Vector2.ONE * 1.25, 1.1)
	tween.parallel().tween_property(_glow, "position", top, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
	var hand := top + Vector2(0.0, float_height * 0.6)
	if player:
		hand = to_local(player.hand_point())
	tween.tween_property(_art, "position", hand, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_art, "scale", Vector2.ONE * 0.3, 0.45)
	tween.parallel().tween_property(_glow, "position", hand, 0.45)
	tween.parallel().tween_property(_glow, "modulate:a", 0.0, 0.45)
	tween.parallel().tween_property(_art, "modulate:a", 0.0, 0.45).set_delay(0.2)
	await tween.finished
	_art.visible = false
	_glow.visible = false
	if player:
		player.unlock(LOCK)
	taken.emit()


static func _additive() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


## 가운데가 밝고 가장자리로 사라지는 둥근 빛.
static func _glow_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex
