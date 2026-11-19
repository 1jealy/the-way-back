extends SceneTree
## 소리 가져오기. assets/audio/의 소리 반복 설정을 맞추고 amb_<place_id>를 장소 씬 Sound/Ambience에 넣는다.
## 규칙은 assets/audio/README.md, 동작은 tools/audio_import_lib.gd.
##
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/audio_import.gd            # 씬을 고친다
##   godot --headless --path . --script res://tools/audio_import.gd -- --check # 보기만 한다
##
## 소리를 넣거나 빼거나 이름을 바꿨으면 다시 돌리고, 바뀐 씬을 같이 커밋한다.


func _initialize() -> void:
	var check := "--check" in OS.get_cmdline_user_args()
	var lib: RefCounted = load("res://tools/audio_import_lib.gd").new()
	lib.run(not check)

	for w in lib.warnings:
		print("  경고  ", w)
	for e in lib.errors:
		print("  FAIL  ", e)
	if check:
		for s in lib.out_of_sync:
			print("  FAIL  %s: 소리와 맞지 않는다. 도구를 --check 없이 돌려 고친다" % s)
	else:
		for s in lib.out_of_sync:
			print("  고침  ", s)
		for p in lib.reimport_needed:
			print("  고침  %s.import — godot --headless --path . --import 를 다시 돌린 뒤 이 도구를 한 번 더" % p)

	var failed: bool = not lib.errors.is_empty() or (check and not lib.ok())
	if failed:
		print("소리 가져오기: 실패")
	elif lib.out_of_sync.is_empty() and lib.reimport_needed.is_empty():
		print("소리 가져오기: 바꿀 것 없음")
	else:
		print("소리 가져오기: 끝")
	quit(1 if failed else 0)
