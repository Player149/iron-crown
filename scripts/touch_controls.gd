extends Control

var arena
var joystick_id: int = -1
var active_buttons: Dictionary = {}
var knob: Vector2 = Vector2.ZERO

func button_layout() -> Array:
	return [
		["attack", "공격", Vector2(size.x - 66, size.y - 84), 42.0],
		["block", "막기", Vector2(size.x - 155, size.y - 53), 32.0],
		["dash", "대시", Vector2(size.x - 148, size.y - 136), 32.0],
		["e", "E", Vector2(size.x - 226, size.y - 63), 26.0],
		["r", "R", Vector2(size.x - 226, size.y - 123), 26.0],
		["q", "Q", Vector2(size.x - 204, size.y - 184), 26.0],
		["run", "달리기", Vector2(224, size.y - 56), 30.0]
	]

func clear_input() -> void:
	joystick_id = -1
	active_buttons.clear()
	knob = Vector2.ZERO
	if arena == null: return
	arena.touch_move = Vector2.ZERO
	arena.touch_attack = false
	arena.touch_block = false
	arena.touch_run = false

func _input(event: InputEvent) -> void:
	if arena == null or not arena.active(): return
	var origin = Vector2(104, size.y - 94)
	if event is InputEventScreenTouch:
		arena.touch_mode = true
		if event.pressed:
			if event.position.distance_to(origin) < 88 and joystick_id == -1:
				joystick_id = event.index
				knob = (event.position - origin).limit_length(50)
				arena.touch_move = knob / 50
			else:
				for b in button_layout():
					if event.position.distance_to(b[2]) <= b[3]:
						active_buttons[event.index] = b[0]
						if b[0] == "dash": arena.player.dash(arena.touch_move)
						elif b[0] in ["e", "r", "q"]: arena.player.skill(b[0])
		else:
			if event.index == joystick_id:
				joystick_id = -1
				knob = Vector2.ZERO
				arena.touch_move = Vector2.ZERO
			active_buttons.erase(event.index)
		arena.touch_attack = active_buttons.values().has("attack")
		arena.touch_block = active_buttons.values().has("block")
		arena.touch_run = active_buttons.values().has("run")
	elif event is InputEventScreenDrag and event.index == joystick_id:
		knob = (event.position - origin).limit_length(50)
		arena.touch_move = knob / 50
	queue_redraw()

func _draw() -> void:
	var origin = Vector2(104, size.y - 94)
	draw_circle(origin, 68, Color(0.08, 0.15, 0.24, 0.7))
	draw_arc(origin, 68, 0, TAU, 40, Color("7891a9"), 2)
	draw_circle(origin + knob, 26, Color(0.7, 0.8, 0.95, 0.45))
	for b in button_layout():
		draw_circle(b[2], b[3], Color("91374e") if b[0] == "attack" else Color(0.1, 0.17, 0.26, 0.85))
		draw_arc(b[2], b[3], 0, TAU, 32, Color("9aaebf"), 1.5)
		draw_string(get_theme_default_font(), b[2] + Vector2(-22, 6), b[1], HORIZONTAL_ALIGNMENT_CENTER, 44, 17, Color.WHITE)
