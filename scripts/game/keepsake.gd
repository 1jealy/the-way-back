class_name Keepsake
extends Interactable
## 할아버지 물건(#111, 기획서 "할아버지의 물건"). 장소에 놓인 물건 그림이 보이고, E로 주우면
## 그림이 빛에 싸여 하윤 머리 위로 떠올랐다 사라진다(글·카드 없음, 조작은 안 막는다).
## 주우면 플래그 item_<item>을 세운다(이어하기 뒤에도 남는다). 물건 다섯은 ITEMS.
## 장소 씬에 B가 놓는다(Keepsake_<장면>_<물건>). 원점은 땅 위. 담당: A(게임플레이).

## 주워서 얻는 물건: 이름 → 그림. 순서는 얻는 순서(들판 → 간이역 → 숲 → 철교). 강가 조약돌은 하늘이가 물어 온다(#148, AskSpot).
## 모두 할아버지가 하윤에게 만들어 준 아이 크기의 것(#144). 손전등은 #147에서 호루라기로 바뀌었다.
const ITEMS := {
	&"kite": "prop_kite",
	&"pocket_watch": "prop_pocket_watch",
	&"willow_flute": "prop_willow_flute",
	&"whistle": "prop_whistle",
}
const FLOAT_HEIGHT := 380.0
const FLOAT_SECONDS := 1.2

## 물건 이름(ITEMS의 열쇠).
@export var item: StringName = &"kite"
## 땅에 놓인 그림의 자리(원점 기준)와 기울기(도). 그림은 ITEMS에서 고른다.
@export var art_offset: Vector2 = Vector2(0.0, -60.0)
@export var art_rotation: float = 0.0
## 놓인 그림의 z(하윤 0 기준). 기본은 하윤 뒤 땅 위. 들판 연처럼 풀숲 끝에 걸쳐 놓으면 풀 사이(뒤 겹보다 위)로 올린다(#142).
@export var art_z: int = -2

## 물건이 떠올라 사라졌을 때.
signal taken

var _art: Sprite2D


static func flag_for(item_name: StringName) -> StringName:
	return StringName("item_%s" % item_name)


static func art_for(item_name: StringName) -> String:
	return ITEMS.get(item_name, "")


func _ready() -> void:
	if prompt == "살펴보기":
		prompt = "줍기"
	one_shot = true
	grants_flag = flag_for(item)
	pickup_art = ""
	if sound.is_empty():
		sound = "sfx_pickup_"
	super._ready()
	var path := CutscenePlayer.find_art(art_for(item))
	if path.is_empty():
		push_warning("물건 %s: 그림 '%s'이 없다" % [name, art_for(item)])
	else:
		_art = Sprite2D.new()
		_art.name = "Art"
		_art.texture = load(path)
		_art.position = art_offset
		_art.rotation_degrees = art_rotation
		_art.z_index = art_z
		add_child(_art)
	if GameState.has_flag(grants_flag):
		used = true
		if _art:
			_art.visible = false
	interacted.connect(_float_away)


## 하윤 머리 위로 떠올라 사라진다. 뒤에 빛 알갱이가 번진다.
func _float_away() -> void:
	if _art == null:
		taken.emit()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var start := _art.global_position
	# 하윤이 무릎을 굽혀 숙이고 집는다(#114). 손이 닿는 순간 물건이 손으로 오고, 거기서 떠오른다.
	if player and player.has_method("play_pickup"):
		if player.has_method("face"):
			player.face(1 if global_position.x >= player.global_position.x else -1)
		await player.play_pickup()
		var grab := create_tween()
		grab.tween_property(_art, "global_position", player.hand_point(), 0.12)
		grab.parallel().tween_property(_art, "rotation", 0.0, 0.12)
		await grab.finished
		# 일어나는 동안 손에 들려 따라 올라온다
		var held := 0.0
		while held < 0.45 and is_instance_valid(player):
			_art.global_position = player.hand_point()
			await get_tree().process_frame
			if not get_tree().paused:
				held += get_process_delta_time()
	var top := (player.global_position if player else global_position) + Vector2(0.0, -FLOAT_HEIGHT)
	_art.z_index = 20
	var glow := Sprite2D.new()
	glow.name = "Glow"
	var mote := CutscenePlayer.find_art("fx_light_mote")
	if not mote.is_empty():
		glow.texture = load(mote)
	glow.scale = Vector2(4.0, 4.0)
	glow.modulate.a = 0.0
	glow.show_behind_parent = true
	_art.add_child(glow)
	var tween := create_tween()
	tween.tween_property(_art, "global_position", top, FLOAT_SECONDS * 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_art, "rotation", 0.0, FLOAT_SECONDS * 0.55)
	tween.parallel().tween_property(glow, "modulate:a", 0.9, FLOAT_SECONDS * 0.4)
	tween.tween_interval(FLOAT_SECONDS * 0.15)
	tween.tween_property(_art, "modulate:a", 0.0, FLOAT_SECONDS * 0.3)
	tween.parallel().tween_property(_art, "scale", Vector2(0.6, 0.6), FLOAT_SECONDS * 0.3)
	await tween.finished
	_art.visible = false
	_art.global_position = start
	taken.emit()
