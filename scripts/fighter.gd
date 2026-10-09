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
var combat_style: String = "sword"
var form_id: String = ""
var posture: float = 0.0
var stagger_left: float = 0.0
var stagger_protection: float = 0.0
var parry_left: float = 0.0
var previous_block: bool = false
var attack_pending: bool = false
var attack_windup: float = 0.0
var dash_strike: bool = false
var robot_heat: float = 0.0
var attack_chain: int = 0
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
	stagger_left = maxf(0, stagger_left - dt)
	stagger_protection = maxf(0, stagger_protection - dt)
	parry_left = maxf(0, parry_left - dt)
	robot_heat = maxf(0, robot_heat - dt * 18.0)
	if attack_pending:
		attack_windup = maxf(0, attack_windup - dt)
		if attack_windup <= 0:
			attack_pending = false
			if can_act(): resolve_attack()
	combat_left = maxf(0, combat_left - dt)
	no_hit_time += dt
	blocking = false
	velocity = Vector2.ZERO
	if exhausted <= 0:
		if is_player:
			player_control()
		else:
			ai_control(dt)
	if dash_left > 0 and can_act():
		dash_left -= dt
		velocity = dash_velocity
		arena.fx_ring(position, 12, Color("79dbf4") if is_player and Meta.rune_level("frost") > 0 else tint, 0.2)
		if dash_strike and dash_left <= 0.09:
			dash_strike = false
			arena.area_attack(self, 72.0 * body_scale, damage * (1.25 if combat_style == "spear" else 0.7))
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
	var wants_block = (Input.is_action_pressed("block") or arena.touch_block) and stamina > 0
	if wants_block and not previous_block:
		if combat_style in ["fist", "dual", "spider"]:
			dash(move if move.length() > 0.1 else -Vector2.from_angle(facing))
		else:
			parry_left = 0.18 if combat_style in ["sword", "shield", "greatsword", "spear"] else 0.0
	previous_block = wants_block
	blocking = wants_block and combat_style not in ["fist", "dual", "spider"]
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
	var preferred = 125.0 if combat_style == "spear" else (76.0 if combat_style in ["fist", "dual"] else 92.0)
	var toward = 1.0 if distance > preferred else (-0.4 if distance < preferred * 0.65 else 0.0)
	if hp / max_hp < 0.22 and not boss_flag: toward = -0.75
	if distance < 145 and randf() < dt * 0.7: ai_block = randf_range(0.25, 0.6)
	blocking = ai_block > 0 and stamina > 0 and combat_style not in ["fist", "dual", "spider"]
	if blocking and not previous_block and combat_style in ["sword", "shield", "greatsword", "spear"]:
		parry_left = 0.12
	previous_block = blocking
	var side = offset.normalized().orthogonal() * sin(float(get_instance_id()) + arena.elapsed * 0.8) * (0.42 if distance < 230 else 0.0)
	velocity = (offset.normalized() * toward + side) * speed * (0.5 if blocking else 1.0)
	if distance < (168 if combat_style == "spear" else 106): attack()
	if distance < 430 and randf() < dt * 0.5: skill("e")
	if distance < 220 and randf() < dt * 0.3: skill("r")
	if distance < 260 and randf() < dt * 0.18: skill("q")
	if distance > 210 and distance < 440 and randf() < dt * 0.24: dash(offset.normalized())

func can_act() -> bool:
	return alive and exhausted <= 0 and stagger_left <= 0

func spend(amount: float) -> bool:
	if combat_left <= 0: return true
	if stamina < amount: return false
	stamina -= amount
	return true

func attack() -> void:
	if not can_act() or blocking or cooldown.attack > 0 or attack_pending: return
	if combat_style == "robot" and robot_heat >= 95: return
	if not spend(arena.balance.attack_cost): return
	attack_chain += 1
	if combat_style == "robot": robot_heat = minf(100, robot_heat + 24)
	var tempo = 0.58
	match combat_style:
		"fist", "dual": tempo = 0.34
		"hammer": tempo = 0.95
		"greatsword": tempo = 0.85
		"spin": tempo = 0.78
		"spear": tempo = 0.66
		"axe", "brute": tempo = 0.76
	cooldown.attack = tempo / attack_speed
	attack_windup = (0.4 if combat_style == "hammer" else (0.33 if combat_style == "greatsword" else (0.24 if combat_style in ["spin", "axe"] else 0.12))) / attack_speed
	attack_pending = true
	$AnimationPlayer.play("swing", -1, attack_speed)
	arena.sound("swing", self)

func resolve_attack() -> void:
	var reach: float = (attack_range_override if attack_range_override > 0 else arena.balance.attack_range) * body_scale
	var arc: float = arena.balance.attack_arc
	var multiplier: float = 1.0
	var posture_power: float = 12.0
	match combat_style:
		"fist": reach *= 0.72; multiplier = 0.68; posture_power = 10
		"dual": reach *= 0.87; multiplier = 0.76; arc = 1.75
		"spear": reach *= 1.75; arc = 0.58; multiplier = 1.05
		"axe": reach *= 1.05; arc = 1.75; multiplier = 1.3; posture_power = 27
		"greatsword": reach *= 1.45; arc = 1.85; multiplier = 1.75; posture_power = 36
		"hammer": reach *= 1.14; arc = 1.48; multiplier = 1.7; posture_power = 46
		"shield": reach *= 0.8; multiplier = 0.8; posture_power = 24
		"scythe": reach *= 1.35; arc = 2.2; multiplier = 0.98
		"spin": reach *= 1.38; arc = TAU; multiplier = 1.15; posture_power = 22
		"shovel": reach *= 1.15; arc = 1.7; multiplier = 1.02; posture_power = 25
		"brute", "beast": reach *= 1.2; arc = 1.8; multiplier = 1.45; posture_power = 28
		"robot": reach *= 1.05; multiplier = 1.1
	arena.fx_ring(position + Vector2.from_angle(facing) * 48, reach * 0.65, attack_color(), 0.18)
	var count: int = 0
	for target in arena.targets(self):
		var offset: Vector2 = target.position - position
		if offset.length() > reach + target.radius: continue
		if absf(angle_difference(facing, offset.angle())) > arc * 0.5: continue
		var critical = randf() < crit
		var dealt = arena.deal_damage(target, damage * multiplier * (1.7 if critical else 1.0), self)
		if dealt <= 0: continue
		arena.apply_posture(target, posture_power * (1.45 if critical else 1.0), self)
		if combat_style == "scythe": target.position -= offset.normalized() * 28.0
		elif combat_style == "shield": target.position += offset.normalized() * 24.0
		else: target.position += offset.normalized() * 5.0
		count += 1
		if combat_style == "dual":
			arena.deal_damage(target, damage * 0.35, self)
		if exhausted > 0 or (count >= 2 and combat_style not in ["spin", "scythe", "greatsword"]): break
	if combat_style == "shovel":
		arena.fx_ring(position + Vector2.from_angle(facing) * 75, 65, Color("bd9a69"), 0.35)
	arena.add_xp(self, 0.35)

func dash(direction: Vector2 = Vector2.ZERO) -> void:
	if not can_act() or cooldown.dash > 0: return
	if direction.length() < 0.1: direction = Vector2.from_angle(facing)
	dash_left = 0.22 if combat_style in ["spear", "shield", "angel"] else 0.17
	dash_velocity = direction.normalized() * (900 if combat_style == "spear" else (740 if combat_style in ["shield", "angel"] else 690))
	dash_strike = combat_style in ["spear", "shield"]
	invuln = 0.22 if combat_style not in ["fist", "dual"] else 0.31
	cooldown.dash = (1.5 if combat_style in ["fist", "dual"] else 2.15) * dash_mult
	arena.sound("dash", self)

func skill(key: String) -> void:
	var tier: int = {"e": 1, "r": 2, "q": 3}[key]
	if not can_act() or evolutions.size() < tier or cooldown[key] > 0: return
	if not spend(arena.balance.skill_cost): return
	cooldown[key] = {"e": 6.5, "r": 11.0, "q": 23.0}[key]
	arena.add_xp(self, {"e": 1.3, "r": 2.0, "q": 3.0}[key])
	arena.sound("skill", self)
	var style: String = CrownTest1Rules.style_for(str(evolutions[tier - 1]))
	var power: float = damage * skill_power * (1.0 + (tier - 1) * 0.32)
	match style:
		"shield":
			invuln = maxf(invuln, 0.35)
			dash_left = 0.22
			dash_velocity = Vector2.from_angle(facing) * 730
			dash_strike = true
			arena.area_attack(self, 85, power * 0.7)
		"fist":
			invuln = maxf(invuln, 0.3)
			arena.area_attack(self, 90, power * 1.35)
		"dual":
			for i in range(-2, 3): arena.shoot(self, facing + i * 0.12, 470, power * 0.32, 0.58)
		"axe":
			arena.area_attack(self, 115, power * 1.65)
		"spin":
			arena.area_attack(self, 160 * body_scale, power * 1.24)
		"hammer", "greatsword":
			arena.area_attack(self, 150 * body_scale, power * 1.72)
			for target in arena.targets(self):
				if position.distance_to(target.position) < 150 * body_scale + target.radius: arena.apply_posture(target, 42, self)
		"spear":
			dash_left = 0.38
			dash_velocity = Vector2.from_angle(facing) * 940
			dash_strike = true
			invuln = 0.38
			arena.shoot(self, facing, 550, power * 1.4, 0.8, 2)
		"scythe":
			for target in arena.targets(self):
				if position.distance_to(target.position) < 230:
					target.position = target.position.move_toward(position, 65)
					arena.deal_damage(target, power, self)
			arena.fx_ring(position, 230, Color("a176ce"), 0.38)
		"summon", "music", "spider":
			arena.spawn_minion(self, style)
			if tier >= 2: arena.spawn_minion(self, style)
			if tier == 3: arena.area_attack(self, 140, power * 0.8)
		"robot":
			robot_heat = maxf(0, robot_heat - 50)
			for i in range(-1, 2): arena.shoot(self, facing + i * 0.25, 500, power * 0.85, 1.0)
		"shovel":
			arena.area_attack(self, 170, power * 1.22)
			arena.fx_ring(position + Vector2.from_angle(facing) * 70, 85, Color("ab8c52"), 0.5)
		"pirate":
			var target = arena.nearest_target(self, 220)
			if target != null:
				target.position = target.position.move_toward(position, 90)
				arena.deal_damage(target, power * 1.15, self)
			arena.shoot(self, facing, 430, power, 0.65)
		"angel":
			invuln = maxf(invuln, 0.38)
			for i in range(-2, 3): arena.shoot(self, facing + i * 0.23, 490, power * 0.72, 0.8)
		"beast", "brute":
			arena.area_attack(self, 120 * body_scale, power * 1.65)
		_:
			arena.shoot(self, facing, 480, power * 1.25, 1.0, 2)

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
	$Visual/Shield.visible = combat_style in ["shield", "sword"]
	$Visual/WeaponPivot.visible = combat_style not in ["fist", "beast", "brute", "spider", "summon", "music", "robot"]
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
	if stagger_left > 0:
		draw_arc(Vector2.ZERO, 46 * body_scale, 0, TAU, 28, Color("ffdb77"), 5)
	if posture > 0:
		draw_rect(Rect2(-29, -43, 58, 4), Color("1d1a26"))
		draw_rect(Rect2(-29, -43, 58 * minf(1, posture / 100), 4), Color("f2b969"))
	if attack_pending:
		draw_arc(Vector2.ZERO, 38 * body_scale, facing - PI * 0.6, facing + PI * 0.6, 18, Color("ff9c67"), 3)
	var front = Vector2.from_angle(facing)
	match combat_style:
		"spear":
			draw_line(front * 34, front * 94, Color("c9c6a4"), 5)
			var tip = front * 104
			draw_circle(tip, 7, Color("fff1bd"))
		"axe", "spin":
			draw_line(front * 35, front * 76, Color("967753"), 7)
			draw_circle(front * 77, 14, Color("c9d3da"))
		"hammer":
			draw_line(front * 35, front * 75, Color("ac8251"), 6)
			draw_line(front * 75 + front.orthogonal() * 17, front * 75 - front.orthogonal() * 17, Color("bec5d0"), 13)
		"scythe":
			draw_line(front * 30, front * 93, Color("888d93"), 5)
			draw_arc(front * 83, 25, facing - 1.5, facing + 0.7, 12, Color("9f91bc"), 5)
		"fist", "dual":
			draw_circle(front.orthogonal() * 19 + front * 26, 10, Color("e0b67b"))
			draw_circle(-front.orthogonal() * 19 + front * 26, 10, Color("e0b67b"))
		"robot":
			draw_rect(Rect2(-19, -19, 38, 38), Color("7ea5aa"), false, 4)
		"spider", "summon":
			for i in 4:
				draw_circle(Vector2.from_angle(facing + i * TAU / 4) * 32, 5, Color("e3a3d7"))
		"angel":
			draw_arc(Vector2.ZERO, 47, facing - 1.7, facing + 1.7, 22, Color("f3e7a2"), 4)
	# TEST1 silhouette identifiers for heads/weapon families. All are temporary.
	if "horn" in form_id or "beast" in form_id:
		draw_line(Vector2(-24, -10), Vector2(-35, -40), Color("ddd4ba"), 7)
		draw_line(Vector2(24, -10), Vector2(35, -40), Color("ddd4ba"), 7)
	if "wing" in form_id or "angel" in form_id or "celestial" in form_id:
		for direction in [-1, 1]:
			draw_line(Vector2(direction * 24, 10), Vector2(direction * 70, -22), Color("dceffb"), 11)
			draw_line(Vector2(direction * 28, 12), Vector2(direction * 62, 20), Color("f5e7b9"), 8)
	if "king" in form_id or "royal" in form_id or "captain" in form_id or "queen" in form_id:
		draw_line(Vector2(-26, -29), Vector2(-26, -44), Color("efd274"), 5)
		draw_line(Vector2(0, -29), Vector2(0, -49), Color("efd274"), 6)
		draw_line(Vector2(26, -29), Vector2(26, -44), Color("efd274"), 5)
		draw_line(Vector2(-27, -29), Vector2(27, -29), Color("efd274"), 6)
	if "pirate" in form_id:
		draw_line(Vector2(-41, -33), Vector2(41, -33), Color("332a39"), 9)
	if "spider" in form_id:
		for i in 6:
			var v: Vector2 = Vector2.from_angle(i * TAU / 6.0)
			draw_line(v * 28, v * 48, Color("b39db3"), 4)
	if "eye" in form_id or "mothership" in form_id or "manyeyes" in form_id:
		for i in 6:
			var v: Vector2 = Vector2.from_angle(i * TAU / 6.0)
			draw_circle(v * 42, 6, Color("dceffb"))
			draw_circle(v * 42, 2.5, Color("46223b"))
	if "hammer" in form_id and attack_pending:
		draw_arc(Vector2.ZERO, 76, 0, TAU * (1.0 - minf(1.0, attack_windup / 0.5)), 25, Color("e0ba7e"), 5)

