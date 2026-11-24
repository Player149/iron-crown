extends Node

var failures: Array = []
var assertions: int = 0

func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures.append(description)
		push_error(description)

func near(actual: float, expected: float, description: String) -> void:
	check(absf(actual - expected) < 0.01, description + " (%s, expected %s)" % [actual, expected])

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var meta = get_tree().root.get_node("Meta")
	meta.muted = true
	meta.equipped = []
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.set_physics_process(false)
	game.start_game()
	check(game.ui.box.has_node("BalanceLab"), "Main menu exposes AI balance laboratory")
	check(load("res://tests/balance_lab.gd") != null, "Embedded balance laboratory script is loadable")
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
	await get_tree().process_frame
	check(p.position.is_equal_approx(Vector2(1000, 1000)), "Attack animation preserves world position")
	check(attack_target.hp < hp_before_swing, "Swing hit timing applies damage")
	var stamina_before_dash = p.stamina
	p.dash(Vector2.RIGHT)
	near(p.stamina, stamina_before_dash - game.balance.dash_stamina_cost, "Dash cancels normal attack recovery and consumes stamina")
	check(p.dash_left > 0.0 and p.attack_lock <= 0.0 and not p.swing_active, "Dash starts and clears basic swing")
	p.dash_left = 0
	p.invuln = 0
	p.cooldown.dash = 0
	p.cooldown.attack = 0
	p.stamina = p.max_stamina
	p.attack()
	var hp_before_cancel: float = attack_target.hp
	p.dash(Vector2.RIGHT)
	p.resolve_attack_hit()
	near(attack_target.hp, hp_before_cancel, "Cancelling startup prevents stale hit event")
	near(p.cooldown.attack, maxf(p.definition.attack_cooldown / p.attack_speed, p.get_node("AnimationPlayer").get_animation("swing").length / p.attack_speed), "Cancellation preserves attack cooldown")
	near(CrownFighter.calculate_hitstun(50, 0.30, 50, 0.10), 0.15, "Equal poise halves hitstun")
	near(CrownFighter.calculate_hitstun(50, 0.30, 51, 0.10), 0, "Higher poise prevents hitstun")
	near(CrownFighter.calculate_hitstun(50, 0.15, 50, 0.10), 0.10, "Minimum hitstun clamps reduction")
	near(CrownFighter.calculate_hitstun(0, 0.30, 0, 0.10), 0, "Zero stagger power disables hitstun")
	p.dash_left = 0.0
	p.invuln = 0.0
	p.set_poise_modifier("test", 30.0, 0.25)
	near(p.effective_poise(), 40.0, "Timed skill poise adds to base")
	check(not p.apply_hitstun(25, 0.3), "Poise bonus prevents weak stagger")
	p.update_poise_modifiers(0.25)
	near(p.effective_poise(), 10.0, "Poise expires without changing base")
	check(p.apply_hitstun(25, 0.30), "Hitstun applies below strength")
	near(p.hitstun_left, 0.24, "Duration scales with poise")
	check(not p.apply_hitstun(100, 1.0), "Active hitstun does not stack")
	p.stamina = 50.0
	var before_stun_position: Vector2 = p.position
	game.touch_move = Vector2.RIGHT
	p.tick(0.1)
	near(p.position.distance_to(before_stun_position), 0, "Hitstun prevents movement")
	near(p.stamina, 50.0 + game.balance.stamina_regen * 0.1, "Hitstun allows stamina recovery")
	check(not p.can_act(), "Hitstun blocks actions")
	p.update_hitstun(0.2)
	check(p.can_act() and not p.apply_hitstun(100, 1.0), "Recovery grants hitstun-only immunity")
	p.reset_hitstun()
	game.touch_move = Vector2.ZERO
	# Guard coverage uses the shield archetype, not a guard bolted onto the starter.
	var defender = load("res://scenes/characters/swordsman.tscn").instantiate()
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
	await get_tree().process_frame
	check(p.guard.blocking and p.guard.phase == "hold", "Raise animation event activates guard")
	near(p.guard.perfect_left, game.balance.perfect_guard_window, "Guard starts perfect-block window")
	p.guard.requested = false
	p.guard.tick(0.0)
	check(not p.guard.blocking and p.guard.phase == "lower", "Guard lowering loses protection")
	guard_player.advance(0.23)
	await get_tree().process_frame
	check(p.guard.phase == "idle", "Lower animation event restores idle state")
	var default_windup = game.balance.guard_windup
	var default_recovery = game.balance.guard_recovery
	game.balance.guard_windup = 0.30
	game.balance.guard_recovery = 0.40
	p.guard.requested = true
	p.guard.tick(0.0)
	near(guard_player.get_playing_speed(), guard_player.get_animation("guard_raise").length / 0.30, "Custom windup scales animation speed")
	guard_player.advance(0.29)
	await get_tree().process_frame
	check(not p.guard.blocking, "Custom windup keeps guard vulnerable")
	guard_player.advance(0.02)
	await get_tree().process_frame
	check(p.guard.blocking, "Custom windup animation event enables guard")
	p.guard.requested = false
	p.guard.tick(0.0)
	near(guard_player.get_playing_speed(), guard_player.get_animation("guard_lower").length / 0.40, "Custom recovery scales animation speed")
	guard_player.advance(0.39)
	await get_tree().process_frame
	check(p.guard.phase == "lower", "Custom recovery keeps action lock")
	guard_player.advance(0.02)
	await get_tree().process_frame
	check(p.guard.phase == "idle", "Custom recovery ends via animation event")
	game.balance.guard_windup = default_windup
	game.balance.guard_recovery = default_recovery
	p.evolutions.clear()
	p.update_visual()
	p.hp = 20
	p.grow_level()
	near(p.hp, 20 + p.max_hp * 0.15, "Level heals 15% of maximum HP")
	for i in 23: p.grow_level()
	near(p.max_hp, 285, "Level 25 automatic HP growth")
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
	near(p.guard.parry_cooldown_left, 4.0, "Successful parry starts a four-second cooldown")
	p.guard.reset()
	p.guard.requested = true
	p.guard.phase = "raise"
	p.guard.on_guard_raised()
	near(p.guard.perfect_left, 0, "Re-raising cannot bypass parry cooldown")
	check(p.guard.blocking, "Normal guard remains available during parry cooldown")
	game.deal_damage(p, 1, enemy)
	near(enemy.groggy, 60, "Guard during cooldown does not parry")
	p.guard.reset()
	p.guard.tick(4.0)
	p.guard.requested = true
	p.guard.phase = "raise"
	p.guard.on_guard_raised()
	near(p.guard.perfect_left, game.balance.perfect_guard_window, "Parry returns after four seconds")
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
	near(p.hp, 40 + p.max_hp * 0.10, "Peaceful HP regeneration 10% per second")
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
	# Confirm each of the four new Lv.5 choices swaps the actual fighter scene.
	var new_choices = CrownCatalog.EVOLUTIONS[6]
	check(new_choices.size() == 4, "Lv6 offers exactly four weapon evolutions")
	var expected = {
		"hammerman": ["hammerman.gd", "res://assets/hammer.png", false, "Hammer"],
		"spearman": ["spearman.gd", "res://assets/Spear.png", true, "Spear"],
		"shieldbearer": ["shieldbearer.gd", "res://assets/Shield_Big1.png", true, "Shield"],
		"swordsman": ["swordsman.gd", "res://assets/sword_A.png", true, "Sword"]
	}
	for choice in new_choices:
		game.start_game()
		var starter = game.player
		starter.level = 6
		starter.hp = 47.0
		starter.stamina = 42.0
		starter.kills = 3
		var starter_index = game.fighters.find(starter)
		var id: String = choice[0]
		check(CrownCatalog.options_for(starter, 6).size() == 4, "Starter receives four evolution choices")
		var evolved = CrownCatalog.evolve(starter, choice)
		check(evolved == game.player and evolved != starter, "Evolution replaces player scene: " + id)
		check(game.fighters[starter_index] == evolved, "Arena roster points to evolved actor: " + id)
		check(evolved.get_script().resource_path.ends_with(expected[id][0]), "Subclass scene is active: " + id)
		check(evolved.level == 6 and evolved.kills == 3, "Progress retained through evolution: " + id)
		near(evolved.hp, 47.0, "Current HP retained: " + id)
		near(evolved.stamina, 42.0, "Stamina retained: " + id)
		check(evolved.evolutions == [id] and evolved.class_name_text == choice[1], "Evolution identity applied: " + id)
		check(evolved.can_guard() == expected[id][2], "Guard component matches class: " + id)
		var weapon_path = "Visual/WeaponPivot1/WeaponPivot2/" + expected[id][3]
		check(evolved.has_node(weapon_path), "Class-specific weapon node exists: " + id)
		if evolved.has_node(weapon_path):
			check(evolved.get_node(weapon_path).texture.resource_path == expected[id][1], "Class weapon sprite applied: " + id)
		check(evolved.get_node("AnimationPlayer").has_animation("swing"), "Class attack animation exists: " + id)
		var advanced = CrownCatalog.options_for(evolved, 13)
		check(not advanced.is_empty(), "Lv13 options still available after new evolution: " + id)
	# AI uses the same scene-replacement route.
	game.start_game()
	var ai_starter = game.fighters[1]
	ai_starter.level = 6
	var ai_index = game.fighters.find(ai_starter)
	var ai_evolved = CrownCatalog.evolve(ai_starter, new_choices[0])
	check(not ai_evolved.is_player and game.fighters[ai_index] == ai_evolved, "AI evolution updates fighter roster")

	# Class-specific combat regression checks, independent of evolution selection UI.
	for spec in [
		["swordsman", "검사"],
		["spearman", "창병"],
		["hammerman", "망치병"],
		["shieldbearer", "방패병"]
	]:
		game.start_game()
		var actor = game.player
		actor.level = 6
		var picked = CrownCatalog.EVOLUTIONS[6].filter(func(c): return c[0] == spec[0])[0]
		var damage_before_evolution: float = actor.damage
		actor = CrownCatalog.evolve(actor, picked)
		actor.stamina = actor.max_stamina
		actor.invuln = 0
		var victim = game.fighters[1]
		victim.position = actor.position + Vector2(40, 0)
		victim.invuln = 0
		if spec[0] == "swordsman":
			actor.attack()
			check(actor.basic_swing, "Sword normal swing starts before E")
			actor.cooldown.attack = 2.0
			actor.cooldown.e = 0
			actor.skill("e")
			check(actor.swing_active and not actor.basic_swing, "Sword E cancels basic swing into independent skill swing")
			actor.dash(Vector2.RIGHT)
			check(actor.dash_left <= 0.0 and actor.swing_active, "Dash does not cancel sword skill swing")
			near(actor.swing_power, 1.25, "Sword E swing deals 125%")
			near(actor.cooldown.attack, 2.0, "Sword E does not change normal attack cooldown")
			check(actor.cooldown.e > 0.0, "Sword E has separate skill cooldown")
			check(actor.guard != null and actor.guard.mode == "timed", "Sword retains original timed guard")
		elif spec[0] == "spearman":
			check(actor.attack_reach() >= 130.0, "Spear receives longer attack reach")
			check(actor.guard != null and actor.guard.mode == "simple", "Spear uses damage-reduction-only guard")
			actor.guard.phase = "hold"
			actor.guard.blocking = true
			var stamina_before_guard_hit = victim.stamina
			var hp_before_simple_guard = actor.hp
			game.deal_damage(actor, 20.0, victim)
			check(actor.hp < hp_before_simple_guard, "Simple spear guard reduces damage, not negates it")
			near(victim.stamina, stamina_before_guard_hit, "Spear guard does not punish attacking stamina")
			actor.guard.reset()
			actor.attack()
			actor.skill("e")
			check(not actor.swing_active, "Lunge cancels normal swing")
			check(actor.cooldown.e > 0.0 and actor.lunge_left > 0.0, "Spear E begins short damaging lunge")
			near(actor.dash_velocity.length(), 650.0, "Spear E lunge speed")
		elif spec[0] == "hammerman":
			actor.attack()
			check(actor.charging, "Hammer attack begins charge")
			actor.charge_time = 3.0
			actor.release_charge()
			near(actor.swing_power, 2.5, "Full hammer charge deals 250%")
			actor.cooldown.e = 0.0
			actor.hp = 40.0
			actor.skill("e")
			check(not actor.swing_active and actor.attack_lock <= 0.0, "Hammer heal cancels normal swing")
			near(actor.hp, 40.0 + actor.max_hp * 0.25, "Ironman restores 25% of max health")
		elif spec[0] == "shieldbearer":
			check(actor.guard != null and actor.guard.mode == "barrier", "Shield uses durability barrier guard")
			near(actor.damage, damage_before_evolution * 0.8, "Shieldbearer evolution lowers base attack by 20 percent")
			actor.facing = 0.0
			actor.armor = 0.0
			near(game.deal_damage(actor, 20.0, victim), 15.0, "Frontal hit receives passive shield reduction")
			near(game.deal_damage(actor, 20.0, victim, Vector2.UP), 20.0, "Side projectile bypasses passive shield reduction")
			near(game.deal_damage(actor, 20.0, victim, Vector2.LEFT), 20.0, "Rear projectile bypasses passive shield reduction")
			near(game.deal_damage(actor, 20.0, null), 20.0, "Directionless hazard bypasses passive shield reduction")
			actor.hp = actor.max_hp
			actor.guard.phase = "hold"
			actor.guard.blocking = true
			actor.stamina = 50.0
			var barrier_stamina = actor.stamina
			var barrier_hp = actor.hp
			victim.stamina = victim.max_stamina
			game.deal_damage(actor, 30.0, victim)
			near(victim.stamina, victim.max_stamina - game.balance.attack_stamina_cost * game.balance.blocked_attack_stamina_multiplier, "Barrier drains attacker stamina")
			near(actor.hp, barrier_hp, "Barrier negates incoming damage")
			near(actor.stamina, barrier_stamina, "Barrier consumes no stamina when hit")
			near(actor.guard.meter, 70.0, "Barrier meter loses incoming damage")
			check(victim.hitstun_left > 0.0 and actor.hitstun_left <= 0.0, "Successful guard staggers only attacker")
			actor.guard.requested = true
			actor.guard.tick(0.5)
			near(actor.stamina, barrier_stamina - game.balance.guard_drain_per_second * 0.25, "Barrier hold drains half the timed guard rate")
			game.deal_damage(actor, 70.0, victim)
			near(actor.hp, barrier_hp, "Hit that breaks the barrier is fully absorbed")
			check(not actor.guard.blocking, "Empty barrier lowers the shield")
			actor.guard.reset()
			actor.guard.requested = true
			actor.guard.tick(2.99)
			check(actor.guard.meter > 0.0 and actor.guard.phase == "idle", "Regenerated durability cannot bypass the break lock")
			actor.guard.tick(0.02)
			check(actor.guard.phase == "raise", "Barrier can raise again after three seconds")
			actor.guard.reset()
			var old_damage = actor.damage
			actor.skill("e")
			near(actor.useless_left, 6.0, "Useless buff activates")
			near(actor.damage, old_damage * 1.25, "Useless raises attack power by 25%")
			actor.attack_lock = 0.0
			actor.cooldown.attack = 0.0
			actor.attack()
			near(actor.swing_power, 1.0, "Useless does not double-count normal swing multiplier")
	game.start_game()
	p = game.player
	game.add_xp(p, 1000000)
	check(p.level == 25, "Level cap is 25")
	var evolution_levels: Array = [6] if game.choice_open else []
	# First open modal consumes a stat event; evolutions remain queued.
	for choice in game.choices:
		if choice.kind == "evolution": evolution_levels.append(choice.level)
	check(evolution_levels == [6, 13, 21], "Evolution thresholds 6 / 13 / 21")
	check(game.active(), "Pending evolution does not pause player or AI combat")
	check(game.ui.evolution_panel.visible, "Evolution appears on HUD instead of covering modal")
	check(not game.ui.modal.visible, "Evolution UI does not show fullscreen modal")
	check(game.ui.evolution_choice_count == 4, "Four options appear in top evolution row")
	game.ui.select_evolution(CrownCatalog.EVOLUTIONS[6][0])
	check(game.player.evolutions.has(CrownCatalog.EVOLUTIONS[6][0][0]), "Top-row selection actually evolves player")
	check(game.active(), "Choosing evolution preserves active combat")
	game.choices.clear()
	game.choice_open = false
	game.ui.modal.hide()
	game.ui.evolution_panel.hide()
	game.ui.show_game()
	# Restart to test all later tiers from a clean evolution chain.
	game.start_game()
	p = game.player
	for i in 24: p.grow_level()
	for level in [6, 13, 21]:
		p = CrownCatalog.evolve(p, CrownCatalog.EVOLUTIONS[level][0])
	check(p == game.player and p.evolutions.size() == 3, "Later evolutions retain the replaced player actor")
	check(not p.abilities.has("e") and p.abilities.has("r") and p.abilities.has("q"), "Existing Lv15/Lv25 skills remain available")
	p.skill("r")
	p.skill("q")
	check(p.cooldown.r > 0 and p.cooldown.q > 0, "Later evolution skills execute")
	check(game.get_node("Projectiles").get_child_count() == 0, "Skill input waits for animation event")
	p.ability_players.q.advance(0.201)
	await get_tree().process_frame
	check(game.get_node("Projectiles").get_child_count() == 12, "Lv25 skill animation event launches projectiles")
	p.resolve_skill_hit("q")
	check(game.get_node("Projectiles").get_child_count() == 12, "Repeated event cannot duplicate consumed cast")
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
	# Level growth is independent of the six investable stats.
	game.start_game()
	var investor = game.player
	check(investor.level == 1 and investor.stat_points == 1, "Lv1 starts with one investable point")
	game.ui.refresh_growth_panels()
	check(game.ui.stat_panel.visible and not game.ui.modal.visible, "Unspent points show inline without modal")
	check(game.ui.stat_rows.size() == 6, "Six stat upgrade rows exist in vertical HUD")
	check(investor.stat_allocations.size() == 6 and CrownBuilds.MAX_RANK == 8, "Six stats and eight ranks per stat")
	var base_attack = investor.damage
	var base_speed = investor.speed
	var base_stamina = investor.max_stamina
	var base_armor = investor.armor
	var base_haste = investor.attack_speed
	game.ui.invest_stat("health")
	check(investor.stat_allocations["health"] == 1, "Inline plus button path invests without pause")
	check(game.active() and not game.ui.stat_panel.visible, "Spending last point hides stat HUD and preserves combat")
	near(investor.max_hp, game.balance.starting_hp + 12, "HP investment adds 12")
	for i in 24: investor.grow_level()
	check(investor.level == 25 and investor.stat_points == 24, "Lv25 has 25 lifetime points")
	check(game.balance.xp_needed(24) < 500, "Last-level XP requirement reduced")
	for i in 7: check(CrownBuilds.invest(investor, "health"), "Can fill HP to rank 8")
	for i in 8: check(CrownBuilds.invest(investor, "damage"), "Can fill damage to rank 8")
	for i in 8: check(CrownBuilds.invest(investor, "speed"), "Can fill move speed to rank 8")
	check(investor.stat_points == 1, "Three completed rank-8 stats leave one point")
	check(not CrownBuilds.invest(investor, "damage"), "Cannot exceed rank 8")
	check(not CrownBuilds.invest(investor, "invalid"), "Unknown stats cannot consume points")
	check(CrownBuilds.invest(investor, "stamina"), "Final leftover point may buy stamina")
	near(investor.max_stamina, base_stamina + 8, "Stamina investment raises cap by 8")
	check(investor.stat_points == 0, "All 25 earned points may be spent")
	check(not CrownBuilds.invest(investor, "armor"), "Spent points cannot be reused")
	near(investor.damage, base_attack * pow(1.04, 8), "Eight damage ranks apply multiplicatively")
	near(investor.speed, base_speed * pow(1.03, 8), "Eight speed ranks apply multiplicatively")
	check(investor.armor == base_armor and investor.attack_speed == base_haste, "Uninvested stats stay at baseline")
	investor.grow_level()
	check(investor.level == 25 and investor.stat_points == 0, "No points beyond level cap")
	var profile_bot = game.fighters[1]
	check(CrownBuilds.PROFILES.has(profile_bot.ai_build), "Every AI is assigned a valid build style")
	check(profile_bot.stat_points == 0, "AI automatically spends its available points")
	var allocated: int = 0
	for rank in profile_bot.stat_allocations.values(): allocated += int(rank)
	check(allocated == profile_bot.level, "AI allocates one point per earned level")
	var profiles_distinct = {}
	for profile in ["assault", "defense", "charge"]:
		var bot = game.spawn_fighter(false)
		bot.ai_build = profile
		# Discard the initial random-style point only by leaving it invested;
		# successive choices should still follow the selected profile.
		for i in 11:
			bot.grow_level()
			CrownBuilds.allocate_ai(bot)
		profiles_distinct[profile] = bot.stat_allocations.duplicate(true)
	check(profiles_distinct["assault"] != profiles_distinct["defense"], "Assault and defense allocate differently")
	check(profiles_distinct["charge"] != profiles_distinct["defense"], "Charge and defense allocate differently")
	# Duel mode: only two equally leveled combatants, no XP or extra arena entities.
	game.start_duel("spearman", "shieldbearer")
	check(game.mode == "duel" and game.active(), "Duel becomes active")
	check(game.fighters.size() == 2 and game.monsters.is_empty(), "Duel spawns exactly two fighters without monsters")
	check(game.player != game.duel_enemy and not game.duel_enemy.is_player, "Duel assigns a human and an AI")
	check(game.player.class_name_text == "창병" and game.duel_enemy.class_name_text == "방패병", "Duel picks the requested classes")
	check(game.player.level == 6 and game.duel_enemy.level == 6, "Duel starts both at Lv6")
	near(game.player.max_hp, game.duel_enemy.max_hp, "Duel players have equal maximum HP")
	near(game.duel_enemy.damage, game.player.damage * 0.8, "Duel preserves shieldbearer attack penalty")
	near(game.duel_enemy.base_stats.damage, game.player.base_stats.damage * 0.8, "Boss normalization preserves shieldbearer base attack")
	near(game.player.stamina, game.duel_enemy.stamina, "Duel players start with equal stamina")
	check(game.get_node("Zones").visible == false, "Duel hides XP zones")
	var duel_xp_before: float = game.player.xp
	game.add_xp(game.player, 2500.0)
	near(game.player.xp, duel_xp_before, "Duel disables XP growth")
	var duel_kills_before: int = game.run_kills
	game.kill_target(game.duel_enemy, game.player)
	check(game.mode == "duel_result", "Duel ends as soon as opponent dies")
	check(game.run_kills == duel_kills_before, "Duel grants no normal run kills or gold")
	game.start_duel("hammerman", "swordsman")
	check(game.mode == "duel" and game.player.class_name_text == "망치병" and game.duel_enemy.class_name_text == "검사", "Duel rematch supports new class pair")
	game.return_menu()
	check(game.mode == "menu", "Duel can return to the main menu")
	game.start_game()
	check(game.mode == "play" and game.monsters.size() == 28, "Standard arena remains available after duel")
	game.mode = "menu"
	game.queue_free()
	await get_tree().process_frame
	print("IRON CROWN: %d assertions, %d failures" % [assertions, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
