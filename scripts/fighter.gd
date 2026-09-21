class_name CrownFighter
extends CharacterBody2D

@export var display_name: String = "기사"
@export var is_player: bool = false
@export var damage: float = 18.0
@export var speed: float = 178.0
@export var tint: Color = Color("78b4df")
@export var attack_range_override: float = 0.0
var arena
var level: int = 1
var xp: float = 0
var max_hp: float = 100
var hp: float = 100
var max_stamina: float = 100
var stamina: float = 100
var armor: float = 3
var attack_speed: float = 1
var crit: float = 0.06
var lifesteal: float = 0
var skill_power: float = 1
var xp_gain: float = 1
var gold_bonus: float = 1
var dash_mult: float = 1
var block_reduction: float = 0.64
var body_scale: float = 1
var radius: float = 25
var alive: bool = true
var kills: int = 0
var boss_flag: bool = false
var boss_damage: float = 0
var boss_kills: int = 0
var invuln: float = 0
var blocking: bool = false
var combat_left: float = 0
var no_hit_time: float = 99
var exhausted: float = 0
var dash_left: float = 0
var dash_velocity: Vector2 = Vector2.ZERO
var facing: float = 0
var evolutions: Array = []
var class_name_text: String = "초보 기사"
var cooldown: Dictionary = {"attack": 0.0, "dash": 0.0, "e": 0.0, "r": 0.0, "q": 0.0}
var base_stats: Dictionary
var ai_target
var ai_retarget: float = 0
var ai_block: float = 0
var respawn_timer: float = 0

func _ready() -> void:
	max_hp = arena.balance.starting_hp
	hp = max_hp
	max_stamina = arena.balance.starting_stamina
	stamina = max_stamina
	base_stats = snapshot_stats()
	if is_player:
		Meta.apply_runes(self)
	$Visual/Body.modulate = tint
	update_visual()

func snapshot_stats() -> Dictionary:
	var result = {}
	for key in ["max_hp", "max_stamina", "damage", "speed", "attack_speed", "armor", "crit", "lifesteal", "skill_power", "xp_gain", "body_scale", "dash_mult", "block_reduction", "gold_bonus"]:
		result[key] = get(key)
	return result

func tick(dt: float) -> void:
	if not alive:
		return
	for key in cooldown:
		cooldown[key] = maxf(0, cooldown[key] - dt)
	invuln = maxf(0, invuln - dt)
	exhausted = maxf(0, exhausted - dt)
	combat_left = maxf(0, combat_left - dt)
	no_hit_time += dt
	blocking = false
	velocity = Vector2.ZERO
	if exhausted <= 0:
		if is_player:
			player_control()
		else:
			ai_control(dt)
	if dash_left > 0 and exhausted <= 0:
		dash_left -= dt
		velocity = dash_velocity
		arena.fx_ring(position, 12, Color("79dbf4") if is_player and Meta.rune_level("frost") > 0 else tint, 0.2)
	position += velocity * dt
	var bounds: Rect2 = arena.bounds()
	position = position.clamp(bounds.position + Vector2.ONE * 30, bounds.end - Vector2.ONE * 30)
	if not blocking:
		stamina = minf(max_stamina, stamina + arena.balance.stamina_regen * dt)
	if no_hit_time >= arena.balance.regen_delay:
		hp = minf(max_hp, hp + max_hp * arena.balance.health_regen * dt)
	update_visual()

func player_control() -> void:
	var move = Input.get_vector("left", "right", "up", "down") + arena.touch_move
	move = move.limit_length()
	var target = arena.nearest_target(self, 520) if arena.touch_mode else null
	if arena.touch_mode:
		if target != null: facing = (target.position - position).angle()
		elif move.length() > 0.1: facing = move.angle()
	else:
		facing = (get_global_mouse_position() - global_position).angle()
	blocking = (Input.is_action_pressed("block") or arena.touch_block) and stamina > 0
	var multiplier = 1.42 if Input.is_action_pressed("run") or arena.touch_run else 1.0
	if blocking: multiplier *= 0.5
	velocity = move * speed * multiplier
	if (not arena.touch_mode and Input.is_action_pressed("attack")) or arena.touch_attack: attack()
	if Input.is_action_just_pressed("dash"): dash(move)
	for key in ["e", "r", "q"]:
		if Input.is_action_just_pressed(key): skill(key)

func ai_control(dt: float) -> void:
	ai_retarget -= dt
	ai_block = maxf(0, ai_block - dt)
	if ai_retarget <= 0 or not is_instance_valid(ai_target) or not arena.valid_target(self, ai_target):
		ai_target = arena.nearest_target(self, 780)
		ai_retarget = randf_range(0.25, 0.7)
	if ai_target == null: return
	var offset: Vector2 = ai_target.position - position
	var distance = offset.length()
	facing = offset.angle()
	var toward = 1.0 if distance > 92 else (-0.4 if distance < 58 else 0.0)
	if hp / max_hp < 0.22 and not boss_flag: toward = -0.75
	if distance < 145 and randf() < dt * 0.7: ai_block = randf_range(0.25, 0.6)
	blocking = ai_block > 0 and stamina > 0
	var side = offset.normalized().orthogonal() * sin(float(get_instance_id()) + arena.elapsed * 0.8) * (0.42 if distance < 230 else 0.0)
	velocity = (offset.normalized() * toward + side) * speed * (0.5 if blocking else 1.0)
	if distance < 92: attack()
	if distance < 430 and randf() < dt * 0.5: skill("e")
	if distance < 220 and randf() < dt * 0.3: skill("r")
	if distance < 260 and randf() < dt * 0.18: skill("q")
	if distance > 210 and distance < 440 and randf() < dt * 0.24: dash(offset.normalized())

func can_act() -> bool:
	return alive and exhausted <= 0

func spend(amount: float) -> bool:
	if combat_left <= 0: return true
	if stamina < amount: return false
	stamina -= amount
	return true

func attack() -> void:
	if not can_act() or blocking or cooldown.attack > 0: return
	if not spend(arena.balance.attack_cost): return
	cooldown.attack = 0.56 / attack_speed
	$AnimationPlayer.play("swing", -1, attack_speed)
	arena.sound("swing", self)
	var reach = (attack_range_override if attack_range_override > 0 else arena.balance.attack_range) * body_scale
	var count = 0
	arena.fx_ring(position + Vector2.from_angle(facing) * 50, reach * 0.5, attack_color(), 0.15)
	for target in arena.targets(self):
		var offset: Vector2 = target.position - position
		if offset.length() < reach + target.radius and absf(angle_difference(facing, offset.angle())) < arena.balance.attack_arc * 0.5:
			var critical = randf() < crit
			arena.deal_damage(target, damage * (1.7 if critical else 1.0), self)
			target.position += offset.normalized() * 5
			count += 1
			if exhausted > 0 or (count >= 2 and not evolutions.has("reaper")): break
	arena.add_xp(self, 0.35)

func dash(direction: Vector2 = Vector2.ZERO) -> void:
	if not can_act() or cooldown.dash > 0: return
	if direction.length() < 0.1: direction = Vector2.from_angle(facing)
	dash_left = 0.17
	dash_velocity = direction.normalized() * 690
	invuln = 0.22
	cooldown.dash = 2.15 * dash_mult
	arena.sound("dash", self)

func skill(key: String) -> void:
	var tier = {"e": 1, "r": 2, "q": 3}[key]
	if not can_act() or evolutions.size() < tier or cooldown[key] > 0: return
	if not spend(arena.balance.skill_cost): return
	cooldown[key] = {"e": 6.5, "r": 11.0, "q": 23.0}[key]
	arena.add_xp(self, {"e": 1.3, "r": 2.0, "q": 3.0}[key])
	arena.sound("skill", self)
	var power = damage * skill_power
	if key == "e":
		if evolutions.has("guardian"):
			arena.area_attack(self, 135, power * 1.25)
			invuln = maxf(invuln, 0.34)
		else:
			var count = 3 if evolutions.has("berserker") else 1
			for i in count: arena.shoot(self, facing + (i - (count - 1) / 2.0) * 0.18, 420, power * 1.2, 1.15, 2 if evolutions.has("duelist") else 1)
	elif key == "r":
		if evolutions.has("lancer"):
			dash_left = 0.38
			dash_velocity = Vector2.from_angle(facing) * 850
			invuln = 0.42
			arena.area_attack(self, 115, power * 1.65)
		elif evolutions.has("slayer"):
			for i in range(-2, 3): arena.shoot(self, facing + i * 0.13, 520, power * 0.78, 1.3)
		else: arena.area_attack(self, 205, power * 1.5)
	else:
		if evolutions.has("storm"):
			for i in 12: arena.shoot(self, i * TAU / 12, 490, power * 0.95, 1.4, 2)
		elif evolutions.has("colossus"):
			arena.area_attack(self, 310, power * 2.15)
			invuln = 1.1
		else:
			arena.area_attack(self, 230, power * 2.6)
			hp = minf(max_hp, hp + max_hp * 0.18)

func exhaust_if_empty() -> void:
	if stamina > 0 or exhausted > 0: return
	exhausted = arena.balance.exhaustion_duration
	blocking = false
	dash_left = 0
	velocity = Vector2.ZERO
	arena.float_text(position, "탈진!", Color("ffcf63"))

func grow_level() -> void:
	level += 1
	var hp_gain = (arena.balance.final_hp - arena.balance.starting_hp) / (arena.balance.max_level - 1)
	var stamina_gain = (arena.balance.final_stamina - arena.balance.starting_stamina) / (arena.balance.max_level - 1)
	max_hp += hp_gain
	max_stamina += stamina_gain
	base_stats.max_hp += hp_gain
	base_stats.max_stamina += stamina_gain
	stamina = minf(max_stamina, stamina + stamina_gain)
	hp = minf(max_hp, hp + max_hp * arena.balance.level_heal)

func attack_color() -> Color:
	return Color("ff8258") if is_player and Meta.rune_level("ember") > 0 else tint.lightened(0.3)

func update_visual() -> void:
	$Visual.rotation = facing
	$Visual.scale = Vector2.ONE * body_scale
	$Visual/Shield.modulate = Color("bfefff") if blocking else Color("6d798b")
	$Visual/Body.modulate = Color("ffd47b") if boss_flag else tint
	$NameLabel.text = "%s · Lv.%d" % [display_name, level]
	$Health.value = hp / max_hp * 100
	queue_redraw()

func _draw() -> void:
	if not alive: return
	draw_circle(Vector2(0, 18), 29 * body_scale, Color(0, 0, 0, 0.25))
	if evolutions.size() > 0:
		draw_arc(Vector2.ZERO, 32 * body_scale, 0, TAU, 32, tint, evolutions.size() + 1)
	if blocking:
		draw_arc(Vector2.ZERO, 42 * body_scale, facing - 0.8, facing + 0.8, 16, Color("88d7f7"), 4)
	if exhausted > 0:
		draw_arc(Vector2(0, -75), 10, 0, TAU * exhausted / 2.0, 16, Color("ffc664"), 3)
