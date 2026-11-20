extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	get_tree().root.get_node("Meta").muted = true
	var game = load("res://scenes/main.tscn").instantiate()
	game.balance = game.balance.duplicate()
	game.balance.bot_count = 0
	game.balance.monster_count = 0
	get_tree().root.add_child(game)
	for zone in game.get_node("Zones").get_children(): zone.experience_per_second = 0
	game.start_game()
	game.touch_mode = true
	for i in 5: await get_tree().process_frame
	game.touch_move = Vector2.RIGHT
	game.touch_attack = true
	var origin: Vector2 = game.player.position
	var previous: Vector2 = origin
	var failures = 0
	for i in 120:
		await get_tree().physics_frame
		var current: Vector2 = game.player.position
		if current.distance_to(previous) > 20:
			push_error("World position jumped during moving attack: %s -> %s" % [previous, current])
			failures += 1
		previous = current
	if game.player.position.x - origin.x < 200:
		push_error("Movement input did not advance the player while attacking")
		failures += 1
	game.set_physics_process(false)
	game.queue_free()
	await get_tree().process_frame
	print("PLAYBACK: 120 physics frames, %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
