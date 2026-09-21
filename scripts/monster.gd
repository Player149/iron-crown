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
			hp = max_hp
			alive = true
			show()
		return
	cooldown = maxf(0, cooldown - dt)
	var target = arena.nearest_fighter(position, 360)
	if target != null:
		var delta = target.position - position
		if delta.length() > 45:
			position += delta.normalized() * speed * dt
		if delta.length() < 55 and cooldown <= 0:
			arena.deal_damage(target, 13.0 if brute else 8.0, self)
			cooldown = 1.15
	$Sprite2D.rotation += dt
	queue_redraw()

func _draw() -> void:
	if hp < max_hp and alive:
		draw_rect(Rect2(-20, -32, 40, 4), Color("1c1728"))
		draw_rect(Rect2(-20, -32, 40 * maxf(0, hp / max_hp), 4), Color("c88bd4"))
