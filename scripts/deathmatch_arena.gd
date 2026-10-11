extends "res://scripts/arena.gd"

# TEST1-only single-player simulation: the same weapons and evolution tree,
# but a timed score match against nine growing AI knights (no networking).
const Rules = preload("res://scripts/deathmatch_rules.gd")
const XpBox = preload("res://scripts/xp_box.gd")

var round_remaining: float = Rules.DURATION
var boxes: Array = []
var replenish_left: float = 0.0

func _ready() -> void:
	super._ready()
	start_game()

func is_deathmatch() -> bool:
	return true

func start_game(_boost: bool = false) -> void:
	super.start_game(false)
	round_remaining = Rules.DURATION
	replenish_left = 0.0
	boxes.clear()
	boss_countdown = Rules.DURATION + 9999.0
	# Discard normal survival mode's pre-leveled bots and monsters.
	for f in fighters.slice(1):
		$Actors.remove_child(f)
		f.queue_free()
	fighters = [player]
	for m in monsters:
		$Actors.remove_child(m)
		m.queue_free()
	monsters.clear()
	for zone in $Zones.get_children():
		zone.experience_per_second = 0.0
		zone.hide()
	for i in (Rules.POPULATION - 1):
		spawn_fighter(false)
	for f in fighters:
		f.set_meta("dm_score", 0)
		f.set_meta("dm_deaths", 0)
		f.set_meta("dm_peak", 1)
	for i in Rules.BOX_LIMIT: spawn_box()
	player.position = balance.world_size * 0.5
	camera.position = player.position
	ui.notice("데스매치 · 8분", "경험치 결정을 모으고 AI 기사와 싸워 높은 점수를 얻으세요")
	update_match_hud()

func start_boss(_manual: bool = false) -> void:
	pass

func bank_gold() -> void:
	# TEST1 match scores do not modify the existing persistent wallet.
	pass

func return_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func spawn_box() -> void:
	if boxes.size() >= Rules.BOX_LIMIT: return
	var box = XpBox.new()
	box.value = [24.0, 35.0, 50.0, 75.0].pick_random()
	box.position = random_position()
	$Actors.add_child(box)
	boxes.append(box)

func nearest_xp_box(at: Vector2, distance: float):
	var nearest = null
	for box in boxes:
		var d: float = at.distance_to(box.position)
		if d < distance:
			nearest = box
			distance = d
	return nearest

# Called by the shared fighter AI before its ordinary attack behavior.
# Close enemies take priority; otherwise bots seek nearby XP boxes and level up.
func ai_pickup_control(f) -> bool:
	if f.level >= balance.max_level or nearest_target(f, 230.0) != null: return false
	var box = nearest_xp_box(f.position, 900.0)
	if box == null: return false
	var offset: Vector2 = box.position - f.position
	f.facing = offset.angle()
	f.velocity = offset.normalized() * f.speed
	return true

func add_match_points(f, amount: int) -> void:
	f.set_meta("dm_score", int(f.get_meta("dm_score", 0)) + amount)

func match_points(f) -> int:
	return int(f.get_meta("dm_score", 0))

func ranking() -> Array:
	var result: Array = fighters.duplicate()
	result.sort_custom(func(a, b):
		return match_points(a) > match_points(b) if match_points(a) != match_points(b) else a.kills > b.kills)
	return result

func add_xp(f, amount: float) -> void:
	if not f.alive or mode != "play": return
	add_match_points(f, maxi(1, roundi(amount * Rules.XP_POINTS)))
	if f.level >= balance.max_level: return
	f.xp += amount * f.xp_gain
	while f.level < balance.max_level and f.xp >= balance.xp_needed(f.level):
		f.xp -= balance.xp_needed(f.level)
		f.grow_level()
		# Prevent infinite stat farming when re-earning levels lost on death.
		if f.level <= int(f.get_meta("dm_peak", 1)): continue
		f.set_meta("dm_peak", f.level)
		if f.level % 3 == 0:
			CrownCatalog.apply_stat(f, CrownCatalog.STATS.pick_random()[0])
		if f.is_player:
			if f.level in [5, 15, 25]:
				choices.append({"kind": "evolution", "level": f.level})
			elif f.level in [10, 20, 30, 40]:
				choices.append({"kind": "stat", "level": f.level})
			sound("level", f)
		elif f.level in [5, 15, 25]:
			var available: Array = CrownTest1Rules.options_for(f, f.level)
			if not available.is_empty():
				CrownTest1Rules.evolve(f, available.pick_random())
	if f.is_player: process_choices()

func kill_target(target, killer) -> void:
	if not target.alive: return
	target.hp = 0
	target.alive = false
	target.hide()
	fx_ring(target.position, 70, Color("ff627f"), 0.5)
	if not target is CrownFighter: return
	target.respawn_timer = 999999.0 # Override inherited AI-replacement rule.
	target.set_meta("dm_respawn", Rules.RESPAWN_TIME)
	target.set_meta("dm_deaths", int(target.get_meta("dm_deaths", 0)) + 1)
	Rules.penalize(target, balance)
	if killer is CrownFighter and killer != target:
		killer.kills += 1
		add_match_points(killer, Rules.KILL_POINTS)
		add_xp(killer, 95.0 + target.level * 12.0)
		killer.hp = killer.max_hp
		killer.stamina = killer.max_stamina
		killer.exhausted = 0
		killer.combat_left = 0
		if killer == player: run_kills += 1
		ui.feed("%s → %s · +100점" % [killer.display_name, target.display_name])
	if target == player:
		ui.notice("사망 · 3초 뒤 부활", "진화 유지 / 최근 진화 이후 경험치 20% 손실")

func respawn(f) -> void:
	var location: Vector2 = random_position()
	var safety: float = -1.0
	for i in 12:
		var sample: Vector2 = random_position()
		var closest: float = 99999999.0
		for other in fighters:
			if other != f and other.alive:
				closest = minf(closest, sample.distance_squared_to(other.position))
		if closest > safety:
			safety = closest
			location = sample
	f.position = location
	f.alive = true
	f.hp = f.max_hp
	f.stamina = f.max_stamina
	f.invuln = 2.0
	f.exhausted = 0
	f.stagger_left = 0
	f.posture = 0
	f.blocking = false
	f.previous_block = false
	f.attack_pending = false
	f.combat_left = 0
	f.no_hit_time = 0
	f.dash_left = 0
	f.ai_target = null
	f.show()
	if f == player:
		ui.notice("부활!", "레벨과 진화는 유지되지만 일부 XP를 잃었습니다")
		process_choices()

func collect_boxes(dt: float) -> void:
	for box in boxes.duplicate():
		for f in fighters:
			if f.alive and f.position.distance_squared_to(box.position) < 1700.0:
				add_xp(f, box.value)
				fx_ring(box.position, 23, Color("8cecf5"), 0.18)
				boxes.erase(box)
				box.queue_free()
				break
	replenish_left -= dt
	if replenish_left <= 0 and boxes.size() < Rules.BOX_LIMIT:
		spawn_box()
		replenish_left = 0.33

func _physics_process(dt: float) -> void:
	if active():
		round_remaining -= dt
		if round_remaining <= 0:
			end_round()
			return
	super._physics_process(dt)
	if not active(): return
	collect_boxes(dt)
	for f in fighters:
		if f.alive: continue
		var remaining: float = float(f.get_meta("dm_respawn", Rules.RESPAWN_TIME)) - dt
		f.set_meta("dm_respawn", remaining)
		if remaining <= 0: respawn(f)
	update_match_hud()

func update_match_hud() -> void:
	var hud = ui.hud
	hud.get_node("Boss").text = "DEATHMATCH / 남은 시간\n%s" % ui.time_text(round_remaining)
	var leaders: Array = ranking()
	var lines: String = "DEATHMATCH SCORE\n"
	for f in leaders.slice(0, 5):
		lines += "%s · %d점 · %d킬\n" % [f.display_name, match_points(f), f.kills]
	hud.get_node("Leaderboard").text = lines
	hud.get_node("Info/Stats").text = "HP %d/%d · ST %d/%d\n점수 %d · 처치 %d · 사망 %d\n자세 %d/100" % [ceili(player.hp), roundi(player.max_hp), ceili(player.stamina), roundi(player.max_stamina), match_points(player), player.kills, int(player.get_meta("dm_deaths", 0)), roundi(player.posture)]

func end_round() -> void:
	if mode != "play": return
	round_remaining = 0.0
	mode = "matchover"
	paused = false
	choice_open = false
	choices.clear()
	var leaders: Array = ranking()
	var my_rank: int = leaders.find(player) + 1
	var description: String = "내 기록: %d점 / %d킬 / %d데스\n" % [match_points(player), player.kills, int(player.get_meta("dm_deaths", 0))]
	for i in mini(5, leaders.size()):
		var f = leaders[i]
		description += "%d위 · %s · %d점 · %d킬\n" % [i + 1, f.display_name, match_points(f), f.kills]
	ui.clear_modal("8분 경기 종료 · %d위" % my_rank, description)
	ui.add_button("다시 플레이", start_game)
	ui.add_button("TEST1 메뉴로", return_menu)
