extends Control

var arena

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if arena == null or not is_instance_valid(arena.player): return
	var factor: Vector2 = size / arena.balance.world_size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.08, 0.12, 0.85))
	draw_rect(Rect2(Vector2.ZERO, size), Color("52667a"), false)
	if arena.mode == "play":
		for zone in arena.get_node("Zones").get_children():
			draw_circle(zone.position * factor, zone.radius * factor.x, Color(0.3, 0.8, 0.8, 0.35))
	for f in arena.fighters:
		if not f.alive: continue
		draw_circle(f.position * factor, 4 if f.is_player or f.boss_flag else 2, Color("efc665") if f.is_player else (Color("ff5775") if f.boss_flag else Color("829fb4")))
