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
	# Explicit advance() calls control animation time in this test.
	p.get_node("AnimationPlayer").callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var enemy = game.fighters[1]
	check(game.fighters.size() == 16 and game.monsters.size() == 28, "Arena population")
	near(p.max_hp, 100, "Starting HP")
	near(p.stamina, 100, "Starting stamina")
	check(p.facing == -PI / 2.0, "Stick fighter defaults to facing upward")
	check(p.get_node("Visual/Body").texture.resource_path == "res://assets/Character_Base.png", "Base body uses supplied PNG")
	check(p.get_node("Visual/WeaponPivot1/WeaponPivot2/Sword").texture.resource_path == "res://assets/Stick.png", "Starter weapon uses supplied stick")
	check(not p.can_guard() and not p.has_node("Visual/Shield"), "Starter cannot guard and has no shield")
	near(p.max_stamina, 100, "Maximum stamina stays constant at spawn")
	check(not p.get_node("AnimationPlayer").has_animation("guard_raise"), "Starter has no guard raise animation")
	check(not p.get_node("AnimationPlayer").has_animation("guard_lower"), "Starter has no guard recovery animation")
	check(p.get_node("AnimationPlayer").autoplay.is_empty(), "Combat animation does not autoplay on spawn")
	var attack_target = game.fighters[1]
	p.position = Vector2(1000, 1000)
	attack_target.position = p.position + Vector2(80, 0)
	p.facing = 0
	p.combat_left = 0
	p.cooldown.attack = 0
	var hp_before_swing = attack_target.hp
	p.attack()
	near(p.stamina, 90, "Attack consumes stamina")
	check(p.attack_lock > 0, "Attack startup/recovery action lock")
	near(attack_target.hp, hp_before_swing, "Attack waits for swing hit timing")
	p.get_node("AnimationPlayer").advance(0.201)
	await process_frame
	check(p.position.is_equal_approx(Vector2(1000, 1000)), "Attack animation preserves world position")
	check(attack_target.hp < hp_before_swing, "Swing hit timing applies damage")
	var stamina_before_dash = p.stamina
	p.dash(Vector2.RIGHT)
	near(p.stamina, stamina_before_dash, "Cannot dash-cancel attack recovery")
	p.attack_lock = 0
	p.cooldown.dash = 0
	p.dash(Vector2.RIGHT)
	check(p.stamina < stamina_before_dash, "Dash consumes stamina when available")
	p.dash_left = 0
	p.cooldown.dash = 0
	# Guard coverage uses the shield archetype, not a guard bolted onto the starter.
	var defender = load("res://scenes/characters/shieldbearer.tscn").instantiate()
	defender.arena = game
	defender.is_player = true
	defender.position = p.position
	game.get_node("Actors").add_child(defender)
	game.fighters.append(defender)
	game.player = defender
	p = defender
	p.get_node("AnimationPlayer").callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	p.guard.requested = true
	var stamina_before_guard_raise = p.stamina
	p.guard.tick(0.0)
	var guard_player: AnimationPlayer = p.get_node("AnimationPlayer")
	near(p.stamina, stamina_before_guard_raise, "Guard raise has no stamina cost")
	check(not p.guard.blocking and p.guard.phase == "raise", "Guard stays vulnerable during windup")
	# A method key in the animation, not advance_guard(), activates blocking.
	p.guard.tick(0.15)
	check(not p.guard.blocking, "Guard state is not driven by timer")
	guard_player.advance(0.15)
	await process_frame
	check(p.guard.blocking and p.guard.phase == "hold", "Raise animation event activates guard")
	near(p.guard.perfect_left, game.balance.perfect_guard_window, "Guard starts perfect-block window")
	p.guard.requested = false
	p.guard.tick(0.0)
	check(not p.guard.blocking and p.guard.phase == "lower", "Guard lowering loses protection")
	guard_player.advance(0.23)
	await process_frame
	check(p.guard.phase == "idle", "Lower animation event restores idle state")
	var default_windup = game.balance.guard_windup
	var default_recovery = game.balance.guard_recovery
	game.balance.guard_windup = 0.30
	game.balance.guard_recovery = 0.40
	p.guard.requested = true
	p.guard.tick(0.0)
	near(guard_player.get_playing_speed(), guard_player.get_animation("guard_raise").length / 0.30, "Custom windup scales animation speed")
	guard_player.advance(0.29)
	await process_frame
	check(not p.guard.blocking, "Custom windup keeps guard vulnerable")
	guard_player.advance(0.02)
	await process_frame
	check(p.guard.blocking, "Custom windup animation event enables guard")
	p.guard.requested = false
	p.guard.tick(0.0)
	near(guard_player.get_playing_speed(), guard_player.get_animation("guard_lower").length / 0.40, "Custom recovery scales animation speed")
	guard_player.advance(0.39)
	await process_frame
	check(p.guard.phase == "lower", "Custom recovery keeps action lock")
	guard_player.advance(0.02)
	await process_frame
	check(p.guard.phase == "idle", "Custom recovery ends via animation event")
	game.balance.guard_windup = default_windup
	game.balance.guard_recovery = default_recovery
	p.evolutions.clear()
	p.update_visual()
	p.hp = 20
	p.grow_level()
	near(p.hp, 20 + p.max_hp * 0.15, "Level heals 15% of maximum HP")
	for i in 38: p.grow_level()
	near(p.max_hp, 400, "Level 40 base HP")
	near(p.max_stamina, 100, "Level-ups do not increase maximum stamina")
	p.reset_groggy()
	p.hp = p.max_hp
	p.invuln = 0
	p.guard.blocking = false
	enemy.reset_groggy()
	enemy.stamina = enemy.max_stamina
	game.deal_damage(p, 1, enemy)
	near(p.groggy, 6, "Normal hit adds six groggy")
	p.update_groggy(0.5)
	near(p.groggy, 5, "Groggy decays continuously without delay")
	p.guard.phase = "hold"
	p.guard.blocking = true
	p.guard.perfect_left = 0
	var defender_groggy_before = p.groggy
	var attacker_stamina_before = enemy.stamina
	game.deal_damage(p, 1, enemy)
	near(p.groggy, defender_groggy_before, "Regular guard does not gain groggy")
	near(enemy.stamina, attacker_stamina_before - 15, "Blocked attack costs attacker 1.5x attack stamina extra")
	p.guard.perfect_left = 0.10
	game.deal_damage(p, 1, enemy)
	near(enemy.groggy, 60, "Perfect guard adds 60 groggy to attacker")
	near(p.guard.perfect_left, 0, "Perfect guard can trigger once per raise")
	game.deal_damage(p, 1, enemy)
	near(enemy.groggy, 60, "Repeated hit in same hold does not duplicate parry")
	p.guard.phase = "idle"
	p.guard.blocking = false
	p.invuln = 1
	game.deal_damage(p, 1, enemy)
	near(p.groggy, defender_groggy_before, "Invulnerable hit adds no groggy")
	p.invuln = 0
	p.reset_groggy()
	p.get_node("Visual/WeaponPivot1").rotation = 1.2
	p.get_node("Visual/WeaponPivot1/WeaponPivot2").rotation = -0.7
	# Approximately twenty normal hits at half-second intervals should cause groggy.
	for i in 20:
		p.add_groggy(game.balance.groggy_hit)
		if i < 19: p.update_groggy(0.5)
	near(p.groggy_left, 2, "About twenty sustained hits trigger two-second groggy")
	check(not p.can_act(), "Groggy disables actions")
	near(p.get_node("Visual/WeaponPivot1").rotation, 0, "Groggy resets weapon shoulder")
	near(p.get_node("Visual/WeaponPivot1/WeaponPivot2").rotation, 0, "Groggy resets weapon wrist")
	p.add_groggy(100)
	near(p.groggy_left, 2, "Hits cannot extend active groggy")
	game.touch_move = Vector2.RIGHT
	var old_position: Vector2 = p.position
	p.tick(0.5)
	near(p.position.distance_to(old_position), 0, "Groggy disables movement")
	game.touch_move = Vector2.ZERO
	p.update_groggy(1.5)
	check(p.can_act(), "Groggy recovers automatically")
	near(p.groggy, 0, "Recovery clears meter")
	p.add_groggy(100)
	near(p.groggy, 0, "Recovery immunity prevents chain groggy")
	p.update_groggy(1.1)
	p.add_groggy(30)
	p.update_groggy(3.0)
	near(p.groggy, 24, "Groggy decays throughout combat")
	p.update_groggy(1.0)
	near(p.groggy, 22, "Groggy always decays two per second")
	p.reset_groggy()
	p.combat_left = 0
	p.guard.blocking = false
	game.deal_damage(p, 1, game.monsters[0])
	near(p.combat_left, 0, "Monster damage does not activate knight combat")
	near(p.groggy, 6, "Monster hit uses normal groggy gain")
	p.hp = 40
	p.no_hit_time = 5
	p.tick(1)
	near(p.hp, 80, "Peaceful HP regeneration 10% per second")
	p.hp = 50
	p.combat_left = 5
	p.groggy_left = 1
	game.kill_target(enemy, p)
	near(p.hp, p.max_hp, "Knight kill restores HP")
	near(p.groggy, 0, "Knight kill clears groggy meter")
	near(p.groggy_left + p.combat_left, 0, "Knight kill clears groggy and combat")
	# Exhaustion: an exact zero expenditure causes a one-second action lock.
	p.get_node("Visual/WeaponPivot1").rotation = 1.2
	p.get_node("Visual/WeaponPivot1/WeaponPivot2").rotation = -0.7
	p.stamina = 10
	check(not p.spend_stamina(10), "Exact stamina depletion interrupts action")
	near(p.stamina, 0, "Exhaustion starts at zero stamina")
	near(p.get_node("Visual/WeaponPivot1").rotation, 0, "Exhaustion resets weapon shoulder")
	near(p.get_node("Visual/WeaponPivot1/WeaponPivot2").rotation, 0, "Exhaustion resets weapon wrist")
	near(p.exhaustion_left, 1, "Exhaustion lasts one second")
	check(not p.can_act(), "Exhausted fighter cannot act")
	var exhausted_guard_phase = p.guard.phase
	p.guard.requested = true
	p.guard.tick(0.1)
	check(p.guard.phase == exhausted_guard_phase, "Exhaustion prevents guarding")
	p.tick(0.5)
	near(p.stamina, 0, "Stamina stays empty during exhaustion")
	check(not p.can_act(), "Exhaustion still active after half second")
	p.tick(0.51)
	check(p.can_act() and p.stamina > 0, "Actions and stamina regenerate after exhaustion")
	p.stamina = 0
	p.exhaustion_left = 1
	# Solo kill heals to full and refills stamina even if exhausted.
	var solo_victim = game.fighters[2]
	p.hp = 35
	solo_victim.damage_contributors[p.get_instance_id()] = game.elapsed
	game.kill_target(solo_victim, p)
	near(p.hp, p.max_hp, "Solo contributor gets full health")
	near(p.stamina, p.max_stamina, "Kill always refills stamina")
	near(p.exhaustion_left, 0, "Kill clears exhaustion")
	# Two distinct attackers within the combat window halve the final hitter's reward.
	var shared_victim = game.fighters[3]
	var ally = game.fighters[4]
	shared_victim.damage_contributors[p.get_instance_id()] = game.elapsed
	shared_victim.damage_contributors[ally.get_instance_id()] = game.elapsed
	shared_victim.damage_contributors[ally.get_instance_id()] = game.elapsed
	check(game.recent_contributor_count(shared_victim) == 2, "Repeated hits from same attacker count once")
	p.hp = 20
	p.stamina = 15
	game.kill_target(shared_victim, p)
	near(p.hp, 20 + p.max_hp * 0.5, "Two contributors restore half of max HP")
	near(p.stamina, p.max_stamina, "Assisted kill still restores full stamina")
	# Old damage contributions expire using the same combat-duration window.
	var stale_victim = game.fighters[5]
	game.elapsed += game.balance.combat_duration + 0.1
	stale_victim.damage_contributors[ally.get_instance_id()] = 0.0
	stale_victim.damage_contributors[p.get_instance_id()] = game.elapsed
	check(game.recent_contributor_count(stale_victim) == 1, "Expired contribution no longer divides healing")
	p.hp = 20
	game.kill_target(stale_victim, p)
	near(p.hp, p.max_hp, "Expired second contributor allows full heal")
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
	check(game.get_node("Projectiles").get_child_count() == 0, "Skill input waits for animation event")
	p.ability_players.e.advance(0.201)
	await process_frame
	check(game.get_node("Projectiles").get_child_count() == 1, "Skill animation event launches projectile")
	p.resolve_skill_hit("e")
	check(game.get_node("Projectiles").get_child_count() == 1, "Repeated event cannot duplicate consumed cast")
	check(game.spawn_fighter(false).abilities.is_empty(), "Equipped skills are isolated per fighter")
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
