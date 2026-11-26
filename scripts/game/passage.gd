class_name Passage
extends Interactable
## 조사하면 화면이 어두워졌다 밝아지며 하윤이 같은 장소의 다른 자리(to_x)로 옮겨 간다.
## 길이 바닥 높이로 이어지지 않는 곳에 쓴다(철교 들머리 → 강둑 길, 6-3).
## 조사 대상과 같은 속성을 쓴다(prompt, requires_flag, one_shot …). 이름은 Look_<장면>_<무엇>.
## 담당: A(게임플레이). (A 세션이 쉬는 동안 B 세션이 만듦, #32)

## 옮겨 갈 x(장소 안).
@export var to_x: float = 0.0
## 이 플래그가 서기 전에는 to_x 대신 fallback_to_x로 간다(#111 숲 둘째 갈림길: 피리로 메아리를 따라 불기 전에는
## 맞는 입구도 이끼 바위 앞으로 돌아온다). 비우면 늘 to_x.
@export var fallback_until_flag: StringName = &""
@export var fallback_to_x: float = 0.0


## 지금 들어가면 옮겨 갈 x.
func target_x() -> float:
	if not fallback_until_flag.is_empty() and not GameState.has_flag(fallback_until_flag):
		return fallback_to_x
	return to_x


func interact() -> void:
	if not is_available():
		return
	await super.interact()
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("move_player_to"):
		await main.move_player_to(target_x())
