class_name CrownBalance
extends Resource

@export_category("Base growth")
@export var max_level: int = 40
@export var starting_hp: float = 100.0
@export var final_hp: float = 400.0
@export_category("Groggy - provisional balance")
@export var groggy_threshold: float = 100.0
@export var groggy_hit: float = 20.0
@export var groggy_block: float = 30.0
@export var groggy_duration: float = 1.3333333
@export var groggy_decay_delay: float = 3.0
@export var groggy_decay_rate: float = 15.0
@export var groggy_recovery_immunity: float = 1.0
@export_category("Stamina - timed combat")
@export var stamina_max: float = 100.0
@export var stamina_regen: float = 35.0
@export var attack_stamina_cost: float = 10.0
@export var dash_stamina_cost: float = 22.0
@export var guard_start_cost: float = 0.0
@export var guard_drain_per_second: float = 13.0
@export var guard_hit_cost: float = 12.0
@export var guard_windup: float = 0.14
@export var guard_recovery: float = 0.22
@export_category("Combat")
@export var combat_duration: float = 5.0
@export var regen_delay: float = 5.0
@export var health_regen: float = 0.1
@export var level_heal: float = 0.15
@export var attack_range: float = 84.0
@export var attack_arc: float = 1.28
@export_category("Arena")
@export var world_size: Vector2 = Vector2(3200, 2200)
@export var bot_count: int = 15
@export var monster_count: int = 28
@export var boss_interval: float = 300.0
@export var boss_duration: float = 180.0

func xp_needed(level: int) -> float:
	return floor(38.0 + level * 15.0 + pow(level, 1.28) * 5.0)
