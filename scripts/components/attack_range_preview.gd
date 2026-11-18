@tool
extends Node2D

const DEFAULT_BALANCE = preload("res://data/balance.tres")

var preview_reach: float
var preview_arc: float

func _ready() -> void:
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	var fighter := get_parent()
	var range_override: float = fighter.get("attack_range_override")
	var arc_override: float = fighter.get("attack_arc_override_degrees")
	var reach: float = range_override if range_override > 0.0 else DEFAULT_BALANCE.attack_range
	var arc: float = deg_to_rad(arc_override) if arc_override > 0.0 else DEFAULT_BALANCE.attack_arc
	if reach != preview_reach or arc != preview_arc:
		preview_reach = reach
		preview_arc = arc
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_sector(self, preview_reach, preview_arc, -PI / 2.0, 42.0)

static func draw_sector(canvas: Node2D, reach: float, arc: float, facing: float, label_y: float) -> void:
	if reach <= 0.0 or arc <= 0.0:
		return

	var fill := Color(0.3, 0.9, 1.0, 0.18)
	var outline := Color(0.55, 0.94, 1.0, 0.9)
	if arc >= TAU:
		canvas.draw_circle(Vector2.ZERO, reach, fill, true, -1.0, true)
		canvas.draw_arc(Vector2.ZERO, reach, 0.0, TAU, 64, outline, 2.0, true)
	else:
		var sector := PackedVector2Array([Vector2.ZERO])
		var steps := maxi(2, ceili(64.0 * arc / TAU))
		for step in range(steps + 1):
			var angle := facing - arc * 0.5 + arc * float(step) / steps
			sector.append(Vector2.from_angle(angle) * reach)
		canvas.draw_colored_polygon(sector, fill)
		sector.append(Vector2.ZERO)
		canvas.draw_polyline(sector, outline, 2.0, true)

	var label := "%.1f° / %.1f" % [rad_to_deg(arc), reach]
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var label_position := Vector2(-width * 0.5, label_y)
	canvas.draw_string_outline(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	canvas.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, outline)
