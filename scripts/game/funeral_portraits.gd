class_name FuneralPortraits
extends Node2D
## 장면표 1-2: 거실 벽에 영정사진 두 개. 할아버지는 또렷하고, 옆 사진(하윤)은 흐려서 누구인지 보이지 않는다.
## 조사할 수 없는 배경이다(말없이 둔다). 7-8 엔딩에서 같은 두 장이 다시 비치고 하윤 사진이 또렷해진다(BoatRide).
## 장소 씬에 B가 놓는다(Portraits_1-2, 땅 위 x에 두고 사진 높이는 photo_y). 담당: B(연출).
## (A 세션이 쉬는 동안 B 세션이 만듦)

const BLUR := preload("res://shaders/blur.gdshader")
## 그림 이름(assets/art 아래). 진짜 그림이 placeholder보다 먼저. 하윤 사진은 또렷하게 그린 것을 게임이 흐린다.
const ART_GRANDPA := "prop_portrait_grandpa"
const ART_HAYUN := "prop_portrait_hayun"

## 사진 가운데 높이(땅 기준, 위로 -).
@export var photo_y: float = -430.0
## 두 사진 사이(가운데끼리, px).
@export var gap: float = 190.0
@export var photo_scale: float = 1.0

var grandpa: Sprite2D
var hayun: Sprite2D


func _ready() -> void:
	z_index = -4  # 물건 층(-5) 위, 하윤 뒤
	z_as_relative = false
	grandpa = _photo(ART_GRANDPA, Vector2(-gap * 0.5, photo_y))
	hayun = _photo(ART_HAYUN, Vector2(gap * 0.5, photo_y))
	hayun.material = blurred_material(1.0)


func _photo(art: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = art
	var path := CutscenePlayer.find_art(art)
	if not path.is_empty():
		s.texture = load(path)
	s.position = pos
	s.scale = Vector2.ONE * photo_scale
	add_child(s)
	return s


## 흐림 재질(amount 1 = 안 보임, 0 = 또렷). 엔딩(7-8)도 같은 것을 쓴다.
static func blurred_material(amount: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BLUR
	mat.set_shader_parameter("amount", amount)
	return mat


func hayun_blur() -> float:
	return (hayun.material as ShaderMaterial).get_shader_parameter("amount") if hayun and hayun.material else 0.0
