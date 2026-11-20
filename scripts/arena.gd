extends Node2D

const FighterScene = preload("res://scenes/characters/base_knight.tscn")
const MonsterScene = preload("res://scenes/monster.tscn")
const ProjectileScene = preload("res://scenes/projectile.tscn")
@export var balance: CrownBalance = preload("res://data/balance.tres")
var player
var fighters: Array = []
var monsters: Array = []
var mode: String = "menu"
var paused: bool = false
var elapsed: float = 0
var boss_countdown: float = 300
var boss_timer: float = 0
var boss
var participants: Array = []
var snapshots: Array = []
var run_gold: int = 0
var run_kills: int = 0
var revives: int = 0
var choices: Array = []
var choice_open: bool = false
var touch_mode: bool = false
var touch_move: Vector2 = Vector2.ZERO
var touch_attack: bool = false
var touch_block: bool = false
var touch_run: bool = false
var effects: Array = []
var boss_finish_pending: bool = false
var duel_enemy
var duel_player_class: String = "swordsman"
var duel_enemy_class: String = "hammerman"
const DUEL_SIZE := Vector2(900, 540)
var sounds: Dictionary = {}
@onready var ui = $UI
@onready var camera = $Camera2D

func _ready() -> void:
	setup_input()
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	for key in ["swing", "hit", "heavy", "dash", "skill", "level", "death"]:
		sounds[key] = load("res://assets/%s.wav" % key)
	ui.arena = self
	ui.show_menu()

func setup_input() -> void:
	var keys = {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "run": KEY_SHIFT, "dash": KEY_SPACE, "e": KEY_E, "r": KEY_R, "q": KEY_Q, "pause": KEY_ESCAPE, "level_test": KEY_L, "boss_test": KEY_B}
	for key in keys:
		if not InputMap.has_action(key): InputMap.add_action(key)
		var event = InputEventKey.new()
		event.physical_keycode = keys[key]
		InputMap.action_add_event(key, event)
	for pair in [["attack", MOUSE_BUTTON_LEFT], ["block", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]): InputMap.add_action(pair[0])
		var event = InputEventMouseButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag: touch_mode = true
	if active() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		player.show_attack_range = not player.show_attack_range
		player.queue_redraw()
	if event.is_action_pressed("pause") and mode in ["play", "boss", "duel"] and not choice_open:
		paused = not paused
		ui.show_pause(paused)
	if active() and event.is_action_pressed("level_test") and mode == "play": add_xp(player, balance.xp_needed(player.level) - player.xp + 1)
	if active() and event.is_action_pressed("boss_test"): start_boss(true)

func active() -> bool:
	return mode in ["play", "boss", "duel"] and not paused and not choice_open

func start_game(boost: bool = false) -> void:
	$Zones.show()
	duel_enemy = null
	for node in $Actors.get_children():
		$Actors.remove_child(node)
		node.queue_free()
	clear_projectiles()
	fighters.clear()
	monsters.clear()
	choices.clear()
	effects.clear()
	mode = "play"
	paused = false
	choice_open = false
	elapsed = 0
	boss_countdown = balance.boss_interval
	run_gold = 0
	run_kills = 0
	revives = 0
	boss = null
	player = spawn_fighter(true)
	player.position = balance.world_size / 2
	for i in balance.bot_count:
		var bot = spawn_fighter(false)
		for j in randi_range(0, 4): advance_bot(bot)
		bot.hp = bot.max_hp
	for i in balance.monster_count:
		var monster = MonsterScene.instantiate()
		monster.arena = self
		monster.position = random_position()
		monster.brute = randf() < 0.25
		$Actors.add_child(monster)
		monsters.append(monster)
	if boost and Meta.boosts > 0:
		Meta.boosts -= 1
		for i in 4:
			player.grow_level()
			CrownCatalog.apply_stat(player, CrownCatalog.STATS.pick_random()[0])
		choices.append({"kind": "evolution", "level": 5})
		player.hp = player.max_hp
		Meta.save_data()
	camera.position = player.position
	ui.show_game()
	ui.notice("전장 입장", "살아남아 왕관을 차지하세요")
	process_choices()

## Replace the actor node so evolution applies its authored weapon, animation,
## collision setup and optional Guard component, not only its stats.
## Keep player/AI references and accumulated combat state.
func replace_fighter_scene(old_f, definition: CrownCharacterDefinition):
	if definition.evolution_scene == null: return old_f
	var replacement = definition.evolution_scene.instantiate()
	replacement.arena = self
	replacement.definition = definition
	replacement.is_player = old_f.is_player
	replacement.display_name = old_f.display_name
	replacement.tint = old_f.tint
	replacement.position = old_f.position
	$Actors.add_child(replacement)
	# Initialization in _ready() uses the new scene's correct animations and Guard.
	# Restore run progress after the new actor's initial setup.
	var state_keys = [
		"position", "velocity", "level", "xp", "max_hp", "hp", "armor",
		"damage", "speed", "attack_speed", "crit", "lifesteal", "skill_power",
		"xp_gain", "gold_bonus", "dash_mult", "block_reduction", "body_scale",
		"radius", "alive", "kills", "boss_flag", "boss_damage", "boss_kills",
		"invuln", "stamina", "max_stamina", "exhaustion_left",
		"damage_contributors", "combat_left", "no_hit_time", "groggy_left",
		"groggy", "groggy_decay_left", "groggy_immunity", "dash_left",
		"dash_velocity", "facing", "evolutions", "class_name_text",
		"cooldown", "base_stats", "ai_target", "ai_retarget", "ai_block",
		"respawn_timer", "attack_lock", "swing_power", "show_attack_range"
	]
	for key in state_keys:
		var value = old_f.get(key)
		replacement.set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	# Retain previously unlocked skills when a later evolution changes the model.
	for slot in old_f.abilities:
		replacement.equip_ability(slot, old_f.abilities[slot])
	# Future projectile, targeting and ranking queries must refer to the new node.
	var index = fighters.find(old_f)
	if index >= 0: fighters[index] = replacement
	if player == old_f: player = replacement
	if boss == old_f: boss = replacement
	for i in participants.size():
		if participants[i] == old_f: participants[i] = replacement
	for entry in snapshots:
		if entry.fighter == old_f: entry.fighter = replacement
	for actor in fighters:
		if actor.ai_target == old_f: actor.ai_target = replacement
		# Preserve recent kill-contribution records across a change of actor node.
		if actor.damage_contributors.has(old_f.get_instance_id()):
			var last_hit = actor.damage_contributors[old_f.get_instance_id()]
			actor.damage_contributors.erase(old_f.get_instance_id())
			actor.damage_contributors[replacement.get_instance_id()] = last_hit
	for projectile in $Projectiles.get_children():
		if projectile.source == old_f: projectile.source = replacement
	for meta_name in old_f.get_meta_list():
		replacement.set_meta(meta_name, old_f.get_meta(meta_name))
	old_f.set_meta("evolution_replacement", replacement)
	old_f.hide()
	old_f.queue_free()
	replacement.update_visual()
	return replacement

func spawn_fighter(human: bool):
	var f = FighterScene.instantiate()
	f.arena = self
	f.is_player = human
	f.display_name = Meta.player_name if human else ["회색 늑대", "청동 방패", "별 없는 밤", "랜스롯", "참새 기사", "붉은 장미", "철갑 상어", "달빛 검객", "까마귀", "북풍"].pick_random()
	f.tint = Color("f4bf59") if human else [Color("66b8de"), Color("dc7589"), Color("a899de"), Color("69c7ab")].pick_random()
	f.position = random_position()
	$Actors.add_child(f)
	fighters.append(f)
	return f

## A self-contained, equal-level fight without XP, monsters, zones or boss events.
func start_duel(player_class: String = "swordsman", enemy_class: String = "hammerman") -> void:
	if CrownCatalog.ROSTER.find(player_class) == null or CrownCatalog.ROSTER.find(enemy_class) == null: return
	duel_player_class = player_class
	duel_enemy_class = enemy_class
	for actor in $Actors.get_children():
		$Actors.remove_child(actor)
		actor.queue_free()
	clear_projectiles()
	fighters.clear()
	monsters.clear()
	choices.clear()
	effects.clear()
	mode = "duel"
	paused = false
	choice_open = false
	elapsed = 0.0
	run_kills = 0
	boss = null
	duel_enemy = null
	$Zones.hide()
	player = spawn_fighter(true)
	duel_enemy = spawn_fighter(false)
	# A player can own persistent runes; normalize before evolution for fair testing.
	for key in duel_enemy.base_stats:
		player.set(key, duel_enemy.base_stats[key])
	player.base_stats = duel_enemy.base_stats.duplicate(true)
	var center: Vector2 = balance.world_size / 2.0
	player.position = center + Vector2(-180, 0)
	duel_enemy.position = center + Vector2(180, 0)
	player.facing = 0.0
	duel_enemy.facing = PI
	for fighter in fighters:
		for i in 4: fighter.grow_level()
		fighter.hp = fighter.max_hp
		fighter.stamina = fighter.max_stamina
		fighter.xp = 0.0
		fighter.invuln = 0.0
		fighter.cooldown = {"attack": 0.0, "dash": 0.0, "e": 0.0, "r": 0.0, "q": 0.0}
	player = CrownCatalog.evolve(player, [player_class])
	duel_enemy = CrownCatalog.evolve(duel_enemy, [enemy_class])
	player.display_name = "플레이어"
	duel_enemy.display_name = "AI 상대"
	player.update_visual()
	duel_enemy.update_visual()
	camera.position = center
	ui.show_game()
	ui.notice("1대1 실전 테스트", "%s VS %s" % [player.class_name_text, duel_enemy.class_name_text])

func random_position() -> Vector2:
	return Vector2(randf_range(100, balance.world_size.x - 100), randf_range(100, balance.world_size.y - 100))

func bounds() -> Rect2:
	return Rect2(balance.world_size / 2.0 - DUEL_SIZE / 2.0, DUEL_SIZE) if mode == "duel" else (Rect2(500, 250, 2200, 1700) if mode == "boss" else Rect2(Vector2.ZERO, balance.world_size))

func _physics_process(dt: float) -> void:
	if active():
		elapsed += dt
		if mode == "play":
			boss_countdown -= dt
			if boss_countdown <= 0: start_boss()
		elif mode == "boss":
			boss_timer -= dt
			if boss_timer <= 0: finish_boss(false)
		if not active(): return
		for f in fighters.duplicate():
			if not active(): break
			if f.alive: f.tick(dt)
			elif not f.is_player and mode == "play":
				f.respawn_timer -= dt
				if f.respawn_timer <= 0:
					fighters.erase(f)
					f.queue_free()
					spawn_fighter(false)
		if mode == "play" and active():
			for m in monsters: m.tick(dt)
			for f in fighters:
				if not f.alive: continue
				for zone in $Zones.get_children():
					if f.position.distance_to(zone.position) < zone.radius: add_xp(f, zone.experience_per_second * dt)
		if active():
			for p in $Projectiles.get_children():
				if not p.is_queued_for_deletion(): p.tick(dt)
		if boss_finish_pending:
			boss_finish_pending = false
			finish_boss(true)
	for fx in effects: fx.life -= dt
	effects = effects.filter(func(fx): return fx.life > 0)
	if is_instance_valid(player):
		var focus = player if player.alive or boss == null else boss
		camera.position = camera.position.lerp(balance.world_size / 2.0 if mode == "duel" else focus.position, 1 - exp(-8 * dt))
	ui.update_hud()
	queue_redraw()

func valid_target(source, target) -> bool:
	if not is_instance_valid(target) or not target.alive or target == source: return false
	if mode == "boss":
		if not target is CrownFighter or not participants.has(target): return false
		return target != boss if source == boss else target == boss
	return true

func targets(source) -> Array:
	var result = fighters.filter(func(f): return valid_target(source, f))
	if mode == "play": result.append_array(monsters.filter(func(m): return m.alive))
	return result

func nearest_target(source, distance: float):
	var best = null
	for target in targets(source):
		var d = source.position.distance_to(target.position)
		if d < distance:
			distance = d
			best = target
	return best

func nearest_fighter(at: Vector2, distance: float):
	var best = null
	for f in fighters:
		if f.alive and at.distance_to(f.position) < distance:
			distance = at.distance_to(f.position)
			best = f
	return best

func deal_damage(target, amount: float, source) -> float:
	if not target.alive or target.invuln > 0: return 0
	if target is CrownFighter: target.no_hit_time = 0
	if source is CrownFighter: source.no_hit_time = 0
	var duel = target is CrownFighter and source is CrownFighter
	if duel:
		target.combat_left = balance.combat_duration
		source.combat_left = balance.combat_duration
	var shield_reduction = -1.0
	if target is CrownFighter and target.guard != null:
		shield_reduction = target.guard.receive_hit(source, amount)
	var was_blocking = shield_reduction >= 0.0
	# Barrier guard negates a hit completely: no HP, groggy, lifesteal or XP.
	if shield_reduction >= 1.0:
		float_text(target.position, "방어!", Color("80cffa"))
		return 0.0
	var reduction = target.armor / (100.0 + target.armor)
	if was_blocking:
		reduction = 1 - (1 - reduction) * (1 - shield_reduction)
	var final = maxf(1, amount * (1 - reduction))
	if duel:
		# A fully absorbed shield hit is not a damage contribution.
		target.damage_contributors[source.get_instance_id()] = elapsed
	target.hp -= final
	if target is CrownFighter and target.hp > 0 and not was_blocking:
		target.add_groggy(balance.groggy_hit)
	if source is CrownFighter:
		source.hp = minf(source.max_hp, source.hp + final * source.lifesteal)
		add_xp(source, minf(2, final * 0.028))
		if mode == "boss" and target == boss: source.boss_damage += final
	float_text(target.position, str(roundi(final)), Color("f6d8da"))
	if source == player or target == player: sound("hit", player)
	if target.hp <= 0: kill_target(target, source)
	return final

func recent_contributor_count(victim) -> int:
	if not victim is CrownFighter: return 1
	var count = 0
	for timestamp in victim.damage_contributors.values():
		if elapsed - float(timestamp) <= balance.combat_duration: count += 1
	return maxi(1, count)

func kill_target(target, killer) -> void:
	if not target.alive: return
	target.hp = 0
	target.alive = false
	target.hide()
	target.respawn_timer = randf_range(5, 9)
	fx_ring(target.position, 70, Color("ff627f"), 0.5)
	if not target is CrownFighter:
		target.respawn_timer = randf_range(8, 14)
		if killer is CrownFighter: add_xp(killer, 48 if target.brute else 28)
		return
	if mode == "duel":
		mode = "duel_result"
		paused = true
		ui.show_duel_result(target != player, player.class_name_text, duel_enemy.class_name_text, elapsed)
		return
	if mode == "boss":
		if target == boss: boss_finish_pending = true
		elif killer == boss:
			boss.boss_kills += 1
			if participants.filter(func(f): return f != boss and f.alive).is_empty(): finish_boss(false)
		return
	if killer is CrownFighter:
		var contributor_count = recent_contributor_count(target)
		killer.kills += 1
		add_xp(killer, 110 + target.level * 25)
		# XP can evolve an AI on the killing hit; reward its replacement.
		if killer.has_meta("evolution_replacement"):
			killer = killer.get_meta("evolution_replacement")
		if contributor_count == 1:
			killer.hp = killer.max_hp
		else:
			killer.hp = minf(killer.max_hp, killer.hp + killer.max_hp / contributor_count)
		killer.combat_left = 0
		killer.reset_groggy()
		killer.stamina = killer.max_stamina
		killer.exhaustion_left = 0.0
		float_text(killer.position, "완전 회복!" if contributor_count == 1 else "체력 회복 (기여자 %d명)" % contributor_count, Color("7be2b0"))
		if killer.is_player:
			run_kills += 1
			run_gold += roundi((70 + target.level * 20) * killer.gold_bonus)
		ui.feed("%s → %s" % [killer.display_name, target.display_name])
	if target is CrownFighter: target.damage_contributors.clear()
	if target == player:
		mode = "gameover"
		choice_open = false
		bank_gold()
		ui.show_gameover()

func area_attack(source, radius: float, power: float) -> void:
	fx_ring(source.position, radius, source.attack_color(), 0.4)
	for target in targets(source):
		if source.position.distance_to(target.position) < radius + target.radius: deal_damage(target, power, source)

func shoot(source, angle: float, speed: float, power: float, life: float, pierce: int = 1) -> void:
	var p = ProjectileScene.instantiate()
	p.source = source
	p.arena = self
	p.position = source.position + Vector2.from_angle(angle) * 35
	p.velocity = Vector2.from_angle(angle) * speed
	p.damage = power
	p.lifetime = life
	p.pierce = pierce
	p.tint = source.attack_color()
	$Projectiles.add_child(p)

func clear_projectiles() -> void:
	for p in $Projectiles.get_children():
		$Projectiles.remove_child(p)
		p.queue_free()

func add_xp(f, amount: float) -> void:
	if not f.alive or mode != "play" or f.level >= balance.max_level: return
	f.xp += amount * f.xp_gain
	while f.level < balance.max_level and f.xp >= balance.xp_needed(f.level):
		f.xp -= balance.xp_needed(f.level)
		f.grow_level()
		if f.is_player:
			run_gold += roundi((28 + f.level * 5) * f.gold_bonus)
			if not CrownCatalog.options_for(f, f.level).is_empty(): choices.append({"kind": "evolution", "level": f.level})
			choices.append({"kind": "stat", "level": f.level})
			sound("level", f)
		else:
			CrownCatalog.apply_stat(f, CrownCatalog.STATS.pick_random()[0])
			if not CrownCatalog.options_for(f, f.level).is_empty(): f = CrownCatalog.evolve(f, CrownCatalog.options_for(f, f.level).pick_random())
	if f.is_player: process_choices()

func advance_bot(f):
	f.grow_level()
	CrownCatalog.apply_stat(f, CrownCatalog.STATS.pick_random()[0])
	if not CrownCatalog.options_for(f, f.level).is_empty(): f = CrownCatalog.evolve(f, CrownCatalog.options_for(f, f.level).pick_random())
	return f

func process_choices() -> void:
	if choices.is_empty() or choice_open or paused or not is_instance_valid(player) or not player.alive: return
	choice_open = true
	ui.show_choices(choices.pop_front())

func start_boss(manual: bool = false) -> void:
	if mode != "play" or choice_open or paused: return
	participants = fighters.filter(func(f): return f.alive and f.level >= 10)
	if manual and player.level >= 10 and participants.size() < 2:
		for f in fighters:
			if f != player and f.alive:
				var contender = f
				while contender.level < 10: contender = advance_bot(contender)
				participants.append(contender)
				break
	if participants.size() < 2:
		boss_countdown = 60
		ui.notice("보스전 대기", "Lv.10 이상 기사 2명이 필요합니다")
		return
	snapshots.clear()
	for f in fighters:
		var values = f.snapshot_stats()
		for key in ["position", "hp", "stamina", "exhaustion_left", "damage_contributors", "attack_lock", "groggy", "groggy_decay_left", "groggy_immunity", "alive", "invuln", "combat_left", "no_hit_time", "groggy_left", "dash_left", "dash_velocity", "cooldown"]: values[key] = f.get(key).duplicate() if key in ["cooldown", "damage_contributors"] else f.get(key)
		snapshots.append({"fighter": f, "values": values})
		if not participants.has(f):
			f.alive = false
			f.hide()
			continue
		for key in f.base_stats:
			if key != "body_scale": f.set(key, f.base_stats[key] + (f.get(key) - f.base_stats[key]) * 0.1)
		f.hp = f.max_hp
		f.combat_left = 0
		f.reset_groggy()
		f.reset_guard()
		f.exhaustion_left = 0.0
		f.damage_contributors.clear()
		f.invuln = 1
		f.boss_damage = 0
		f.boss_kills = 0
	boss = participants.pick_random()
	var original = snapshots.filter(func(s): return s.fighter == boss)[0].values
	boss.boss_flag = true
	boss.max_hp = original.max_hp * (1 + (participants.size() - 1) * 0.7)
	boss.hp = boss.max_hp
	boss.damage = original.damage * 4
	boss.attack_speed = original.attack_speed * 0.55
	boss.body_scale = original.body_scale * 1.62
	for i in participants.size():
		participants[i].position = balance.world_size / 2 + Vector2.from_angle(i * TAU / participants.size()) * 550
	boss.position = balance.world_size / 2
	mode = "boss"
	boss_timer = balance.boss_duration
	clear_projectiles()
	for m in monsters: m.hide()
	$Zones.hide()
	ui.notice("왕관의 폭주", "%s 님이 보스입니다" % boss.display_name)

func finish_boss(victory: bool) -> void:
	if mode != "boss": return
	var reward = 0
	if participants.has(player):
		if player == boss: reward = roundi(300000.0 * boss.boss_kills / participants.size())
		elif victory: reward = roundi(100000.0 * participants.size() * minf(1, player.boss_damage / boss.max_hp))
	run_gold += reward
	for s in snapshots:
		for key in s.values: s.fighter.set(key, s.values[key].duplicate() if key in ["cooldown", "damage_contributors"] else s.values[key])
		s.fighter.reset_guard()
		s.fighter.boss_flag = false
		s.fighter.visible = s.fighter.alive
	clear_projectiles()
	for m in monsters: m.visible = m.alive
	$Zones.show()
	boss = null
	mode = "play"
	boss_countdown = balance.boss_interval
	paused = true
	ui.show_result("도전자 승리" if victory else "보스 생존", "보상 %s 골드\n전장 복구 완료" % reward)

func bank_gold() -> void:
	Meta.gold += run_gold
	run_gold = 0
	Meta.save_data()

func revive() -> void:
	if mode != "gameover" or revives >= 3: return
	var cost = [800, 1800, 4000][revives]
	if Meta.gold < cost: return
	Meta.gold -= cost
	Meta.save_data()
	revives += 1
	player.alive = true
	player.show()
	player.hp = player.max_hp
	player.reset_groggy()
	player.reset_guard()
	player.stamina = player.max_stamina
	player.exhaustion_left = 0.0
	player.damage_contributors.clear()
	player.invuln = 3
	player.position = balance.world_size / 2
	mode = "play"
	ui.show_game()
	process_choices()

func return_menu() -> void:
	if mode not in ["duel", "duel_result"]: bank_gold()
	duel_enemy = null
	$Zones.show()
	mode = "menu"
	paused = false
	choice_open = false
	ui.show_menu()

func sound(key: String, source) -> void:
	if Meta.muted or not sounds.has(key): return
	if source != player and randf() > 0.12: return
	if key == "hit" and Meta.rune_level("echo") > 0: key = "heavy"
	var audio = AudioStreamPlayer.new()
	audio.stream = sounds[key]
	audio.volume_db = -18 if source == player else -30
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func float_text(at: Vector2, text: String, color: Color) -> void:
	effects.append({"type": "text", "at": at, "text": text, "color": color, "life": 1.2, "max": 1.2})

func fx_ring(at: Vector2, radius: float, color: Color, life: float) -> void:
	effects.append({"type": "ring", "at": at, "radius": radius, "color": color, "life": life, "max": life})

func _draw() -> void:
	var rect = bounds()
	draw_rect(rect, Color("1d1420") if mode == "boss" else Color("12232d"))
	for x in range(0, int(balance.world_size.x), 80): draw_line(Vector2(x, 0), Vector2(x, balance.world_size.y), Color(0.3, 0.5, 0.6, 0.07))
	for y in range(0, int(balance.world_size.y), 80): draw_line(Vector2(0, y), Vector2(balance.world_size.x, y), Color(0.3, 0.5, 0.6, 0.07))
	draw_rect(rect, Color("81506b") if mode == "boss" else Color("425769"), false, 5)
	for fx in effects:
		var color = Color(fx.color, fx.life / fx.max)
		if fx.type == "ring": draw_arc(fx.at, fx.radius * (1.1 - fx.life / fx.max * 0.3), 0, TAU, 32, color, 3)
		else: draw_string(ui.font, fx.at + Vector2(-22, -50 - (1 - fx.life / fx.max) * 30), fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
