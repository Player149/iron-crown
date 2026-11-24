extends RefCounted

const Bracket = preload("res://scripts/coronation_bracket.gd")
const RESOURCE_KINDS := ["crystal", "tree", "mushroom"]
const ZONE := preload("res://scenes/zone.tscn")
const MONSTER := preload("res://scenes/monster.tscn")

var arena
var rules
var bracket
var contributions: Dictionary = {}
var terrain_marks := PackedVector2Array()
var last_stage := -1
var sites: Array[Dictionary] = []
var phase := 0
var winner_announced := false
var resource_clock := 0.0
var hazard_clock := 0.0
var reopen_at := 0.0
var tournament_elapsed := 0.0
var after_first_tournament := false
var final_tournament := false

func _init(game) -> void:
	arena = game
	rules = game.coronation_rules

func world() -> Vector2:
	return Vector2.ONE * rules.map_side

func setup() -> void:
	for i in rules.terrain_mark_count:
		terrain_marks.append(Vector2(randf_range(0.0, rules.map_side), randf_range(0.0, rules.map_side)))

	for zone in arena.get_node("Zones").get_children():
		zone.hide()
	var layout := []
	for quadrant in 4:
		var cells := [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]
		cells.shuffle()
		var offset := Vector2(quadrant % 2, floori(quadrant / 2.0)) * 2.0
		for i in cells.size():
			layout.append({"cell": offset + cells[i], "field": i >= 2})
	for entry in layout:
		var center: Vector2 = (entry.cell + Vector2(0.5, 0.5)) * (world().x / 4.0)
		center += Vector2(randf_range(-rules.site_jitter, rules.site_jitter), randf_range(-rules.site_jitter, rules.site_jitter))
		if center.distance_to(world() / 2.0) < rules.site_center_clearance:
			center = world() / 2.0 + (center - world() / 2.0).normalized() * rules.site_center_clearance
		var field: bool = entry.field
		var radius: float = rules.monster_field_radius if field else rules.xp_zone_radius
		sites.append({"center": center, "radius": radius, "field": field})
		if field:
			spawn_monster("field", center, center, radius)
			var offset: Vector2 = Vector2.from_angle(randf() * TAU) * rules.roaming_monster_offset
			spawn_monster("roamer", center + offset, center + offset, rules.roaming_monster_leash)
		else:
			var zone = ZONE.instantiate()
			zone.position = center
			zone.radius = radius
			zone.set_meta("coronation", true)
			arena.get_node("Zones").add_child(zone)
	for i in rules.resource_count:
		spawn_resource()

func spawn_monster(kind: String, point: Vector2, home: Vector2, leash: float) -> void:
	var monster = MONSTER.instantiate()
	monster.arena = arena
	monster.position = point
	monster.home = home
	monster.leash = leash
	monster.coronation_kind = kind
	monster.brute = kind == "field" or (kind == "roamer" and randf() < rules.roaming_brute_chance)
	if kind in RESOURCE_KINDS:
		monster.max_hp = rules.resource_hp[RESOURCE_KINDS.find(kind)]
	arena.get_node("Actors").add_child(monster)
	arena.monsters.append(monster)

func spawn_resource() -> void:
	spawn_monster(RESOURCE_KINDS.pick_random(), safe_spawn(), Vector2.ZERO, 0.0)

func safe_spawn() -> Vector2:
	var best := world() / 2.0
	var best_clearance := -INF
	for i in rules.spawn_attempts:
		var point := Vector2(randf_range(rules.spawn_border, world().x - rules.spawn_border), randf_range(rules.spawn_border, world().y - rules.spawn_border))
		var center_distance := point.distance_to(world() / 2.0)
		var clearance: float = center_distance - rules.center_spawn_clearance
		if phase == 1: clearance = minf(clearance, safe_radius() - center_distance - rules.zone_ai_margin)
		for site in sites:
			clearance = minf(clearance, point.distance_to(site.center) - site.radius - rules.site_spawn_margin)
		for f in arena.fighters:
			if f.alive: clearance = minf(clearance, point.distance_to(f.position) - rules.fighter_spawn_clearance)
		for m in arena.monsters:
			if m.alive: clearance = minf(clearance, point.distance_to(m.position) - (rules.roamer_spawn_clearance if m.coronation_kind == "roamer" else rules.resource_spawn_clearance))
		if clearance > 0.0: return point
		if clearance > best_clearance:
			best_clearance = clearance
			best = point
	return best

func safe_radius() -> float:
	var previous := world().length() * 0.5
	if after_first_tournament and not rules.opening_contractions.is_empty():
		previous = minf(previous, rules.opening_contractions[0].target_radius)
	var schedule_elapsed := contraction_elapsed()
	for contraction in contractions():
		var radius := minf(previous, contraction.target_radius)
		var progress := clampf((schedule_elapsed - contraction.start_seconds) / maxf(0.01, contraction.duration_seconds), 0.0, 1.0)
		if progress < 1.0:
			return lerpf(previous, radius, progress)
		previous = radius
	return previous

func contractions() -> Array[CrownZoneContraction]:
	return rules.closing_contractions if after_first_tournament else rules.opening_contractions

func contraction_elapsed() -> float:
	return arena.elapsed - rules.first_tournament_start_seconds() if after_first_tournament else arena.elapsed

func stage() -> int:
	var schedule := contractions()
	var schedule_elapsed := contraction_elapsed()
	for i in range(schedule.size() - 1, -1, -1):
		if schedule_elapsed >= schedule[i].start_seconds: return i
	return -1

func step(dt: float) -> void:
	if phase == 2:
		tournament_elapsed += dt
		bracket.step()
		if winner_announced and tournament_elapsed >= reopen_at:
			if final_tournament: finish()
			else: reopen()
		return

	var first_start: float = rules.first_tournament_start_seconds()
	if not after_first_tournament and arena.elapsed >= first_start:
		arena.elapsed = first_start
		start_tournament(false)
		return
	if after_first_tournament and arena.elapsed >= rules.match_seconds:
		arena.elapsed = rules.match_seconds
		start_tournament(true)
		return

	var current := stage()
	if current > last_stage:
		phase = 1
		last_stage = current
		var contraction_number := current + (2 if after_first_tournament else 1)
		arena.ui.notice("%d차 안전 구역 수축" % contraction_number, "경계를 확인하고 중앙으로 이동하세요")
	if phase == 1:
		hazard_clock += dt
		if hazard_clock >= rules.hazard_interval:
			hazard_clock -= rules.hazard_interval
			for f in arena.fighters:
				if f.alive and f.position.distance_to(world() / 2.0) > safe_radius():
					arena.deal_damage(f, f.max_hp * rules.hazard_hp_fraction, null)
	resource_clock += dt
	if resource_clock >= rules.resource_interval:
		resource_clock = 0.0
		var count: int = arena.monsters.filter(func(m): return m.is_resource() and m.alive).size()
		if count < rules.resource_count: spawn_resource()

func start_tournament(is_final: bool) -> void:
	phase = 2
	final_tournament = is_final
	tournament_elapsed = 0.0
	winner_announced = false
	bracket = Bracket.new(self)
	bracket.start()

func crown_winner(winner) -> void:
	winner_announced = true
	reopen_at = tournament_elapsed + rules.final_break_seconds
	winner.iron_score += rules.champion_score
	arena.ui.notice("%s · 중앙 토너먼트 우승" % winner.display_name, "철혈 +%d" % rules.champion_score)

func combat_bounds(f) -> Rect2:
	if phase == 2:
		var pair: Dictionary = bracket.pairing(f.match_slot)
		if not pair.is_empty(): return pair.rect
	return arena.bounds()

func reopen() -> void:
	after_first_tournament = true
	last_stage = -1
	hazard_clock = 0.0
	phase = 1
	arena.clear_projectiles()
	var entrants: Array = arena.fighters.duplicate()
	entrants.shuffle()
	for f in entrants: f.alive = false
	for f in entrants: reset_fighter(f, safe_spawn(), rules.spawn_protection)
	arena.camera.position = arena.player.position
	arena.ui.notice("전장 재개", "철혈과 빌드를 유지하며 다시 흩어집니다")

func reset_fighter(f, position: Vector2, protection: float) -> void:
	f.position = position
	f.velocity = Vector2.ZERO
	f.dash_left = 0.0
	for key in f.cooldown: f.cooldown[key] = 0.0
	f.pending_skills.clear()
	for animator in f.ability_players.values(): animator.stop()
	f.reset_guard()
	f.reset_groggy()
	f.reset_hitstun()
	f.reset_weapon_pose()
	f.clear_match_action()
	f.coronation_effect = 0.0
	f.combat_left = 0.0
	f.damage_contributors.clear()
	contributions.erase(f.match_slot)
	f.ai_target = null
	f.ai_retarget = 0.0
	f.ai_retreat_left = 0.0
	f.ai_reacting = false
	f.hp = f.max_hp
	f.stamina = f.max_stamina
	f.exhaustion_left = 0.0
	f.invuln = protection
	f.alive = true
	f.show()

func combat_clock() -> float:
	return tournament_elapsed if phase == 2 else arena.elapsed

func record_damage(target, source, amount: float) -> void:
	if phase == 2: bracket.record_damage(source, amount)
	var victim: Dictionary = contributions.get_or_add(target.match_slot, {})
	var entry: Dictionary = victim.get_or_add(source.match_slot, {"samples": [], "damage": 0.0})
	prune_damage(entry)
	entry.samples.append(Vector2(combat_clock(), amount))
	entry.damage += amount

func prune_damage(entry: Dictionary) -> void:
	var samples: Array = entry.samples
	while not samples.is_empty() and combat_clock() - samples[0].x > rules.assist_window:
		entry.damage -= samples.pop_front().y

func on_knockout(target, killer) -> void:
	target.respawn_timer = rules.fighter_respawn
	var victim: Dictionary = contributions.get(target.match_slot, {})
	contributions.erase(target.match_slot)
	if killer is CrownFighter:
		award(killer, rules.kill_score)
		var total := 0.0
		for entry in victim.values():
			prune_damage(entry)
			total += entry.damage
		if total > 0.0:
			for f in arena.fighters:
				if f == killer or not victim.has(f.match_slot): continue
				var ratio: float = victim[f.match_slot].damage / total
				var points := floori(rules.kill_score * rules.assist_max_ratio * ratio)
				if points > 0: award(f, points)
	if phase == 2: bracket.knock_out(target)

func award(f, points: int) -> void:
	f.iron_score += points
	if phase == 2: f.center_score += points

func on_monster_death(monster, killer) -> void:
	if monster.is_resource():
		arena.monsters.erase(monster)
		monster.queue_free()
		if killer is CrownFighter:
			var fraction: float = rules.resource_level_fractions[RESOURCE_KINDS.find(monster.coronation_kind)]
			arena.add_xp(killer, arena.balance.xp_needed(killer.level) * fraction)
		return
	monster.respawn_timer = rules.field_respawn if monster.coronation_kind == "field" else rules.roamer_respawn
	if not killer is CrownFighter: return
	var major: bool = monster.coronation_kind == "field"
	award(killer, rules.field_score if major else (rules.brute_score if monster.brute else rules.roamer_score))
	killer.hp = minf(killer.max_hp, killer.hp + killer.max_hp * (rules.field_heal if major else rules.roamer_heal))
	if major:
		killer.coronation_effect = rules.haste_seconds
		killer.stamina = killer.max_stamina
		arena.float_text(killer.position, "가속 · %.0f초" % rules.haste_seconds, Color("edc66b"))
	var fraction: float = rules.field_level_fraction if major else (rules.brute_level_fraction if monster.brute else rules.roamer_level_fraction)
	arena.add_xp(killer, arena.balance.xp_needed(killer.level) * fraction)

func finish() -> void:
	arena.mode = "coronation_result"
	arena.paused = true
	if arena.run_gold > 0: arena.bank_gold()
	arena.ui.show_coronation_result(ranking())

func ranking() -> Array:
	var ranked: Array = arena.fighters.duplicate()
	ranked.sort_custom(func(a, b):
		if a.iron_score != b.iron_score: return a.iron_score > b.iron_score
		if a.kills != b.kills: return a.kills > b.kills
		if a.center_score != b.center_score: return a.center_score > b.center_score
		return a.match_slot < b.match_slot)
	return ranked

func growth(f, dt: float) -> void:
	if phase == 2 or not f.alive: return
	var rate := 1.0 / maxf(1.0, rules.passive_level_seconds)
	for site in sites:
		if not site.field and f.position.distance_to(site.center) < site.radius:
			rate = 1.0 / maxf(1.0, rules.zone_level_seconds)
			break
	arena.add_xp(f, arena.balance.xp_needed(f.level) * rate * dt)

func guide(f) -> bool:
	if phase == 1 and f.position.distance_to(world() / 2.0) > safe_radius() - rules.zone_ai_margin:
		var toward: Vector2 = f.position.direction_to(world() / 2.0)
		f.facing = toward.angle()
		f.velocity = toward * f.speed * arena.balance.sprint_multiplier
		return true
	return false

func roam(f) -> void:
	if phase == 2 or sites.is_empty(): return
	var index: int = (f.match_slot + int(arena.elapsed / maxf(1.0, rules.ai_roam_period))) % sites.size()
	var direction: Vector2 = f.position.direction_to(sites[index].center)
	f.facing = direction.angle()
	f.velocity = direction * f.speed

func draw_map(canvas: CanvasItem, factor: Vector2, minimap: bool = false) -> void:
	var scale := factor.x
	if not minimap:
		var viewport: Vector2 = canvas.get_viewport_rect().size / arena.camera.zoom
		var terrain_view := Rect2(arena.camera.position - viewport / 2.0, viewport).grow(90.0)
		for i in terrain_marks.size():
			var seed_point := terrain_marks[i]
			if not terrain_view.has_point(seed_point): continue
			var tint := Color("426354") if i % 4 == 0 else Color("304839")
			if i % 5 == 0:
				canvas.draw_circle(seed_point, 8.0, Color("405159"))
				canvas.draw_circle(seed_point + Vector2(10, 7), 4.0, Color("344751"))
			else:
				for blade in 3:
					var point := seed_point + Vector2(blade * 5.0, absf(blade - 1.0) * 2.0)
					canvas.draw_line(point, point + Vector2((blade - 1.0) * 5.0, -8.0), tint, 2.0)
	for site in sites:
		if site.field or minimap:
			var color := Color("f4a15b") if site.field else Color("62bbc4")
			canvas.draw_arc(site.center * factor, site.radius * scale, 0, TAU, 40, color, 1.5 if minimap else 3.0)
	var center := world() * 0.5 * factor
	if phase in [1, 2]:
		canvas.draw_arc(center, safe_radius() * scale, 0, TAU, 128, Color("ff745f"), 2.0 if minimap else 6.0, true)
	if phase == 2 and bracket != null:
		for pair in bracket.pairs:
			var rect: Rect2 = pair.rect
			var scaled := Rect2(rect.position * factor, rect.size * factor)
			canvas.draw_rect(scaled, Color("4c3d2a"))
			canvas.draw_rect(scaled, Color("7c7662") if pair.done else Color("eac674"), false, 1.0 if minimap else 6.0)
