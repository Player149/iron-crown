class_name CrownCatalog
extends RefCounted

const FREE_STATS = [
	["damage", "공격력", "공격력 +4%"],
	["health", "체력", "최대 체력 +6%"],
	["haste", "공격속도", "공격속도 +4% (최대 +80%)"],
	["speed", "이동속도", "이동속도 +3% (최대 +45%)"]
]
const PERKS = [
	["crit", "급소 감각", "치명타 확률 +6%p (최대 48%)"],
	["leech", "흡혈", "가한 피해의 4% 회복 (최대 24%)"],
	["power", "비전 증폭", "스킬 위력 +12%"],
	["dash", "짧은 발놀림", "대시 쿨타임 -12%"],
	["execute", "처형 본능", "체력 30% 미만 대상 추가 피해 (+12%, 최대 3중첩)"],
	["siphon", "전투 수확", "몬스터 처치 시 최대 체력 4% 회복 (최대 3중첩)"]
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

static func spend_stat(f, id: String) -> bool:
	if f.stat_points <= 0: return false
	match id:
		"damage": f.damage *= 1.04
		"health":
			var gain = f.max_hp * 0.06
			f.max_hp += gain
			f.hp += gain
		"haste":
			if f.attack_speed >= 1.8: return false
			f.attack_speed = minf(1.8, f.attack_speed * 1.04)
		"speed":
			if f.speed >= 1.45 * f.base_stats.speed: return false
			f.speed = minf(1.45 * f.base_stats.speed, f.speed * 1.03)
		_: return false
	f.stat_points -= 1
	return true

static func apply_perk(f, id: String) -> void:
	match id:
		"crit": f.crit = minf(0.48, f.crit + 0.06)
		"leech": f.lifesteal = minf(0.24, f.lifesteal + 0.04)
		"power": f.skill_power *= 1.12
		"dash": f.dash_mult = maxf(0.45, f.dash_mult * 0.88)
		"execute", "siphon": f.perks[id] = mini(3, int(f.perks.get(id, 0)) + 1)

static func evolve(f, choice: Array) -> void:
	var d = ROSTER.find(choice[0])
	if d == null or f.evolutions.has(d.id): return
	if not options_for(f, d.unlock_level).any(func(row): return row[0] == d.id): return
	f.evolutions.append(d.id)
	f.class_name_text = d.title
	var old_hp = f.max_hp
	for key in d.multipliers: f.set(key, f.get(key) * d.multipliers[key])
	for key in d.additions: f.set(key, f.get(key) + d.additions[key])
	f.hp = minf(f.max_hp, f.hp + maxf(0, f.max_hp - old_hp))
	f.attack_target_limit = d.attack_target_limit
	if d.attack_animation != null:
		f.get_node("AnimationPlayer").get_animation_library("").add_animation("swing", d.attack_animation)
	if d.ability != null: f.equip_ability(d.skill_slot, d.ability)
