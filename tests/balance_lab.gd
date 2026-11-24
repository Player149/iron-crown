extends Node

signal batch_progress(completed: int, total: int)
signal batch_finished(records: Array, failures: int)
var embedded := false
var host_game
var previous_mute := false
var previous_equipped: Array = []
## Development-only AI vs AI balance laboratory.
## Run this scene (F6) or: godot --headless --path . res://tests/balance_lab.tscn -- --runs=100 --seed=421
## Uses the real arena, fighter AI, character scenes, attacks and hit callbacks.

const CLASSES := ["swordsman", "spearman", "hammerman", "shieldbearer"]
const DEFAULT_RUNS := 20
const MAX_RUNS := 10000
const MAX_DUEL_SECONDS := 60.0
const DT := 1.0 / 60.0

var requested_runs := DEFAULT_RUNS
var seed_base := 421
var results: Array[Dictionary] = []
var game

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			requested_runs = clampi(int(argument.trim_prefix("--runs=")), 1, MAX_RUNS)
		elif argument.begins_with("--seed="):
			seed_base = int(argument.trim_prefix("--seed="))
	if not embedded: call_deferred("run_batch")

func run_embedded(existing_game, rounds: int) -> void:
	if game != null: return
	embedded = true
	host_game = existing_game
	requested_runs = clampi(rounds, 1, MAX_RUNS)
	call_deferred("run_batch")

func run_batch() -> void:
	# Preserve the player preferences. The caller can keep using the same game.
	previous_mute = Meta.muted
	previous_equipped = Meta.equipped.duplicate()
	Meta.muted = true
	Meta.equipped = []
	if host_game == null:
		game = load("res://scenes/main.tscn").instantiate()
		get_tree().root.add_child(game)
	else:
		game = host_game
	game.set_physics_process(false)
	game.simulation_batch = true
	results.clear()
	var total := CLASSES.size() * CLASSES.size()
	var failures := 0
	for i in requested_runs:
		var index := i % total
		var left_class: String = CLASSES[index / CLASSES.size()]
		var right_class: String = CLASSES[index % CLASSES.size()]
		# Paired swaps compare both spawn sides with the same RNG seed.
		if i % 2 == 1:
			var tmp := left_class
			left_class = right_class
			right_class = tmp
		var match_seed := seed_base + i / total
		seed(match_seed)
		game.start_duel(left_class, right_class)
		# Let the already queued old actor nodes leave the scene tree.
		if embedded: batch_progress.emit(i, requested_runs)
		await get_tree().process_frame
		var left = game.player
		var right = game.duel_enemy
		if not is_instance_valid(left) or not is_instance_valid(right):
			failures += 1
			push_error("Could not initialise AI duel %d" % i)
			continue
		# Both sides run the existing fighter AI, with equal base stats and no runes.
		left.is_player = false
		right.is_player = false
		left.ai_build = "assault"
		right.ai_build = "assault"
		CrownBuilds.allocate_ai(left)
		CrownBuilds.allocate_ai(right)
		var left_spawn: Vector2 = left.position
		var right_spawn: Vector2 = right.position
		var left_taken := 0.0
		var right_taken := 0.0
		var left_hp_before: float = left.hp
		var right_hp_before: float = right.hp
		var ticks := 0
		while game.mode == "duel" and ticks < int(MAX_DUEL_SECONDS / DT):
			# Exactly the same combat step as 1x and 16x, including all animations.
			game.step_simulation(DT)
			var hp_left_now: float = maxf(0.0, left.hp)
			var hp_right_now: float = maxf(0.0, right.hp)
			left_taken += maxf(0.0, left_hp_before - hp_left_now)
			right_taken += maxf(0.0, right_hp_before - hp_right_now)
			left_hp_before = hp_left_now
			right_hp_before = hp_right_now
			ticks += 1
			# Yield rarely so Godot can free expired projectiles and actors.
			if ticks % 120 == 0:
				await get_tree().process_frame
		var outcome := "timeout"
		if left.alive and not right.alive: outcome = "left"
		elif right.alive and not left.alive: outcome = "right"
		var record: Dictionary = {
			"schema_version": 1,
			"recorded_at_utc": Time.get_datetime_string_from_system(true),
			"mode": "ai_duel",
			"match_index": i,
			"seed": match_seed,
			"side_a_class": left_class,
			"side_b_class": right_class,
			"side_a_build": left.ai_build,
			"side_b_build": right.ai_build,
			"side_a_stats": left.stat_allocations.duplicate(true),
			"side_b_stats": right.stat_allocations.duplicate(true),
			"side_a_level": left.level,
			"side_b_level": right.level,
			"arena": "duel",
			"starting_distance": game.balance.duel_spawn_distance,
			"side_a_start": [left_spawn.x, left_spawn.y],
			"side_b_start": [right_spawn.x, right_spawn.y],
			"side_a_end": [left.position.x, left.position.y],
			"side_b_end": [right.position.x, right.position.y],
			"duration_seconds": snappedf(ticks * DT, 0.01),
			"outcome": outcome,
			"winner_class": left_class if outcome == "left" else (right_class if outcome == "right" else ""),
			"side_a_damage_taken_estimate": snappedf(left_taken, 0.01),
			"side_b_damage_taken_estimate": snappedf(right_taken, 0.01),
			"side_a_hp_remaining": snappedf(maxf(0.0, left.hp), 0.01),
			"side_b_hp_remaining": snappedf(maxf(0.0, right.hp), 0.01)
		}
		results.append(record)
		if embedded: batch_progress.emit(i + 1, requested_runs)
		if i % 10 == 0 or i == requested_runs - 1:
			print("BALANCE LAB %d/%d, %s vs %s: %s" % [i + 1, requested_runs, left_class, right_class, outcome])
	Meta.muted = previous_mute
	Meta.equipped = previous_equipped
	game.simulation_batch = false
	if embedded:
		game.return_menu()
		game.set_physics_process(true)
		batch_finished.emit(results, failures)
		game = null
		queue_free()
	else:
		print(format_report(results))
		game.queue_free()
		await get_tree().process_frame
		get_tree().quit(0 if failures == 0 else 1)

const CLASS_NAMES := {"swordsman": "검사", "spearman": "창병", "hammerman": "망치병", "shieldbearer": "방패병"}

static func format_report(records: Array) -> String:
	var matchups := {}
	var matches := PackedStringArray()
	for record in records:
		var left: String = CLASS_NAMES[record.side_a_class]
		var right: String = CLASS_NAMES[record.side_b_class]
		var key := "%s vs %s" % [left, right]
		var totals: Dictionary = matchups.get_or_add(key, {"left": 0, "right": 0, "timeout": 0, "seconds": 0.0})
		totals[record.outcome] += 1
		totals.seconds += record.duration_seconds
		var result: String = {"left": "왼쪽 승", "right": "오른쪽 승", "timeout": "시간 초과"}[record.outcome]
		matches.append("%d경기  %s  ·  %s  ·  %.1f초\n남은 HP %.1f / %.1f  ·  받은 피해(추정) %.1f / %.1f  ·  시드 %d" % [record.match_index + 1, key, result, record.duration_seconds, record.side_a_hp_remaining, record.side_b_hp_remaining, record.side_a_damage_taken_estimate, record.side_b_damage_taken_estimate, record.seed])
	var lines := PackedStringArray(["대진별 집계 · 왼쪽 / 오른쪽 기준"])
	for key in matchups:
		var totals: Dictionary = matchups[key]
		var count: int = totals.left + totals.right + totals.timeout
		lines.append("%s  ·  %d판  ·  %d승 / %d승  ·  시간 초과 %d  ·  평균 %.1f초" % [key, count, totals.left, totals.right, totals.timeout, totals.seconds / count])
	lines.append("\n경기별 상세 · 수치는 왼쪽 / 오른쪽 순서")
	lines.append_array(matches)
	return "\n\n".join(lines)
