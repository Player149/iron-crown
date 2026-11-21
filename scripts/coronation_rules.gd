class_name CrownCoronationRules
extends Resource

@export_group("Match and zone")
@export var match_seconds := 480.0
@export var map_side := 5340.0
## Start and finish seconds of the three contractions, in chronological order.
@export var shrink_starts := Vector3(95.0, 155.0, 215.0)
@export var shrink_ends := Vector3(120.0, 180.0, 240.0)
@export var shrink_radii := Vector3(2900.0, 2200.0, 1450.0)
@export var hazard_interval := 0.5
@export var hazard_hp_fraction := 0.10
@export var zone_ai_margin := 95.0

@export_group("Tournament")
@export var ring_side := 510.0
@export var ring_gap := 120.0
@export var bout_seconds := 13.0
@export var round_break_seconds := 1.25
@export var final_break_seconds := 3.0
@export var bout_spawn_separation := 150.0
@export var bout_spawn_protection := 0.45
@export var bout_damage_multiplier := 1.25
@export var bout_damage_ramp := 0.60
@export var bout_ramp_start := 0.6

@export_group("Iron points")
@export var kill_score := 1000
@export_range(0.0, 0.5) var assist_max_ratio := 0.5
@export var assist_window := 5.0
@export var champion_score := 2000
@export var field_score := 400
@export var brute_score := 200
@export var roamer_score := 100

@export_group("Growth and bonuses")
@export var passive_level_seconds := 32.0
@export var zone_level_seconds := 20.0
@export var kill_level_fraction := 0.65
@export var field_level_fraction := 0.70
@export var brute_level_fraction := 0.42
@export var roamer_level_fraction := 0.24
@export var field_heal := 0.25
@export var roamer_heal := 0.12
@export var haste_seconds := 8.0
@export var haste_movement := 1.15
@export var slow_seconds := 2.0
@export var slow_movement := 0.80

@export_group("Field and spawning")
@export var xp_zone_radius := 195.0
@export var monster_field_radius := 235.0
@export var site_jitter := 250.0
@export var site_center_clearance := 610.0
@export var roaming_monster_offset := 340.0
@export var roaming_monster_leash := 260.0
@export var roaming_brute_chance := 0.25
@export var field_respawn := 28.0
@export var roamer_respawn := 14.0
@export var resource_count := 50
@export var resource_interval := 1.5
@export var resource_hp := Vector3(72.0, 48.0, 24.0)
@export var resource_level_fractions := Vector3(0.28, 0.18, 0.10)
@export var terrain_mark_count := 420
@export var spawn_attempts := 70
@export var spawn_border := 130.0
@export var center_spawn_clearance := 440.0
@export var site_spawn_margin := 90.0
@export var fighter_spawn_clearance := 320.0
@export var roamer_spawn_clearance := 230.0
@export var resource_spawn_clearance := 85.0
@export var fighter_respawn := 4.0
@export var spawn_protection := 2.0
@export var ai_roam_period := 16.0

