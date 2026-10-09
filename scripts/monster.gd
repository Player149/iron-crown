extends Node2D

@export var max_hp: float = 60.0
@export var speed: float = 70.0
var hp: float = 60.0
var alive: bool = true
var brute: bool = false
var radius: float = 18.0
var armor: float = 0.0
var invuln: float = 0.0
var cooldown: float = 0.0
var respawn_timer: float = 0.0
var arena
var kind: String = "plain"
var strike_damage: float = 8.0
var wobble: float = 0.0

func configure_region() -> void:
	var center: Vector2 = arena.balance.world_size * 0.5
	var distance: float = position.distance_to(center)
	if distance < 470:
		kind = "crown"
		max_hp = 130
		speed = 86
		strike_damage = 18
		armor = 12
		radius = 27
		scale = Vector2.ONE * 1.35
		$Sprite2D.modulate = Color("db797e")
	elif distance < 850:
		kind = "ruins"
		max_hp = 82
		speed = 111
		strike_damage = 11
		armor = 5
		radius = 21
		scale = Vector2.ONE * 1.12
		$Sprite2D.modulate = Color("b1a1e8")
	else:
		kind = "plain"
		max_hp = 48
		speed = 72
		strike_damage = 7
		armor = 0
		radius = 17
		scale = Vector2.ONE
		$Sprite2D.modulate = Color("88d1ac")
	brute = kind == "crown"
	hp = max_hp

func _ready() -> void:
	if brute:
		max_hp = 105
		radius = 24
		scale = Vector2.ONE * 1.3
	hp = max_hp

func tick(dt: float) -> void:
	if not alive:
		respawn_timer -= dt
		if respawn_timer <= 0:
			position = arena.random_position()
			configure_region()
			hp = max_hp
			alive = true
			show()
		return
	cooldown = maxf(0, cooldown - dt)
	var target = arena.nearest_fighter(position, 360)
	if target != null:
		var delta = target.position - position
		var direction: Vector2 = delta.normalized()
		if kind == "ruins":
			direction = (direction + direction.orthogonal() * sin(arena.elapsed * 3.5 + float(get_instance_id() % 17)) * 0.58).normalized()
		elif kind == "crown" and delta.length() < 120:
			direction = direction.rotated(sin(arena.elapsed * 1.5 + float(get_instance_id() % 9)) * 0.4)
		if delta.length() > 45:
			position += direction * speed * dt
		if delta.length() < radius + 36 and cooldown <= 0:
			arena.deal_damage(target, strike_damage, self)
			arena.apply_posture(target, 24 if kind == "crown" else (13 if kind == "ruins" else 6), self)
			cooldown = 1.3 if kind == "crown" else (0.85 if kind == "ruins" else 1.15)
	$Sprite2D.rotation += dt
	queue_redraw()

func _draw() -> void:
	if hp < max_hp and alive:
		draw_rect(Rect2(-20, -32, 40, 4), Color("1c1728"))
		draw_rect(Rect2(-20, -32, 40 * maxf(0, hp / max_hp), 4), Color("c88bd4"))
