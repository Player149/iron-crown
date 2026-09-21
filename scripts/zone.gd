@tool
extends Node2D

@export var radius: float = 145.0:
	set(value):
		radius = value
		queue_redraw()
@export var experience_per_second: float = 3.2

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.12, 0.5, 0.7, 0.1))
	draw_circle(Vector2.ZERO, radius * 0.8, Color(0.2, 0.7, 0.9, 0.06))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 80, Color(0.3, 0.8, 0.9, 0.3), 2)
	draw_string(ThemeDB.fallback_font, Vector2(-35, 5), "XP ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("69aec5"))
