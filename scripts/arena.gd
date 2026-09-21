extends Node2D

const FighterScene = preload("res://scenes/fighter.tscn")
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
	if event.is_action_pressed("pause") and mode in ["play", "boss"] and not choice_open:
		paused = not paused
		ui.show_pause(paused)
	if active() and event.is_action_pressed("level_test") and mode == "play": add_xp(player, balance.xp_needed(player.level) - player.xp + 1)
	if active() and event.is_action_pressed("boss_test"): start_boss(true)

func active() -> bool:
	return mode in ["play", "boss"] and not paused and not choice_open

func start_game(boost: bool = false) -> void:
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

func random_position() -> Vector2:
	return Vector2(randf_range(100, balance.world_size.x - 100), randf_range(100, balance.world_size.y - 100))

func bounds() -> Rect2:
	return Rect2(500, 250, 2200, 1700) if mode == "boss" else Rect2(Vector2.ZERO, balance.world_size)

func _physics_process(dt: float) -> void:
	if active():
		elapsed += dt
		if mode == "play":
			boss_countdown -= dt
			if boss_countdown <= 0: start_boss()
		else:
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
		camera.position = camera.position.lerp(focus.position, 1 - exp(-8 * dt))
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
	var reduction = target.armor / (100.0 + target.armor)
	if target is CrownFighter and target.blocking and target.stamina > 0:
		reduction = 1 - (1 - reduction) * (1 - target.block_reduction)
		if duel:
			target.stamina = maxf(0, target.stamina - balance.block_cost)
			source.stamina = maxf(0, source.stamina - balance.blocked_cost)
			source.exhaust_if_empty()
			target.exhaust_if_empty()
		fx_ring(target.position, 45, Color("91dfff"), 0.2)
	var final = maxf(1, amount * (1 - reduction))
	target.hp -= final
	if source is CrownFighter:
		source.hp = minf(source.max_hp, source.hp + final * source.lifesteal)
		add_xp(source, minf(2, final * 0.028))
		if mode == "boss" and target == boss: source.boss_damage += final
	float_text(target.position, str(roundi(final)), Color("f6d8da"))
	if source == player or target == player: sound("hit", player)
	if target.hp <= 0: kill_target(target, source)
	return final

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
	if mode == "boss":
		if target == boss: boss_finish_pending = true
		elif killer == boss:
			boss.boss_kills += 1
			if participants.filter(func(f): return f != boss and f.alive).is_empty(): finish_boss(false)
		return
	if killer is CrownFighter:
		killer.kills += 1
		add_xp(killer, 110 + target.level * 25)
		killer.hp = killer.max_hp
		killer.stamina = killer.max_stamina
		killer.combat_left = 0
		killer.exhausted = 0
		float_text(killer.position, "완전 회복!", Color("7be2b0"))
		if killer.is_player:
			run_kills += 1
			run_gold += roundi((70 + target.level * 20) * killer.gold_bonus)
		ui.feed("%s → %s" % [killer.display_name, target.display_name])
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
			if CrownCatalog.EVOLUTIONS.has(f.level): choices.append({"kind": "evolution", "level": f.level})
			choices.append({"kind": "stat", "level": f.level})
			sound("level", f)
		else:
			CrownCatalog.apply_stat(f, CrownCatalog.STATS.pick_random()[0])
			if CrownCatalog.EVOLUTIONS.has(f.level): CrownCatalog.evolve(f, CrownCatalog.EVOLUTIONS[f.level].pick_random())
	if f.is_player: process_choices()

func advance_bot(f) -> void:
	f.grow_level()
	CrownCatalog.apply_stat(f, CrownCatalog.STATS.pick_random()[0])
	if CrownCatalog.EVOLUTIONS.has(f.level): CrownCatalog.evolve(f, CrownCatalog.EVOLUTIONS[f.level].pick_random())

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
				while f.level < 10: advance_bot(f)
				participants.append(f)
				break
	if participants.size() < 2:
		boss_countdown = 60
		ui.notice("보스전 대기", "Lv.10 이상 기사 2명이 필요합니다")
		return
	snapshots.clear()
	for f in fighters:
		var values = f.snapshot_stats()
		for key in ["position", "hp", "stamina", "alive", "invuln", "combat_left", "no_hit_time", "exhausted", "dash_left", "blocking", "dash_velocity", "cooldown"]: values[key] = f.get(key).duplicate() if key == "cooldown" else f.get(key)
		snapshots.append({"fighter": f, "values": values})
		if not participants.has(f):
			f.alive = false
			f.hide()
			continue
		for key in f.base_stats:
			if key != "body_scale": f.set(key, f.base_stats[key] + (f.get(key) - f.base_stats[key]) * 0.1)
		f.hp = f.max_hp
		f.stamina = f.max_stamina
		f.combat_left = 0
		f.exhausted = 0
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
		for key in s.values: s.fighter.set(key, s.values[key])
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
	player.stamina = player.max_stamina
	player.exhausted = 0
	player.invuln = 3
	player.position = balance.world_size / 2
	mode = "play"
	ui.show_game()
	process_choices()

func return_menu() -> void:
	bank_gold()
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
