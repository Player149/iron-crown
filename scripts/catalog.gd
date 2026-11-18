class_name CrownCatalog
extends RefCounted

const STATS = [
	["edge", "날 세우기", "공격력 +12%"],
	["health", "생명력", "최대 체력 +15%, 증가분 회복"],
	["speed", "가벼운 갑옷", "이동 속도 +9%"],
	["haste", "연속 베기", "공격 속도 +13%"],
	["armor", "강철판", "방어력 +8"],
	["crit", "급소 감각", "치명타 +7%p (최대 55%)"],
	["leech", "흡혈", "흡혈 +4%p (최대 25%)"],
	["power", "비전 증폭", "기술 위력 +14%"],
	["dash", "짧은 발놀림", "대시 쿨타임 -14%"]
]
const ROSTER = preload("res://data/characters/roster.tres")
static var EVOLUTIONS: Dictionary = evolution_table()

static func evolution_table() -> Dictionary:
	var result = {}
	for definition in ROSTER.characters:
		if definition.unlock_level <= 1: continue
		if not result.has(definition.unlock_level): result[definition.unlock_level] = []
		result[definition.unlock_level].append([definition.id, definition.title, definition.description])
	return result

static func options_for(f, level: int) -> Array:
	var previous = f.evolutions.back() if not f.evolutions.is_empty() else f.definition.id
	return EVOLUTIONS.get(level, []).filter(func(row):
		var d = ROSTER.find(row[0])
		return d.parent_ids.is_empty() or d.parent_ids.has(previous))

const RUNES = [
	["edge", "예리한 검날", "공격력 +4% / 레벨"],
	["heart", "거인의 심장", "시작 최대 체력 +5% / 레벨"],
	["wind", "순풍 각인", "이동 속도 +3% / 레벨"],
	["wisdom", "전투 교본", "경험치 +5% / 레벨"],
	["ember", "잿불 궤적", "붉은 공격 궤적"],
	["frost", "서리 궤적", "푸른 대시 궤적"],
	["echo", "강철의 메아리", "묵직한 타격음"],
	["fortune", "황금 손", "골드 +8% / 레벨"]
]

static func apply_stat(f, id: String) -> void:
	match id:
		"edge": f.damage *= 1.12
		"health":
			var gain = f.max_hp * 0.15
			f.max_hp += gain
			f.hp += gain
		"speed": f.speed *= 1.09
		"haste": f.attack_speed *= 1.13
		"armor": f.armor += 8
		"crit": f.crit = minf(0.55, f.crit + 0.07)
		"leech": f.lifesteal = minf(0.25, f.lifesteal + 0.04)
		"power": f.skill_power *= 1.14
		"dash": f.dash_mult *= 0.86

static func evolve(f, choice: Array) -> void:
	if f == null or not is_instance_valid(f): return
	var d = ROSTER.find(choice[0])
	if d == null or f.evolutions.has(d.id): return
	if not options_for(f, d.unlock_level).any(func(row): return row[0] == d.id): return
	if d.evolution_scene != null:
		f = f.arena.replace_fighter_scene(f, d)
	f.evolutions.append(d.id)
	f.class_name_text = d.title
	var old_hp = f.max_hp
	for key in d.multipliers: f.set(key, f.get(key) * d.multipliers[key])
	for key in d.additions: f.set(key, f.get(key) + d.additions[key])
	f.hp = minf(f.max_hp, f.hp + maxf(0, f.max_hp - old_hp))
	f.block_reduction = minf(0.82, f.block_reduction)
	f.attack_target_limit = d.attack_target_limit
	if d.attack_animation != null:
		f.get_node("AnimationPlayer").get_animation_library("").add_animation("swing", d.attack_animation)
	if d.ability != null: f.equip_ability(d.skill_slot, d.ability)
