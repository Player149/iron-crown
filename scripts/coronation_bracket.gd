extends RefCounted

var match_ref: WeakRef
var match_data:
	get: return match_ref.get_ref()
var pairs: Array[Dictionary] = []
var advancing: Array[int] = []
var round_number := 0
var next_round_at := -1.0
var deadline := 0.0
var round_seconds := 0.0

func _init(match_instance) -> void:
	match_ref = weakref(match_instance)

func start() -> void:
	var slots: Array[int] = []
	for f in match_data.arena.fighters:
		slots.append(f.match_slot)
	slots.shuffle()
	round_seconds = maxf(1.0, match_data.rules.bout_seconds)
	start_round(slots)

func start_round(slots: Array[int]) -> void:
	var game = match_data.arena
	game.clear_projectiles()
	pairs.clear()
	advancing.clear()
	for f in game.fighters:
		f.alive = false
		f.hide()
	if slots.size() == 1:
		match_data.crown_winner(fighter(slots[0]))
		return
	if slots.size() % 2 == 1:
		advancing.append(slots.pop_back())
	round_number += 1
	next_round_at = -1.0
	deadline = match_data.tournament_elapsed + round_seconds
	var count := floori(slots.size() / 2.0)
	var columns := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / columns)
	var side: float = match_data.rules.ring_side
	var stride: float = side + match_data.rules.ring_gap
	for i in count:
		var column := i % columns
		var row := floori(float(i) / columns)
		var center: Vector2 = match_data.world() / 2.0 + Vector2(column - (columns - 1) / 2.0, row - (rows - 1) / 2.0) * stride
		var rect := Rect2(center - Vector2.ONE * side / 2.0, Vector2.ONE * side)
		var a := slots[i * 2]
		var b := slots[i * 2 + 1]
		var offset := Vector2.RIGHT * minf(side * 0.6, match_data.rules.bout_spawn_separation) / 2.0
		match_data.reset_fighter(fighter(a), center - offset, match_data.rules.bout_spawn_protection)
		match_data.reset_fighter(fighter(b), center + offset, match_data.rules.bout_spawn_protection)
		pairs.append({"a": a, "b": b, "rect": rect, "done": false, "damage": {a: 0.0, b: 0.0}})
	if game.player.alive: game.camera.position = game.player.position
	var title := "결승" if count == 1 and advancing.is_empty() else "%d강" % (count * 2 + advancing.size())
	game.ui.notice("중앙 토너먼트 · " + title, "1대1 동시 진행 · %d초" % ceili(round_seconds))

func fighter(slot: int):
	for f in match_data.arena.fighters:
		if f.match_slot == slot: return f
	return null

func pairing(slot: int) -> Dictionary:
	for pair in pairs:
		if not pair.done and (pair.a == slot or pair.b == slot): return pair
	return {}

func can_target(source, target) -> bool:
	if not source is CrownFighter or not target is CrownFighter: return false
	var pair := pairing(source.match_slot)
	return not pair.is_empty() and (target.match_slot == pair.a or target.match_slot == pair.b)

func record_damage(source, amount: float) -> void:
	var pair := pairing(source.match_slot)
	if not pair.is_empty(): pair.damage[source.match_slot] += amount

func damage_multiplier() -> float:
	var rules = match_data.rules
	var progress := clampf(1.0 - (deadline - match_data.tournament_elapsed) / round_seconds, 0.0, 1.0)
	var ramp := clampf((progress - rules.bout_ramp_start) / maxf(0.01, 1.0 - rules.bout_ramp_start), 0.0, 1.0)
	return rules.bout_damage_multiplier + ramp * rules.bout_damage_ramp

func knock_out(target) -> void:
	var pair := pairing(target.match_slot)
	if pair.is_empty(): return
	complete(pair, pair.b if pair.a == target.match_slot else pair.a)

func complete(pair: Dictionary, winner: int) -> void:
	pair.done = true
	advancing.append(winner)
	for slot in [pair.a, pair.b]:
		var f = fighter(slot)
		f.alive = false
		f.hide()
	if pairs.all(func(entry): return entry.done):
		next_round_at = match_data.tournament_elapsed + match_data.rules.round_break_seconds

func step() -> void:
	if match_data.winner_announced: return
	if next_round_at >= 0.0:
		if match_data.tournament_elapsed >= next_round_at:
			var slots := advancing.duplicate()
			start_round(slots)
		return
	if match_data.tournament_elapsed < deadline: return
	for pair in pairs:
		if pair.done: continue
		var a = fighter(pair.a)
		var b = fighter(pair.b)
		var a_hp: float = a.hp / a.max_hp
		var b_hp: float = b.hp / b.max_hp
		var winner: int = pair.a
		if not is_equal_approx(a_hp, b_hp):
			winner = pair.a if a_hp > b_hp else pair.b
		elif not is_equal_approx(pair.damage[pair.a], pair.damage[pair.b]):
			winner = pair.a if pair.damage[pair.a] > pair.damage[pair.b] else pair.b
		complete(pair, winner)

