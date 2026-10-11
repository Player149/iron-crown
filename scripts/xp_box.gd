extends Node2D

var value: float = 35.0
var phase: float = 0.0

func _process(dt: float) -> void:
	phase += dt * 2.2
	queue_redraw()

func _draw() -> void:
	var tint: Color = Color("ffcc77") if value >= 70 else (Color("90e6fa") if value >= 45 else Color("8ce6a8"))
	var radius: float = 13.0 if value >= 70 else 10.0
	var y: float = sin(phase) * 2.5
	draw_circle(Vector2(0, y), 19, Color(tint, 0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(0, y - radius), Vector2(radius, y), Vector2(0, y + radius), Vector2(-radius, y)]), tint)
	draw_line(Vector2(-radius / 2, y), Vector2(radius / 2, y), Color(1, 1, 1, 0.7), 2.0)
