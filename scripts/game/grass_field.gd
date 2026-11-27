class_name GrassField
extends Node2D
## 바람에 흔들리는 풀잎(#142). 장면표 2 "하윤이 지나가면 들풀이 갈라진다".
## 풀잎 한 장 한 장을 MultiMesh로 그리고 shaders/grass.gdshader가 흔든다. 하윤 가까이 있는 풀은
## 하윤에게서 바깥으로 휘었다가 하윤이 지나가면 돌아온다. 뒤 겹(back_z, 하윤 뒤)과 앞 겹(front_z, 하윤 앞)
## 두 겹이라 키 큰 풀숲에서는 하윤이 허리까지 파묻힌다. 2-3 날아간 지도(MapChase)가 날아갈 때 풀이 크게 눕는다.
## 장소 씬에 B가 놓는다(Grass_<장면>_<이름>). 원점은 풀숲 왼쪽 끝 땅 위(y = 810). 담당: B(연출, 바람 셰이더).

## 풀숲 길이(px, 원점에서 오른쪽으로).
@export var length: float = 2000.0
## 100px에 풀잎 몇 장.
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
## 끝 쪽 키를 양 끝에서 줄이는 구간(px). 풀숲이 갑자기 끝나 보이지 않게.
@export var taper: float = 300.0
## 풀잎 색(뿌리는 더 어둡게 칠한다). 하나씩 골라 조금씩 흔든다.
@export var colors: PackedColorArray = PackedColorArray([
	Color(0.78, 0.55, 0.24), Color(0.86, 0.64, 0.3), Color(0.72, 0.5, 0.22), Color(0.93, 0.76, 0.42)])
## 앞 겹 색에 곱한다(가까워서 조금 어둡다).
@export var front_tint: Color = Color(0.82, 0.76, 0.7)
## 앞 겹을 비우는 자리(전역 x)와 반폭. 땅에 놓인 물건(방패연)이 가려지지 않게.
@export var clear_spots: PackedFloat32Array = PackedFloat32Array()
@export var clear_half: float = 90.0
@export var sway_px: float = 9.0
@export var push_radius: float = 120.0
@export var push_px: float = 70.0
@export var seed_text: String = "grass"

var back: MultiMeshInstance2D
var front: MultiMeshInstance2D
var gust: float = 0.0
var _mat: ShaderMaterial
var _gust_tween: Tween


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
	back = _build("Back", total - n_front, back_z, back_root, Color.WHITE, rng, false)
	front = _build("Front", n_front, front_z, front_root, front_tint, rng, true)
	_connect_wind.call_deferred()


## 2-3 날아간 지도: 지도가 날아갈 때 풀이 크게 눕는다.
func _connect_wind() -> void:
	for mc in get_tree().get_nodes_in_group("map_chase"):
		if mc.has_signal("blown_away") and not mc.blown_away.is_connected(blow):
			mc.blown_away.connect(blow)


func _build(node_name: String, count: int, z: int, root: Vector2, tint: Color,
		rng: RandomNumberGenerator, is_front: bool) -> MultiMeshInstance2D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _blade_mesh()
	var items: Array = []
	var tries := 0
	while items.size() < count and tries < count * 3:
		tries += 1
		var x := rng.randf() * length
		if is_front and _cleared(global_position.x + x):
			continue
		items.append(x)
	mm.instance_count = items.size()
	for i in items.size():
		var x: float = items[i]
		var edge := clampf(minf(x, length - x) / maxf(taper, 1.0), 0.0, 1.0)
		var h := rng.randf_range(height.x, height.y) * lerpf(0.35, 1.0, edge)
		var wd := rng.randf_range(blade_width.x, blade_width.y)
		var y := rng.randf_range(root.x, root.y)
		var t := Transform2D(Vector2(wd, 0.0), Vector2(0.0, h), Vector2(x, y))
		mm.set_instance_transform_2d(i, t)
		var c: Color = colors[rng.randi() % colors.size()]
		c = c.lightened(rng.randf_range(-0.08, 0.1)) * tint
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


## 풀잎 한 장: 키 1, 폭 1. 뿌리(0,0)에서 위(-y)로 가늘어지며 살짝 휜다. 뿌리는 어둡고 투명하게(땅에 녹게), 끝은 밝다.
static func _blade_mesh() -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var seg := 6
	for i in seg + 1:
		var t := float(i) / seg  # 0 = 뿌리
		var half := 0.5 * (1.0 - t * 0.92)
		var cx := -0.9 * t * t  # 끝이 왼쪽으로 조금 휜다(폭 단위)
		var shade := lerpf(0.55, 1.08, t)
		for side in [-1.0, 1.0]:
			verts.append(Vector2(cx + side * half, -t))
			uvs.append(Vector2(0.5 + side * 0.5, 1.0 - t))
			cols.append(Color(shade, shade, shade, smoothstep(0.0, 0.3, t)))  # 뿌리는 땅에 녹는다
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


func _process(_delta: float) -> void:
	_mat.set_shader_parameter("origin", global_position)
	_mat.set_shader_parameter("gust", gust)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_mat.set_shader_parameter("player_pos", player.global_position)


## 센 바람 한 번: 풀이 크게 눕었다가 천천히 일어난다.
func blow(strength: float = 1.0) -> void:
	if _gust_tween and _gust_tween.is_valid():
		_gust_tween.kill()
	_gust_tween = create_tween()
	_gust_tween.tween_property(self, "gust", strength, 0.35).set_trans(Tween.TRANS_SINE)
	_gust_tween.tween_property(self, "gust", 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
