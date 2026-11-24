class_name CrownBalance
extends Resource

@export_category("Base growth")
@export var max_level: int = 25
@export var starting_hp: float = 100.0
@export var final_hp: float = 285.0
@export_category("Groggy - provisional balance")
@export var groggy_threshold: float = 100.0
@export var groggy_hit: float = 6.0
@export var groggy_block: float = 0.0
@export var groggy_duration: float = 2.0
@export var groggy_decay_delay: float = 0.0
@export var groggy_decay_rate: float = 2.0
@export var perfect_guard_groggy: float = 60.0
@export var groggy_recovery_immunity: float = 1.0
@export_category("Hitstun")
@export var hitstun_min_duration: float = 0.10
@export var hitstun_recovery_immunity: float = 0.50
@export_category("Stamina - timed combat")
@export var stamina_max: float = 100.0
@export var stamina_regen: float = 35.0
@export var exhaustion_duration: float = 1.0
@export var attack_stamina_cost: float = 10.0
@export var dash_stamina_cost: float = 22.0
@export var guard_start_cost: float = 0.0
@export var guard_drain_per_second: float = 13.0
@export var guard_hit_cost: float = 12.0
@export var blocked_attack_stamina_multiplier: float = 1.5
@export var perfect_guard_window: float = 0.10
@export_category("Guard timing - seconds, animation scales to match")
@export_range(0.01, 2.0, 0.01, "or_greater") var guard_windup: float = 0.10
@export_range(0.01, 2.0, 0.01, "or_greater") var guard_recovery: float = 0.16
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

@export_group("Experience and movement")
@export var xp_base := 30.0
@export var xp_linear := 12.0
@export var xp_exponent := 1.2
@export var xp_curve := 2.7
@export var sprint_multiplier := 1.42
@export var guard_move_multiplier := 0.5
@export var swing_move_multiplier := 0.75
@export var dash_seconds := 0.17
@export var dash_speed := 690.0
@export var dash_immunity_seconds := 0.22
@export var dash_cooldown := 2.15
@export var crit_damage_multiplier := 1.7
@export var hit_pushback := 5.0
@export var hit_xp_per_damage := 0.028
@export var hit_xp_cap := 2.0

@export_group("AI behavior")
@export var ai_detection_radius := 780.0
@export var ai_retarget_seconds := 0.4
@export var ai_retreat_hp_ratio := 0.28
@export var ai_retreat_seconds := 1.15
@export var ai_retreat_cooldown := 6.0
@export var ai_player_reaction_seconds := Vector2(0.065, 0.135)
@export var ai_player_defense_recovery := Vector2(0.85, 1.25)
@export var ai_guard_timing_window := 0.045
@export var ai_dodge_timing_window := 0.11

@export_group("Legacy arena and economy")
@export var duel_size := Vector2(900.0, 540.0)
@export var duel_spawn_distance := 360.0
@export var duel_level := 6
@export var revive_costs := PackedInt32Array([800, 1800, 4000])
@export var revive_immunity := 3.0
@export var kill_gold_base := 70
@export var kill_gold_per_level := 20
@export var level_gold_base := 28
@export var level_gold_per_level := 5

func xp_needed(level: int) -> float:
	return maxf(1.0, floor(xp_base + level * xp_linear + pow(level, xp_exponent) * xp_curve))
