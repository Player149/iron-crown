extends Node2D

# Simple server-friendly summon prototype (maximum three per owner).
var arena
var owner_fighter
var kind: String = "summon"
var lifetime: float = 13.0
var attack_cooldown: float = 0.0
var radius: float = 12.0

func tick(dt: float) -> void:
	if not is_instance_valid(owner_fighter) or not owner_fighter.alive:
		queue_free()
		return
	lifetime -= dt
	if lifetime <= 0:
		queue_free()
		return
	attack_cooldown = maxf(0, attack_cooldown - dt)
	var target = arena.nearest_target(owner_fighter, 240)
	if target == null:
		var return_spot: Vector2 = owner_fighter.position + Vector2.from_angle(float(get_instance_id() % 6) * TAU / 6.0) * 62
		position = position.move_toward(return_spot, dt * 175)
	else:
		var away: Vector2 = target.position - position
		if away.length() > 32:
			position += away.normalized() * (215 if kind == "spider" else 145) * dt
		elif attack_cooldown <= 0:
			arena.deal_damage(target, owner_fighter.damage * (0.27 if kind == "music" else 0.36), owner_fighter)
			arena.apply_posture(target, 6.0, owner_fighter)
			attack_cooldown = 0.95
	queue_redraw()

func _draw() -> void:
	var color = Color("e5c5ff") if kind == "summon" else (Color("c5ebff") if kind == "music" else Color("b89fe4"))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(3, -2), 3.2, Color("242e45"))
	if kind == "spider":
		for i in 6:
			var direction = Vector2.from_angle(i * TAU / 6.0)
			draw_line(direction * 7, direction * 20, Color("8d8aba"), 2)
