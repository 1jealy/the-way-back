extends Control
## 타이틀 화면. "이어하기"(저장이 없으면 흐림) / "처음부터" / "끝내기"(웹에서는 없음).
## 배경은 간이역 노을 임시 그림이 천천히 흐르고, 멀리 하윤과 하늘이가 걸어간다. 담당: A(게임플레이).

const MAIN_SCENE := "res://scenes/main.tscn"
const ART := "res://assets/art/placeholder/station/bg_station_%s.png"
## 층 이름 → 한쪽 끝에서 다른 끝까지 갔다 오는 데 걸리는 초. 멀수록 느리다.
const LAYERS := [["sky", 420.0], ["far", 300.0], ["mid", 220.0], ["ground_01", 160.0]]
const FADE_IN := 1.4
const FADE_OUT := 0.7
const AMBIENCE := "res://assets/audio/placeholder/amb_station.ogg"
const AMBIENCE_DB := -16.0

const DIM := Color(0.92, 0.88, 0.80, 0.5)
const BRIGHT := Color(1.0, 0.96, 0.86, 1.0)

var _layers: Array[TextureRect] = []
var _time: float = 0.0
var _leaving: bool = false
var _ambience: AudioStreamPlayer

@onready var _menu: VBoxContainer = $Menu
@onready var _continue: Button = $Menu/Continue
@onready var _new: Button = $Menu/New
@onready var _quit: Button = $Menu/Quit
@onready var _marker: ColorRect = $Marker
@onready var _fade: ColorRect = $Fade
@onready var _title: Control = $Title
@onready var _subtitle: Control = $Subtitle


func _ready() -> void:
	_build_background()
	_style_buttons()
	_continue.disabled = not GameState.has_save()
	_quit.visible = not OS.has_feature("web")
	_continue.pressed.connect(start_continue)
	_new.pressed.connect(start_new)
	_quit.pressed.connect(_quit_game)
	for b in _buttons():
		b.focus_entered.connect(_on_focus.bind(b))
		b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	(_new if _continue.disabled else _continue).grab_focus.call_deferred()
	_start_ambience()
	_fade_in()


func _buttons() -> Array[Button]:
	return [_continue, _new, _quit]


func start_continue() -> void:
	if _leaving:
		return
	if not GameState.load_game():
		_continue.disabled = true
		_new.grab_focus()
		return
	_leave(MAIN_SCENE)


func start_new() -> void:
	if _leaving:
		return
	GameState.delete_save()
	GameState.reset()
	GameState.opening_pending = true  # 0-1 오프닝(사고 뒤 길가)은 처음부터 할 때만
	_leave(MAIN_SCENE)


func _quit_game() -> void:
	if _leaving:
		return
	_leaving = true
	await _fade_out()
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	# E로도 고른다(Enter·Space는 버튼이 받는다).
	if event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused and not focused.disabled:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()


func _process(delta: float) -> void:
	_time += delta
	var view := get_viewport_rect().size
	for i in _layers.size():
		var layer := _layers[i]
		var travel := maxf(layer.size.x - view.x, 0.0)
		var period: float = LAYERS[i][1]
		# 끝에서 끝까지 천천히 갔다가 돌아온다.
		layer.position.x = -travel * (0.5 - 0.5 * cos(_time * TAU / period))


func _build_background() -> void:
	var holder: Control = $Background
	for item in LAYERS:
		var path := ART % item[0]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.size = tex.get_size()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
		_layers.append(rect)
	# 글이 읽히게 왼쪽과 아래를 누른다.
	holder.add_child(_shade(Vector2(0, 0.5), Vector2(1, 0.5), [Color(0.05, 0.03, 0.08, 0.86), Color(0.05, 0.03, 0.08, 0.0)], [0.0, 0.66]))
	holder.add_child(_shade(Vector2(0.5, 0), Vector2(0.5, 1), [Color(0, 0, 0, 0.0), Color(0.03, 0.02, 0.05, 0.72)], [0.62, 1.0]))
	# 멀리 길 위를 걷는 하윤과 하늘이, 그 위로 떠오르는 빛 알갱이.
	var walkers := Node2D.new()
	walkers.name = "Walkers"
	walkers.set_script(load("res://scripts/ui/title_walkers.gd"))
	walkers.position = Vector2(0, 790)
	holder.add_child(walkers)
	holder.add_child(_motes())


func _shade(from: Vector2, to: Vector2, colors: Array, offsets: Array) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _motes() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Motes"
	p.amount = 46
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector2(1100, 1000)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1000, 120)
	p.direction = Vector2(0.15, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -4)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 0.86, 0.55, 0.0), Color(1, 0.86, 0.55, 0.7), Color(1, 0.9, 0.65, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = ramp
	return p


func _style_buttons() -> void:
	var empty := StyleBoxEmpty.new()
	for b in _buttons():
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			b.add_theme_stylebox_override(state, empty)
		b.add_theme_color_override("font_color", DIM)
		b.add_theme_color_override("font_hover_color", BRIGHT)
		b.add_theme_color_override("font_focus_color", BRIGHT)
		b.add_theme_color_override("font_pressed_color", BRIGHT)
		b.add_theme_color_override("font_hover_pressed_color", BRIGHT)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.16))


## 고른 줄 옆으로 짧은 선이 따라간다.
func _on_focus(b: Button) -> void:
	await get_tree().process_frame
	var y := b.global_position.y + b.size.y * 0.5 - _marker.size.y * 0.5
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_marker, "global_position:y", y, 0.18)


func _start_ambience() -> void:
	if not ResourceLoader.exists(AMBIENCE):
		return
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = load(AMBIENCE)
	_ambience.bus = &"Ambience"
	_ambience.volume_db = -60.0
	add_child(_ambience)
	_ambience.play()
	create_tween().tween_property(_ambience, "volume_db", AMBIENCE_DB, 2.5)


func _fade_in() -> void:
	_fade.modulate.a = 1.0
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_menu.modulate.a = 0.0
	_marker.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 0.0, FADE_IN)
	t.tween_property(_title, "modulate:a", 1.0, 0.9)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.4)
	t.tween_property(_menu, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(_marker, "modulate:a", 1.0, 0.6)


func _fade_out() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_fade, "modulate:a", 1.0, FADE_OUT)
	if _ambience:
		t.tween_property(_ambience, "volume_db", -60.0, FADE_OUT)
	await t.finished


func _leave(scene: String) -> void:
	_leaving = true
	await _fade_out()
	get_tree().change_scene_to_file(scene)
