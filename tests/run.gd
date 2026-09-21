extends SceneTree

var failures: Array = []
var assertions: int = 0

func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures.append(description)
		push_error(description)

func near(actual: float, expected: float, description: String) -> void:
	check(absf(actual - expected) < 0.01, description + " (%s, expected %s)" % [actual, expected])

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var meta = root.get_node("Meta")
	meta.muted = true
	meta.equipped = []
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_game()
	var p = game.player
	var enemy = game.fighters[1]
	check(game.fighters.size() == 16 and game.monsters.size() == 28, "Arena population")
	near(p.max_hp, 100, "Starting HP")
	near(p.max_stamina, 100, "Starting stamina")
	p.hp = 20
	p.grow_level()
	near(p.hp, 20 + p.max_hp * 0.15, "Level heals 15% of maximum HP")
	for i in 38: p.grow_level()
	near(p.max_hp, 400, "Level 40 base HP")
	near(p.max_stamina, 200, "Level 40 base stamina")
	p.stamina = 60
	p.combat_left = 0
	check(p.spend(15), "Out-of-combat attack permitted")
	near(p.stamina, 60, "Out-of-combat attack free")
	p.combat_left = 5
	check(p.spend(15), "Combat attack permitted")
	near(p.stamina, 45, "Combat attack costs 15")
	check(p.spend(25), "Combat skill permitted")
	near(p.stamina, 20, "Combat skill costs 25")
	p.tick(1)
	near(p.stamina, 40, "Regeneration 20 per second")
	game.touch_block = true
	p.tick(1)
	near(p.stamina, 40, "Blocking prevents regeneration")
	game.touch_block = false
	p.blocking = true
	p.stamina = 5
	enemy.stamina = 15
	p.invuln = 0
	game.deal_damage(p, 10, enemy)
	near(p.stamina, 0, "Successful block costs 5")
	near(enemy.stamina, 0, "Blocked attacker loses 15")
	near(p.exhausted, 2, "Defender exhausted 2 seconds")
	near(enemy.exhausted, 2, "Attacker exhausted 2 seconds")
	check(not p.can_act() and not enemy.can_act(), "Exhaustion disables actions")
	game.touch_move = Vector2.RIGHT
	var old_position: Vector2 = p.position
	p.tick(0.5)
	near(p.position.distance_to(old_position), 0, "Exhaustion disables movement")
	game.touch_move = Vector2.ZERO
	p.exhausted = 0
	p.blocking = false
	p.combat_left = 0
	p.invuln = 0
	game.deal_damage(p, 10, game.monsters[0])
	near(p.combat_left, 0, "Monster damage does not activate knight combat")
	p.hp = 40
	p.no_hit_time = 5
	p.tick(1)
	near(p.hp, 80, "Peaceful HP regeneration 10% per second")
	p.hp = 50
	p.stamina = 10
	p.combat_left = 5
	p.exhausted = 1
	game.kill_target(enemy, p)
	near(p.hp, p.max_hp, "Knight kill restores HP")
	near(p.stamina, p.max_stamina, "Knight kill restores stamina")
	near(p.exhausted + p.combat_left, 0, "Knight kill clears exhaustion and combat")
	game.start_game()
	p = game.player
	game.add_xp(p, 1000000)
	check(p.level == 40, "Level cap is 40")
	var evolution_levels: Array = []
	# First open modal consumes a stat event; evolutions remain queued.
	for choice in game.choices:
		if choice.kind == "evolution": evolution_levels.append(choice.level)
	check(evolution_levels == [5, 15, 25], "Evolution thresholds 5 / 15 / 25")
	game.choices.clear()
	game.choice_open = false
	game.ui.modal.hide()
	for level in [5, 15, 25]: CrownCatalog.evolve(p, CrownCatalog.EVOLUTIONS[level][0])
	p.skill("e")
	p.skill("r")
	p.skill("q")
	check(p.cooldown.e > 0 and p.cooldown.r > 0 and p.cooldown.q > 0, "All evolved skills execute")
	var hp_before: float = p.hp
	var damage_before: float = p.damage
	game.start_boss(true)
	check(game.mode == "boss" and game.participants.size() >= 2, "Boss battle starts")
	var boss = game.boss
	var original = game.snapshots.filter(func(s): return s.fighter == boss)[0].values
	near(boss.max_hp, original.max_hp * (1 + (game.participants.size() - 1) * 0.7), "Boss HP scaling")
	near(boss.damage, original.damage * 4, "Boss attack multiplier")
	game.kill_target(p, boss if p != boss else game.participants.filter(func(f): return f != boss)[0])
	if game.mode == "boss": game.finish_boss(p == boss)
	check(p.alive and game.mode == "play", "Boss death does not end arena run")
	near(p.hp, hp_before, "Boss HP snapshot restored")
	near(p.damage, damage_before, "Boss stats restored")
	game.paused = false
	game.boss_finish_pending = false
	game.mode = "menu"
	game.queue_free()
	await process_frame
	print("IRON CROWN: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
