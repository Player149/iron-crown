class_name CrownBuilds
extends RefCounted

## Every level grants one point, including level 1. Eight points cap one stat.
## At Lv.25 players earn 25 points: three fully maxed stats and one spare.
const MAX_RANK: int = 8
const ORDER := ["health", "damage", "speed", "stamina", "armor", "haste"]
const STAT_INFO := {
	"health": ["체력", "최대 체력 +12"],
	"damage": ["공격력", "공격력 +4%"],
	"speed": ["이동속도", "이동 속도 +3%"],
	"stamina": ["기력", "최대 기력 +8"],
	"armor": ["방어력", "방어력 +3"],
	"haste": ["공격속도", "공격 속도 +3%"]
}
## Ordered investment priority defines a recognizable build rather than random increments.
const PROFILES := {
	"assault": {
		"title": "공격형",
		"priority": ["damage", "haste", "speed", "health", "stamina", "armor"],
		"weight": [5, 4, 3, 2, 2, 1]
	},
	"defense": {
		"title": "수비형",
		"priority": ["health", "armor", "stamina", "damage", "haste", "speed"],
		"weight": [5, 5, 4, 2, 1, 1]
	},
	"charge": {
		"title": "돌진형",
		"priority": ["speed", "stamina", "damage", "haste", "health", "armor"],
		"weight": [5, 4, 4, 3, 1, 1]
	}
}

static func create_allocations() -> Dictionary:
	var result := {}
	for id in ORDER: result[id] = 0
	return result

static func can_spend(f, stat: String) -> bool:
	return ORDER.has(stat) and f.stat_points > 0 and int(f.stat_allocations.get(stat, 0)) < MAX_RANK

static func invest(f, stat: String) -> bool:
	if not can_spend(f, stat): return false
	f.stat_points -= 1
	f.stat_allocations[stat] = int(f.stat_allocations.get(stat, 0)) + 1
	match stat:
		"health":
			f.max_hp += 12.0
			f.hp = minf(f.max_hp, f.hp + 12.0)
		"damage": f.damage *= 1.04
		"speed": f.speed *= 1.03
		"stamina":
			f.max_stamina += 8.0
			f.stamina = minf(f.max_stamina, f.stamina + 8.0)
		"armor": f.armor += 3.0
		"haste": f.attack_speed *= 1.03
	f.update_visual()
	return true

static func choose_ai_stat(f) -> String:
	var profile: Dictionary = PROFILES.get(f.ai_build, PROFILES["assault"])
	var priority: Array = profile["priority"]
	var weight: Array = profile["weight"]
	var best := ""
	var lowest := INF
	# Lowest relative investment to the profile target, with stable tie-breaking.
	for i in priority.size():
		var stat: String = priority[i]
		if int(f.stat_allocations.get(stat, 0)) >= MAX_RANK: continue
		var ratio: float = float(f.stat_allocations.get(stat, 0)) / float(weight[i])
		if ratio < lowest:
			lowest = ratio
			best = stat
	return best

static func allocate_ai(f) -> void:
	while f.stat_points > 0:
		var stat := choose_ai_stat(f)
		if stat.is_empty() or not invest(f, stat): break

static func random_profile() -> String:
	return PROFILES.keys().pick_random()

static func profile_title(profile: String) -> String:
	return str(PROFILES.get(profile, PROFILES["assault"])["title"])
