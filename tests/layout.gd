extends SceneTree

var failed = 0
var checks = 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in 5: await process_frame

func run() -> void:
	root.get_node("Meta").muted = true
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.touch_mode = true
	game.start_game()
	var player = game.player
	player.hp = 71
	for dimensions in [Vector2i(360, 800), Vector2i(390, 844), Vector2i(320, 568), Vector2i(690, 720), Vector2i(844, 390), Vector2i(1152, 648)]:
		root.size = dimensions
		game.ui.refresh_layout(true)
		await settle()
		var touch = game.ui.touch
		var screen = Rect2(Vector2.ZERO, touch.size)
		verify(player == game.player and player.hp == 71, "Rotation preserves player and HP")
		var controls = touch.button_layout()
		for b in controls:
			verify(screen.encloses(Rect2(b[2] - Vector2.ONE * b[3], Vector2.ONE * b[3] * 2)), "Button stays on screen: " + b[0])
			verify(b[2].distance_to(touch.joystick_origin()) > b[3] + 88, "Button does not overlap joystick: " + b[0])
			for other in controls:
				if b[0] != other[0]: verify(b[2].distance_to(other[2]) > b[3] + other[3], "Buttons do not overlap")
		game.ui.show_menu()
		await settle()
		verify(screen.encloses(game.ui.box.get_global_rect()), "Menu fits " + str(dimensions))
		game.ui.show_shop()
		await settle()
		verify(screen.encloses(game.ui.panel.get_global_rect()), "Shop fits " + str(dimensions))
		game.ui.show_choices({"kind": "evolution", "level": 25})
		await settle()
		verify(screen.encloses(game.ui.panel.get_global_rect()), "Evolution modal fits " + str(dimensions))
		game.ui.show_game()
		game.touch_attack = true
		game.touch_block = true
		touch.joystick_id = 2
		game.ui.refresh_layout(true)
		verify(not game.touch_attack and not game.touch_block and touch.joystick_id == -1, "Rotation clears held input")
	game.queue_free()
	await process_frame
	print("LAYOUT: %d checks, %d failures" % [checks, failed])
	quit(0 if failed == 0 else 1)
