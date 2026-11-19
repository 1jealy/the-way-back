extends SceneTree
## 앞 층 기둥이 하윤 앞을 가리는 순간을 찍는다.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/shot_front.gd -- [place_id] [저장 경로]
## 하윤을 오른쪽으로 걷게 하다가 앞 층 물체와 화면에서 겹치면 한 장 찍고 끝낸다.

const STEP := 4.0


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var place_id := args[0] if args.size() > 0 else "house"
	var out := args[1] if args.size() > 1 else "user://front_%s.png" % place_id

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	if place_id != "house":
		main.go_to("res://scenes/places/%s.tscn" % place_id)
		await create_timer(2.0).timeout

	var player: CharacterBody2D = main.get_node("World/Player")
	var front: Node = main.current_place().get_node("Layers/Front")
	Input.action_press(&"move_right")
	for i in 600:
		await process_frame
		var feet := player.get_global_transform_with_canvas().origin
		var body := Rect2(feet.x - 34.0, feet.y - 250.0, 68.0, 250.0)
		for post in front.get_children():
			if post is ColorRect:
				var p: Vector2 = post.get_global_transform_with_canvas().origin
				if Rect2(p, post.size).intersects(body):
					Input.action_release(&"move_right")
					await process_frame
					await process_frame
					root.get_texture().get_image().save_png(out)
					print("찍음 ", out, " 하윤 화면 x=", feet.x)
					quit(0)
					return
	Input.action_release(&"move_right")
	print("FAIL 앞 층 물체와 겹치는 순간이 없었다")
	quit(1)
