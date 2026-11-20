class_name MistReveal
extends Node
## 장면표 7-1: 장소에 들어서면 하얀 안개가 천천히 걷히고, 휘파람 선율이 작게 시작된다.
## 나루터 씬에 B가 놓는다(Mist_7-1). 음악은 main이 들고 있어서 장소를 옮겨도(7-6 강 위) 이어진다.
## 담당: B(안개 연출). (A 세션이 쉬는 동안 B 세션이 만듦)

@export var reveal_seconds: float = 5.0
@export var mist_color: Color = Color(1.0, 0.99, 0.96, 0.92)
@export var music: String = "mus_theme_full"
@export var music_db: float = -14.0


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var mist := ColorRect.new()
	mist.name = "Mist"
	mist.color = mist_color
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(mist)
	create_tween().tween_property(mist, "color:a", 0.0, reveal_seconds).set_trans(Tween.TRANS_SINE)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("play_music") and not music.is_empty():
		main.play_music(music, music_db, reveal_seconds)
