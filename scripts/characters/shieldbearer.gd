extends "res://scripts/fighter.gd"
## Shield E: a timed 25% normal-attack buff, separate from Guard's barrier meter.
@export var buff_cooldown: float = 12.0
@export var buff_duration: float = 6.0
@export var buff_multiplier := 1.25
@export var buff_poise_bonus: float = 0.0
@export_range(0.0, 1.0) var frontal_damage_reduction: float = 0.25
@export_range(0.0, 180.0) var frontal_half_angle_degrees: float = 60.0
var useless_left: float = 0.0

func incoming_damage_multiplier(direction_to_hit: Vector2) -> float:
	if direction_to_hit.is_zero_approx():
		return 1.0
	if absf(angle_difference(facing, direction_to_hit.angle())) <= deg_to_rad(frontal_half_angle_degrees):
		return 1.0 - frontal_damage_reduction
	return 1.0

func _ready() -> void:
	super._ready()
	class_name_text = definition.title

func tick(dt: float) -> void:
	super.tick(dt)
	if useless_left > 0.0:
		useless_left = maxf(0.0, useless_left - dt)
		if useless_left <= 0.0: damage /= buff_multiplier

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if not arena.active() or not can_start_cancel_action() or cooldown.e > 0.0: return
	cancel_basic_attack()
	set_poise_modifier("shield_buff", buff_poise_bonus, buff_duration)
	cooldown.e = buff_cooldown
	damage *= buff_multiplier
	useless_left = buff_duration
	arena.float_text(position, "쓸모없음 +%d%%!" % roundi((buff_multiplier - 1.0) * 100.0), Color("e0beff"))
	arena.fx_ring(position, 50, Color("bda0ed"), 0.35)

func clear_match_action() -> void:
	if useless_left > 0.0: damage /= buff_multiplier
	useless_left = 0.0
	remove_poise_modifier("shield_buff")

func attack() -> void:
	super.attack()

func ai_preferred_distance(reach: float) -> float:
	return reach * 0.55

func ai_use_class_skill(distance: float, reach: float, retreating: bool, target_ready: bool) -> bool:
	if retreating or not target_ready or distance > reach - 6.0 or cooldown.e > 0.0: return false
	if stamina <= arena.balance.attack_stamina_cost + 3.0: return false
	skill("e")
	return cooldown.e > 0.0
