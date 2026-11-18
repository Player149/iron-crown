extends "res://scripts/fighter.gd"
## Spearman: long normal reach, simple reduced-damage guard, contact damage on E lunge.
const LUNGE_COOLDOWN: float = 7.0
const LUNGE_DURATION: float = 0.20
const LUNGE_SPEED: float = 650.0
const LUNGE_DAMAGE: float = 0.5
var lunge_left: float = 0.0
var lunge_hits: Dictionary = {}

func _ready() -> void:
	super._ready()
	class_name_text = definition.title
	attack_range_override = 138.0
	attack_arc_override_degrees = 42.0

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if not arena.active() or not can_act() or guard_busy() or attack_lock > 0.0 or cooldown.e > 0.0 or dash_left > 0.0: return
	cooldown.e = LUNGE_COOLDOWN
	lunge_left = LUNGE_DURATION
	lunge_hits.clear()
	dash_left = LUNGE_DURATION
	dash_velocity = Vector2.from_angle(facing) * LUNGE_SPEED
	arena.fx_ring(position, 22, Color("86c8fb"), 0.20)
	hit_lunge_path(position, position)

func tick(dt: float) -> void:
	var old_position: Vector2 = position
	super.tick(dt)
	if lunge_left <= 0.0: return
	if not can_act():
		lunge_left = 0.0
		return
	hit_lunge_path(old_position, position)
	lunge_left = maxf(0.0, lunge_left - dt)

func hit_lunge_path(start: Vector2, finish: Vector2) -> void:
	if not arena.active(): return
	var step: Vector2 = finish - start
	for target in arena.targets(self):
		if lunge_hits.has(target.get_instance_id()): continue
		var t: float = clampf((target.position - start).dot(step) / maxf(1.0, step.length_squared()), 0.0, 1.0)
		var closest: Vector2 = start + step * t
		if closest.distance_to(target.position) > target.radius + 24.0: continue
		lunge_hits[target.get_instance_id()] = true
		arena.deal_damage(target, damage * LUNGE_DAMAGE, self)
