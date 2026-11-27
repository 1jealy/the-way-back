class_name BankLight
extends MiniGame
## 철교 6-2 끊긴 끝에서 강둑 아래를 비추는 미니게임(#116, 기획서 "미니게임"). 집 마당에서 주운 할아버지 손전등으로 한다.
## 끊긴 끝에서 [E] 강둑 비추기(#119)로 하윤이 손전등을 켜 아래 안개를 비춘다. ← →로 빛을 아래위로 움직인다.
## 안개 속에 디딤돌 다섯이 강둑까지 이어져 있고, 빛이 다음 돌에 잠깐 머물면 그 돌이 빛을 머금고 남는다(차례대로).
## 다음 돌이 아닌 돌은 빛이 지나갈 때만 비치고, 거기 머물면 한 번 깜빡이며 다음 돌이 숨 쉰다("아직", #119). 물그림자(가짜 돌)를 오래 비추면 흩어진다(한 번 어긋남).
## 다 찾으면 돌이 하나씩 다시 빛나고 grants_flag(bridge_bank_path)가 서서 "강둑으로 내려가기"가 열린다.
## 도움(세 번 어긋나면): 빛이 넓어지고, 하늘이가 다음 돌 쪽을 보고 짖고, 다음 돌이 빛 밖에서도 희미하게 숨 쉰다.
## 손전등 없이 왔으면 시작하지 않는다 — 예전처럼 하늘이 냄새 부탁(ask_spot)으로 간다. 손전등이 있으면 그 부탁 자리는 닫는다.
## 장소 씬에 B가 놓는다(BankLight_6-3). 원점은 땅 위, 하윤이 손전등을 가진 채 원점을 지나면 시작한다.

## 차례가 아닌 돌을 먼저 비췄을 때(i = 그 돌).
signal not_yet(i: int)

const MIX_RATE := 22050
const AIM_MIN := 22.0
const AIM_MAX := 88.0
const AIM_SPEED := 38.0          # 도/초
const BEAM_LENGTH := 720.0
const STONE_COLOR := Color(0.86, 0.84, 0.95)
const LIT_COLOR := Color(1.0, 0.93, 0.72)

## 이 플래그(물건)가 서 있어야 시작한다.
@export var trigger_flag: StringName = &"item_flashlight"
## 손전등이 있으면 닫는 예전 길(하늘이 냄새 부탁).
@export var ask_spot: NodePath
## 디딤돌 다섯의 자리(장소 좌표, 하윤에게서 먼 쪽이 마지막). 강둑 비탈까지 이어진다.
@export var stones: PackedVector2Array = PackedVector2Array([
	Vector2(3725, 965), Vector2(3830, 1008), Vector2(3935, 1036), Vector2(4040, 1014), Vector2(4145, 985)])
## 물그림자(가짜 돌) 자리. 하윤 손에서 본 각도가 이웃 돌과 5도 넘게 떨어져야 한다(빛 가운데 판정이 반폭의 0.6).
@export var decoys: PackedVector2Array = PackedVector2Array([Vector2(3760, 1050), Vector2(3880, 1070)])
## 빛 반폭(도). 도움이면 넓어진다.
@export var beam_half: float = 8.0
## 빛이 이만큼 머물러야 돌을 찾는다(초).
@export var dwell: float = 0.7

## 지금까지 찾은 돌 수.
var found: int = 0
## 빛의 각도(도, 수평에서 아래로).
var aim: float = 40.0
## aim(비추는 중) / done
var phase: StringName = &"idle"

var _stone_nodes: Array[Sprite2D] = []
var _stone_glows: Array[Sprite2D] = []
var _decoy_nodes: Array[Sprite2D] = []
var _decoy_hold: PackedFloat32Array = PackedFloat32Array()
var _decoy_gone: PackedFloat32Array = PackedFloat32Array()
var _hold: float = 0.0
var _beam: Polygon2D
var _fog: Polygon2D
var _torch: Sprite2D
var _sfx: AudioStreamPlayer
var _chime: AudioStreamWAV
var _click: AudioStreamWAV
var _plop: AudioStreamWAV
var _t: float = 0.0
var _pulse: float = 0.0
var _hinted: bool = false
var _early_hold: float = 0.0
var _early_cool: float = 0.0
## 다음 돌이 숨 쉬는 정도(1 → 0, "아직" 뒤 잠깐).
var _guide: float = 0.0
var _flash: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	super._ready()
	setup_start(trigger_flag)
	if GameState.has_flag(trigger_flag):
		_close_ask_spot.call_deferred()
	GameState.flag_changed.connect(_on_flag_changed)


func _on_flag_changed(flag: StringName) -> void:
	if flag == trigger_flag and GameState.has_flag(flag):
		_close_ask_spot()


## 손전등이 있으면 냄새 부탁 자리는 쓰지 않는다(힌트도 거기를 안 가리키게).
func _close_ask_spot() -> void:
	if ask_spot.is_empty() or done:
		return
	var spot := get_node_or_null(ask_spot)
	if spot and "used" in spot and not GameState.has_flag(grants_flag):
		spot.used = true


func _process(delta: float) -> void:
	if not running and not done and not starts_on_prompt() and GameState.has_flag(trigger_flag):
		var player := get_tree().get_first_node_in_group("player") as Player
		if player and player.controls_enabled and player.global_position.x >= global_position.x:
			play()
	super._process(delta)


func _begin() -> void:
	if _chime == null:
		_chime = _make_tone(880.0, 0.7)
		_click = _make_noise(0.05, 0.9, 0.8)
		_plop = _make_noise(0.35, 0.12, 0.6)
	_build()
	if _player:
		_player.face(1)
		_player.set_pose(&"flashlight")
	_sfx.stream = _click
	_sfx.play()
	aim = 40.0
	found = 0
	phase = &"aim"
	var tw := create_tween()
	tw.tween_property(_beam, "modulate:a", 1.0, 0.35)
	show_key_hint(["←", "→"], "비추기")


func _build() -> void:
	var mote := CutscenePlayer.find_art("fx_light_mote")
	var glow_tex: Texture2D = load(mote) if not mote.is_empty() else null
	var stone_path := CutscenePlayer.find_art("prop_step_stone")
	var moss_path := CutscenePlayer.find_art("prop_step_stone_moss")
	_fog = Polygon2D.new()
	_fog.name = "Fog"
	_fog.z_index = 3
	_fog.z_as_relative = false
	# 가장자리가 번지는 안개(네 열 × 세 줄 격자, 바깥 열·윗줄이 투명)
	var x0 := stones[0].x - 200.0
	var x1 := stones[stones.size() - 1].x + 220.0
	var xs := [x0, x0 + 180.0, x1 - 180.0, x1]
	var ys := [870.0, 950.0, 1090.0]
	var col_a := [0.0, 1.0, 1.0, 0.0]
	var row_a := [0.0, 0.8, 1.0]
	var fc := Color(0.55, 0.51, 0.69)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for r in 3:
		for c in 4:
			pts.append(Vector2(xs[c], ys[r]))
			cols.append(Color(fc, 0.5 * col_a[c] * row_a[r]))
	var quads := []
	for r in 2:
		for c in 3:
			var k := r * 4 + c
			quads.append(PackedInt32Array([k, k + 1, k + 5, k + 4]))
	_fog.polygon = pts
	_fog.vertex_colors = cols
	_fog.polygons = quads
	add_child(_fog)
	_fog.global_position = Vector2.ZERO
	_stone_nodes.clear()
	_stone_glows.clear()
	_flash.resize(stones.size())
	_flash.fill(0.0)
	for i in stones.size():
		var g := Sprite2D.new()
		g.name = "StoneGlow%d" % i
		g.texture = glow_tex
		g.scale = Vector2(3.0, 1.5)
		g.modulate = Color(LIT_COLOR, 0.0)
		g.z_index = 4
		g.z_as_relative = false
		add_child(g)
		g.global_position = stones[i] + Vector2(0, 4)
		_stone_glows.append(g)
		var s := Sprite2D.new()
		s.name = "Stone%d" % i
		var p := moss_path if i % 2 == 1 and not moss_path.is_empty() else stone_path
		if not p.is_empty():
			s.texture = load(p)
		s.scale = Vector2(0.72, 0.72) * (1.0 + i * 0.06)
		s.modulate = Color(STONE_COLOR, 0.0)
		s.z_index = 4
		s.z_as_relative = false
		add_child(s)
		s.global_position = stones[i]
		_stone_nodes.append(s)
	_decoy_nodes.clear()
	_decoy_hold.resize(decoys.size())
	_decoy_gone.resize(decoys.size())
	for i in decoys.size():
		var d := Sprite2D.new()
		d.name = "Decoy%d" % i
		if not stone_path.is_empty():
			d.texture = load(stone_path)
		d.scale = Vector2(0.6, 0.42)
		d.modulate = Color(0.7, 0.72, 0.9, 0.0)
		d.z_index = 4
		d.z_as_relative = false
		add_child(d)
		d.global_position = decoys[i]
		_decoy_nodes.append(d)
		_decoy_hold[i] = 0.0
		_decoy_gone[i] = 0.0
	_beam = Polygon2D.new()
	_beam.name = "Beam"
	_beam.z_index = 5
	_beam.z_as_relative = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = add
	_beam.modulate.a = 0.0
	add_child(_beam)
	_torch = Sprite2D.new()
	_torch.name = "HeldTorch"
	var tp := CutscenePlayer.find_art("prop_flashlight")
	if not tp.is_empty():
		_torch.texture = load(tp)
	_torch.scale = Vector2(0.42, 0.42)
	_torch.z_index = 1
	_torch.z_as_relative = false
	add_child(_torch)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Sfx"
	_sfx.bus = SoundBank.BUS_SFX
	add_child(_sfx)
	var tw := create_tween()
	tw.tween_method(_set_fog_alpha, 0.0, 1.0, 0.8)


func _set_fog_alpha(a: float) -> void:
	if _fog:
		_fog.modulate.a = a


## 빛이 나오는 자리(손전등 앞).
func beam_origin() -> Vector2:
	var hand := _player.hand_point() if _player else global_position + Vector2(40, -180)
	return hand + Vector2.from_angle(deg_to_rad(aim)) * 34.0


## 그 자리가 빛 가운데에서 몇 도 떨어져 있나.
func angle_off(p: Vector2) -> float:
	var v := p - beam_origin()
	return absf(rad_to_deg(v.angle()) - aim)


## i번째 돌을 비추려면 몇 도로 들어야 하나.
func aim_for(p: Vector2) -> float:
	return rad_to_deg((p - beam_origin()).angle())


func _half() -> float:
	return beam_half * (1.8 if help else 1.0)


func _tick(delta: float) -> void:
	_t += delta
	_pulse = move_toward(_pulse, 0.0, delta * 2.0)
	_guide = move_toward(_guide, 0.0, delta * 0.6)
	for k in _flash.size():
		_flash[k] = move_toward(_flash[k], 0.0, delta * 1.6)
	if phase == &"aim":
		var dir := 0.0
		if MiniGame.autoplay:
			var want := aim_for(stones[found])
			dir = clampf((want - aim) / 4.0, -1.0, 1.0)
		else:
			# 오른쪽(→)은 멀리(빛을 든다), 왼쪽(←)은 가까이(발밑으로)
			if Input.is_action_pressed("move_right"):
				dir -= 1.0
			if Input.is_action_pressed("move_left"):
				dir += 1.0
		if dir != 0.0 and has_key_hint():
			hide_key_hint()
		aim = clampf(aim + dir * AIM_SPEED * delta, AIM_MIN, AIM_MAX)
		_check(delta)
	_draw_beam()
	_shade()
	_pose_player()
	_place_torch()
	_place_hint()


func _check(delta: float) -> void:
	var half := _half()
	if found < stones.size() and angle_off(stones[found]) < half * 0.6:
		_hold += delta
		if _hold >= dwell:
			_light(found)
	else:
		_hold = maxf(0.0, _hold - delta * 2.0)
	# 차례가 아닌 돌(더 먼 돌)에 머물면 "아직" — 그 돌이 한 번 깜빡이고 다음 돌이 숨 쉰다(#119: 반응이 없어 헷갈렸다)
	var early := -1
	var best := half * 0.6
	for i in range(found + 1, stones.size()):
		var off := angle_off(stones[i])
		if off < best:
			best = off
			early = i
	if early >= 0:
		_early_hold += delta
		if _early_hold >= dwell and _early_cool <= 0.0:
			_not_yet(early)
	else:
		_early_hold = 0.0
	_early_cool -= delta
	for i in decoys.size():
		if _decoy_gone[i] > 0.0:
			_decoy_gone[i] -= delta
			continue
		# 도움이 켜지면 물그림자는 더 속이지 않는다
		if not help and angle_off(decoys[i]) < half * 0.6:
			_decoy_hold[i] += delta
			if _decoy_hold[i] >= dwell + 0.25:
				_scatter(i)
		else:
			_decoy_hold[i] = maxf(0.0, _decoy_hold[i] - delta)


func _light(i: int) -> void:
	_hold = 0.0
	found += 1
	_hinted = false
	_pulse = 1.0
	_sfx.stream = _chime
	_sfx.pitch_scale = 1.0 + i * 0.12
	_sfx.play()
	var g := _stone_glows[i]
	var tw := create_tween().set_parallel()
	tw.tween_property(g, "modulate:a", 0.85, 0.25)
	tw.tween_property(g, "scale", Vector2(3.2, 1.6), 0.25)
	tw.chain().tween_property(g, "modulate:a", 0.7, 0.6)
	tw.parallel().tween_property(g, "scale", Vector2(2.4, 1.2), 0.6)
	if found >= stones.size():
		_finish()


## 더 먼 돌을 먼저 비췄다: 어긋남은 아니다. 그 돌이 한 번 깜빡이고(낮은 종) 다음 돌이 잠깐 숨 쉰다.
func _not_yet(i: int) -> void:
	_early_hold = 0.0
	_early_cool = 1.5
	_guide = 1.0
	_sfx.stream = _chime
	_sfx.pitch_scale = 0.75
	_sfx.play()
	_flash[i] = 1.0
	not_yet.emit(i)


## 물그림자였다: 일렁이며 흩어진다. 한 번 어긋남.
func _scatter(i: int) -> void:
	_decoy_hold[i] = 0.0
	_decoy_gone[i] = 3.0
	_sfx.stream = _plop
	_sfx.pitch_scale = 1.0
	_sfx.play()
	var d := _decoy_nodes[i]
	var tw := create_tween().set_parallel()
	tw.tween_property(d, "scale", Vector2(1.1, 0.18), 0.6)
	tw.tween_property(d, "modulate:a", 0.0, 0.6)
	tw.chain().tween_property(d, "scale", Vector2(0.6, 0.42), 0.01)
	miss()


func _on_help() -> void:
	var dog := get_tree().get_first_node_in_group("dog") as Dog
	if dog and dog.is_joined() and found < stones.size():
		dog.look(1)
		if dog.has_method("_bark"):
			dog._bark()


## 돌·물그림자가 빛에 든 만큼 비친다. 찾은 돌은 늘 보인다.
func _shade() -> void:
	if _stone_nodes.is_empty():
		return
	var half := _half()
	var on := _beam.modulate.a if _beam else 0.0
	for i in _stone_nodes.size():
		var s := _stone_nodes[i]
		var a := 0.0
		if i < found:
			a = 1.0
			s.modulate = Color(LIT_COLOR.lerp(STONE_COLOR, 0.35), 1.0)
			continue
		var off := angle_off(stones[i])
		a = clampf(1.0 - (off - half * 0.5) / (half * 1.6), 0.0, 1.0) * on * 0.9
		if i < _flash.size():
			a = maxf(a, _flash[i] * 0.9)
		if i == found:
			a = maxf(a, clampf(_hold / dwell, 0.0, 1.0))
			if help:
				a = maxf(a, 0.18 + 0.12 * sin(_t * 3.0))
			if _guide > 0.0:
				a = maxf(a, _guide * (0.35 + 0.25 * sin(_t * 9.0)))
		s.modulate = Color(STONE_COLOR, a)
	for i in _decoy_nodes.size():
		if _decoy_gone[i] > 0.0:
			continue
		var off := angle_off(decoys[i])
		var a := clampf(1.0 - (off - half * 0.5) / (half * 1.6), 0.0, 1.0) * on * 0.8
		# 물그림자는 일렁인다
		_decoy_nodes[i].modulate.a = a * (0.75 + 0.25 * sin(_t * 7.0 + i))
		_decoy_nodes[i].scale.x = 0.6 + 0.05 * sin(_t * 5.0 + i * 2.0)


## 빛 원뿔: 손전등에서 퍼지며 끝으로 갈수록 옅어진다.
func _draw_beam() -> void:
	if _beam == null or _player == null:
		return
	var o := beam_origin()
	var half := deg_to_rad(_half() * 1.25)
	var a := deg_to_rad(aim)
	var pts := PackedVector2Array([o])
	var cols := PackedColorArray([Color(1.0, 0.95, 0.78, 0.5 + _pulse * 0.3)])
	var n := 8
	for k in n + 1:
		var u := float(k) / n
		var ang := a - half + 2.0 * half * u
		var edge := 1.0 - absf(u - 0.5) * 2.0
		pts.append(o + Vector2.from_angle(ang) * BEAM_LENGTH * (0.92 + 0.08 * edge))
		cols.append(Color(1.0, 0.92, 0.7, 0.04 * edge))
	_beam.global_position = Vector2.ZERO
	_beam.polygon = pts
	_beam.vertex_colors = cols


## 손전등 든 몸: 팔이 빛을 따라 오르내리고 고개는 빛이 가는 곳을 본다. 숨 쉬듯 살짝 흔들리고 찾으면 움찔한다.
func _pose_player() -> void:
	# 하늘이가 빛이 가는 쪽을 눈으로 따라간다(발밑이면 고개를 숙이고, 멀면 든다, #120)
	var dog := get_tree().get_first_node_in_group("dog")
	if phase == &"aim" and dog and dog.has_method("attend") and dog.is_joined() and not dog.is_busy():
		dog.attend({"head": clampf((aim - 50.0) * 0.5, -14.0, 16.0), "ear": -5.0})
	if _player == null:
		return
	var d := aim - 45.0
	var breath := sin(_t * TAU * 0.4)
	_player.set_motion({
		"shoulder": d * 0.9 + breath * 1.2,
		"elbow": -d * 0.15,
		"head": d * 0.35 - _pulse * 4.0,
		"torso": d * 0.08 + breath * 1.0 - _pulse * 2.0,
		"far_shoulder": breath * 1.5,
	})


func _place_torch() -> void:
	if _torch and _player:
		_torch.global_position = _player.hand_point() + Vector2.from_angle(deg_to_rad(aim)) * 6.0
		_torch.rotation = deg_to_rad(aim)


## 다 찾았다: 돌이 가까운 것부터 하나씩 다시 빛나 길이 된다.
func _finish() -> void:
	var watcher := get_tree().get_first_node_in_group("dog")
	if watcher and watcher.has_method("attend"):
		watcher.attend({})  # 빛을 따라보던 고개를 돌려 놓는다
	phase = &"done"
	hide_key_hint()
	await _wait(0.6)
	for i in _stone_glows.size():
		var tw := create_tween()
		tw.tween_property(_stone_glows[i], "modulate:a", 0.95, 0.2)
		tw.tween_property(_stone_glows[i], "modulate:a", 0.75, 0.5)
		await _wait(0.18)
	await _wait(0.6)
	var fade := create_tween().set_parallel()
	fade.tween_property(_beam, "modulate:a", 0.0, 0.5)
	fade.tween_property(_torch, "modulate:a", 0.0, 0.5)
	fade.tween_method(_set_fog_alpha, 1.0, 0.55, 0.8)
	await fade.finished
	_sfx.stream = _click
	_sfx.pitch_scale = 0.9
	_sfx.play()
	if _player:
		_player.set_motion({})
		_player.set_pose(&"stand")
	_torch.queue_free()
	_torch = null
	_beam.queue_free()
	_beam = null
	clear()


func _make_tone(hz: float, seconds: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		var t := float(k) / MIX_RATE
		var env := minf(1.0, t / 0.01) * exp(-t * 5.0)
		var v := sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 2.0 * t) * exp(-t * 9.0)
		data.encode_s16(k * 2, int(clampf(v * env * 0.32, -1.0, 1.0) * 32767.0))
	return _wav(data)


## 거른 잡음. smooth가 작을수록 낮고 둔하다(물소리), 크면 딸깍.
func _make_noise(seconds: float, smooth: float, gain: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var y := 0.0
	for k in n:
		var t := float(k) / MIX_RATE
		var env := minf(1.0, t / 0.004) * clampf((seconds - t) / (seconds * 0.7), 0.0, 1.0)
		y = lerpf(y, randf() * 2.0 - 1.0, smooth)
		data.encode_s16(k * 2, int(clampf(y * env * gain, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.data = data
	return w
