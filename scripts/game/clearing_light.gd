class_name ClearingLight
extends Node2D
## 장면표 4-3 빈터: "하윤이 앉으면 빛이 쏟아진다. 하늘이가 한쪽을 바라보며 꼬리를 흔든다."
## 빈터의 앉는 자리(BenchSit, sit 경로)에 하윤이 앉으면 위에서 빛기둥이 짙어지며 금빛 알갱이가 쏟아지고
## 장소 층이 따뜻하게 밝아진다. 하늘이는 그 자리에 멈춰 look_dir 쪽(기억 장면이 떴던 쪽)을 보며 꼬리를 흔든다.
## 일어나면 천천히 원래대로. 몇 번이든 앉을 수 있다. 대사 없음.
## 장소 씬에 B가 놓는다(Light_4-3, 원점은 땅 위, 빛이 내리는 가운데). 담당: B(연출). 하늘이 동작: A.

signal poured
signal faded

## 이 자리에 앉으면 빛이 쏟아진다(BenchSit).
@export var sit: NodePath
## 하늘이가 바라보는 쪽(1 = 오른쪽, -1 = 왼쪽).
@export var look_dir: int = 1
## 빛기둥 폭·높이(px). 화면 위 바깥에서 땅까지.
@export var beam_size: Vector2 = Vector2(520.0, 1100.0)
@export var beam_color: Color = Color(1.0, 0.9, 0.62, 1.0)
## 앉아 있는 동안 장소 층 색(1보다 크면 밝아진다).
@export var place_tint: Color = Color(1.12, 1.08, 0.94, 1.0)
@export var pour_seconds: float = 2.4
@export var fade_seconds: float = 2.0

var pouring: bool = false
var _beam: Sprite2D
var _motes: CPUParticles2D
var _tween: Tween
var _dog: Node


func _ready() -> void:
	add_to_group("clearing_light")
	_beam = Sprite2D.new()
	_beam.name = "Beam"
	_beam.texture = _beam_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = mat
	_beam.z_index = 6  # 하윤 앞(빛이 하윤 위로 쏟아진다), 앞 층 뒤
	_beam.z_as_relative = false
	_beam.scale = beam_size / 64.0
	_beam.position = Vector2(0.0, -beam_size.y * 0.5 + 40.0)
	_beam.modulate = Color(beam_color, 0.0)
	add_child(_beam)

	_motes = CPUParticles2D.new()
	_motes.name = "Motes"
	_motes.emitting = false
	_motes.amount = 90
	_motes.lifetime = 3.2
	_motes.position = Vector2(0.0, -beam_size.y + 120.0)
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(beam_size.x * 0.35, 20.0)
	_motes.direction = Vector2(0.0, 1.0)
	_motes.spread = 12.0
	_motes.gravity = Vector2(0.0, 40.0)
	_motes.initial_velocity_min = 140.0
	_motes.initial_velocity_max = 260.0
	_motes.scale_amount_min = 2.0
	_motes.scale_amount_max = 5.0
	_motes.color = Color(1.0, 0.88, 0.55, 0.9)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 0.8))
	_motes.color_ramp = fade
	_motes.z_index = 6
	_motes.z_as_relative = false
	_motes.material = mat
	add_child(_motes)

	var s := get_node_or_null(sit)
	if s:
		s.sat_down.connect(_pour)
		s.stood_up.connect(_fade)


func _pour() -> void:
	pouring = true
	_motes.emitting = true
	_retween()
	_tween.tween_property(_beam, "modulate:a", 0.62, pour_seconds).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_beam, "scale:x", beam_size.x * 1.35 / 64.0, pour_seconds)
	var layers := _layers()
	if layers:
		_tween.parallel().tween_property(layers, "modulate", place_tint, pour_seconds)
	_dog = get_tree().get_first_node_in_group("dog")
	if _dog and _dog.has_method("is_joined") and _dog.is_joined() and not _dog.is_busy():
		_dog.script_move_to(_dog.global_position.x)  # 그 자리에 멈춰 앉는다
		_dog.look(look_dir)
		_dog.wag(true)
	else:
		_dog = null
	poured.emit()


func _fade() -> void:
	pouring = false
	_motes.emitting = false
	_retween()
	_tween.tween_property(_beam, "modulate:a", 0.0, fade_seconds)
	_tween.parallel().tween_property(_beam, "scale:x", beam_size.x / 64.0, fade_seconds)
	var layers := _layers()
	if layers:
		_tween.parallel().tween_property(layers, "modulate", Color.WHITE, fade_seconds)
	if _dog and is_instance_valid(_dog):
		_dog.wag(false)
		_dog.release_script()
	_dog = null
	faded.emit()


func _retween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()


func _layers() -> CanvasItem:
	var place := get_tree().get_first_node_in_group("place") as Node
	return place.get_node_or_null("Layers") as CanvasItem if place else null


func _exit_tree() -> void:
	if pouring:
		var layers := _layers()
		if layers:
			layers.modulate = Color.WHITE
		if _dog and is_instance_valid(_dog):
			_dog.wag(false)


## 가운데가 밝고 양옆으로 사라지는 빛기둥(위아래는 같은 밝기, 위쪽은 화면 밖이다).
static func _beam_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.5))
	g.add_point(0.32, Color(1, 1, 1, 0.18))
	g.add_point(0.68, Color(1, 1, 1, 0.18))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex
