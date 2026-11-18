extends "res://scripts/fighter.gd"
## Hold attack for up to 3 seconds. Release for a 1.0 - 2.5x authored swing.
const MAX_CHARGE: float = 3.0
const IRONMAN_COOLDOWN: float = 12.0
var charging: bool = false
var charge_time: float = 0.0
var ai_charge_goal: float = 1.0

func _ready() -> void:
	super._ready()
	class_name_text = definition.title

func attack() -> void:
	if charging or not can_act() or guard_busy() or attack_lock > 0.0 or cooldown.attack > 0.0: return
	charging = true
	charge_time = 0.0
	ai_charge_goal = randf_range(0.7, MAX_CHARGE)

func tick(dt: float) -> void:
	super.tick(dt)
	if not charging: return
	if not can_act() or not arena.active():
		charging = false
		charge_time = 0.0
		return
	charge_time = minf(MAX_CHARGE, charge_time + dt)
	if is_player:
		var held: bool = (Input.is_action_pressed("attack") and not arena.touch_mode) or arena.touch_attack
		if not held: release_charge()
	elif charge_time >= ai_charge_goal:
		release_charge()
	queue_redraw()

func release_charge() -> void:
	if not charging: return
	var power: float = 1.0 + 1.5 * clampf(charge_time / MAX_CHARGE, 0.0, 1.0)
	charging = false
	charge_time = 0.0
	perform_swing(power)
	queue_redraw()

func dash(direction: Vector2 = Vector2.ZERO) -> void:
	if charging: return
	super.dash(direction)

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if charging or not can_act() or not arena.active() or guard_busy() or attack_lock > 0.0 or cooldown.e > 0.0: return
	cooldown.e = IRONMAN_COOLDOWN
	hp = minf(max_hp, hp + max_hp * 0.25)
	arena.float_text(position, "철인 +25%!", Color("8df4c2"))
	arena.fx_ring(position, 48, Color("7ddeae"), 0.35)

func _draw() -> void:
	super._draw()
	if charging and alive:
		draw_arc(Vector2.ZERO, 37 * body_scale, -PI / 2, -PI / 2 + TAU * (charge_time / MAX_CHARGE), 24, Color("ffbd69"), 4)
