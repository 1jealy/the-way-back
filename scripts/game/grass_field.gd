class_name GrassField
extends Node2D
## 바람에 흔들리는 풀(#142). 장면표 2 "하윤이 지나가면 들풀이 갈라진다".
## 풀잎을 한 장씩 MultiMesh로 그리고 shaders/grass.gdshader가 흔든다. 풀잎은 고르게 깔지 않고 포기(다발)로 모아
## 부채꼴로 벌어지게 심고, 그 사이에 이삭 달린 줄기(stalk)를 섞는다. 끝은 해빛에 밝다(배경의 밝은 테와 같은 빛).
## 하윤이 지나가면 가까운 풀이 하윤에게서 비켜 눕고, 지나간 뒤에는 출렁이며 돌아온다(구멍이 뚫리지 않게 휘기만).
## 뒤 겹(back_z, 하윤 뒤)과 앞 겹(front_z, 하윤 앞, 어둡고 성긴 실루엣) 두 겹이라 키 큰 풀숲에서는 하윤이 파묻힌다.
## 2-3 날아간 지도(MapChase)가 날아갈 때 풀이 크게 눕는다.
## 장소 씬에 B가 놓는다(Grass_<장면>_<이름>). 원점은 풀숲 왼쪽 끝 땅 위(y = 810). 담당: B(연출, 바람 셰이더).

## 풀숲 길이(px, 원점에서 오른쪽으로).
@export var length: float = 2000.0
## 100px에 풀잎 몇 장(이삭 줄기는 따로 stalk_ratio만큼 더).
@export var density: float = 60.0
## 앞 겹 비율(0 = 모두 하윤 뒤).
@export_range(0.0, 1.0) var front_ratio: float = 0.0
@export var back_z: int = -4
@export var front_z: int = 3
## 뿌리 높이(원점 기준 y, 아래가 +). 뒤 겹과 앞 겹 따로.
@export var back_root: Vector2 = Vector2(-22.0, -14.0)
@export var front_root: Vector2 = Vector2(22.0, 60.0)
## 풀잎 키·폭(px).
@export var height: Vector2 = Vector2(30.0, 80.0)
@export var blade_width: Vector2 = Vector2(4.0, 7.0)
## 한 포기의 풀잎 수.
@export var clump: Vector2i = Vector2i(5, 11)
## 풀잎 수에 대한 이삭 줄기 비율.
@export var stalk_ratio: float = 0.12
## 양 끝에서 키를 줄이는 구간(px). 풀숲이 갑자기 끝나 보이지 않게.
@export var taper: float = 300.0
## 풀잎 색(뿌리는 어둡고 끝은 밝게 칠한다). 하나씩 골라 조금씩 흔든다. 배경 가까운 밭(near)의 들풀 색과 같은 계열.
@export var colors: PackedColorArray = PackedColorArray([
	Color(0.73, 0.52, 0.21), Color(0.8, 0.58, 0.25), Color(0.68, 0.47, 0.2), Color(0.88, 0.68, 0.34)])
## 앞 겹 색에 곱한다(가까워서 어두운 실루엣. 배경의 흐린 앞 층 들풀과 같게).
@export var front_tint: Color = Color(0.66, 0.52, 0.42)
## 앞 겹 밀도에 곱한다(성기게 — 사이로 하윤이 보이게).
@export var front_sparse: float = 0.85
## 앞 겹을 비우는 자리(전역 x)와 반폭. 땅에 놓인 물건(연)이 가려지지 않게.
@export var clear_spots: PackedFloat32Array = PackedFloat32Array()
@export var clear_half: float = 90.0
@export var sway_px: float = 9.0
@export var push_radius: float = 120.0
@export var push_px: float = 40.0
@export var seed_text: String = "grass"

var back: MultiMeshInstance2D
var front: MultiMeshInstance2D
var back_stalks: MultiMeshInstance2D
var front_stalks: MultiMeshInstance2D
var gust: float = 0.0
var _mat: ShaderMaterial
var _gust_tween: Tween
var _player_vel: float = 0.0
var _last_player_x: float = NAN


func _ready() -> void:
	add_to_group("grass_field")
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/grass.gdshader")
	_mat.set_shader_parameter("sway_px", sway_px)
	_mat.set_shader_parameter("push_radius", push_radius)
	_mat.set_shader_parameter("push_px", push_px)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var total := int(length / 100.0 * density)
	var n_front := int(total * front_ratio)
	var n_back := total - n_front
	back = _build("Back", _blade_mesh(), n_back, back_z, back_root, Color.WHITE, rng, false, 1.0)
	front = _build("Front", _blade_mesh(), n_front, front_z, front_root, front_tint, rng, true, 1.0)
	back_stalks = _build("BackStalks", _stalk_mesh(), int(n_back * stalk_ratio), back_z, back_root, Color.WHITE, rng, false, 1.15)
	front_stalks = _build("FrontStalks", _stalk_mesh(), int(n_front * stalk_ratio), front_z, front_root, front_tint, rng, true, 1.15)
	_connect_wind.call_deferred()


## 2-3 날아간 지도: 지도가 날아갈 때 풀이 크게 눕는다.
func _connect_wind() -> void:
	for mc in get_tree().get_nodes_in_group("map_chase"):
		if mc.has_signal("blown_away") and not mc.blown_away.is_connected(blow):
			mc.blown_away.connect(blow)


## count장을 포기로 모아 심는다. 포기 가운데가 키가 크고, 바깥 잎일수록 부채꼴로 벌어진다.
func _build(node_name: String, mesh: Mesh, count: int, z: int, root: Vector2, tint: Color,
		rng: RandomNumberGenerator, is_front: bool, tall: float) -> MultiMeshInstance2D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	var want := count
	if is_front:
		want = int(count * front_sparse)
	var blades: Array = []  # [x, y, h, wd, lean]
	var guard := 0
	while blades.size() < want and guard < want * 4:
		guard += 1
		var cx := rng.randf() * length
		if is_front and _cleared(global_position.x + cx):
			continue
		var edge := clampf(minf(cx, length - cx) / maxf(taper, 1.0), 0.0, 1.0)
		var tallest := rng.randf_range(height.x, height.y) * lerpf(0.35, 1.0, edge) * tall
		var cy := rng.randf_range(root.x, root.y)
		var n := rng.randi_range(clump.x, clump.y)
		for k in n:
			if blades.size() >= want:
				break
			var u := rng.randf_range(-1.0, 1.0)  # -1 왼쪽 바깥 잎 … 1 오른쪽 바깥 잎
			var x := cx + u * 12.0 + rng.randf_range(-3.0, 3.0)
			if is_front and _cleared(global_position.x + x):
				continue
			var h := tallest * lerpf(1.0, 0.55, absf(u)) * rng.randf_range(0.85, 1.05)
			var lean := u * h * rng.randf_range(0.25, 0.45)  # 부채꼴로 벌어진다(끝이 이만큼 옆으로)
			blades.append([x, cy + rng.randf_range(-3.0, 3.0), h, rng.randf_range(blade_width.x, blade_width.y), lean])
	mm.instance_count = blades.size()
	for i in blades.size():
		var b: Array = blades[i]
		var x: float = b[0]
		var y: float = b[1]
		var h: float = b[2]
		var wd: float = b[3]
		var lean: float = b[4]
		# 풀잎 메시는 키 1(위가 -y), 폭 1. y축에 기울기(-lean)를 넣으면 끝이 lean만큼 옆으로 간다.
		mm.set_instance_transform_2d(i, Transform2D(Vector2(wd, 0.0), Vector2(-lean, h), Vector2(x, y)))
		var c: Color = colors[rng.randi() % colors.size()]
		c = c.lightened(rng.randf_range(-0.06, 0.08)) * tint
		c.a = 1.0
		mm.set_instance_color(i, c)
		mm.set_instance_custom_data(i, Color(x, floorf(wd * 10.0) + rng.randf() * 0.999, h, y))
	var inst := MultiMeshInstance2D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material = _mat
	inst.z_index = z
	inst.z_as_relative = false
	add_child(inst)
	return inst


func _cleared(gx: float) -> bool:
	for s in clear_spots:
		if absf(gx - s) < clear_half:
			return true
	return false


## 풀잎 한 장: 키 1, 폭 1. 뿌리(0,0)에서 위(-y)로 가늘어지며 살짝 휜다.
## 색: 뿌리는 어둡고 투명하게(땅에 녹게), 위로 갈수록 밝고, 끝은 해빛에 더 밝다.
static func _blade_mesh() -> ArrayMesh:
	return _strip_mesh(func(t: float) -> float: return 0.5 * (1.0 - t * 0.94), 7)


## 이삭 줄기: 가는 줄기 끝에 길쭉한 이삭이 달린다.
static func _stalk_mesh() -> ArrayMesh:
	return _strip_mesh(func(t: float) -> float:
		if t < 0.72:
			return 0.16
		var u := (t - 0.72) / 0.28
		return 0.16 + 0.5 * sin(u * PI) * (1.0 - u * 0.4), 10)


static func _strip_mesh(half_width: Callable, seg: int) -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in seg + 1:
		var t := float(i) / seg  # 0 = 뿌리
		var half: float = half_width.call(t)
		var cx := -0.6 * t * t  # 끝이 왼쪽으로 조금 휜다(폭 단위)
		var shade := lerpf(0.5, 1.0, smoothstep(0.0, 0.7, t)) + smoothstep(0.75, 1.0, t) * 0.28
		for side in [-1.0, 1.0]:
			verts.append(Vector2(cx + side * half, -t))
			uvs.append(Vector2(0.5 + side * 0.5, 1.0 - t))
			cols.append(Color(shade, shade, shade, smoothstep(0.0, 0.3, t)))
	for i in seg:
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(delta: float) -> void:
	_mat.set_shader_parameter("origin", global_position)
	_mat.set_shader_parameter("gust", gust)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var px := player.global_position.x
		if not is_nan(_last_player_x) and delta > 0.0:
			var v := clampf((px - _last_player_x) / delta, -600.0, 600.0)
			_player_vel = lerpf(_player_vel, v, minf(1.0, delta * 6.0))
		_last_player_x = px
		_mat.set_shader_parameter("player_pos", player.global_position)
		_mat.set_shader_parameter("player_vel", _player_vel)


## 센 바람 한 번: 풀이 크게 눕었다가 천천히 일어난다.
func blow(strength: float = 1.0) -> void:
	if _gust_tween and _gust_tween.is_valid():
		_gust_tween.kill()
	_gust_tween = create_tween()
	_gust_tween.tween_property(self, "gust", strength, 0.35).set_trans(Tween.TRANS_SINE)
	_gust_tween.tween_property(self, "gust", 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
