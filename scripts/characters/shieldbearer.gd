extends "res://scripts/fighter.gd"
## Shield E: a timed 25% normal-attack buff, separate from Guard's barrier meter.
@export var buff_cooldown: float = 12.0
@export var buff_duration: float = 6.0
@export var buff_multiplier := 1.25
var useless_left: float = 0.0

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
	if not arena.active() or not can_act() or guard_busy() or attack_lock > 0.0 or cooldown.e > 0.0: return
	cooldown.e = buff_cooldown
	damage *= buff_multiplier
	useless_left = buff_duration
	arena.float_text(position, "쓸모없음 +%d%%!" % roundi((buff_multiplier - 1.0) * 100.0), Color("e0beff"))
	arena.fx_ring(position, 50, Color("bda0ed"), 0.35)

func clear_match_action() -> void:
	if useless_left > 0.0: damage /= buff_multiplier
	useless_left = 0.0

func attack() -> void:
	super.attack()

func ai_preferred_distance(reach: float) -> float:
	return reach * 0.55

func ai_use_class_skill(distance: float, reach: float, retreating: bool, target_ready: bool) -> bool:
	if retreating or not target_ready or distance > reach - 6.0 or cooldown.e > 0.0: return false
	if stamina <= arena.balance.attack_stamina_cost + 3.0: return false
	skill("e")
	return cooldown.e > 0.0
