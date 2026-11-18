extends "res://scripts/fighter.gd"
## Shield E: a timed 25% normal-attack buff, separate from Guard's barrier meter.
const USELESS_COOLDOWN: float = 12.0
const USELESS_DURATION: float = 6.0
var useless_left: float = 0.0

func _ready() -> void:
	super._ready()
	class_name_text = definition.title

func tick(dt: float) -> void:
	super.tick(dt)
	if useless_left > 0.0:
		useless_left = maxf(0.0, useless_left - dt)
		if useless_left <= 0.0: damage /= 1.25

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if not arena.active() or not can_act() or guard_busy() or attack_lock > 0.0 or cooldown.e > 0.0: return
	cooldown.e = USELESS_COOLDOWN
	useless_left = USELESS_DURATION
	arena.float_text(position, "쓸모없음 +25%!", Color("e0beff"))
	arena.fx_ring(position, 50, Color("bda0ed"), 0.35)

func attack() -> void:
	perform_swing(1.25 if useless_left > 0.0 else 1.0)
