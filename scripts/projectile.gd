extends Node2D

var source
var arena
var velocity: Vector2
var damage: float = 20
var lifetime: float = 1.3
var radius: float = 13
var pierce: int = 1
var tint: Color = Color("8be5ff")
var hit: Array = []

func tick(dt: float) -> void:
	lifetime -= dt
	position += velocity * dt
	rotation = velocity.angle()
	if not is_instance_valid(source):
		queue_free()
		return
	for target in arena.targets(source):
		if target in hit:
			continue
		if position.distance_to(target.position) < radius + target.radius:
			hit.append(target)
			arena.deal_damage(target, damage, source)
			pierce -= 1
			if pierce <= 0:
				lifetime = 0
				break
	if lifetime <= 0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-20, 0), Vector2(20, 0), Color(tint, 0.15), 18)
	draw_line(Vector2(-20, 0), Vector2(20, 0), tint, 5)
