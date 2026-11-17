extends SceneTree

var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("Meta").muted = true
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_game()
	var libraries: Array = []
	for id in ["swordsman", "spearman", "shieldbearer", "hammerman"]:
		var fighter = load("res://scenes/characters/%s.tscn" % id).instantiate()
		fighter.arena = game
		game.get_node("Actors").add_child(fighter)
		fighter.get_node("AnimationPlayer").callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var library = fighter.get_node("AnimationPlayer").get_animation_library("")
		check(library.resource_local_to_scene, id + " library is local to scene")
		check(not libraries.has(library), id + " has independent library")
		libraries.append(library)
		var authored = load("res://scenes/characters/%s.tscn" % id).instantiate()
		var authored_library = authored.get_node("AnimationPlayer").get_animation_library("")
		var scene_state = load("res://scenes/characters/%s.tscn" % id).get_state()
		var owns_library: bool = false
		for node_index in scene_state.get_node_count():
			if scene_state.get_node_name(node_index) != &"AnimationPlayer": continue
			for property_index in scene_state.get_node_property_count(node_index):
				if scene_state.get_node_property_name(node_index, property_index) != &"libraries/": continue
				var source_library = scene_state.get_node_property_value(node_index, property_index)
				owns_library = source_library.resource_path.begins_with("res://scenes/characters/%s.tscn::" % id)
		check(owns_library, id + " animations authored in own scene")
		check(authored.get_node("AnimationPlayer").owner == authored, id + " owns AnimationPlayer")
		authored_library.add_animation("custom_preview", Animation.new())
		check(not library.has_animation("custom_preview"), id + " custom animation is isolated")
		authored.free()
		check(fighter.get_node("AnimationPlayer").has_animation("guard_raise") == (id in ["swordsman", "shieldbearer"]), id + " owns only its guard animation")
		check(fighter.guard != null if id in ["swordsman", "shieldbearer"] else fighter.guard == null, id + " optional guard component")
		check(fighter.definition.id == id, id + " definition")
		check(fighter.class_name_text == fighter.definition.title, id + " class title")
		check((fighter.guard != null and fighter.guard.shield != null) == (id in ["swordsman", "shieldbearer"]), id + " shield ownership")
		check(fighter.can_guard() == (id in ["swordsman", "shieldbearer"]), id + " starter guard")
		check(fighter.has_node("Visual/WeaponPivot1/WeaponPivot2/Sword") == (id != "shieldbearer"), id + " sword ownership")
		fighter.attack()
		check(fighter.attack_lock > 0 and fighter.stamina < fighter.max_stamina, id + " inherited attack")
		fighter.get_node("AnimationPlayer").advance(0.21)
		await process_frame
		fighter.add_groggy(100)
		check(fighter.groggy_left > 0 and not fighter.can_act(), id + " groggy")
		check(is_zero_approx(fighter.get_node("Visual/WeaponPivot1").rotation) and is_zero_approx(fighter.get_node("Visual/WeaponPivot1/WeaponPivot2").rotation), id + " weapon reset")
		fighter.reset_groggy()
		fighter.trigger_exhaustion()
		check(fighter.exhaustion_left > 0, id + " exhaustion")
		fighter.exhaustion_left = 0
		fighter.stamina = fighter.max_stamina
		if id in ["swordsman", "shieldbearer"]:
			fighter.guard.requested = true
			fighter.guard.tick(0)
			fighter.get_node("AnimationPlayer").advance(0.15)
			await process_frame
			check(fighter.guard.blocking, "Shieldbearer guard animation enables block")
			fighter.update_visual()
			fighter.guard.requested = false
			fighter.guard.tick(0)
			fighter.get_node("AnimationPlayer").advance(0.23)
			await process_frame
			check(fighter.guard.phase == "idle", "Shieldbearer guard lowers")
			# Removing visual animations must not leave the combat state stuck.
			fighter.reset_guard()
			var library_without_guard = fighter.get_node("AnimationPlayer").get_animation_library("")
			library_without_guard.remove_animation("guard_raise")
			library_without_guard.remove_animation("guard_lower")
			fighter.guard.requested = true
			fighter.guard.tick(0)
			fighter.guard.tick(game.balance.guard_windup + 0.01)
			check(fighter.blocking, "Missing guard animation uses safe windup")
			fighter.guard.requested = false
			fighter.guard.tick(0)
			fighter.guard.tick(game.balance.guard_recovery + 0.01)
			check(fighter.guard.phase == "idle", "Missing guard animation uses safe recovery")
		fighter.queue_free()
	game.queue_free()
	await process_frame
	print("CHARACTER TEMPLATES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
