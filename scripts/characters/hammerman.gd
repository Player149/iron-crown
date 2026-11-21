extends "res://scripts/fighter.gd"
## Hold attack for up to 3 seconds. Release for a 1.0 - 2.5x authored swing.
@export var max_charge_seconds: float = 3.0
@export var ironman_cooldown: float = 12.0
@export var charge_bonus_multiplier := 1.5
@export var ironman_heal := 0.25
@export var quick_charge_seconds := 0.38
@export var safe_charge_seconds := 0.95
var charging: bool = false
var charge_time: float = 0.0

func _ready() -> void:
	super._ready()
	class_name_text = definition.title

func clear_match_action() -> void:
	charging = false
	charge_time = 0.0

func attack() -> void:
	if charging or not can_act() or guard_busy() or attack_lock > 0.0 or cooldown.attack > 0.0: return
	charging = true
	charge_time = 0.0

func tick(dt: float) -> void:
	super.tick(dt)
	if not charging: return
	if not can_act() or not arena.active():
		charging = false
		charge_time = 0.0
		return
	charge_time = minf(max_charge_seconds, charge_time + dt)
	if is_player:
		var held: bool = (Input.is_action_pressed("attack") and not arena.touch_mode) or arena.touch_attack
		if not held: release_charge()
	else:
		ai_update_charge()
	queue_redraw()

func release_charge() -> void:
	if not charging: return
	var power: float = 1.0 + charge_bonus_multiplier * clampf(charge_time / max_charge_seconds, 0.0, 1.0)
	charging = false
	charge_time = 0.0
	perform_swing(power)
	queue_redraw()

func dash(direction: Vector2 = Vector2.ZERO) -> void:
	if charging and is_player: return
	super.dash(direction)
	if dash_left > 0.0 and charging:
		charging = false
		charge_time = 0.0

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if charging or not can_act() or not arena.active() or guard_busy() or attack_lock > 0.0 or cooldown.e > 0.0: return
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
		charging = false
		charge_time = 0.0
		return
	var distance: float = position.distance_to(ai_target.position)
	var reach: float = attack_reach() + ai_target.radius
	var opponent := ai_target as CrownFighter
	if ai_target_is_open() and distance <= reach - 6.0:
		var quick_hit := distance >= reach - 25.0 or (opponent != null and opponent.attack_lock > 0.0)
		if charge_time >= (quick_charge_seconds if quick_hit else safe_charge_seconds):
			release_charge()
	elif charge_time >= max_charge_seconds:
		charging = false
		charge_time = 0.0
