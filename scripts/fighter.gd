class_name CrownFighter
extends CharacterBody2D

const AttackRangePreview = preload("res://scripts/components/attack_range_preview.gd")

@export var display_name: String = "기사"
@export var is_player: bool = false
@export var damage: float = 18.0
@export var speed: float = 178.0
@export var tint: Color = Color("78b4df")
@export var attack_range_override: float = 0.0
## Total attack angle in degrees. Zero uses the arena balance value.
@export_range(0.0, 360.0, 0.1) var attack_arc_override_degrees: float = 0.0
@export var show_attack_range: bool = false
@export var definition: CrownCharacterDefinition = preload("res://data/characters/knight.tres")
var abilities: Dictionary = {}
var ability_players: Dictionary = {}
var pending_skills: Dictionary = {}
var attack_target_limit: int = 2
var arena
var level: int = 1
## Manual progression points; all six stats cap at eight ranks.
var stat_points: int = 1
var stat_allocations: Dictionary = CrownBuilds.create_allocations()
## AI uses a consistent playstyle rather than random stat purchases.
var ai_build: String = "assault"
var xp: float = 0
var max_hp: float = 100
var hp: float = 100
var armor: float = 3
var attack_speed: float = 1
var crit: float = 0.06
var lifesteal: float = 0
var skill_power: float = 1
var xp_gain: float = 1
var gold_bonus: float = 1
var dash_mult: float = 1
var block_reduction: float = 0.64
var body_scale: float = 1
var radius: float = 25
var alive: bool = true
var kills: int = 0
var match_slot: int = 0
var iron_score: int = 0
var center_score: int = 0
var coronation_effect: float = 0.0
var boss_flag: bool = false
var boss_damage: float = 0
var boss_kills: int = 0
var invuln: float = 0
var blocking: bool:
	get: return guard != null and guard.blocking
var stamina: float = 100.0
var max_stamina: float = 100.0
var exhaustion_left: float = 0.0
var damage_contributors: Dictionary = {} # attacker instance ID -> most recent hit time
@onready var guard = get_node_or_null("Guard")
var attack_lock: float = 0.0
var swing_active: bool = false
var basic_swing: bool = false
var swing_hit_committed: bool = false
var hitstun_left: float = 0.0
var hitstun_immunity: float = 0.0
var poise_modifiers: Dictionary = {}
## Damage multiplier for current authored swing animation and its hit event.
var swing_power: float = 1.0
var combat_left: float = 0
var no_hit_time: float = 99
var groggy_left: float = 0
var groggy: float = 0
var groggy_decay_left: float = 0
var groggy_immunity: float = 0
var dash_left: float = 0
var dash_velocity: Vector2 = Vector2.ZERO
var facing: float = -PI / 2.0
var evolutions: Array = []
var class_name_text: String = "나뭇가지 전사"
var cooldown: Dictionary = {"attack": 0.0, "dash": 0.0, "e": 0.0, "r": 0.0, "q": 0.0}
var base_stats: Dictionary
var ai_target
var ai_retarget: float = 0
var ai_retreat_left: float = 0
var ai_retreat_cooldown: float = 0
var ai_reaction_left: float = 0.0
var ai_reacting: bool = false
var ai_defense_recovery: float = 0.0
var swing_hit_time: float = -1.0
var respawn_timer: float = 0

func _ready() -> void:
	max_hp = arena.balance.starting_hp
	hp = max_hp
	for key in definition.multipliers: set(key, get(key) * definition.multipliers[key])
	for key in definition.additions: set(key, get(key) + definition.additions[key])
	hp = max_hp
	max_stamina = arena.balance.stamina_max
	stamina = max_stamina
	attack_target_limit = definition.attack_target_limit
	var library = $AnimationPlayer.get_animation_library("").duplicate(true)
	$AnimationPlayer.remove_animation_library("")
	$AnimationPlayer.add_animation_library("", library)
	if definition.attack_animation != null: library.add_animation("swing", definition.attack_animation)
	var swing := $AnimationPlayer.get_animation("swing") as Animation
	for track in swing.get_track_count():
		if swing.track_get_type(track) != Animation.TYPE_METHOD: continue
		for index in swing.track_get_key_count(track):
			if swing.method_track_get_name(track, index) == &"resolve_attack_hit":
				swing_hit_time = swing.track_get_key_time(track, index)
				break
	if definition.ability != null: equip_ability(definition.skill_slot, definition.ability)
	base_stats = snapshot_stats()
	if is_player:
		Meta.apply_runes(self)
	$Visual/Body.modulate = Color.WHITE
	update_visual()

func incoming_damage_multiplier(_direction_to_hit: Vector2) -> float:
	return 1.0

func snapshot_stats() -> Dictionary:
	var result = {}
	for key in ["max_hp", "max_stamina", "damage", "speed", "attack_speed", "armor", "crit", "lifesteal", "skill_power", "xp_gain", "body_scale", "dash_mult", "block_reduction", "gold_bonus"]:
		result[key] = get(key)
	return result

func tick(dt: float) -> void:
	if not alive:
		return
	for key in cooldown:
		cooldown[key] = maxf(0, cooldown[key] - dt)
	invuln = maxf(0, invuln - dt)
	attack_lock = maxf(0, attack_lock - dt)
	update_hitstun(dt)
	update_poise_modifiers(dt)
	if exhaustion_left > 0.0: exhaustion_left = maxf(0.0, exhaustion_left - dt)
	elif stamina <= 0.0: trigger_exhaustion()
	update_groggy(dt)
	combat_left = maxf(0, combat_left - dt)
	no_hit_time += dt
	ai_defense_recovery = maxf(0.0, ai_defense_recovery - dt)
	if guard != null: guard.requested = false
	velocity = Vector2.ZERO
	if can_act():
		if is_player:
			player_control()
		else:
			ai_control(dt)
	elif hitstun_left > 0.0 and groggy_left <= 0.0 and exhaustion_left <= 0.0:
		if is_player: player_control()
		elif is_instance_valid(ai_target) and ai_target.alive:
			facing = (ai_target.position - position).angle()
	if guard != null: guard.tick(dt)
	if exhaustion_left <= 0.0 and (hitstun_left > 0.0 or (not guard_busy() and attack_lock <= 0.0)):
		stamina = minf(max_stamina, stamina + arena.balance.stamina_regen * dt)
	if dash_left > 0 and can_act():
		dash_left -= dt
		velocity = dash_velocity
		arena.fx_ring(position, 12, Color("79dbf4") if is_player and Meta.rune_level("frost") > 0 else tint, 0.2)
	var speed_factor := 1.0
	if dash_left <= 0.0:
		if coronation_effect > 0.0: speed_factor = arena.coronation_rules.haste_movement
		elif coronation_effect < 0.0: speed_factor = arena.coronation_rules.slow_movement
	coronation_effect = move_toward(coronation_effect, 0.0, dt)
	position += velocity * dt * speed_factor
	var bounds: Rect2 = arena.fighter_bounds(self)
	position = position.clamp(bounds.position + Vector2.ONE * 30, bounds.end - Vector2.ONE * 30)
	if no_hit_time >= arena.balance.regen_delay and (arena.coronation == null or arena.coronation.phase != 2):
		hp = minf(max_hp, hp + max_hp * arena.balance.health_regen * dt)
	update_visual()

func player_control() -> void:
	var move = Input.get_vector("left", "right", "up", "down") + arena.touch_move
	move = move.limit_length()
	var target = arena.nearest_target(self, 520) if arena.touch_mode else null
	if arena.touch_mode:
		if target != null: facing = (target.position - position).angle()
		elif move.length() > 0.1: facing = move.angle()
	else:
		facing = (get_global_mouse_position() - global_position).angle()
	if not can_act(): return
	if guard != null: guard.requested = Input.is_action_pressed("block") or arena.touch_block
	var multiplier = arena.balance.sprint_multiplier if Input.is_action_pressed("run") or arena.touch_run else 1.0
	if guard_busy(): multiplier *= arena.balance.guard_move_multiplier
	elif attack_lock > 0: multiplier *= arena.balance.swing_move_multiplier
	velocity = move * speed * multiplier
	if (not arena.touch_mode and Input.is_action_pressed("attack")) or arena.touch_attack: attack()
	if Input.is_action_just_pressed("dash"): dash(move)
	for key in ["e", "r", "q"]:
		if Input.is_action_just_pressed(key): skill(key)

func clear_match_action() -> void:
	pass

func ai_control(dt: float) -> void:
	if arena.coronation != null and dash_left <= 0.0 and arena.coronation.guide(self): return
	ai_retarget -= dt
	ai_retreat_left = maxf(0.0, ai_retreat_left - dt)
	ai_retreat_cooldown = maxf(0.0, ai_retreat_cooldown - dt)
	if ai_retarget <= 0.0 or not arena.valid_target(self, ai_target):
		var previous_target = ai_target
		ai_target = arena.nearest_target(self, arena.balance.ai_detection_radius)
		if ai_target != previous_target: ai_reacting = false
		ai_retarget = arena.balance.ai_retarget_seconds
	if ai_target == null or dash_left > 0.0:
		ai_reacting = false
		if dash_left <= 0.0 and arena.coronation != null: arena.coronation.roam(self)
		return

	var offset: Vector2 = ai_target.position - position
	var distance := offset.length()
	var direction := offset / maxf(distance, 0.001) if distance > 0.001 else Vector2.from_angle(facing)
	facing = direction.angle()
	var reach: float = attack_reach() + ai_target.radius
	var preferred := ai_preferred_distance(reach)
	var escape := ai_escape_direction(direction)
	var vulnerable: bool = ai_target is CrownFighter and not ai_target.can_act()
	var target_ready := ai_target_is_open()
	var attack_cost: float = arena.balance.attack_stamina_cost
	var dash_cost: float = arena.balance.dash_stamina_cost

	if ai_retreat_cooldown <= 0.0 and not vulnerable:
		if (not boss_flag and hp < max_hp * arena.balance.ai_retreat_hp_ratio and hp < ai_target.hp) or stamina < attack_cost + 5.0:
			ai_retreat_left = arena.balance.ai_retreat_seconds
			ai_retreat_cooldown = arena.balance.ai_retreat_cooldown
	var retreating: bool = ai_retreat_left > 0.0 and not vulnerable

	var move := direction if distance > preferred + 5.0 else Vector2.ZERO
	if retreating or distance < preferred - 12.0:
		move = escape
	velocity = move * speed * (arena.balance.swing_move_multiplier if attack_lock > 0.0 else 1.0)

	var threat := INF
	if ai_target is CrownFighter:
		threat = ai_target.ai_threat_time(self)
	if ai_defend(threat, escape, dt):
		velocity = move * speed * (arena.balance.guard_move_multiplier if guard_busy() else 1.0)
		return
	if guard_busy():
		velocity *= arena.balance.guard_move_multiplier
		return
	if (attack_lock > 0.0 and not basic_swing) or not pending_skills.is_empty(): return

	if ai_use_class_skill(distance, reach, retreating, target_ready): return
	if retreating:
		if distance < reach + 20.0 and stamina > dash_cost + 6.0 and escape != Vector2.ZERO:
			dash(escape)
		return
	if not target_ready: return

	for slot in ["q", "r", "e"]:
		if cooldown[slot] <= 0.0 and abilities.has(slot):
			var ability: CrownAbility = abilities[slot]
			if ability.effect == "area" and distance <= ability.radius + ai_target.radius - 12.0:
				skill(slot)
				return
			if ability.effect == "projectiles" and distance <= ai_projectile_range(ability):
				skill(slot)
				return

	if distance <= reach - 6.0 and stamina > attack_cost + 3.0:
		attack()
	elif cooldown.dash <= 0.0 and stamina > dash_cost + attack_cost + 18.0:
		# Spend a dash to close a gap that walking cannot cover during an opening.
		if distance > preferred + 75.0 and distance <= preferred + 135.0:
			dash(direction)

func ai_preferred_distance(reach: float) -> float:
	return reach * 0.68

func ai_use_class_skill(_distance: float, _reach: float, _retreating: bool, _target_ready: bool) -> bool:
	return false

func ai_target_is_open() -> bool:
	if ai_target.invuln > 0.0: return false
	var opponent := ai_target as CrownFighter
	# Pressure a raised barrier so a shieldbearer cannot hold it indefinitely.
	return opponent == null or not opponent.blocking or opponent.guard.mode == "barrier"

func ai_projectile_range(ability: CrownAbility) -> float:
	var useful_range := minf(280.0, ability.projectile_speed * ability.projectile_lifetime * 0.7)
	# An even fan has no shot on the center line, so use it closer to the target.
	if not ability.radial and ability.projectile_count % 2 == 0 and ability.spread > 0.0:
		var half_gap := sin(ability.spread * 0.5)
		useful_range = minf(useful_range, (ai_target.radius + 7.0) / maxf(0.01, half_gap))
	if ability.radial: useful_range = minf(useful_range, 120.0)
	return useful_range

func ai_escape_direction(toward: Vector2) -> Vector2:
	var bounds: Rect2 = arena.fighter_bounds(self).grow(-31.0)
	if bounds.has_point(position - toward * 85.0): return -toward
	var tangent := toward.orthogonal()
	if bounds.has_point(position + tangent * 85.0): return tangent
	if bounds.has_point(position - tangent * 85.0): return -tangent
	return position.direction_to(bounds.get_center())

func ai_defend(threat: float, escape: Vector2, dt: float) -> bool:
	if threat == INF:
		ai_reacting = false
		return false

	var facing_player: bool = ai_target.is_player
	if facing_player and not ai_reacting:
		ai_reacting = true
		ai_reaction_left = randf_range(arena.balance.ai_player_reaction_seconds.x, arena.balance.ai_player_reaction_seconds.y)
	elif facing_player:
		ai_reaction_left = maxf(0.0, ai_reaction_left - dt)
	if (attack_lock > 0.0 and not basic_swing) or not pending_skills.is_empty(): return false

	var guard_windup: float = arena.balance.guard_windup
	var can_guard_hit := false
	if guard != null:
		can_guard_hit = guard.meter > 0.0 if guard.mode == "barrier" else stamina > arena.balance.guard_hit_cost + 6.0
		if can_guard_hit and guard.phase in ["raise", "hold"]:
			guard.requested = true
			return true

	# Let the player follow up after a defense. The existing guard can finish normally.
	if facing_player and (ai_reaction_left > 0.0 or ai_defense_recovery > 0.0): return false
	if can_guard_hit and guard.phase == "idle":
		if threat >= guard_windup and threat <= guard_windup + arena.balance.ai_guard_timing_window:
			guard.requested = true
			if facing_player: ai_defense_recovery = randf_range(arena.balance.ai_player_defense_recovery.x, arena.balance.ai_player_defense_recovery.y)
			return true
		# A late guard read does not turn into an instant dodge against the player.
		if facing_player: return false
	if threat <= arena.balance.ai_dodge_timing_window and not guard_busy() and stamina > arena.balance.dash_stamina_cost + 8.0:
		dash(escape)
		if dash_left > 0.0:
			if facing_player: ai_defense_recovery = randf_range(arena.balance.ai_player_defense_recovery.x, arena.balance.ai_player_defense_recovery.y)
			return true
	return false
func ai_threat_time(target: CrownFighter) -> float:
	if attack_lock <= 0.0 or swing_hit_time < 0.0 or not $AnimationPlayer.is_playing():
		return INF
	if $AnimationPlayer.current_animation != "swing": return INF
	var remaining: float = (swing_hit_time - $AnimationPlayer.current_animation_position) / attack_speed
	if remaining < 0.0 or remaining > 0.25: return INF
	var offset := target.position - position
	if offset.length() > attack_reach() + target.radius + 12.0: return INF
	if absf(angle_difference(facing, offset.angle())) > attack_arc_radians() * 0.5 + 0.12: return INF
	return remaining

func can_act() -> bool:
	return alive and groggy_left <= 0 and exhaustion_left <= 0.0 and hitstun_left <= 0.0

## Shared, pure hitstun calculation. A floor never lengthens the base duration.
static func calculate_hitstun(power: float, duration: float, poise: float, minimum: float) -> float:
	if power <= 0.0 or duration <= 0.0 or poise > power: return 0.0
	return maxf(clampf(minimum, 0.0, duration), duration * (1.0 - clampf(poise / power, 0.0, 1.0) * 0.5))

func effective_poise() -> float:
	var result: float = definition.poise
	for modifier in poise_modifiers.values(): result += float(modifier.amount)
	return maxf(0.0, result)

## Named bonuses can be negative. Negative duration persists until removed.
func set_poise_modifier(source: String, amount: float, duration: float = -1.0) -> void:
	if is_zero_approx(amount) or is_zero_approx(duration):
		remove_poise_modifier(source)
		return
	poise_modifiers[source] = {"amount": amount, "left": duration}

func set_effective_poise(source: String, value: float, duration: float = -1.0) -> void:
	remove_poise_modifier(source)
	var raw: float = definition.poise
	for modifier in poise_modifiers.values(): raw += float(modifier.amount)
	set_poise_modifier(source, maxf(0.0, value) - raw, duration)

func remove_poise_modifier(source: String) -> void:
	poise_modifiers.erase(source)

func update_poise_modifiers(dt: float) -> void:
	for key in poise_modifiers.keys():
		var modifier: Dictionary = poise_modifiers[key]
		if float(modifier.left) < 0.0: continue
		modifier.left = maxf(0.0, float(modifier.left) - dt)
		if modifier.left <= 0.0: poise_modifiers.erase(key)

func update_hitstun(dt: float) -> void:
	if hitstun_left > 0.0:
		var previous: float = hitstun_left
		hitstun_left = maxf(0.0, hitstun_left - dt)
		if hitstun_left <= 0.0:
			hitstun_immunity = maxf(0.0, arena.balance.hitstun_recovery_immunity - maxf(0.0, dt - previous))
	else:
		hitstun_immunity = maxf(0.0, hitstun_immunity - dt)

func reset_hitstun() -> void:
	hitstun_left = 0.0
	hitstun_immunity = 0.0
	poise_modifiers.clear()

func apply_hitstun(power: float, duration: float) -> bool:
	if not can_act() or hitstun_immunity > 0.0: return false
	var seconds: float = calculate_hitstun(power, duration, effective_poise(), arena.balance.hitstun_min_duration)
	if seconds <= 0.0: return false
	hitstun_left = seconds
	var recovery: float = attack_lock if swing_hit_committed or not swing_active else 0.0
	interrupt_actions()
	attack_lock = recovery
	arena.float_text(position, "경직!", Color("ffd29a"))
	return true

func can_start_cancel_action() -> bool:
	return can_act() and not guard_busy() and dash_left <= 0.0 and (attack_lock <= 0.0 or basic_swing)

## Valid dash/skill may cancel an active basic swing without refunding costs.
func cancel_basic_attack() -> void:
	if not basic_swing: return
	swing_active = false
	basic_swing = false
	swing_hit_committed = false
	attack_lock = 0.0
	swing_power = 1.0
	remove_poise_modifier("swing")
	$AnimationPlayer.stop()
	$Visual.position = Vector2.ZERO
	reset_weapon_pose()

func clear_basic_preparation() -> void:
	pass

func cancel_special_action() -> void:
	pass

func interrupt_actions() -> void:
	clear_basic_preparation()
	cancel_special_action()
	for key in pending_skills.keys(): remove_poise_modifier("skill_" + str(key))
	pending_skills.clear()
	for animator in ability_players.values(): animator.stop()
	reset_guard()
	dash_left = 0.0
	velocity = Vector2.ZERO
	$Visual.position = Vector2.ZERO
	reset_weapon_pose()
	swing_power = 1.0

func attack_stagger_power() -> float:
	return definition.attack_stagger_power

func attack_stagger_duration() -> float:
	return definition.attack_stagger_duration

func can_guard() -> bool:
	return guard != null

func trigger_exhaustion() -> void:
	if exhaustion_left > 0.0 or not alive: return
	exhaustion_left = arena.balance.exhaustion_duration
	stamina = 0.0
	interrupt_actions()
	arena.float_text(position, "탈진!", Color("ff9f70"))

func reset_weapon_pose() -> void:
	$Visual/WeaponPivot1.rotation = 0.0
	$Visual/WeaponPivot1/WeaponPivot2.rotation = 0.0

func spend_stamina(cost: float) -> bool:
	if not can_act() or stamina < cost: return false
	stamina = maxf(0.0, stamina - cost)
	if stamina <= 0.0:
		trigger_exhaustion()
		return false
	return true

func guard_busy() -> bool:
	return guard != null and guard.is_busy()

func reset_guard() -> void:
	if guard != null: guard.reset()
	attack_lock = 0.0
	swing_active = false
	basic_swing = false
	swing_hit_committed = false
	remove_poise_modifier("swing")
	$AnimationPlayer.stop()

func perform_swing(multiplier: float = 1.0, use_attack_cooldown: bool = true) -> bool:
	if not can_start_cancel_action(): return false
	if use_attack_cooldown and (cooldown.attack > 0 or attack_lock > 0 or not pending_skills.is_empty()): return false
	if not spend_stamina(arena.balance.attack_stamina_cost): return false
	if not use_attack_cooldown: cancel_basic_attack()
	swing_power = multiplier
	swing_active = true
	basic_swing = use_attack_cooldown
	swing_hit_committed = false
	var swing: Animation = $AnimationPlayer.get_animation("swing")
	attack_lock = swing.length / attack_speed
	if use_attack_cooldown:
		cooldown.attack = maxf(definition.attack_cooldown / attack_speed, attack_lock)
	$AnimationPlayer.play("swing", -1, attack_speed)
	arena.sound("swing", self)
	return true

func attack() -> void:
	perform_swing()

func attack_reach() -> float:
	var base_reach: float = attack_range_override if attack_range_override > 0 else arena.balance.attack_range
	return base_reach * body_scale

func attack_arc_radians() -> float:
	if attack_arc_override_degrees > 0.0:
		return deg_to_rad(attack_arc_override_degrees)
	return arena.balance.attack_arc

func resolve_attack_hit() -> void:
	if not swing_active or not can_act() or blocking or not arena.active(): return
	if $AnimationPlayer.current_animation != "swing": return
	if swing_hit_time >= 0.0 and $AnimationPlayer.current_animation_position + 0.001 < swing_hit_time: return
	swing_hit_committed = true
	var reach := attack_reach()
	var arc := attack_arc_radians()
	var count = 0
	arena.fx_ring(position + Vector2.from_angle(facing) * 50, reach * 0.5, attack_color(), 0.15)
	for target in arena.targets(self):
		var offset: Vector2 = target.position - position
		if offset.length() < reach + target.radius and (arc >= TAU or absf(angle_difference(facing, offset.angle())) < arc * 0.5):
			var critical = randf() < crit
			arena.deal_damage(target, damage * swing_power * (arena.balance.crit_damage_multiplier if critical else 1.0), self, Vector2.ZERO, attack_stagger_power(), attack_stagger_duration())
			target.position += offset.normalized() * arena.balance.hit_pushback
			count += 1
			if not can_act() or (attack_target_limit > 0 and count >= attack_target_limit): break
	arena.add_xp(self, 0.35)

func dash(direction: Vector2 = Vector2.ZERO) -> void:
	if not can_start_cancel_action() or cooldown.dash > 0.0 or not pending_skills.is_empty(): return
	if not spend_stamina(arena.balance.dash_stamina_cost): return
	cancel_basic_attack()
	if direction.length() < 0.1: direction = Vector2.from_angle(facing)
	dash_left = arena.balance.dash_seconds
	dash_velocity = direction.normalized() * arena.balance.dash_speed
	invuln = arena.balance.dash_immunity_seconds
	cooldown.dash = arena.balance.dash_cooldown * dash_mult
	arena.sound("dash", self)

func equip_ability(slot: String, ability: CrownAbility) -> void:
	if not cooldown.has(slot) or ability.animation == null: return
	abilities[slot] = ability
	if not ability_players.has(slot):
		var animator = AnimationPlayer.new()
		animator.name = "Skill_" + slot.to_upper()
		add_child(animator)
		ability_players[slot] = animator
	var animator = ability_players[slot]
	animator.stop()
	pending_skills.erase(slot)
	if animator.has_animation_library(""): animator.remove_animation_library("")
	var library = AnimationLibrary.new()
	library.add_animation("cast", ability.animation)
	animator.add_animation_library("", library)

func skill(key: String) -> void:
	if not abilities.has(key) or not can_start_cancel_action() or not arena.active() or cooldown[key] > 0: return
	var ability: CrownAbility = abilities[key]
	cancel_basic_attack()
	var duration: float = ability.poise_duration if ability.poise_duration > 0.0 else ability.animation.length
	set_poise_modifier("skill_" + key, ability.poise_bonus, duration)
	cooldown[key] = ability.cooldown
	pending_skills[key] = ability
	ability_players[key].play("cast")
	arena.sound("skill", self)

## Called by the ability Animation method track, not by input or a timer.
func resolve_skill_hit(key: String) -> void:
	if not pending_skills.has(key): return
	var ability: CrownAbility = pending_skills[key]
	pending_skills.erase(key)
	if not can_act() or not arena.active(): return
	ability.execute(self)
	arena.add_xp(self, ability.experience)

func add_groggy(amount: float) -> void:
	if not alive or groggy_left > 0 or groggy_immunity > 0: return
	groggy = minf(arena.balance.groggy_threshold, groggy + maxf(0, amount))
	groggy_decay_left = arena.balance.groggy_decay_delay
	if groggy < arena.balance.groggy_threshold: return
	groggy_left = arena.balance.groggy_duration
	interrupt_actions()
	arena.float_text(position, "그로기!", Color("ffcf63"))

func update_groggy(dt: float) -> void:
	if groggy_left > 0:
		groggy_left = maxf(0, groggy_left - dt)
		if groggy_left == 0:
			groggy = 0
			groggy_immunity = arena.balance.groggy_recovery_immunity
		return
	groggy_immunity = maxf(0, groggy_immunity - dt)
	var decay_dt = maxf(0, dt - groggy_decay_left)
	groggy_decay_left = maxf(0, groggy_decay_left - dt)
	groggy = maxf(0, groggy - arena.balance.groggy_decay_rate * decay_dt)

func reset_groggy() -> void:
	groggy = 0
	groggy_left = 0
	groggy_decay_left = 0
	groggy_immunity = 0

func grow_level() -> void:
	if level >= arena.balance.max_level: return
	level += 1
	stat_points += 1
	var hp_gain = (arena.balance.final_hp - arena.balance.starting_hp) / (arena.balance.max_level - 1)
	max_hp += hp_gain
	base_stats.max_hp += hp_gain
	hp = minf(max_hp, hp + max_hp * arena.balance.level_heal)

func attack_color() -> Color:
	return Color("ff8258") if is_player and Meta.rune_level("ember") > 0 else tint.lightened(0.3)

func update_visual() -> void:
	# Source sprite faces upward (-PI/2); align it with combat facing.
	$Visual.rotation = facing + PI / 2.0
	$Visual.scale = Vector2.ONE * body_scale
	$Visual/Body.modulate = Color("ff9476") if exhaustion_left > 0.0 else (Color("ffd29a") if hitstun_left > 0.0 else (Color("ffd47b") if boss_flag else Color.WHITE))
	$NameLabel.text = "%s · %s · Lv.%d" % [display_name, CrownBuilds.profile_title(ai_build), level] if not is_player else "%s · Lv.%d" % [display_name, level]
	$Health.value = hp / max_hp * 100
	if guard != null: guard.update_visual()
	queue_redraw()

func _draw() -> void:
	if not alive: return
	draw_circle(Vector2(0, 18), 29 * body_scale, Color(0, 0, 0, 0.25))
	if evolutions.size() > 0:
		draw_arc(Vector2.ZERO, 32 * body_scale, 0, TAU, 32, tint, evolutions.size() + 1)
	if groggy_left > 0:
		draw_arc(Vector2(0, -75), 10, 0, TAU * groggy_left / arena.balance.groggy_duration, 16, Color("ffc664"), 3)
	if show_attack_range and arena != null:
		AttackRangePreview.draw_sector(self, attack_reach(), attack_arc_radians(), facing, 42.0 * body_scale)
