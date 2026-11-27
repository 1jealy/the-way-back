extends SceneTree
const OUT := "/tmp/claude-0/-home-user/45582209-7240-5dd0-987d-6378c07c210b/scratchpad/pose_%s.png"
func _initialize() -> void:
	_run.call_deferred()
func _w(s: float) -> void:
	await create_timer(s).timeout
func _shot(n: String, p: Node2D) -> void:
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var c := root.get_viewport().get_canvas_transform() * p.global_position
	img.get_region(Rect2i(int(c.x) - 330, int(c.y) - 420, 660, 470)).save_png(OUT % n)
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.set_flag(&"has_map"); gs.set_flag(&"dog_joined")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _w(1.0)
	main.go_to("res://scenes/places/riverside.tscn")
	await _w(2.5)
	var p = main.get_node("World/Player")
	var d = main.get_node("World/Dog")
	d.join(p)
	p.global_position.x = 1200
	await _w(1.0)
	p.lock(&"test")
	for pose in ["stand", "crouch", "sit", "sit_floor", "kite", "flute", "flashlight"]:
		p.set_pose(StringName(pose))
		await _w(1.2)
		await _shot(pose, p)
	p.set_pose(&"stand"); await _w(0.8)
	p.play_pickup(); await _w(0.5); await _shot("pickup", p)
	await _w(1.5)
	p.play_throw(); await _w(0.35); await _shot("throw", p)
	await _w(1.5)
	p.get_node("Visual/Rig").play_wrist_touch(); await _w(1.2); await _shot("wrist", p)
	await _w(2.5)
	p.unlock(&"test")
	# walk frames
	var ev := InputEventAction.new(); ev.action = &"move_right"; ev.pressed = true; Input.parse_input_event(ev)
	await _w(1.0); await _shot("walk1", p); await _w(0.18); await _shot("walk2", p)
	ev = InputEventAction.new(); ev.action = &"move_right"; ev.pressed = false; Input.parse_input_event(ev)
	await _w(3.0)
	await _shot("dog_sit", d)
	var rig = d.get_node("Visual/Rig")
	for dp in ["fetch", "sniff", "hold"]:
		d.state = d.State.SCRIPTED
		rig.set_pose(StringName(dp)); await _w(1.0); await _shot("dog_" + dp, d)
	rig.set_pose(&"stand"); rig.bark(); await _w(0.15); await _shot("dog_bark", d)
	quit()
