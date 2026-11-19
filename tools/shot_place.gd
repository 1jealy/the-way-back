extends SceneTree
## 장소 하나를 장면 표시(Markers) 자리마다 찍는다. 그림·색을 훑어볼 때 쓴다.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://tools/shot_place.gd -- <place_id> <저장 경로 앞부분>
## → <앞부분>_<장면 번호>.png


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var place_id: String = args[0] if args.size() > 0 else "house"
	var out: String = args[1] if args.size() > 1 else "user://shot_%s" % place_id

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	if main.current_place() == null or main.current_place().place_id != StringName(place_id):
		main.go_to("res://scenes/places/%s.tscn" % place_id)
		await create_timer(2.0).timeout
	for node in root.find_children("*", "Control", true, false):
		if node.get_parent() is CanvasLayer and node.visible and node.name != "Fade":
			node.visible = false  # 제목 화면·안내 같은 UI는 가린다
	var player: Node2D = main.get_node("World/Player")
	var camera: Camera2D = player.get_node("Camera")
	var place: Node = main.current_place()
	for marker in place.get_node("Markers").get_children():
		player.global_position.x = marker.position.x
		camera.reset_smoothing()
		await create_timer(0.4).timeout
		var path := "%s_%s.png" % [out, marker.name]
		root.get_texture().get_image().save_png(path)
		print("찍음 ", path)
	quit(0)
