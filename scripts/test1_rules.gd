class_name CrownTest1Rules
extends RefCounted

# Test1: branches are based on the PREVIOUS form, not on a free tier-wide list.
# [id, display name, evolution level, parent id, fighting style, play hint]
const FORMS = [
	["guardstick", "막대 방패병", 5, "root", "shield", "방패 충돌 · 단단한 막기"],
	["knight", "검방 기사", 5, "root", "sword", "검격 · 방어 · 패링"],
	["axe", "도끼 전사", 5, "root", "axe", "묵직한 내려치기"],
	["fist", "맨손 격투가", 5, "root", "fist", "회피 · 짧은 연타"],
	["spear", "창병", 5, "root", "spear", "찌르기 · 장거리 돌진"],
	["hammer", "망치병", 5, "root", "hammer", "무기 회전 예열 · 강타"],
	["scythe", "낫 전사", 5, "root", "scythe", "넓게 베고 끌어당김"],
	["shovel", "삽 전사", 5, "root", "shovel", "지면 뒤집기 · 기습"],
	["club", "곤봉 야만인", 5, "root", "brute", "큰 몸짓 · 높은 기본 피해"],
	["shield", "방패 투사", 5, "root", "shield", "방패만으로 몸통박치기"],
	["aberrant", "외눈 괴생명체", 5, "root", "summon", "가시와 작은 생명체"],
	["music", "지휘봉 연주자", 5, "root", "music", "음파 · 소환 지휘"],

	["horn_guard", "뿔 방패병", 15, "guardstick", "shield", "뿔을 이용한 방패 충돌"],
	["triangle_guard", "삼각 방패병", 15, "guardstick", "shield", "좁은 방패로 재빠른 가드"],
	["knight_helm", "투구 기사", 15, "knight", "sword", "강화된 검방 · 패링"],
	["dual_cross", "교차 쌍검사", 15, "knight", "dual", "양검 교차 연타"],
	["greatsword", "대검 전사", 15, "knight", "greatsword", "후딜이 긴 강력한 일격"],
	["scar_axe", "흉터 도끼병", 15, "axe", "axe", "강력한 방어 압박"],
	["twin_axes", "쌍도끼 광전사", 15, "axe", "axe", "도끼 연속 타격"],
	["rotating_axe", "회전 양날도끼", 15, "axe", "spin", "몸과 도끼를 360도 회전"],
	["ring_fist", "철링 격투가", 15, "fist", "fist", "철링을 두른 근접 연타"],
	["iron_balls", "철구 권투가", 15, "fist", "fist", "양손 철구 · 자세 압박"],
	["claws", "발톱 투사", 15, "fist", "beast", "할퀴고 물어뜯는 이형 진화"],
	["steel_crane", "기계 갈고리 팔", 15, "fist", "robot", "기계식 타격과 과열"],
	["banner_spear", "깃창 기사", 15, "spear", "spear", "강화된 창 돌진"],
	["trident", "삼지창 전사", 15, "spear", "spear", "세 갈래 찌르기"],
	["hammer_plus", "강화 망치병", 15, "hammer", "hammer", "더 무거운 차징 망치"],
	["hammer_charger", "회전 망치병", 15, "hammer", "hammer", "회전 예열 후 광역 강타"],
	["dark_scythe", "그림자 낫 전사", 15, "scythe", "scythe", "원호 베기 · 끌어당김"],
	["zombie", "죽어가는 자", 15, "scythe", "beast", "예상 밖의 좀비 진화"],
	["twin_shovel", "쌍삽 굴착꾼", 15, "shovel", "shovel", "양손의 삽으로 지면 공격"],
	["dizzy_shovel", "빙글눈 삽꾼", 15, "shovel", "shovel", "혼란스러운 지면 공격"],
	["pirate", "갈고리 해적", 15, "club", "pirate", "후크 끌기 · 해적 검"],
	["primal", "원시 폭군", 15, "club", "brute", "곤봉 · 높은 기본 성능"],
	["horn_shield", "독각 방패병", 15, "shield", "shield", "가드 돌진 특화"],
	["rush_shield", "돌격 방패병", 15, "shield", "shield", "적을 밀어내는 방패"],
	["manyeyes", "사안 괴생명체", 15, "aberrant", "summon", "눈 네 개 · 다중 소환"],
	["spider_spawn", "기형 거미인", 15, "aberrant", "spider", "덫 · 측면 기동"],
	["conductor", "전장 지휘자", 15, "music", "music", "음파 연계 · 소환 지휘"],
	["celestial", "빛의 연주자", 15, "music", "angel", "기동 · 광역 빛 공격"],

	["horn_armor", "철갑 뿔 방패", 25, "horn_guard", "shield", "갑옷 · 밀쳐내기"],
	["triangle_tower", "삼각 성채", 25, "triangle_guard", "shield", "삼각 방패를 이용한 대형 수비"],
	["king_knight", "황금 투구 기사", 25, "knight_helm", "sword", "정교한 패링 · 검방"],
	["winged_sword", "광휘의 날개검", 25, "knight_helm", "angel", "빛나는 검 · 날개 돌진"],
	["blind_dual", "안대의 쌍검사", 25, "dual_cross", "dual", "시야를 가린 엇박자 연격"],
	["double_cross", "교차 검무사", 25, "dual_cross", "dual", "순간 교차 연타"],
	["giant_sword", "거대 검방 기사", 25, "greatsword", "greatsword", "몸의 세 배에 가까운 검"],
	["cleaver", "파쇄 도끼왕", 25, "scar_axe", "axe", "땅을 울리는 일격"],
	["jewel_twins", "보석 쌍도끼", 25, "twin_axes", "spin", "쌍도끼 회전 난타"],
	["spin_king", "회전 광전사", 25, "rotating_axe", "spin", "폭넓은 360도 공격"],
	["body_rings", "전신 철링 투사", 25, "ring_fist", "fist", "전신 철링 · 회피 콤보"],
	["celestial_punch", "천사의 철권", 25, "iron_balls", "angel", "빛나는 양손 · 천사 고리"],
	["four_arm_beast", "사완 발톱 괴수", 25, "claws", "beast", "네 팔 · 이빨 · 강한 기본 공격"],
	["spider_six", "육안육완 거미", 25, "claws", "spider", "여섯 팔 · 여섯 눈"],
	["mech_king", "기계 철권 로봇", 25, "steel_crane", "robot", "상위 로봇 · 기계 충전"],
	["spear_lord", "군기창 기사", 25, "banner_spear", "spear", "긴 돌진 · 관통"],
	["trident_lord", "삼지창 군주", 25, "trident", "spear", "삼중 찌르기 · 돌진"],
	["hammer_max", "초중량 망치왕", 25, "hammer_plus", "hammer", "더더더 강한 충전 망치"],
	["hammer_golem", "강철 망치 골렘", 25, "hammer_charger", "hammer", "거대한 몸 · 충격파"],
	["black_reaper", "검은 사신", 25, "dark_scythe", "scythe", "강화 낫 · 흡수"],
	["plague", "불멸의 시체", 25, "zombie", "beast", "스킬이 적고 기본 능력이 강함"],
	["tunnel_beast", "지하 굴착 괴수", 25, "twin_shovel", "shovel", "지중 기습 · 지면 파동"],
	["excavator", "왕관의 굴착자", 25, "dizzy_shovel", "shovel", "넓은 삽 공격 · 파동"],
	["pirate_captain", "망령 해적 선장", 25, "pirate", "pirate", "원거리 후크와 근접 검"],
	["barbarian", "원시 거인", 25, "primal", "brute", "묵직한 곤봉 · 거대화"],
	["horn_fortress", "철갑 뿔 요새", 25, "horn_shield", "shield", "초대형 방패 · 돌진"],
	["giant_tower", "거대 방패 전차", 25, "rush_shield", "shield", "방벽 같은 밀어내기"],
	["mothership", "천안의 마더십", 25, "manyeyes", "summon", "가시 · 무수한 눈 · 소환"],
	["spider_queen", "거미 여왕", 25, "spider_spawn", "spider", "덫 · 거미 소환"],
	["grand_conductor", "왕실 지휘관", 25, "conductor", "music", "광역 음파 · 소환 명령"],
	["winged_angel", "천공의 천사", 25, "celestial", "angel", "날개 · 빛의 돌진"],
	["energy_king", "에너지 왕관 기사", 25, "knight_helm", "shield", "빛의 방패 · 검 · 왕관"]
]

static func options_for(f, at_level: int) -> Array:
	var previous: String = "root" if f.evolutions.is_empty() else str(f.evolutions.back())
	var result: Array = []
	for form in FORMS:
		if form[2] == at_level and form[3] == previous:
			result.append([form[0], form[1], form[5]])
	return result

static func form_for(id: String) -> Array:
	for form in FORMS:
		if form[0] == id: return form
	return []

static func style_for(id: String) -> String:
	var entry: Array = form_for(id)
	return str(entry[4]) if not entry.is_empty() else "sword"

static func evolve(f, choice: Array) -> void:
	var form: Array = form_for(str(choice[0]))
	if form.is_empty(): return
	f.evolutions.append(form[0])
	f.class_name_text = str(form[1])
	f.combat_style = str(form[4])
	f.form_id = str(form[0])
	f.damage *= 1.10
	f.max_hp *= 1.075
	f.hp = minf(f.max_hp, f.hp + f.max_hp * 0.12)
	match f.combat_style:
		"fist", "dual":
			f.attack_speed *= 1.18
			f.speed *= 1.07
		"shield":
			f.armor += 8
			f.block_reduction = minf(0.85, f.block_reduction + 0.06)
		"spear":
			f.speed *= 1.07
		"hammer", "greatsword":
			f.damage *= 1.13
			f.speed *= 0.96
		"spin":
			f.max_stamina += 14
			f.stamina += 14
		"beast", "brute":
			f.damage *= 1.16
			f.max_hp *= 1.12
			f.hp = minf(f.max_hp, f.hp + f.max_hp * 0.12)
		"angel":
			f.dash_mult *= 0.85
		"robot":
			f.armor += 5
		"summon", "music", "spider":
			f.skill_power *= 1.15
	if int(form[2]) == 25 and f.combat_style in ["brute", "beast", "greatsword", "hammer", "shield", "summon"]:
		f.body_scale *= 1.38
	# Procedural tints emphasize that test sprites are placeholders.
	if f.has_node("Visual/Sword"):
		f.get_node("Visual/Sword").visible = f.combat_style in ["sword", "dual", "greatsword", "axe", "spin", "scythe", "pirate", "spear"]
	f.update_visual()
