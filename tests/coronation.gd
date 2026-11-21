extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	seed(4421)
	Meta.muted = true
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.balance = game.balance.duplicate()
	game.balance.bot_count = 3
	game.set_physics_process(false)
	check(game.ui.box.get_node("Start").text.begins_with("영광의 대관"), "Deathmatch is the default menu launch")
	game.start_coronation()
	var match_data = game.coronation
	check(match_data != null and game.mode == "play", "Opens the new deathmatch")
	check(game.bounds().size == Vector2(5340, 5340), "Square map takes 30 seconds to walk across")
	check(match_data.sites.size() == 16 and game.monsters.size() == 66, "Random sites and resources are populated")
	for f in game.fighters:
		for site in match_data.sites:
			check(f.position.distance_to(site.center) > site.radius, "Spawn outside points of interest")
	var player = game.player
	var opponent = game.fighters[1]
	var assist = game.fighters[2]
	match_data.record_damage(opponent, assist, 30.0)
	match_data.record_damage(opponent, player, 70.0)
	check(player.iron_score == 0 and assist.iron_score == 0, "Damage alone earns no iron")
	game.kill_target(opponent, player)
	check(player.iron_score == 1000 and assist.iron_score == 150, "Kill and assist score")
	match_data.reset_fighter(opponent, match_data.safe_spawn(), 2.0)
	check(opponent.alive and opponent.hp == opponent.max_hp, "Free respawn")
	var field = game.monsters.filter(func(m): return m.coronation_kind == "field")[0]
	field.position = field.home + Vector2(field.leash + 15.0, 0.0)
	field.hp = 2.0
	field.tick(0.1)
	check(field.returning and field.invuln > 0.0 and field.hp > 2.0, "Camp monster resets when leashed")
	var resource = game.monsters.filter(func(m): return m.is_resource())[0]
	var xp_before: float = player.xp
	game.kill_target(resource, player)
	check(player.iron_score == 1000 and (player.xp > xp_before or player.level > 1), "Destructible grants XP without iron")
	game.elapsed = 95.0
	match_data.step(0.1)
	check(match_data.phase == 1, "First contraction starts on schedule")
	game.elapsed = 120.0
	var first_radius: float = match_data.safe_radius()
	game.elapsed = 151.0
	check(is_equal_approx(match_data.safe_radius(), first_radius), "Holds after first contraction")
	game.elapsed = 180.0
	var second_radius: float = match_data.safe_radius()
	game.elapsed = 211.0
	check(second_radius < first_radius and is_equal_approx(match_data.safe_radius(), second_radius), "Holds after second contraction")
	game.elapsed = 228.0
	check(match_data.safe_radius() < second_radius, "Third contraction sends fighters to center")
	game.elapsed = 240.0
	match_data.step(0.1)
	var bracket = match_data.bracket
	check(match_data.phase == 2 and bracket.pairs.size() == 2, "Two concurrent semifinal matches")
	var pair: Dictionary = bracket.pairing(player.match_slot)
	var foe = bracket.fighter(pair.a if pair.b == player.match_slot else pair.b)
	var other: Dictionary = bracket.pairs[1] if bracket.pairs[0].a == pair.a else bracket.pairs[0]
	var outsider = bracket.fighter(other.a)
	check(game.targets(player) == [foe] and not game.valid_target(player, outsider), "Only paired opponents can be targeted")
	player.invuln = 0.0
	check(game.deal_damage(player, 9000.0, outsider) == 0.0, "Other ring damage is ignored")
	check(game.fighter_bounds(player) == pair.rect, "Fighter is confined to its ring")
	game.kill_target(foe, player)
	check(not match_data.winner_announced and not outsider == null and outsider.alive, "First bout does not end the other")
	game.elapsed = bracket.deadline
	match_data.step(0.1)
	check(bracket.advancing.size() == 2 and bracket.round_number == 1, "The other bout resolves on timeout")
	game.elapsed = bracket.next_round_at
	match_data.step(0.1)
	check(bracket.round_number == 2 and bracket.pairs.size() == 1 and player.alive, "Semifinal winners reach the final")
	pair = bracket.pairing(player.match_slot)
	foe = bracket.fighter(pair.a if pair.b == player.match_slot else pair.b)
	game.kill_target(foe, player)
	game.elapsed = bracket.next_round_at
	match_data.step(0.1)
	check(match_data.winner_announced and player.iron_score == 5000, "Only bracket champion earns the top bonus")
	var score: int = player.iron_score
	var level: int = player.level
	game.elapsed = match_data.reopen_at
	match_data.step(0.1)
	check(match_data.phase == 3 and game.fighters.all(func(f): return f.alive), "Reopen disperses and respawns all fighters")
	check(player.iron_score == score and player.level == level, "Reopening preserves score and build")
	game.run_gold = 0
	game.elapsed = 481.0
	match_data.step(0.1)
	check(game.mode == "coronation_result" and game.elapsed == 480.0 and match_data.ranking()[0] == player, "Eight-minute finish awards the crown")
	game.start_duel()
	check(game.coronation == null and game.mode == "duel", "Existing duel still opens")
	print("CORONATION: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

