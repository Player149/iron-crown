extends SceneTree

var assertions: int = 0
var failures: Array = []

func check(condition: bool, detail: String) -> void:
	assertions += 1
	if not condition:
		failures.append(detail)
		push_error(detail)

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
	var player = game.player
	var roots: Array = CrownTest1Rules.options_for(player, 5)
	check(roots.size() >= 10, "Wide early-game branch selection")
	var tier5: Array = []
	var tier15: Array = []
	for form in CrownTest1Rules.FORMS:
		check(not CrownTest1Rules.style_for(str(form[0])).is_empty(), "Style assigned to " + str(form[0]))
		if form[2] == 5: tier5.append(form[0])
		if form[2] == 15: tier15.append(form[0])
	for form in CrownTest1Rules.FORMS:
		if form[2] == 15:
			check(tier5.has(form[3]), "Second-tier parent exists: " + str(form[0]))
		if form[2] == 25:
			check(tier15.has(form[3]), "Last-tier parent exists: " + str(form[0]))
	var first: Array = roots.filter(func(choice): return choice[0] == "fist")
	check(not first.is_empty(), "Fist archetype exists")
	if not first.is_empty():
		CrownTest1Rules.evolve(player, first[0])
		var second: Array = CrownTest1Rules.options_for(player, 15)
		check(second.size() >= 3, "Fist has several follow-up branches")
		var mechanical: Array = second.filter(func(choice): return choice[0] == "steel_crane")
		check(not mechanical.is_empty(), "Unexpected robot branch available from fist")
		if not mechanical.is_empty():
			CrownTest1Rules.evolve(player, mechanical[0])
			var final: Array = CrownTest1Rules.options_for(player, 25)
			check(final.any(func(choice): return choice[0] == "mech_king"), "Robot finale reachable")
	var enemy = game.fighters[1]
	enemy.stagger_protection = 0
	game.apply_posture(enemy, 100, player)
	check(enemy.stagger_left > 0, "Full posture causes short stagger")
	check(enemy.posture == 0, "Posture resets on break")
	game.apply_posture(enemy, 60, player)
	check(enemy.posture == 0, "Brief stagger protection prevents chaining")
	enemy.stagger_protection = 0
	enemy.stagger_left = 0
	player.position = Vector2(1000, 1000)
	enemy.position = player.position + Vector2(50, 0)
	player.facing = 0
	player.blocking = true
	player.parry_left = 0.18
	player.stamina = 90
	player.invuln = 0
	var old_hp: float = player.hp
	game.deal_damage(player, 20, enemy)
	check(is_equal_approx(player.hp, old_hp), "Timed frontal parry negates damage")
	check(player.parry_left == 0, "Parry window consumed")
	player.blocking = false
	player.combat_style = "summon"
	for i in 5: game.spawn_minion(player, "summon")
	check(game.minions.size() == 3, "Summon count capped at three per owner")
	var monster = game.monsters[0]
	monster.position = game.balance.world_size * 0.5
	monster.configure_region()
	check(monster.kind == "crown" and monster.max_hp >= 100, "Crown center monster is tougher")
	monster.position = Vector2(50, 50)
	monster.configure_region()
	check(monster.kind == "plain" and monster.max_hp < 100, "Outer plain monster is weaker")
	game.mode = "menu"
	game.queue_free()
	await process_frame
	print("TEST1: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
