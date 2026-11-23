extends Node

signal batch_progress(completed: int, total: int)
signal batch_finished(records: Array, saved: bool)
var embedded := false
var host_game
var previous_mute := false
var previous_equipped: Array = []
## Development-only AI vs AI balance laboratory.
## Run this scene (F6) or: godot --headless --path . res://tests/balance_lab.tscn -- --runs=100 --seed=421
## Uses the real arena, fighter AI, character scenes, attacks and hit callbacks.

const CLASSES := ["swordsman", "spearman", "hammerman", "shieldbearer"]
const OUTPUT_DIR := "user://combat_stats"
const MATCHES_FILE := OUTPUT_DIR + "/matches.jsonl"
const SUMMARY_FILE := OUTPUT_DIR + "/summary.csv"
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
		for fighter in [left, right]:
			var animation: AnimationPlayer = fighter.get_node("AnimationPlayer")
			animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var left_spawn: Vector2 = left.position
		var right_spawn: Vector2 = right.position
		var left_taken := 0.0
		var right_taken := 0.0
		var left_hp_before: float = left.hp
		var right_hp_before: float = right.hp
		var ticks := 0
		while game.mode == "duel" and ticks < int(MAX_DUEL_SECONDS / DT):
			game._physics_process(DT)
			# Method tracks trigger real melee hit frames and ability actions.
			for fighter in [left, right]:
				if is_instance_valid(fighter):
					fighter.get_node("AnimationPlayer").advance(DT)
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
			"balance_hash": str(FileAccess.get_file_as_string("res://data/balance.tres").hash()),
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
	var saved := append_results(results)
	if saved:
		saved = write_summary() and saved
	print("BALANCE LAB: %d matches, %d initialization failures; persisted=%s" % [results.size(), failures, saved])
	print("BALANCE LAB: %s" % ProjectSettings.globalize_path(MATCHES_FILE))
	print("BALANCE LAB: %s" % ProjectSettings.globalize_path(SUMMARY_FILE))
	Meta.muted = previous_mute
	Meta.equipped = previous_equipped
	if embedded:
		game.return_menu()
		game.set_physics_process(true)
		batch_finished.emit(results.duplicate(true), saved and failures == 0)
		game = null
		queue_free()
	else:
		game.queue_free()
		await get_tree().process_frame
		get_tree().quit(0 if saved and failures == 0 else 1)

func append_results(records: Array[Dictionary]) -> bool:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		push_error("Cannot create battle history folder: " + absolute_dir)
		return false
	var file := FileAccess.open(MATCHES_FILE, FileAccess.READ_WRITE)
	if file == null:
		# READ_WRITE requires an existing file on some platforms.
		file = FileAccess.open(MATCHES_FILE, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open battle history: %s" % FileAccess.get_open_error())
		return false
	file.seek_end()
	for record in records:
		file.store_line(JSON.stringify(record))
	file.flush()
	file.close()
	return true

func write_summary() -> bool:
	# Aggregate ALL saved matches, not only this batch. Timeouts are a separate result.
	var history := FileAccess.open(MATCHES_FILE, FileAccess.READ)
	if history == null: return false
	var groups: Dictionary = {}
	while not history.eof_reached():
		var line := history.get_line().strip_edges()
		if line.is_empty(): continue
		var record = JSON.parse_string(line)
		if not record is Dictionary or record.get("mode", "") != "ai_duel": continue
		var a: String = str(record.get("side_a_class", ""))
		var b: String = str(record.get("side_b_class", ""))
		for side in ["left", "right"]:
			var own: String = a if side == "left" else b
			var other: String = b if side == "left" else a
			var key := "%s|%s" % [own, other]
			if not groups.has(key):
				groups[key] = {"class": own, "opponent": other, "matches": 0, "wins": 0, "losses": 0, "timeouts": 0, "duration_total": 0.0}
			var group: Dictionary = groups[key]
			group.matches += 1
			group.duration_total += float(record.get("duration_seconds", 0.0))
			if record.outcome == "timeout": group.timeouts += 1
			elif record.outcome == side: group.wins += 1
			else: group.losses += 1
	history.close()
	var output := FileAccess.open(SUMMARY_FILE, FileAccess.WRITE)
	if output == null: return false
	output.store_line("class,opponent,matches,wins,losses,timeouts,decisive_win_rate,average_seconds")
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var g: Dictionary = groups[key]
		var decided: int = g.wins + g.losses
		var rate: float = float(g.wins) / decided if decided > 0 else 0.0
		output.store_line("%s,%s,%d,%d,%d,%d,%.4f,%.2f" % [g["class"], g.opponent, g.matches, g.wins, g.losses, g.timeouts, rate, g.duration_total / g.matches])
	output.flush()
	output.close()
	return true
