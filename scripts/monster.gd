extends Node2D

@export var max_hp: float = 60.0
@export var speed: float = 70.0
@export var brute_hp := 105.0
@export var normal_damage := 8.0
@export var brute_damage := 13.0
@export var attack_seconds := 1.15
@export var aggro_range := 360.0
@export var stop_distance := 45.0
@export var attack_distance := 55.0
@export var return_speed_multiplier := 2.0
@export var return_heal_per_second := 1.0
@export var normal_radius := 18.0
@export var brute_radius := 24.0
var hp: float = 60.0
var alive: bool = true
var brute: bool = false
var radius: float = 18.0
var armor: float = 0.0
var invuln: float = 0.0
var cooldown: float = 0.0
var respawn_timer: float = 0.0
var arena
var coronation_kind: String = ""
var home: Vector2
var leash: float = 0.0
var returning: bool = false

func _ready() -> void:
	radius = normal_radius
	if brute:
		max_hp = brute_hp
		radius = brute_radius
		scale = Vector2.ONE * 1.3
	hp = max_hp
	if is_resource():
		$Sprite2D.hide()
		radius = max_hp / 4.0 + 8.0
	elif coronation_kind == "field":
		$Sprite2D.modulate = Color("ffae72")

func is_resource() -> bool:
	return coronation_kind in ["crystal", "tree", "mushroom"]

func tick(dt: float) -> void:
	if not alive:
		respawn_timer -= dt
		if respawn_timer <= 0:
			position = arena.random_position() if coronation_kind.is_empty() else home
			invuln = 0.0
			returning = false
			hp = max_hp
			alive = true
			show()
		return
	if is_resource(): return
	if leash > 0.0 and (returning or position.distance_to(home) >= leash):
		returning = true
		invuln = 1.0
		position = position.move_toward(home, speed * return_speed_multiplier * dt)
		hp = minf(max_hp, hp + max_hp * return_heal_per_second * dt)
		if position.is_equal_approx(home):
			hp = max_hp
			invuln = 0.0
			returning = false
		queue_redraw()
		return
	cooldown = maxf(0, cooldown - dt)
	var target = arena.nearest_fighter(position, aggro_range)
	if target != null and (leash <= 0.0 or target.position.distance_to(home) <= leash):
		var delta = target.position - position
		if delta.length() > stop_distance:
			position += delta.normalized() * speed * dt
		if delta.length() < attack_distance and cooldown <= 0:
			var dealt: float = arena.deal_damage(target, brute_damage if brute else normal_damage, self)
			if dealt > 0.0 and coronation_kind == "field": target.coronation_effect = -arena.coronation_rules.slow_seconds
			cooldown = attack_seconds
	$Sprite2D.rotation += dt
	queue_redraw()

func _draw() -> void:
	if is_resource():
		match coronation_kind:
			"crystal":
				draw_colored_polygon(PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.65, 0), Vector2.ZERO + Vector2(0, radius), Vector2(-radius * 0.65, 0)]), Color("7bdbed"))
			"tree":
				draw_rect(Rect2(-5, -1, 10, radius), Color("896648"))
				draw_circle(Vector2(0, -5), radius * 0.78, Color("71a778"))
			"mushroom":
				draw_rect(Rect2(-4, -3, 8, radius), Color("e5d0ae"))
				draw_circle(Vector2(0, -4), radius * 0.7, Color("cc7792"))
	if hp < max_hp and alive:
		draw_rect(Rect2(-20, -32, 40, 4), Color("1c1728"))
		draw_rect(Rect2(-20, -32, 40 * maxf(0, hp / max_hp), 4), Color("c88bd4"))
