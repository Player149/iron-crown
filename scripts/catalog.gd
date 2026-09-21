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
	["dash", "짧은 발놀림", "대시 쿨타임 -14%"],
	["stamina", "지구력 훈련", "최대 스태미나 +18"]
]
const EVOLUTIONS = {
	5: [["duelist", "결투가", "E 관통 검기 · 공속 +15%, 이속 +7%"], ["guardian", "수호 기사", "E 방패 폭발 · 체력 +22%, 방어 +7"], ["berserker", "광전사", "E 삼중 검기 · 공격 +20%, 체력 -6%"]],
	15: [["lancer", "창기병", "R 돌진 · 이속 +10%, 공격 +8%"], ["sentinel", "성채 수호자", "R 대지 강타 · 방어 +12, 막기 강화"], ["slayer", "학살자", "R 절멸의 칼날 · 치명타 +10%p, 공속 +8%"]],
	25: [["storm", "폭풍 기사", "Q 검의 폭풍 · 기술 위력 +20%"], ["colossus", "철의 거신", "Q 철의 심판 · 체력 +30%, 크기 증가"], ["reaper", "핏빛 왕", "Q 핏빛 왕관 · 공격 +18%, 흡혈 +6%p"]]
}
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
		"stamina":
			f.max_stamina += 18
			f.stamina = minf(f.max_stamina, f.stamina + 18)

static func evolve(f, choice: Array) -> void:
	f.evolutions.append(choice[0])
	f.class_name_text = choice[1]
	match choice[0]:
		"duelist":
			f.attack_speed *= 1.15
			f.speed *= 1.07
		"guardian":
			f.hp += f.max_hp * 0.22
			f.max_hp *= 1.22
			f.armor += 7
		"berserker":
			f.damage *= 1.2
			f.max_hp *= 0.94
			f.hp = minf(f.hp, f.max_hp)
		"lancer":
			f.speed *= 1.1
			f.damage *= 1.08
		"sentinel":
			f.armor += 12
			f.block_reduction = minf(0.82, f.block_reduction + 0.08)
		"slayer":
			f.crit += 0.1
			f.attack_speed *= 1.08
		"storm": f.skill_power *= 1.2
		"colossus":
			f.hp += f.max_hp * 0.3
			f.max_hp *= 1.3
			f.body_scale *= 1.12
		"reaper":
			f.damage *= 1.18
			f.lifesteal += 0.06
