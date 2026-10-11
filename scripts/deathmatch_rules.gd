class_name CrownDeathmatchRules
extends RefCounted

const DURATION: float = 480.0
const POPULATION: int = 10
const BOX_LIMIT: int = 65
const RESPAWN_TIME: float = 3.0
const KILL_POINTS: int = 100
const XP_POINTS: float = 0.085
const LOSS_RATIO: float = 0.20

static func minimum_level(f) -> int:
	if f.evolutions.is_empty(): return 1
	return [5, 15, 25][mini(f.evolutions.size() - 1, 2)]

static func accumulated_xp(level: int, xp: float, balance: CrownBalance) -> float:
	var total: float = xp
	for n in range(1, level): total += balance.xp_needed(n)
	return total

static func penalize(f, balance: CrownBalance) -> int:
	var old_level: int = f.level
	var minimum: int = minimum_level(f)
	var floor_xp: float = accumulated_xp(minimum, 0, balance)
	var total: float = accumulated_xp(old_level, f.xp, balance)
	var amount: float = floor_xp + (total - floor_xp) * (1.0 - LOSS_RATIO)
	var new_level: int = 1
	while new_level < balance.max_level and amount >= balance.xp_needed(new_level):
		amount -= balance.xp_needed(new_level)
		new_level += 1
	new_level = maxi(minimum, new_level)
	var levels_lost: int = old_level - new_level
	if levels_lost > 0:
		var hp_loss: float = (balance.final_hp - balance.starting_hp) * levels_lost / float(balance.max_level - 1)
		var st_loss: float = (balance.final_stamina - balance.starting_stamina) * levels_lost / float(balance.max_level - 1)
		f.max_hp -= hp_loss
		f.max_stamina -= st_loss
		f.base_stats["max_hp"] = float(f.base_stats["max_hp"]) - hp_loss
		f.base_stats["max_stamina"] = float(f.base_stats["max_stamina"]) - st_loss
	f.level = new_level
	f.xp = amount if new_level < balance.max_level else 0.0
	return levels_lost
