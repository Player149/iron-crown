extends "res://scripts/fighter.gd"
## Hold attack for up to 3 seconds. Release for a 1.0 - 2.5x authored swing.
@export var max_charge_seconds: float = 3.0
@export var ironman_cooldown: float = 12.0
@export var charge_bonus_multiplier := 1.5
@export var ironman_heal := 0.25
@export var quick_charge_seconds := 0.38
@export var safe_charge_seconds := 0.95
@export var charged_stagger_power: float = 60.0
@export var charged_stagger_duration: float = 0.40
@export var charge_poise_threshold: float = 2.0
@export var charge_poise_bonus: float = 12.0
@export var ironman_poise_bonus: float = 0.0
@export var ironman_poise_duration: float = 0.5
var charging: bool = false
var charge_time: float = 0.0
var charge_release_pending: bool = false

func _ready() -> void:
	super._ready()
	class_name_text = definition.title

func clear_match_action() -> void:
	clear_basic_preparation()

func clear_basic_preparation() -> void:
	charging = false
	charge_release_pending = false
	charge_time = 0.0
	remove_poise_modifier("hammer_charge")

func attack() -> void:
	if charging or not can_start_cancel_action() or attack_lock > 0.0 or cooldown.attack > 0.0 or not pending_skills.is_empty(): return
	charging = true
	charge_time = 0.0

func tick(dt: float) -> void:
	super.tick(dt)
	if not charging: return
	if not can_act() or not arena.active():
		clear_basic_preparation()
		return
	if not charge_release_pending:
		charge_time = minf(max_charge_seconds, charge_time + dt)
		if charge_time >= charge_poise_threshold: set_poise_modifier("hammer_charge", charge_poise_bonus)
	if charge_release_pending:
		release_charge()
	elif is_player:
		var held: bool = (Input.is_action_pressed("attack") and not arena.touch_mode) or arena.touch_attack
		if not held: release_charge()
	elif dash_left <= 0.0:
		ai_update_charge()
	queue_redraw()

func release_charge() -> void:
	if not charging: return
	if not can_start_cancel_action() or not pending_skills.is_empty():
		charge_release_pending = true
		return
	var power: float = 1.0 + charge_bonus_multiplier * clampf(charge_time / max_charge_seconds, 0.0, 1.0)
	var charged: bool = charge_time >= charge_poise_threshold
	clear_basic_preparation()
	if perform_swing(power) and charged: set_poise_modifier("swing", charge_poise_bonus, attack_lock)
	queue_redraw()

func attack_stagger_power() -> float:
	return lerpf(definition.attack_stagger_power, charged_stagger_power, clampf((swing_power - 1.0) / maxf(0.001, charge_bonus_multiplier), 0.0, 1.0))

func attack_stagger_duration() -> float:
	return lerpf(definition.attack_stagger_duration, charged_stagger_duration, clampf((swing_power - 1.0) / maxf(0.001, charge_bonus_multiplier), 0.0, 1.0))

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if not can_start_cancel_action() or not arena.active() or cooldown.e > 0.0: return
	cancel_basic_attack()
	set_poise_modifier("ironman", ironman_poise_bonus, ironman_poise_duration)
	cooldown.e = ironman_cooldown
	hp = minf(max_hp, hp + max_hp * ironman_heal)
	arena.float_text(position, "철인 +%d%%!" % roundi(ironman_heal * 100.0), Color("8df4c2"))
	arena.fx_ring(position, 48, Color("7ddeae"), 0.35)

func _draw() -> void:
	super._draw()
	if charging and alive:
		draw_arc(Vector2.ZERO, 37 * body_scale, -PI / 2, -PI / 2 + TAU * (charge_time / max_charge_seconds), 24, Color("ffbd69"), 4)

func ai_preferred_distance(reach: float) -> float:
	return reach * 0.55

func ai_use_class_skill(_distance: float, _reach: float, _retreating: bool, _target_ready: bool) -> bool:
	if hp > max_hp * (1.0 - ironman_heal) or cooldown.e > 0.0 or charging: return false
	skill("e")
	return cooldown.e > 0.0

func ai_update_charge() -> void:
	if not arena.valid_target(self, ai_target) or guard_busy():
		clear_basic_preparation()
		return
	var distance: float = position.distance_to(ai_target.position)
	var reach: float = attack_reach() + ai_target.radius
	var opponent := ai_target as CrownFighter
	if ai_target_is_open() and distance <= reach - 6.0:
		var quick_hit := distance >= reach - 25.0 or (opponent != null and opponent.attack_lock > 0.0)
		if charge_time >= (quick_charge_seconds if quick_hit else safe_charge_seconds):
			release_charge()
	elif charge_time >= max_charge_seconds:
		clear_basic_preparation()
