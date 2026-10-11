extends SceneTree

var checks: int = 0
var failures: Array = []

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("DEATHMATCH: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var meta = root.get_node("Meta")
	meta.muted = true
	meta.equipped = []
	var game = load("res://scenes/deathmatch.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.is_deathmatch(), "Separate TEST1 match arena")
	check(game.fighters.size() == 10, "Player and nine AI knights")
	check(game.monsters.is_empty(), "No unwanted survival monsters")
	check(game.boxes.size() == 65, "XP boxes are placed")
	check(game.round_remaining == 480.0, "Eight minute timer")
	var p = game.player
	var bot = game.fighters[1]
	check(p.level == 1 and bot.level == 1, "All fighters begin at Lv.1")
	var first_score = game.match_points(p)
	game.add_xp(p, 12000.0)
	check(p.level >= 25, "XP grants fast advancement to final evolution")
	check(game.match_points(p) > first_score, "XP awards points")
	# Simulate choosing one valid TEST1 evolution at each threshold.
	game.choices.clear()
	game.choice_open = false
	game.ui.modal.hide()
	for tier in [5, 15, 25]:
		var available: Array = CrownTest1Rules.options_for(p, tier)
		check(not available.is_empty(), "Branch options at Lv.%d" % tier)
		if not available.is_empty(): CrownTest1Rules.evolve(p, available[0])
	var level_before: int = p.level
	game.kill_target(p, bot)
	check(game.mode == "play" and not p.alive, "Death does not end the match")
	check(p.evolutions.size() == 3 and p.level >= 25, "Evolution and its minimum level retained")
	check(p.level <= level_before, "Death costs match XP")
	check(float(p.get_meta("dm_respawn", -1)) == 3.0, "Respawn countdown set")
	game.respawn(p)
	check(p.alive and p.hp == p.max_hp and p.evolutions.size() == 3, "Respawn preserves the chosen form")
	var score_before: int = game.match_points(p)
	game.kill_target(bot, p)
	check(game.match_points(p) >= score_before + 100, "Player kill awards 100 points")
	check(bot.kills == 1, "Bot earns first kill before being defeated")
	game.respawn(bot)
	check(bot.alive and bot.level >= 1, "AI respawns retaining its progression")
	game.end_round()
	check(game.mode == "matchover" and game.round_remaining == 0.0, "End screen freezes the match")
	game.queue_free()
	await process_frame
	print("IRON CROWN DEATHMATCH: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
