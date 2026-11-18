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
var ai_block: float = 0
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
	if definition.ability != null: equip_ability(definition.skill_slot, definition.ability)
	base_stats = snapshot_stats()
	if is_player:
		Meta.apply_runes(self)
	$Visual/Body.modulate = Color.WHITE
	update_visual()

func snapshot_stats() -> Dictionary:
	var result = {}
	for key in ["max_hp", "damage", "speed", "attack_speed", "armor", "crit", "lifesteal", "skill_power", "xp_gain", "body_scale", "dash_mult", "block_reduction", "gold_bonus"]:
		result[key] = get(key)
	return result

func tick(dt: float) -> void:
	if not alive:
		return
	for key in cooldown:
		cooldown[key] = maxf(0, cooldown[key] - dt)
	invuln = maxf(0, invuln - dt)
	attack_lock = maxf(0, attack_lock - dt)
	if exhaustion_left > 0.0: exhaustion_left = maxf(0.0, exhaustion_left - dt)
	elif stamina <= 0.0: trigger_exhaustion()
	update_groggy(dt)
	combat_left = maxf(0, combat_left - dt)
	no_hit_time += dt
	if guard != null: guard.requested = false
	velocity = Vector2.ZERO
	if can_act():
		if is_player:
			player_control()
		else:
			ai_control(dt)
	if guard != null: guard.tick(dt)
	if not guard_busy() and attack_lock <= 0 and exhaustion_left <= 0.0:
		stamina = minf(max_stamina, stamina + arena.balance.stamina_regen * dt)
	if dash_left > 0 and can_act():
		dash_left -= dt
		velocity = dash_velocity
		arena.fx_ring(position, 12, Color("79dbf4") if is_player and Meta.rune_level("frost") > 0 else tint, 0.2)
	position += velocity * dt
	var bounds: Rect2 = arena.bounds()
	position = position.clamp(bounds.position + Vector2.ONE * 30, bounds.end - Vector2.ONE * 30)
	if no_hit_time >= arena.balance.regen_delay:
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
	if guard != null: guard.requested = Input.is_action_pressed("block") or arena.touch_block
	var multiplier = 1.42 if Input.is_action_pressed("run") or arena.touch_run else 1.0
	if guard_busy(): multiplier *= 0.5
	elif attack_lock > 0: multiplier *= 0.75
	velocity = move * speed * multiplier
	if (not arena.touch_mode and Input.is_action_pressed("attack")) or arena.touch_attack: attack()
	if Input.is_action_just_pressed("dash"): dash(move)
	for key in ["e", "r", "q"]:
		if Input.is_action_just_pressed(key): skill(key)

func ai_control(dt: float) -> void:
	ai_retarget -= dt
	ai_block = maxf(0, ai_block - dt)
	if ai_retarget <= 0 or not is_instance_valid(ai_target) or not arena.valid_target(self, ai_target):
		ai_target = arena.nearest_target(self, 780)
		ai_retarget = randf_range(0.25, 0.7)
	if ai_target == null: return
	var offset: Vector2 = ai_target.position - position
	var distance = offset.length()
	facing = offset.angle()
	var toward = 1.0 if distance > 92 else (-0.4 if distance < 58 else 0.0)
	if hp / max_hp < 0.22 and not boss_flag: toward = -0.75
	if distance < 145 and randf() < dt * 0.7: ai_block = randf_range(0.25, 0.6)
	if guard != null: guard.requested = ai_block > 0
	var side = offset.normalized().orthogonal() * sin(float(get_instance_id()) + arena.elapsed * 0.8) * (0.42 if distance < 230 else 0.0)
	velocity = (offset.normalized() * toward + side) * speed * (0.5 if guard_busy() else 1.0)
	if distance < 92: attack()
	if distance < 430 and randf() < dt * 0.5: skill("e")
	if distance < 220 and randf() < dt * 0.3: skill("r")
	if distance < 260 and randf() < dt * 0.18: skill("q")
	if distance > 210 and distance < 440 and randf() < dt * 0.24: dash(offset.normalized())

func can_act() -> bool:
	return alive and groggy_left <= 0 and exhaustion_left <= 0.0

func can_guard() -> bool:
	return guard != null

func trigger_exhaustion() -> void:
	if exhaustion_left > 0.0 or not alive: return
	exhaustion_left = arena.balance.exhaustion_duration
	stamina = 0.0
	reset_guard()
	dash_left = 0.0
	velocity = Vector2.ZERO
	pending_skills.clear()
	$AnimationPlayer.stop()
	$Visual.position = Vector2.ZERO
	reset_weapon_pose()
	swing_power = 1.0
	for animator in ability_players.values(): animator.stop()
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
	$AnimationPlayer.stop()

func perform_swing(multiplier: float = 1.0, use_attack_cooldown: bool = true) -> bool:
	if not can_act() or guard_busy() or attack_lock > 0: return false
	if use_attack_cooldown and cooldown.attack > 0: return false
	if not spend_stamina(arena.balance.attack_stamina_cost): return false
	swing_power = multiplier
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
	if not can_act() or blocking or not arena.active(): return
	var reach := attack_reach()
	var arc := attack_arc_radians()
	var count = 0
	arena.fx_ring(position + Vector2.from_angle(facing) * 50, reach * 0.5, attack_color(), 0.15)
	for target in arena.targets(self):
		var offset: Vector2 = target.position - position
		if offset.length() < reach + target.radius and (arc >= TAU or absf(angle_difference(facing, offset.angle())) < arc * 0.5):
			var critical = randf() < crit
			arena.deal_damage(target, damage * swing_power * (1.7 if critical else 1.0), self)
			target.position += offset.normalized() * 5
			count += 1
			if groggy_left > 0 or (attack_target_limit > 0 and count >= attack_target_limit): break
	arena.add_xp(self, 0.35)

func dash(direction: Vector2 = Vector2.ZERO) -> void:
	if not can_act() or cooldown.dash > 0 or attack_lock > 0 or guard_busy(): return
	if not spend_stamina(arena.balance.dash_stamina_cost): return
	if direction.length() < 0.1: direction = Vector2.from_angle(facing)
	dash_left = 0.17
	dash_velocity = direction.normalized() * 690
	invuln = 0.22
	cooldown.dash = 2.15 * dash_mult
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
	if not abilities.has(key) or not can_act() or not arena.active() or cooldown[key] > 0 or attack_lock > 0 or guard_busy(): return
	var ability: CrownAbility = abilities[key]
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
	reset_guard()
	dash_left = 0
	velocity = Vector2.ZERO
	pending_skills.clear()
	$AnimationPlayer.stop()
	$Visual.position = Vector2.ZERO
	reset_weapon_pose()
	for animator in ability_players.values(): animator.stop()
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
	level += 1
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
	$Visual/Body.modulate = Color("ff9476") if exhaustion_left > 0.0 else (Color("ffd47b") if boss_flag else Color.WHITE)
	$NameLabel.text = "%s · Lv.%d" % [display_name, level]
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
