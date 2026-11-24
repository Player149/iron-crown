class_name CrownAbility
extends Resource

@export var animation: Animation
@export var cooldown: float = 6.5
@export var experience: float = 1.3
@export_enum("area", "projectiles") var effect: String = "area"
@export var power: float = 1.0
@export var radius: float = 135.0
@export var projectile_count: int = 1
@export var spread: float = 0.18
@export var radial: bool = false
@export var projectile_speed: float = 420.0
@export var projectile_lifetime: float = 1.15
@export var pierce: int = 1
@export var dash_duration: float = 0.0
@export var dash_speed: float = 850.0
@export var invulnerability: float = 0.0
@export var heal_fraction: float = 0.0
@export_group("Hitstun")
@export var stagger_power: float = 25.0
@export var stagger_duration: float = 0.22
@export var poise_bonus: float = 0.0
## Zero uses the cast animation length.
@export var poise_duration: float = 0.0

func execute(f) -> void:
	var damage = f.damage * f.skill_power * power
	if dash_duration > 0:
		f.dash_left = dash_duration
		f.dash_velocity = Vector2.from_angle(f.facing) * dash_speed
	f.invuln = maxf(f.invuln, invulnerability)
	if effect == "area":
		f.arena.area_attack(f, radius, damage, stagger_power, stagger_duration)
	else:
		for i in projectile_count:
			var angle = i * TAU / projectile_count if radial else f.facing + (i - (projectile_count - 1) / 2.0) * spread
			f.arena.shoot(f, angle, projectile_speed, damage, projectile_lifetime, pierce, stagger_power, stagger_duration)
	f.hp = minf(f.max_hp, f.hp + f.max_hp * heal_fraction)
