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
	# 상체: 엉덩이를 축으로 앞뒤로 숙인다(몸통·머리·팔·바지). 다리는 root에 붙어 있어 같이 숙지 않는다.
	"torso": ["root", Vector2(190, 335)],
	"head": ["torso", Vector2(204, 165)],
	"ponytail": ["head", Vector2(152, 152)],
	"hip": ["root", Vector2(187, 336)],
	"skirt": ["torso", Vector2(195, 300)],
	"knee": ["hip", Vector2(183, 470)],
	"ankle": ["knee", Vector2(178, 548)],
	"shoulder": ["torso", Vector2(174, 198)],
	"elbow": ["shoulder", Vector2(165, 288)],
}
## 조각 → 관절. 여기 없는 조각은 몸(root)에 붙는다.
const PART_JOINT := {
	"body": "torso", "head": "head", "mouth_neutral": "head", "eye_open": "head", "eyelid": "head", "brow_neutral": "head",
	"hair_front": "head", "hair_tie": "head", "hat": "head", "ponytail": "ponytail",
	"skirt": "skirt", "leg_upper": "hip", "leg_lower": "knee", "foot": "ankle", "bandage": "hip",
	"arm_upper": "shoulder", "arm_lower": "elbow", "hand": "elbow", "bracelet": "elbow",
}
## 팔(어깨·팔꿈치와 거기 붙은 조각)을 원본 자리보다 앞으로 옮긴다(캔버스 px).
## 원본은 팔이 몸통 뒤쪽 끝에 붙어 있어 옆에서 걸을 때 등에 매달린 것처럼 보였다.
const ARM_SHIFT := Vector2(0, 0)
const ARM_JOINTS := ["shoulder", "elbow"]

## 먼 쪽에 복사할 조각(가까운 쪽 이름). 반창고·팔찌는 화면 쪽에만 있다.
## 그리는 순서는 원본 레이어 순서(z)를 따른다 — 정강이가 허벅지 위에 오면 무릎이 인형 관절처럼 보인다.
## 바지도 먼 쪽에 하나 더 깔아 먼 다리를 따라 흔든다(뒤쪽 바짓단이 보이게).
const FAR_COPIES := ["arm_upper", "arm_lower", "hand", "leg_upper", "leg_lower", "foot", "skirt"]
const FAR_TINT := Color(0.86, 0.81, 0.78)  # 회색이 아니라 같은 색을 살짝 그늘지게(진하면 따로 노는 물건처럼 보인다)
## 먼 쪽 팔다리는 몸 뒤로 조금 비킨다(캔버스 px).
const FAR_SHIFT := Vector2(-7, -2)

## 걸음 한 바퀴(두 걸음)의 거리(게임 px). 발소리 간격(110px)의 두 배.
const CYCLE := 220.0
const THIGH_SWING := 24.0
const KNEE_BEND := 22.0
## 팔은 뒤보다 앞으로 더 흔든다(도).
const ARM_SWING_FRONT := 30.0
const ARM_SWING_BACK := 14.0
## 바지가 허벅지를 따라 도는 몫.
## 바지는 모양 그대로 돌린다(기울이기로 밀면 늘어나 보인다). 축은 윗옷 밑단에 가려지는 높이라 허리선은 안 보인다.
const SKIRT_FOLLOW := 0.5
const FAR_SKIRT_FOLLOW := 0.6
## 팔꿈치는 거의 굽히지 않는다: 소매가 통으로 그려져 있어 많이 굽히면 아래팔 소매 윗단이 꺾여 드러난다.
const ELBOW_BEND := 18.0
## 몸통 그림의 겨드랑이 그늘 색과, 그것을 바꿀 몸통 옆면 색. 그림 위쪽 이만큼 줄 안에서만 바꾼다.
const ARMPIT_SHADE := Color8(239, 146, 64)
const BODY_SIDE := Color8(255, 185, 131)
const ARMPIT_ROWS := 120

## 아래팔 소매 그림의 위쪽을 이만큼(그림 px) 잘라 낸다(팔꿈치 축 위의 둥근 윗단).
const FOREARM_CROP := 14
## 그 아래로 이만큼(그림 px)에 걸쳐 서서히 나타난다.
const FOREARM_FADE := 22
## 뒤로 간 발은 뒤꿈치를 든다(발끝으로 차고 나간다).
const HEEL_LIFT := 6.0
## 발목이 다리 기울기를 되돌리는 몫(1 = 늘 땅과 나란히).
const ANKLE_FLATTEN := 0.5
const HAIR_TRAIL := 7.0
const HAIR_SWAY := 3.0

## 자세(#98): 관절 → 각도(도). 걷기 각도에 더해진다. 땅에 닿는 높이는 발로 맞춘다(_ground_bob).
## 앞(오른쪽)으로 드는 쪽이 음수. 발목은 다리를 다 되돌리면 발바닥이 땅과 나란하다.
const POSES := {
	&"stand": {},
	# 쪼그려 앉기(하늘이 만남 3-4, 돌 줍기 5-4): 무릎을 가슴 쪽으로, 팔은 앞으로 내린다.
	&"crouch": {"hip": -100.0, "knee": 120.0, "ankle": -20.0, "far_hip": -95.0, "far_knee": 118.0, "far_ankle": -23.0,
			"skirt": -30.0, "far_skirt": -30.0, "shoulder": -38.0, "elbow": -25.0, "far_shoulder": -30.0, "far_elbow": -25.0,
			"torso": 22.0, "head": -8.0, "ponytail": 6.0},
	# 벤치에 앉기(2-5, 3-3): 허벅지는 앞으로 눕고 종아리는 내린다. 손은 무릎 위에.
	&"sit": {"torso": 4.0, "hip": -85.0, "knee": 85.0, "ankle": 0.0, "far_hip": -82.0, "far_knee": 80.0, "far_ankle": 2.0,
			"skirt": -28.0, "far_skirt": -28.0, "shoulder": -22.0, "elbow": -45.0, "far_shoulder": -18.0, "far_elbow": -45.0,
			"head": 3.0},
	# 바닥에 앉기(오프닝 0-1 마루, 배 위 7-6): 다리를 앞으로 뻗는다.
	&"sit_floor": {"hip": -92.0, "knee": 10.0, "ankle": -6.0, "far_hip": -90.0, "far_knee": 14.0, "far_ankle": -6.0,
			"skirt": -8.0, "far_skirt": -10.0, "shoulder": -30.0, "elbow": -30.0, "far_shoulder": -26.0, "far_elbow": -30.0,
			"head": 4.0},
}
## 자세가 바뀌는 빠르기(클수록 빠르다, 약 0.3초).
const POSE_RATE := 9.0
## 돌 던지기(물수제비 5-4). 물수제비는 옆으로 낮게 던진다(사이드암): 무릎을 굽혀 몸을 낮추고,
## 던지는 팔 반대쪽 발(먼 발)을 앞으로 내딛고, 팔을 허리 높이로 뒤에서 앞으로 휘둘러
## 손이 몸 앞 허리 높이에 왔을 때 놓는다(돌이 물과 약 20도로 낮고 평평하게 날아가야 잘 튄다). 팔은 앞으로 마저 따라간다.
## 키: [초, {관절: 도}]. 사이는 부드럽게 잇는다. 걷기·자세 각도에 더해진다.
const THROW_KEYS := [
	[0.0, {}],
	# 준비: 무릎을 굽혀 몸을 낮추고, 팔을 허리 뒤로 낮게 당긴다
	[0.35, {"hip": -18.0, "knee": 36.0, "ankle": -18.0, "far_hip": -16.0, "far_knee": 34.0, "far_ankle": -18.0,
			"shoulder": 44.0, "elbow": -18.0, "torso": 14.0, "head": -4.0, "ponytail": -3.0}],
	# 내딛기: 먼 발을 앞으로, 가까운 다리는 뒤에 버틴다. 팔은 가장 뒤(허리 높이).
	[0.6, {"hip": 12.0, "knee": 30.0, "ankle": -30.0, "far_hip": -42.0, "far_knee": 44.0, "far_ankle": 2.0,
			"skirt": 4.0, "far_skirt": -16.0, "shoulder": 52.0, "elbow": -20.0, "torso": 8.0, "head": -2.0, "ponytail": -5.0}],
	# 휘두르기 → 놓기: 손이 몸 앞 허리 높이(어깨 약 -30도)
	[0.74, {"hip": 14.0, "knee": 28.0, "ankle": -32.0, "far_hip": -44.0, "far_knee": 42.0, "far_ankle": 4.0,
			"skirt": 4.0, "far_skirt": -16.0, "shoulder": -30.0, "elbow": -6.0, "torso": 22.0, "head": -8.0, "ponytail": 8.0}],
	# 따라가기: 팔이 앞으로 마저 나가고 몸은 낮게 남는다
	[0.92, {"hip": 12.0, "knee": 26.0, "ankle": -30.0, "far_hip": -42.0, "far_knee": 40.0, "far_ankle": 4.0,
			"skirt": 4.0, "far_skirt": -16.0, "shoulder": -60.0, "elbow": -12.0, "torso": 26.0, "head": -10.0, "ponytail": 10.0}],
	[1.45, {}],
]
## 손을 놓는 때(초) = 휘두르기 키.
const THROW_RELEASE_AT := 0.74
## 손목 만지기(대기 동작, 장면표 "손목 만지기" — 팔찌 복선). 화면 쪽 손목을 몸 앞에 들고
## 먼 손이 와서 문지른다. 고개를 숙여 내려다본다. 서 있을 때 / 앉아 있을 때 키가 다르다(앉으면 손이 이미 무릎 위).
const WRIST_KEYS := [
	[0.0, {}],
	[0.55, {"shoulder": -22.0, "elbow": -62.0, "far_shoulder": -40.0, "far_elbow": -48.0, "head": 12.0, "torso": 3.0}],
	[2.15, {"shoulder": -22.0, "elbow": -62.0, "far_shoulder": -40.0, "far_elbow": -48.0, "head": 13.0, "torso": 3.0}],
	[2.8, {}],
]
const WRIST_SIT_KEYS := [
	[0.0, {}],
	[0.55, {"shoulder": -6.0, "elbow": -12.0, "far_shoulder": -18.0, "far_elbow": -6.0, "head": 10.0, "torso": 4.0}],
	[2.15, {"shoulder": -6.0, "elbow": -12.0, "far_shoulder": -18.0, "far_elbow": -6.0, "head": 11.0, "torso": 4.0}],
	[2.8, {}],
]
## 문지르기: 손목을 잡은 동안 먼 팔꿈치를 잘게 오간다(도, 초당 번).
const WRIST_RUB := 5.0
const WRIST_RUB_HZ := 2.2

## 지금 자세.
var pose: StringName = &"stand"
var _pose_cur: Dictionary = {}
var _throw_t: float = -1.0
var _gesture_keys: Array = []
var _gesture_t: float = -1.0

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
	# 아래팔 소매의 둥근 윗단(팔꿈치 축 위)을 지운다: 팔꿈치를 굽히면 그 윗단이 윗소매 밖으로 튀어나왔다.
	# 딱 자르면 윤곽선이 끊긴 자리에 턱이 생겨서, 위에서부터 서서히 투명해지게 한다.
	# 지운 자리는 윗소매 안쪽이라 같은 소매 색 위에 놓여 보이지 않는다.
	var lower := cutout.parts.get("arm_lower") as Sprite2D
	if lower:
		lower.texture = _fade_top(lower.texture, FOREARM_CROP, FOREARM_FADE)
	# 몸통 그림에 팔이 붙는 자리(겨드랑이)를 진한 주황 그늘로 칠해 두었다. 팔을 흔들면 그 그늘이 드러나
	# 색이 튄다 — 몸통 옆면 색으로 바꿔 둔다(위쪽 ARMPIT_ROWS줄 안에서만).
	var body := cutout.parts.get("body") as Sprite2D
	if body:
		body.texture = _recolor(body.texture, ARMPIT_SHADE, BODY_SIDE, ARMPIT_ROWS)
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
		if joint in ARM_JOINTS:
			s.position += ARM_SHIFT * ART_SCALE
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
	_tick_pose(delta)
	_tick_gesture(delta)
	_tick_blink(delta)
	_apply(delta)


## 자세를 바꾼다(stand / crouch / sit / sit_floor). 관절이 약 0.3초에 걸쳐 옮겨 간다.
func set_pose(p: StringName) -> void:
	if not POSES.has(p):
		push_warning("HayunRig: unknown pose %s" % p)
		p = &"stand"
	pose = p


## 돌 던지기 팔 동작. 손을 놓는 순간에 돌아오고(돌을 그때 띄운다), 팔은 그 뒤로 마저 돌아간다.
func play_throw() -> void:
	var total: float = THROW_KEYS[-1][0]
	var t := create_tween()
	t.tween_method(func(v: float): _throw_t = v, 0.0, total, total)
	t.tween_callback(func(): _throw_t = -1.0)
	await get_tree().create_timer(THROW_RELEASE_AT, false).timeout


## 손목 만지기 한 번. 끝나면 돌아온다. 걷기 시작하면 서둘러 내린다(걸음이 섞이면 팔이 꼬인다).
func play_wrist_touch() -> void:
	_gesture_keys = WRIST_SIT_KEYS if pose == &"sit" else WRIST_KEYS
	_gesture_t = 0.0
	while _gesture_t >= 0.0:
		await get_tree().process_frame


func is_gesturing() -> bool:
	return _gesture_t >= 0.0


func _tick_gesture(delta: float) -> void:
	if _gesture_t < 0.0:
		return
	var hold_end: float = _gesture_keys[-2][0]
	if _walk > 0.0:
		# 걷기 시작하면 내리는 구간으로 건너뛰어 빨리 내린다(지금 들린 만큼에서 이어지게).
		var rise: float = _gesture_keys[1][0]
		var fall: float = _gesture_keys[-1][0] - hold_end
		if _gesture_t < rise:
			_gesture_t = _gesture_keys[-1][0] - _gesture_t / rise * fall
		elif _gesture_t < hold_end:
			_gesture_t = hold_end
		delta *= 2.0
	_gesture_t += delta
	if _gesture_t >= _gesture_keys[-1][0]:
		_gesture_t = -1.0


## 화면 쪽 손의 자리(전역 좌표). 던진 돌이 여기서 출발한다.
func hand_point() -> Vector2:
	var hand := cutout.parts.get("hand") as Sprite2D if cutout else null
	if hand == null:
		return global_position
	return hand.get_global_transform() * hand.get_rect().get_center()


func _tick_pose(delta: float) -> void:
	var target: Dictionary = POSES[pose]
	var k := 1.0 - exp(-POSE_RATE * delta)
	var keys := {}
	for j in _pose_cur:
		keys[j] = true
	for j in target:
		keys[j] = true
	for j: String in keys:
		var v := lerpf(float(_pose_cur.get(j, 0.0)), float(target.get(j, 0.0)), k)
		if absf(v) < 0.05 and not target.has(j):
			_pose_cur.erase(j)
		else:
			_pose_cur[j] = v


func _throw_angles(t: float) -> Dictionary:
	return _key_angles(THROW_KEYS, t)


## 키 [초, {관절: 도}] 사이를 부드럽게 이은 각도.
func _key_angles(keys: Array, t: float) -> Dictionary:
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if t <= b[0]:
			var a: Array = keys[i - 1]
			var u := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
			var ka: Dictionary = a[1]
			var kb: Dictionary = b[1]
			var out := {}
			for j in ka:
				out[j] = true
			for j in kb:
				out[j] = true
			for j: String in out:
				out[j] = lerpf(float(ka.get(j, 0.0)), float(kb.get(j, 0.0)), u)
			return out
	return {}


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
	# 발을 든 가운데에서만 뾰족하게 굽힌다(넓게 굽히면 종아리가 흐물거린다).
	var near_knee := KNEE_BEND * pow(maxf(0.0, cos(_phase)), 2.0) * w
	var far_knee := KNEE_BEND * pow(maxf(0.0, -cos(_phase)), 2.0) * w
	# 뒤로 간 발은 뒤꿈치를 든다(시계 방향 = 뒤꿈치가 올라간다)
	var near_heel := HEEL_LIFT * pow(maxf(0.0, near_thigh / THIGH_SWING), 1.5)
	var far_heel := HEEL_LIFT * pow(maxf(0.0, far_thigh / THIGH_SWING), 1.5)
	# 팔: 앞(-)으로 크게, 뒤(+)로 작게. 가까운 팔은 가까운 다리와 반대로.
	var near_arm := s * (ARM_SWING_BACK if s > 0.0 else ARM_SWING_FRONT) * w
	var far_arm := -s * (ARM_SWING_BACK if -s > 0.0 else ARM_SWING_FRONT) * w
	var breeze := sin(_time * 1.4) * 1.6 + sin(_time * 0.7 + 1.0) * 1.0
	var out := {
		"root": 0.0,
		"head": sin(_phase * 2.0) * 1.2 * w,
		"ponytail": HAIR_TRAIL * w + sin(_phase * 2.0 + 0.8) * HAIR_SWAY * w + breeze,
		"hip": near_thigh, "knee": near_knee,
		"far_hip": far_thigh, "far_knee": far_knee,
		# 발은 땅과 거의 나란하게(다리를 따라 돌지 않게 되돌린다). 발끝이 땅에 박히지 않는다.
		# 발은 다리를 절반만 따라 돈다: 종아리와 신발이 한 덩어리로 움직이고(반대로 돌리면 발목이 휘어 보인다),
		# 앞발은 발끝이 들리고(뒤꿈치로 디딤) 뒷발은 뒤꿈치가 들린다(발끝으로 참).
		"ankle": -(near_thigh + near_knee) * ANKLE_FLATTEN + near_heel,
		"far_ankle": -(far_thigh + far_knee) * ANKLE_FLATTEN + far_heel,
		# 팔꿈치는 팔이 앞으로 왔을 때만 조금 굽는다
		"shoulder": near_arm, "elbow": -ELBOW_BEND * maxf(0.0, -near_arm / ARM_SWING_FRONT) * w,
		"far_shoulder": far_arm, "far_elbow": -ELBOW_BEND * maxf(0.0, -far_arm / ARM_SWING_FRONT) * w,
		"skirt": near_thigh * SKIRT_FOLLOW, "far_skirt": far_thigh * FAR_SKIRT_FOLLOW,
	}
	for joint: String in _pose_cur:
		out[joint] = float(out.get(joint, 0.0)) + float(_pose_cur[joint])
	if _throw_t >= 0.0:
		var t := _throw_angles(_throw_t)
		for joint: String in t:
			out[joint] = float(out.get(joint, 0.0)) + float(t[joint])
	if _gesture_t >= 0.0:
		var g := _key_angles(_gesture_keys, _gesture_t)
		# 잡고 있는 동안만 문지른다(들고 내릴 때는 안 한다)
		var hold := smoothstep(0.45, 0.7, _gesture_t) * (1.0 - smoothstep(2.0, 2.3, _gesture_t))
		g["far_elbow"] = float(g.get("far_elbow", 0.0)) + sin(_gesture_t * TAU * WRIST_RUB_HZ) * WRIST_RUB * hold
		for joint: String in g:
			out[joint] = float(out.get(joint, 0.0)) + float(g[joint])
	return out


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


## `from`에 가까운 색을 `to` 쪽으로 옮긴 사본(가까울수록 많이). 위쪽 `rows`줄만. 윤곽선·다른 색은 그대로.
static func _recolor(tex: Texture2D, from: Color, to: Color, rows: int) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var shift := Color(to.r - from.r, to.g - from.g, to.b - from.b, 0.0)
	for y in mini(rows, img.get_height()):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.02:
				continue
			var d := Vector3(c.r - from.r, c.g - from.g, c.b - from.b).length()
			var w := clampf(1.0 - d / 0.3, 0.0, 1.0)
			if w > 0.0:
				img.set_pixel(x, y, Color(c.r + shift.r * w, c.g + shift.g * w, c.b + shift.b * w, c.a))
	return ImageTexture.create_from_image(img)


## 그림 위쪽 `cut`줄은 지우고, 그 아래 `fade`줄에 걸쳐 서서히 나타나게 한 사본.
static func _fade_top(tex: Texture2D, cut: int, fade: int) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in mini(cut + fade, img.get_height()):
		var k := clampf(float(y - cut) / float(fade), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c.a *= k
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 몸을 위아래로 얼마나 옮기면 가장 낮은 발바닥이 땅(발밑 원점)에 닿나(캔버스 px).
func _ground_bob(ang: Dictionary) -> float:
	var cache := {}
	var lowest := -INF
	for bone in _bones:
		var joint: String = bone[1]
		# 발바닥, 그리고 바닥에 앉았을 때는 엉덩이(바지 아랫단)가 땅에 닿는다
		if joint != "ankle" and joint != "far_ankle" and joint != "skirt":
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
		if far and parent != "root" and parent != "torso":
			pj = "far_" + parent
		parent_xf = _joint_xf(pj, ang, cache, bob)
	var pivot := _to_local_pt(def[1])
	if far:
		pivot += FAR_SHIFT * ART_SCALE
	if base in ARM_JOINTS:
		pivot += ARM_SHIFT * ART_SCALE
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
