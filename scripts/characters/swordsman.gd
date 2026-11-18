extends "res://scripts/fighter.gd"
## Sword E: an independently cooled, 125% swing. The ordinary attack cooldown is untouched.
const EXTRA_SWING_COOLDOWN: float = 5.0

func _ready() -> void:
	super._ready()
	class_name_text = definition.title

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if not arena.active() or cooldown.e > 0.0: return
	if perform_swing(1.25, false):
		cooldown.e = EXTRA_SWING_COOLDOWN
		arena.float_text(position, "추가 공격!", Color("e3eaff"))
