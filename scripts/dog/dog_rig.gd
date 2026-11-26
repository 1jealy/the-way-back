class_name DogRig
extends Node2D
## 하늘이 컷아웃 움직임(#101). 그림 담당의 PSB(한글 레이어 12장)를 Cutout이 붙이면 여기서 관절을 돌린다.
## 하윤(HayunRig)과 같은 방식이다:
## - 조각은 Cutout 아래 한 층에 그대로 두고 관절은 계산으로 잇는다(배 위 물그림자가 Visual을 복사해 맞춘다).
## - 먼 쪽 다리는 가까운 쪽 조각을 복사해 그늘 색으로 맨 뒤에 깐다(화면 쪽 한 쌍만 그렸다).
## - 걷기는 걸은 거리로 굴린다. 개는 대각선 다리가 같이 움직이는 속보다(가까운 앞다리 = 먼 뒷다리).
## - 몸 높이는 가장 낮은 발바닥이 땅에 닿게 맞춘다.
## - 꼬리는 늘 흔든다(세 마디가 조금씩 늦게 따라간다). 걸을 때 더 크게.
## - 앉으면(sit) 몸 뒤쪽이 앞다리 어깨를 축으로 내려가고 뒷다리를 접는다. 머리는 그대로 든다.
## 관절 자리(JOINTS)는 char_dog.json 캔버스 px(그림 2배 크기, 오른쪽을 본다, 원점 왼쪽 위)다.
## 담당: A(하늘이).

const CHARACTER := "dog"
const ART_SCALE := 0.5

## 관절 → [부모 관절, 축(캔버스 px)]. 부모가 ""면 몸(root).
## rear: 앉을 때 앞다리 어깨를 축으로 내려가는 몸 뒤쪽(몸통·뒷다리·꼬리).
const JOINTS := {
	"root": ["", Vector2(215, 346)],
	"rear": ["root", Vector2(300, 165)],
	# 목: 가슴 앞 아래를 축으로 머리를 통째로 내린다(물어 오기·냄새). 목줄도 같이 간다.
	"neck": ["root", Vector2(318, 178)],
	"head": ["neck", Vector2(300, 112)],
	"ear": ["head", Vector2(320, 34)],
	"shoulder": ["root", Vector2(300, 160)],
	"wrist": ["shoulder", Vector2(295, 236)],
	"hip": ["rear", Vector2(125, 160)],
	"hock": ["hip", Vector2(76, 262)],
	"tail1": ["rear", Vector2(96, 130)],
	"tail2": ["tail1", Vector2(38, 100)],
	"tail3": ["tail2", Vector2(36, 64)],
}
const PART_JOINT := {
	"body": "rear", "head": "head", "face": "head", "ear": "ear", "collar": "neck",
	"front_upper": "shoulder", "front_lower": "wrist",
	"hind_upper": "hip", "hind_lower": "hock",
	"tail1": "tail1", "tail2": "tail2", "tail3": "tail3",
}
const FAR_COPIES := ["front_upper", "front_lower", "hind_upper", "hind_lower"]
const FAR_TINT := Color(0.84, 0.79, 0.74)
## 먼 쪽 다리는 몸 뒤로 조금 비킨다(캔버스 px).
const FAR_SHIFT := Vector2(-10, -3)

## 걸음 한 바퀴의 거리(게임 px). 하늘이는 하윤 뒤를 따라 걷고 심부름 때 뛴다.
const CYCLE := 170.0
const FRONT_SWING := 22.0
const HIND_SWING := 20.0
const LOWER_BEND := 30.0
const HEAD_BOB := 2.0
const TAIL_WAG := Vector3(5.0, 8.0, 11.0)  # 마디마다 흔드는 크기(도)

## 자세: 관절 → 각도(도), 걷기 각도에 더해진다. 앞(오른쪽)으로 드는 쪽이 음수.
const POSES := {
	&"stand": {},
	# 앉기: 몸 뒤쪽을 내려 엉덩이를 땅에 대고(어깨 축으로 시계 반대), 허벅지는 앞으로 눕히고
	# 뒷발은 앞다리 뒤 땅에 놓는다. 꼬리는 땅에 내려놓고, 머리는 들어 앞을 본다.
	&"sit": {"rear": -42.0, "hip": -50.0, "hock": -10.0, "far_hip": -50.0, "far_hock": -10.0,
			"head": -10.0, "tail1": -20.0, "tail2": -15.0, "tail3": -10.0},
	# 물어 오기(가져와): 목을 내려 입을 땅에 대고, 앞다리를 조금 굽힌다.
	&"fetch": {"neck": 60.0, "head": 24.0, "ear": 12.0, "shoulder": 8.0, "wrist": -14.0, "far_shoulder": 8.0, "far_wrist": -14.0,
			"tail1": -6.0},
	# 냄새 맡기: 목을 내려 코를 땅 가까이, 귀는 앞으로. 맡는 동안 머리가 잘게 움직인다(_angles).
	&"sniff": {"neck": 38.0, "head": 18.0, "ear": 10.0, "shoulder": 6.0, "wrist": -10.0, "far_shoulder": 6.0, "far_wrist": -10.0},
	# 냄새를 따라 걸어가기: 목만 내린다(다리는 걷기 그대로).
	&"sniff_walk": {"neck": 24.0, "head": 10.0, "ear": 6.0},
	# 버티기(징검다리 돌): 앞다리를 앞으로, 뒷다리를 뒤로 조금 벌려 버틴다. 고개는 숙여 힘을 준다.
	&"hold": {"shoulder": -14.0, "wrist": 6.0, "far_shoulder": -14.0, "far_wrist": 6.0,
			"hip": 12.0, "hock": -6.0, "far_hip": 12.0, "far_hock": -6.0,
			"neck": 16.0, "head": 6.0, "ear": -6.0, "tail1": -14.0, "tail2": -8.0},
}
const POSE_RATE := 9.0
## 관절마다 용수철 진동수(#114). 클수록 빨리 따라간다.
const POSE_OMEGA := {
	"root": 12.0, "rear": 11.0, "hip": 12.0, "hock": 12.0, "shoulder": 12.0, "wrist": 12.0,
	"neck": 9.0, "head": 8.5, "ear": 7.0, "tail1": 7.0, "tail2": 6.5, "tail3": 6.0,
}
const POSE_DAMPING := 0.7
## 짖기: 고개를 위로 젖혔다 돌아온다(초).
const BARK_SECONDS := 0.35
const BARK_HEAD := -24.0

var cutout: Cutout
var pose: StringName = &"stand"
var _bones: Array = []
var _phase: float = 0.0
var _walk: float = 0.0
var _time: float = 0.0
var _pose_vel: Dictionary = {}
var _ear_left: float = 4.0
var _ear_t: float = -1.0
var _pose_cur: Dictionary = {}
var _bark_t: float = -1.0
## 신나서 꼬리를 크게·빨리 흔드는 정도(0~1). Dog.wag()가 정한다(4-3 빈터).
var excited: float = 0.0
var _excited_target: float = 0.0


func _ready() -> void:
	cutout = Cutout.new()
	cutout.name = "Cutout"
	cutout.character = CHARACTER
	cutout.art_scale = ART_SCALE
	cutout.blink = false
	add_child(cutout)
	_setup()


static func available() -> bool:
	return Cutout.has_art(CHARACTER)


func set_pose(p: StringName) -> void:
	pose = p if POSES.has(p) else &"stand"


## 한 번 짖는다(고개를 젖혔다 돌아온다). 소리는 dog.gd가 낸다.
## 꼬리를 신나게 흔든다 / 그친다. 천천히 바뀐다.
func set_excited(on: bool) -> void:
	_excited_target = 1.0 if on else 0.0


func bark() -> void:
	_bark_t = 0.0


func walk_amount() -> float:
	return _walk


func joint_angles() -> Dictionary:
	return _angles()


func _setup() -> void:
	if cutout.parts.is_empty():
		return
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
		var joint: String = PART_JOINT.get(name.trim_prefix("far_"), "root")
		if name.begins_with("far_"):
			joint = "far_" + joint
		_bones.append([s, joint, s.transform])
	_apply()


func _process(delta: float) -> void:
	if _bones.is_empty():
		return
	_time += delta
	excited = move_toward(excited, _excited_target, delta * 1.5)
	var dog := get_parent().get_parent() as CharacterBody2D
	var speed := absf(dog.velocity.x) if dog else 0.0
	var walking := speed > 10.0
	_walk = move_toward(_walk, 1.0 if walking else 0.0, delta * 4.0)
	if walking:
		_phase = fmod(_phase + speed * delta / CYCLE * TAU, TAU)
	elif _walk <= 0.0:
		_phase = 0.0
	if _bark_t >= 0.0:
		_bark_t += delta
		if _bark_t > BARK_SECONDS:
			_bark_t = -1.0
	_tick_pose(delta)
	_ear_left -= delta
	if _ear_left <= 0.0:
		_ear_left = randf_range(3.0, 7.0)
		_ear_t = 0.0
	if _ear_t >= 0.0:
		_ear_t += delta
		if _ear_t > 0.35:
			_ear_t = -1.0
	_apply()


## 자세 옮기기는 관절마다 용수철로(#114): 다리·몸이 먼저, 머리·귀·꼬리는 조금 늦게 따라와 살짝 넘쳤다 돌아온다.
func _tick_pose(delta: float) -> void:
	var target: Dictionary = POSES[pose]
	var keys := {}
	for j in _pose_cur:
		keys[j] = true
	for j in target:
		keys[j] = true
	var dt := minf(delta, 1.0 / 30.0)
	for j: String in keys:
		var goal := float(target.get(j, 0.0))
		var x := float(_pose_cur.get(j, 0.0))
		var v := float(_pose_vel.get(j, 0.0))
		var om: float = POSE_OMEGA.get(j, POSE_OMEGA.get(j.trim_prefix("far_"), 11.0))
		v += (om * om * (goal - x) - 2.0 * POSE_DAMPING * om * v) * dt
		x += v * dt
		if absf(x) < 0.05 and absf(v) < 0.05 and not target.has(j):
			_pose_cur.erase(j)
			_pose_vel.erase(j)
		else:
			_pose_cur[j] = x
			_pose_vel[j] = v


func _angles() -> Dictionary:
	var s := sin(_phase)
	var w := _walk
	# 속보: 가까운 앞다리와 먼 뒷다리가 같이, 가까운 뒷다리와 먼 앞다리가 같이 움직인다.
	var a := -s  # 앞으로 내딛는 쪽이 음수
	var lift_a := maxf(0.0, cos(_phase))  # 앞으로 넘어오는 동안 발을 든다
	var lift_b := maxf(0.0, -cos(_phase))
	var wag_speed := 7.0 + 5.0 * w + 7.0 * excited
	var wag_amp := 1.0 + 0.6 * w + 1.2 * excited
	var out := {
		"shoulder": FRONT_SWING * a * w, "wrist": LOWER_BEND * lift_a * lift_a * w,
		"far_shoulder": -FRONT_SWING * a * w, "far_wrist": LOWER_BEND * lift_b * lift_b * w,
		"hip": -HIND_SWING * a * w, "hock": LOWER_BEND * 0.8 * lift_b * lift_b * w,
		"far_hip": HIND_SWING * a * w, "far_hock": LOWER_BEND * 0.8 * lift_a * lift_a * w,
		"head": sin(_phase * 2.0) * HEAD_BOB * w + sin(_time * 1.1) * 1.0,
		"ear": sin(_phase * 2.0 + 1.2) * 4.0 * w + sin(_time * 1.7) * 1.5,
		"tail1": sin(_time * wag_speed) * TAIL_WAG.x * wag_amp,
		"tail2": sin(_time * wag_speed - 0.7) * TAIL_WAG.y * wag_amp,
		"tail3": sin(_time * wag_speed - 1.4) * TAIL_WAG.z * wag_amp,
	}
	# 숨쉬기(가만히 있을 때 목이 아주 조금 오르내린다)와 가끔 귀를 털 듯 움찔(#114)
	out["neck"] = float(out.get("neck", 0.0)) + sin(_time * TAU * 0.35) * 1.4 * (1.0 - w)
	if _ear_t >= 0.0:
		out["ear"] = float(out["ear"]) + sin(_ear_t / 0.35 * TAU) * 9.0
	for j: String in _pose_cur:
		out[j] = float(out.get(j, 0.0)) + float(_pose_cur[j])
	if pose == &"sniff" or pose == &"sniff_walk":
		out["head"] = float(out["head"]) + sin(_time * 22.0) * 2.5  # 킁킁
	if _bark_t >= 0.0:
		out["head"] = float(out["head"]) + BARK_HEAD * sin(clampf(_bark_t / BARK_SECONDS, 0.0, 1.0) * PI)
	return out


func _apply() -> void:
	var ang := _angles()
	var bob := _ground_bob(ang)
	var cache := {}
	for bone in _bones:
		var s := bone[0] as Sprite2D
		s.transform = _joint_xf(bone[1], ang, cache, bob) * (bone[2] as Transform2D)


## 가장 낮은 발바닥이 땅(발밑 원점)에 닿게 몸을 위아래로 얼마나 옮기나(캔버스 px).
func _ground_bob(ang: Dictionary) -> float:
	var cache := {}
	var lowest := -INF
	for bone in _bones:
		var joint: String = bone[1]
		if joint.trim_prefix("far_") != "wrist" and joint.trim_prefix("far_") != "hock":
			continue
		var s := bone[0] as Sprite2D
		var xf: Transform2D = _joint_xf(joint, ang, cache, 0.0) * (bone[2] as Transform2D)
		var r := s.get_rect()
		for fx in [0.15, 0.5, 0.85]:
			lowest = maxf(lowest, (xf * Vector2(r.position.x + r.size.x * fx, r.end.y)).y)
	return 0.0 if lowest == -INF else -lowest / ART_SCALE


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
		if far and parent != "root" and parent != "rear":
			pj = "far_" + parent
		parent_xf = _joint_xf(pj, ang, cache, bob)
	var pivot: Vector2 = (def[1] - Vector2(cutout.canvas.x * 0.5, cutout.canvas.y)) * ART_SCALE
	if far:
		pivot += FAR_SHIFT * ART_SCALE
	var a := deg_to_rad(float(ang.get(joint, 0.0)))
	var xf := parent_xf * Transform2D(0.0, pivot) * Transform2D(a, Vector2.ZERO) * Transform2D(0.0, -pivot)
	cache[joint] = xf
	return xf
