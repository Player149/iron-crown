extends "res://scripts/fighter.gd"
## Sword E: an independently cooled, 125% swing. The ordinary attack cooldown is untouched.
@export var extra_swing_cooldown: float = 5.0

@export var extra_swing_damage := 1.25
@export var extra_swing_stagger_power: float = 30.0
@export var extra_swing_stagger_duration: float = 0.25
@export var extra_swing_poise_bonus: float = 0.0

func _ready() -> void:
	super._ready()
	class_name_text = definition.title

func skill(key: String) -> void:
	if key != "e":
		super.skill(key)
		return
	if not arena.active() or cooldown.e > 0.0: return
	if perform_swing(extra_swing_damage, false):
		set_poise_modifier("swing", extra_swing_poise_bonus, attack_lock)
		cooldown.e = extra_swing_cooldown
		arena.float_text(position, "추가 공격!", Color("e3eaff"))

func attack_stagger_power() -> float:
	return definition.attack_stagger_power if basic_swing else extra_swing_stagger_power

func attack_stagger_duration() -> float:
	return definition.attack_stagger_duration if basic_swing else extra_swing_stagger_duration

func ai_use_class_skill(distance: float, reach: float, retreating: bool, target_ready: bool) -> bool:
	if retreating or not target_ready or distance > reach - 6.0 or cooldown.e > 0.0: return false
	# Use the extra swing during the normal attack's cooldown or to finish an opening.
	if cooldown.attack <= 0.0 and ai_target.hp > damage * extra_swing_damage: return false
	if stamina <= arena.balance.attack_stamina_cost + 3.0: return false
	skill("e")
	return cooldown.e > 0.0
