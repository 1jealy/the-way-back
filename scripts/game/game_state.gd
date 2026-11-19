extends Node
## 게임 진행 상태. 오토로드(GameState)라 장소를 옮겨도 유지된다.
## 담당: A(게임플레이).

## 지금 있는 장소의 place_id.
var current_place: StringName = &""

## 얻은 물건·본 장면 같은 진행 기록.
var flags: Dictionary = {}


func set_flag(flag: StringName, value: Variant = true) -> void:
	flags[flag] = value


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false) == true


func reset() -> void:
	current_place = &""
	flags.clear()
