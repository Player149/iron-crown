extends "res://scripts/fighter.gd"
## Spearman: long normal reach, simple reduced-damage guard, contact damage on E lunge.
@export var lunge_cooldown: float = 7.0
@export var lunge_duration: float = 0.20
@export var lunge_speed: float = 650.0
@export var lunge_damage_fraction: float = 0.5
@export var lunge_stagger_power: float = 30.0
@export var lunge_stagger_duration: float = 0.24
@export var lunge_poise_bonus: float = 10.0
@export var spear_reach := 138.0
@export var spear_arc_degrees := 42.0
@export var lunge_contact_padding := 24.0
var lunge_left: float = 0.0
var lunge_hits: Dictionary = {}

func _ready() -> void:
	super._ready()
	class_name_text = definition.title
	attack_range_override = spear_reach
	attack_arc_override_degrees = spear_arc_degrees

func clear_match_action() -> void:
	cancel_special_action()

func cancel_special_action() -> void:
	lunge_left = 0.0
	lunge_hits.clear()
	remove_poise_modifier("lunge")

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if not arena.active() or not can_start_cancel_action() or cooldown.e > 0.0: return
	cancel_basic_attack()
	set_poise_modifier("lunge", lunge_poise_bonus, lunge_duration)
	cooldown.e = lunge_cooldown
	lunge_left = lunge_duration
	lunge_hits.clear()
	dash_left = lunge_duration
	dash_velocity = Vector2.from_angle(facing) * lunge_speed
	arena.fx_ring(position, 22, Color("86c8fb"), 0.20)
	hit_lunge_path(position, position)

func tick(dt: float) -> void:
	var old_position: Vector2 = position
	super.tick(dt)
	if lunge_left <= 0.0: return
	if not can_act():
		cancel_special_action()
		return
	hit_lunge_path(old_position, position)
	lunge_left = maxf(0.0, lunge_left - dt)

func dash(direction: Vector2 = Vector2.ZERO) -> void:
	if lunge_left > 0.0: return
	super.dash(direction)

func hit_lunge_path(start: Vector2, finish: Vector2) -> void:
	if not arena.active(): return
	var step: Vector2 = finish - start
	for target in arena.targets(self):
		if lunge_hits.has(target.get_instance_id()): continue
		var t: float = clampf((target.position - start).dot(step) / maxf(1.0, step.length_squared()), 0.0, 1.0)
		var closest: Vector2 = start + step * t
		if closest.distance_to(target.position) > target.radius + lunge_contact_padding: continue
		lunge_hits[target.get_instance_id()] = true
		arena.deal_damage(target, damage * lunge_damage_fraction, self, Vector2.ZERO, lunge_stagger_power, lunge_stagger_duration)
		if not can_act() or lunge_left <= 0.0: break

func ai_preferred_distance(reach: float) -> float:
	return reach - 32.0

func ai_use_class_skill(distance: float, reach: float, retreating: bool, target_ready: bool) -> bool:
	if retreating: return false
	var opponent := ai_target as CrownFighter
	if opponent != null and opponent.can_act() and cooldown.dash <= 0.0:
		var enemy_reach := opponent.attack_reach() + radius
		var back := -Vector2.from_angle(facing)
		var bounds: Rect2 = arena.fighter_bounds(self).grow(-31.0)
		if enemy_reach < reach - 20.0 and distance > 44.0 and distance < enemy_reach - 18.0:
			if bounds.has_point(position + back * 105.0) and stamina > arena.balance.dash_stamina_cost + 26.0:
				dash(back)
				return dash_left > 0.0
	if not target_ready or cooldown.e > 0.0: return false
	var contact_range: float = ai_target.radius + lunge_contact_padding
	var travel := lunge_duration * lunge_speed
	if distance > travel + contact_range - 12.0: return false
	# Lunge across a nearby fighter to make space, or use it to catch a target outside normal reach.
	if distance > 44.0 and distance < reach - 6.0 and ai_target.hp > damage * lunge_damage_fraction: return false
	var landing := position + Vector2.from_angle(facing) * travel
	if not (arena.fighter_bounds(self) as Rect2).grow(-31.0).has_point(landing): return false
	skill("e")
	return cooldown.e > 0.0

func ai_threat_time(target: CrownFighter) -> float:
	if lunge_left <= 0.0 or lunge_hits.has(target.get_instance_id()):
		return super.ai_threat_time(target)
	var direction := dash_velocity.normalized()
	var offset := target.position - position
	var along := offset.dot(direction)
	var contact := target.radius + lunge_contact_padding
	var sideways := absf(offset.cross(direction))
	if sideways >= contact or along < -contact: return INF
	var time := maxf(0.0, along - sqrt(contact * contact - sideways * sideways)) / lunge_speed
	return time if time <= lunge_left else INF
