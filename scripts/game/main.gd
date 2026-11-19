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
@onready var _camera: Camera2D = $World/Player/Camera
@onready var _fade: ColorRect = $Overlay/Fade
@onready var _place_label: Label = $Overlay/PlaceLabel


func _ready() -> void:
	_fade.modulate.a = 1.0
	_swap_place(FIRST_PLACE)
	await _fade_to(0.0)


func current_place() -> Place:
	return _place


func go_to(path: String) -> void:
	if _changing:
		return
	_changing = true
	_player.set_controls_enabled(false)
	await _fade_to(1.0)
	_swap_place(path)
	await _fade_to(0.0)
	_player.set_controls_enabled(true)
	_changing = false


func _swap_place(path: String) -> void:
	if _place:
		_place_slot.remove_child(_place)
		_place.queue_free()
	var scene: PackedScene = load(path)
	_place = scene.instantiate()
	_place_slot.add_child(_place)
	_place.exit_reached.connect(_on_exit_reached)

	_player.global_position = _place.spawn_position()
	_player.velocity = Vector2.ZERO
	_camera.limit_left = 0
	_camera.limit_right = int(_place.width)
	_camera.limit_top = 0
	_camera.limit_bottom = int(Place.SCREEN_H)
	_camera.reset_smoothing()

	GameState.current_place = _place.place_id
	_place_label.text = _place.display_name
	place_changed.emit(_place.place_id)


func _on_exit_reached() -> void:
	if _place.next_place.is_empty():
		return
	go_to(_place.next_place)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_SECONDS)
	await tween.finished
