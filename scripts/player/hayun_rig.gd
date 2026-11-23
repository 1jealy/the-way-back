class_name HayunRig
extends Node2D
## 하윤 컷아웃 움직임(#94). Cutout이 조각을 PSD 모습 그대로 붙이면, 여기서 관절을 돌려 걷게 한다.
## - 조각은 Cutout 아래 한 층에 그대로 둔다(그림자·물그림자가 Visual을 복사해 자식 순서대로 맞추기 때문).
##   관절은 노드가 아니라 계산으로 잇는다: 관절 변환 = 부모 관절 변환 × (축을 중심으로 돌리기).
## - 먼 쪽 팔다리는 가까운 쪽 조각을 복사해 어둡게 해서 맨 뒤에 깐다(그림 담당과 정함: 한 세트만 그린다).
## - 걷기는 시간이 아니라 걸은 거리로 굴린다(멈추면 발이 미끄러지지 않게 천천히 서는 자세로).
## - 꽁지머리는 걸을 때 뒤로 날리고 가만히 있어도 살랑인다. 눈은 가끔 깜빡인다.
## 관절 자리(PIVOTS)는 char_hayun.json 캔버스 px(그림 2배 크기, 원점 왼쪽 위)다. 그림이 바뀌면 다시 잡는다.
## 담당: A(하윤).

const CHARACTER := "hayun"
## 그림은 게임 크기의 2배로 들어온다.
const ART_SCALE := 0.5

## 관절 → [부모 관절, 축(캔버스 px)]. 부모가 ""면 몸(root).
const JOINTS := {
	"root": ["", Vector2(191, 645)],
	"head": ["root", Vector2(204, 165)],
	"ponytail": ["head", Vector2(152, 152)],
	"hip": ["root", Vector2(187, 336)],
	"knee": ["hip", Vector2(183, 470)],
	"ankle": ["knee", Vector2(178, 548)],
	"shoulder": ["root", Vector2(174, 198)],
	"elbow": ["shoulder", Vector2(165, 288)],
}
## 조각 → 관절. 여기 없는 조각은 몸(root)에 붙는다.
const PART_JOINT := {
	"head": "head", "mouth_neutral": "head", "eye_open": "head", "eyelid": "head", "brow_neutral": "head",
	"hair_front": "head", "hair_tie": "head", "hat": "head", "ponytail": "ponytail",
	"leg_upper": "hip", "leg_lower": "knee", "foot": "ankle", "bandage": "hip",
	"arm_upper": "shoulder", "arm_lower": "elbow", "hand": "elbow", "bracelet": "elbow",
}
## 먼 쪽에 복사할 조각(가까운 쪽 이름). 반창고·팔찌는 화면 쪽에만 있다.
## 그리는 순서는 원본 레이어 순서(z)를 따른다 — 정강이가 허벅지 위에 오면 무릎이 인형 관절처럼 보인다.
const FAR_COPIES := ["arm_upper", "arm_lower", "hand", "leg_upper", "leg_lower", "foot"]
const FAR_TINT := Color(0.86, 0.81, 0.78)  # 회색이 아니라 같은 색을 살짝 그늘지게(진하면 따로 노는 물건처럼 보인다)
## 먼 쪽 팔다리는 몸 뒤로 조금 비킨다(캔버스 px).
const FAR_SHIFT := Vector2(-7, -2)

## 걸음 한 바퀴(두 걸음)의 거리(게임 px). 발소리 간격(110px)의 두 배.
const CYCLE := 220.0
const THIGH_SWING := 24.0
const KNEE_BEND := 34.0
const ARM_SWING := 20.0
## 팔꿈치는 거의 굽히지 않는다: 소매가 통으로 그려져 있어 많이 굽히면 아래팔 소매 윗단이 꺾여 드러난다.
const ELBOW_BEND := 5.0
## 뒤로 간 발은 뒤꿈치를 든다(발끝으로 차고 나간다).
const HEEL_LIFT := 16.0
const HAIR_TRAIL := 7.0
const HAIR_SWAY := 3.0

var cutout: Cutout
## 조각 이름 → [Sprite2D, 관절, 처음 변환]
var _bones: Array = []
var _phase: float = 0.0
var _walk: float = 0.0  # 0 = 서 있음, 1 = 걷는 중(부드럽게 섞는다)
var _time: float = 0.0
var _blink_left: float = 3.0
var _blink_t: float = -1.0


func _ready() -> void:
	cutout = Cutout.new()
	cutout.name = "Cutout"
	cutout.character = CHARACTER
	cutout.art_scale = ART_SCALE
	cutout.blink = false  # 눈알 하나뿐이라 여기서 눌러서 깜빡인다
	add_child(cutout)  # _ready에서 조각을 붙인다
	_setup()


## 그림이 들어와 있나(없으면 Player가 예전 한 장짜리 그림을 쓴다).
static func available() -> bool:
	return Cutout.has_art(CHARACTER)


func _setup() -> void:
	if cutout.parts.is_empty():
		return
	# 먼 쪽 팔다리: 복사해서 맨 뒤에
	var far: Array = []
	var order := FAR_COPIES.duplicate()
	order.sort_custom(func(a, b): return cutout.parts.has(a) and cutout.parts.has(b) \
			and (cutout.parts[a] as Node).get_index() < (cutout.parts[b] as Node).get_index())
	for name: String in order:
		var src := cutout.parts.get(name) as Sprite2D
		if src == null:
			continue
		var copy := src.duplicate(0) as Sprite2D
		copy.name = "far_" + name
		copy.modulate = FAR_TINT
		copy.position += FAR_SHIFT * ART_SCALE
		far.append(copy)
	for i in far.size():
		cutout.add_child(far[i])
		cutout.move_child(far[i], i)
		cutout.parts[far[i].name] = far[i]
	for name: String in cutout.parts:
		var s := cutout.parts[name] as Sprite2D
		var base := name.trim_prefix("far_")
		var joint: String = PART_JOINT.get(base, "root")
		if name.begins_with("far_"):
			joint = "far_" + joint
		_bones.append([s, joint, s.transform])
	_apply(0.0)


func _process(delta: float) -> void:
	if _bones.is_empty():
		return
	_time += delta
	var player := get_parent().get_parent() as CharacterBody2D
	var speed := absf(player.velocity.x) if player else 0.0
	var walking := speed > 10.0 and (player == null or player.is_on_floor())
	_walk = move_toward(_walk, 1.0 if walking else 0.0, delta * 4.0)
	if walking:
		_phase = fmod(_phase + speed * delta / CYCLE * TAU, TAU)
	elif _walk <= 0.0:
		_phase = 0.0
	_tick_blink(delta)
	_apply(delta)


func _tick_blink(delta: float) -> void:
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t > 0.16:
			_blink_t = -1.0
		return
	_blink_left -= delta
	if _blink_left <= 0.0:
		_blink_left = randf_range(2.5, 6.0)
		_blink_t = 0.0


## 관절 각도(도)를 정한다. 앞으로 내딛는 쪽이 음수(오른쪽을 볼 때 시계 반대).
func _angles() -> Dictionary:
	var s := sin(_phase)
	var w := _walk
	var near_thigh := -THIGH_SWING * s * w
	var far_thigh := THIGH_SWING * s * w
	# 무릎은 다리가 뒤에서 앞으로 넘어올 때(발을 든 쪽) 굽는다. 디딘 다리는 곧게 편다.
	# 가까운 다리는 cos > 0일 때 허벅지가 뒤(+)에서 앞(-)으로 간다.
	var near_knee := KNEE_BEND * maxf(0.0, cos(_phase)) * w
	var far_knee := KNEE_BEND * maxf(0.0, -cos(_phase)) * w
	# 뒤로 간 발은 뒤꿈치를 든다(시계 방향 = 뒤꿈치가 올라간다)
	var near_heel := HEEL_LIFT * pow(maxf(0.0, near_thigh / THIGH_SWING), 1.5)
	var far_heel := HEEL_LIFT * pow(maxf(0.0, far_thigh / THIGH_SWING), 1.5)
	var breeze := sin(_time * 1.4) * 1.6 + sin(_time * 0.7 + 1.0) * 1.0
	return {
		"root": 0.0,
		"head": sin(_phase * 2.0) * 1.2 * w,
		"ponytail": HAIR_TRAIL * w + sin(_phase * 2.0 + 0.8) * HAIR_SWAY * w + breeze,
		"hip": near_thigh, "knee": near_knee,
		"far_hip": far_thigh, "far_knee": far_knee,
		# 발은 땅과 거의 나란하게(다리를 따라 돌지 않게 되돌린다). 발끝이 땅에 박히지 않는다.
		"ankle": -(near_thigh + near_knee) * 0.85 + near_heel,
		"far_ankle": -(far_thigh + far_knee) * 0.85 + far_heel,
		# 팔꿈치는 팔이 앞으로 왔을 때만 조금 굽는다
		"shoulder": ARM_SWING * s * w, "elbow": -ELBOW_BEND * maxf(0.0, -s) * w,
		"far_shoulder": -ARM_SWING * s * w, "far_elbow": -ELBOW_BEND * maxf(0.0, s) * w,
	}


func _apply(_delta: float) -> void:
	var ang := _angles()
	# 몸 높이는 발이 땅에 닿게 맞춘다: 다리를 벌리면 몸이 내려가고 모일 때 올라간다.
	# 고정 오르내림을 쓰면 두 발이 벌어질 때 둘 다 땅에서 떠 미끄러지듯 보인다.
	var bob := _ground_bob(ang) + sin(_time * 2.2) * 0.8 * (1.0 - _walk)
	var cache := {}
	for bone in _bones:
		var s := bone[0] as Sprite2D
		var t: Transform2D = _joint_xf(bone[1], ang, cache, bob)
		s.transform = t * (bone[2] as Transform2D)
	_blink_pose()


## 몸을 위아래로 얼마나 옮기면 가장 낮은 발바닥이 땅(발밑 원점)에 닿나(캔버스 px).
func _ground_bob(ang: Dictionary) -> float:
	var cache := {}
	var lowest := -INF
	for bone in _bones:
		var joint: String = bone[1]
		if joint != "ankle" and joint != "far_ankle":
			continue
		var s := bone[0] as Sprite2D
		var xf: Transform2D = _joint_xf(joint, ang, cache, 0.0) * (bone[2] as Transform2D)
		var r := s.get_rect()
		for fx in [0.12, 0.5, 0.88]:
			var pt := xf * Vector2(r.position.x + r.size.x * fx, r.end.y)
			lowest = maxf(lowest, pt.y)
	if lowest == -INF:
		return 0.0
	return -lowest / ART_SCALE


## 관절의 변환(Cutout 좌표). 축은 캔버스 px → Cutout 좌표(발밑 원점, ART_SCALE).
func _joint_xf(joint: String, ang: Dictionary, cache: Dictionary, bob: float) -> Transform2D:
	if cache.has(joint):
		return cache[joint]
	var far := joint.begins_with("far_")
	var base := joint.trim_prefix("far_")
	var def: Array = JOINTS[base]
	var parent: String = def[0]
	var parent_xf := Transform2D.IDENTITY
	if base == "root":
		parent_xf = Transform2D(0.0, Vector2(0.0, bob * ART_SCALE))
	elif not parent.is_empty():
		var pj := parent
		if far and parent != "root":
			pj = "far_" + parent
		parent_xf = _joint_xf(pj, ang, cache, bob)
	var pivot := _to_local_pt(def[1])
	if far:
		pivot += FAR_SHIFT * ART_SCALE
	var a := deg_to_rad(float(ang.get(joint, 0.0)))
	var local := Transform2D(0.0, pivot) * Transform2D(a, Vector2.ZERO) * Transform2D(0.0, -pivot)
	var xf := parent_xf * local
	cache[joint] = xf
	return xf


func _to_local_pt(canvas_px: Vector2) -> Vector2:
	return (canvas_px - Vector2(cutout.canvas.x * 0.5, cutout.canvas.y)) * ART_SCALE


## 깜빡임: 눈알을 가운데로 눌렀다 편다(감은 눈 그림이 따로 없어서).
func _blink_pose() -> void:
	var eye := cutout.parts.get("eye_open") as Sprite2D
	if eye == null or _blink_t < 0.0:
		return
	var k := 1.0 - sin(clampf(_blink_t / 0.16, 0.0, 1.0) * PI) * 0.92
	var tex_h := eye.texture.get_height() * eye.scale.y
	var center_y := eye.position.y + tex_h * 0.5
	eye.scale.y *= k
	eye.position.y = center_y - tex_h * k * 0.5


## 검사용: 지금 관절 각도(도).
func joint_angles() -> Dictionary:
	return _angles()


func walk_amount() -> float:
	return _walk
