extends Node2D
## 방패를 가진 캐릭터에만 부착한다. 방어 상태, 연출, 피격 반응을 관리한다.

@export var raise_animation: StringName = &"guard_raise"
@export var lower_animation: StringName = &"guard_lower"
@export var shield_path: NodePath = ^"../Visual/Shield"
var requested: bool = false
var phase: String = "idle"
var blocking: bool = false
var perfect_left: float = 0.0
var fallback_left: float = 0.0
var using_fallback: bool = false
@onready var fighter = get_parent()
@onready var animator: AnimationPlayer = fighter.get_node("AnimationPlayer")
@onready var shield: Sprite2D = get_node_or_null(shield_path)
var rest_position: Vector2

func _ready() -> void:
	if shield != null: rest_position = shield.position
	animator.animation_finished.connect(_on_animation_finished)

func is_busy() -> bool:
	return phase != "idle" or requested

func tick(dt: float) -> void:
	if not fighter.can_act():
		reset()
		return
	perfect_left = maxf(0.0, perfect_left - dt)
	if using_fallback:
		fallback_left = maxf(0.0, fallback_left - dt)
		if fallback_left <= 0.0:
			if phase == "raise": on_guard_raised()
			elif phase == "lower": on_guard_lowered()
	if phase == "idle" and requested and fighter.attack_lock <= 0 and fighter.dash_left <= 0:
		phase = "raise"
		play_transition(raise_animation, fighter.arena.balance.guard_windup)
	elif phase == "hold":
		if not requested:
			lower()
		else:
			fighter.stamina = maxf(0.0, fighter.stamina - fighter.arena.balance.guard_drain_per_second * dt)
			if fighter.stamina <= 0.0: fighter.trigger_exhaustion()
	update_visual()

func play_transition(animation_name: StringName, duration: float) -> void:
	fallback_left = maxf(0.01, duration)
	using_fallback = not animator.has_animation(animation_name)
	if using_fallback: return
	var animation = animator.get_animation(animation_name)
	animator.play(animation_name, 0.0, maxf(0.001, animation.length) / fallback_left)
	animator.advance(0.0)

func on_guard_raised() -> void:
	if phase != "raise": return
	using_fallback = false
	phase = "hold"
	blocking = true
	perfect_left = fighter.arena.balance.perfect_guard_window
	if not requested: lower()

func on_guard_lowered() -> void:
	if phase != "lower": return
	using_fallback = false
	phase = "idle"
	blocking = false
	perfect_left = 0.0

func _on_animation_finished(animation_name: StringName) -> void:
	# 키프레임 메서드를 지워도 애니메이션 종료 시 전환을 완료한다.
	if animation_name == raise_animation: on_guard_raised()
	elif animation_name == lower_animation: on_guard_lowered()

func lower() -> void:
	if phase not in ["raise", "hold"]: return
	phase = "lower"
	blocking = false
	perfect_left = 0.0
	play_transition(lower_animation, fighter.arena.balance.guard_recovery)

func reset() -> void:
	var was_active = phase != "idle"
	phase = "idle"
	requested = false
	blocking = false
	perfect_left = 0.0
	fallback_left = 0.0
	using_fallback = false
	if was_active: animator.stop()
	if shield != null: shield.position = rest_position
	update_visual()

func absorb_hit() -> bool:
	if not fighter.can_act() or not blocking or phase != "hold": return false
	if not fighter.spend_stamina(fighter.arena.balance.guard_hit_cost):
		if fighter.exhaustion_left <= 0.0: lower()
		return false
	return true

## Returns -1 for an unblocked hit, otherwise the shield damage reduction.
func receive_hit(source) -> float:
	var perfect = blocking and phase == "hold" and perfect_left > 0.0
	if not absorb_hit(): return -1.0
	var arena = fighter.arena
	arena.fx_ring(fighter.position, 45, Color("91dfff"), 0.2)
	if source is CrownFighter:
		source.stamina = maxf(0.0, source.stamina - arena.balance.attack_stamina_cost * arena.balance.blocked_attack_stamina_multiplier)
		if source.stamina <= 0.0: source.trigger_exhaustion()
		if perfect:
			perfect_left = 0.0
			source.add_groggy(arena.balance.perfect_guard_groggy)
			arena.float_text(fighter.position, "완벽 방어!", Color("f2d47c"))
			arena.fx_ring(fighter.position, 62, Color("ffd877"), 0.25)
	return fighter.block_reduction

func update_visual() -> void:
	if shield != null: shield.modulate = Color("bfefff") if blocking else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(fighter) or not fighter.alive or not blocking: return
	draw_arc(Vector2.ZERO, 42 * fighter.body_scale, fighter.facing - 0.8, fighter.facing + 0.8, 16, Color("88d7f7"), 4)
