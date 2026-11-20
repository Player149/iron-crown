extends CanvasLayer

var arena
var font = preload("res://assets/NotoSansKR.ttf")
var notice_time: float = 0
var feed_lines: Array = []
var last_window_size = Vector2i.ZERO
var last_touch_mode: bool = false
var compact: bool = false
var stat_button: Button
@onready var menu = $Root/Menu
@onready var box = $Root/Menu/Center/Box
@onready var hud = $Root/HUD
@onready var modal = $Root/Modal
@onready var panel = $Root/Modal/Center/Panel
@onready var touch = $Root/Touch

func _ready() -> void:
	box.get_node("Start").pressed.connect(func():
		Meta.player_name = box.get_node("Name").text.strip_edges().left(12)
		if Meta.player_name.is_empty(): Meta.player_name = "방랑 기사"
		Meta.save_data()
		arena.start_game(box.get_node("Boost").button_pressed))
	box.get_node("Shop").pressed.connect(show_shop)
	var duel_button := Button.new()
	duel_button.name = "DuelTest"
	duel_button.text = "1대1 전투 테스트 (플레이어 VS AI)"
	duel_button.custom_minimum_size = Vector2(0, 50)
	box.add_child(duel_button)
	box.move_child(duel_button, box.get_node("Shop").get_index())
	duel_button.pressed.connect(show_duel_select)
	stat_button = Button.new()
	stat_button.name = "StatInvestment"
	stat_button.text = "스탯 투자 +1"
	hud.add_child(stat_button)
	stat_button.pressed.connect(show_stat_allocation)
	hud.get_node("Pause").pressed.connect(func():
		if arena.choice_open: return
		arena.paused = true
		show_pause(true))
	for pair in [["Health", Color("e76078")], ["Stamina", Color("71c8a6")], ["Groggy", Color("e1b459")], ["XP", Color("58bde4")]]:
		var fill = StyleBoxFlat.new()
		fill.bg_color = pair[1]
		fill.set_corner_radius_all(4)
		hud.get_node("Info/" + pair[0]).add_theme_stylebox_override("fill", fill)
	style_buttons(menu)
	style_buttons(hud)
	for child in box.get_children():
		if child is Label: child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_window().size_changed.connect(refresh_layout)
	refresh_layout.call_deferred()

func style_buttons(node: Node) -> void:
	if node is Button:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("23364c")
		style.border_color = Color("566b87")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		node.add_theme_stylebox_override("normal", style)
		var hover = style.duplicate()
		hover.bg_color = Color("375271")
		node.add_theme_stylebox_override("hover", hover)
		node.add_theme_stylebox_override("pressed", hover)
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children(): style_buttons(child)

func _process(dt: float) -> void:
	notice_time = maxf(0, notice_time - dt)
	hud.get_node("Notice").visible = notice_time > 0
	if arena == null: return
	if last_touch_mode != arena.touch_mode:
		last_touch_mode = arena.touch_mode
		refresh_layout(true)
	hud.get_node("Minimap").arena = arena
	hud.get_node("Minimap").visible = not arena.touch_mode and not compact
	touch.arena = arena
	touch.visible = arena.active() and arena.touch_mode
	if not arena.active(): touch.clear_input()


func show_menu() -> void:
	menu.show()
	hud.hide()
	modal.hide()
	touch.hide()
	box.get_node("Name").text = Meta.player_name
	box.get_node("Gold").text = "보유 골드 %d   ·   장착 룬 %d/3" % [Meta.gold, Meta.equipped.size()]
	box.get_node("Boost").text = "Lv.6 시작권 사용 (%d개)" % Meta.boosts
	box.get_node("Boost").disabled = Meta.boosts <= 0
	if Meta.boosts <= 0: box.get_node("Boost").button_pressed = false

func show_game() -> void:
	menu.hide()
	modal.hide()
	hud.show()
	touch.clear_input()

func clear_modal(title: String, subtitle: String = "") -> void:
	for c in panel.get_children():
		panel.remove_child(c)
		c.queue_free()
	modal.show()
	add_label(title, 30, Color("efbf65"))
	if not subtitle.is_empty(): add_label(subtitle, 16)
	arena.touch_attack = false
	arena.touch_block = false

func add_label(text: String, size: int = 18, color: Color = Color("d0daeb")) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	return label

func add_button(text: String, callback: Callable, parent: Node = null) -> Button:
	var button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 46
	button.pressed.connect(callback)
	(parent if parent != null else panel).add_child(button)
	style_buttons(button)
	return button

func close_stat_allocation() -> void:
	modal.hide()
	arena.choice_open = false
	arena.process_choices()

func show_stat_allocation() -> void:
	if arena == null or arena.mode != "play" or not is_instance_valid(arena.player): return
	arena.choice_open = true
	var f = arena.player
	clear_modal("스탯 분배 · 남은 포인트 %d" % f.stat_points, "1레벨당 1포인트 · 스탯별 최대 8단계 · 자동 레벨 성장 별도")
	for id in CrownBuilds.ORDER:
		var stat: String = id
		var info: Array = CrownBuilds.STAT_INFO[stat]
		var rank: int = int(f.stat_allocations.get(stat, 0))
		var button = add_button("%s  %d/%d   ·   %s" % [info[0], rank, CrownBuilds.MAX_RANK, info[1]], func():
			if CrownBuilds.invest(arena.player, stat):
				if arena.player.stat_points > 0: show_stat_allocation()
				else: close_stat_allocation())
		button.disabled = not CrownBuilds.can_spend(f, stat)
	add_button("완료 · 게임으로 돌아가기", close_stat_allocation)

func show_choices(event: Dictionary) -> void:
	var evolution = event.kind == "evolution"
	clear_modal("진화할 계통을 선택하세요" if evolution else "능력 하나를 선택하세요", "LEVEL %d  ·  이번 생존 동안 유지됩니다" % event.level)
	var options = CrownCatalog.options_for(arena.player, event.level) if evolution else CrownCatalog.STATS.duplicate()
	if not evolution:
		options.shuffle()
		options = options.slice(0, 3)
	for choice in options:
		var selected = choice
		add_button("%s\n%s" % [choice[1], choice[2]], func():
			if evolution: CrownCatalog.evolve(arena.player, selected)
			else: CrownCatalog.apply_stat(arena.player, selected[0])
			modal.hide()
			arena.choice_open = false
			arena.process_choices())

func show_duel_select(player_pick: String = "", enemy_pick: String = "") -> void:
	if player_pick.is_empty():
		clear_modal("1대1 테스트 · 내 직업 선택", "Lv.6 동일 스탯 · 아이템/룬/XP/몬스터 없이 대전")
		for choice in CrownCatalog.EVOLUTIONS[6]:
			var selected_id: String = choice[0]
			add_button(choice[1], func(): show_duel_select(selected_id))
	else:
		clear_modal("1대1 테스트 · AI 직업 선택", "내 직업: %s" % CrownCatalog.ROSTER.find(player_pick).title)
		for choice in CrownCatalog.EVOLUTIONS[6]:
			var selected_id: String = choice[0]
			add_button(choice[1], func(): arena.start_duel(player_pick, selected_id))
		add_button("이전 · 내 직업 다시 선택", show_duel_select)
	add_button("취소 · 메인 메뉴", show_menu)

func show_duel_result(won: bool, player_class: String, enemy_class: String, duration: float) -> void:
	clear_modal("승리!" if won else "패배", "%s VS %s · 전투 %s\n동일 레벨/스탯, 부활 및 레벨업 없는 테스트" % [player_class, enemy_class, time_text(duration)])
	add_button("같은 직업으로 재대결", func(): arena.start_duel(arena.duel_player_class, arena.duel_enemy_class))
	add_button("직업 다시 선택", func():
		arena.return_menu()
		show_duel_select())
	add_button("메인 메뉴", arena.return_menu)

func show_pause(open: bool) -> void:
	if not open:
		modal.hide()
		return
	clear_modal("잠시 쉬어가기", "1대1 테스트 · 같은 레벨의 AI와 대전 중" if arena.mode == "duel" else "L: 레벨업 테스트 · B: 보스전 테스트 (Lv.10 이상)")
	add_button("계속하기", func():
		arena.paused = false
		modal.hide()
		arena.process_choices())
	add_button("소리 켜기" if Meta.muted else "소리 끄기", func():
		Meta.muted = not Meta.muted
		Meta.save_data()
		show_pause(true))
	if arena.mode == "duel":
		add_button("처음부터 재대결", func(): arena.start_duel(arena.duel_player_class, arena.duel_enemy_class))
		add_button("직업 다시 선택", func():
			arena.return_menu()
			show_duel_select())
	add_button("메뉴로 돌아가기", arena.return_menu)

func show_result(title: String, details: String) -> void:
	clear_modal(title, details)
	add_button("전장으로 돌아가기", func():
		modal.hide()
		arena.paused = false
		arena.process_choices())

func show_gameover() -> void:
	clear_modal("왕관을 놓쳤습니다", "Lv.%d  /  처치 %d  /  생존 %s\n획득 골드는 보관되었습니다" % [arena.player.level, arena.run_kills, time_text(arena.elapsed)])
	if arena.revives < 3:
		var cost = [800, 1800, 4000][arena.revives]
		var b = add_button("%d 골드 · 부활 (%d/3)" % [cost, arena.revives], arena.revive)
		b.disabled = Meta.gold < cost
	add_button("메뉴로", arena.return_menu)

func show_shop(message: String = "") -> void:
	clear_modal("룬 · 장비 보관함", "보유 %d 골드 · 최대 3개 장착 · 룬 최대 Lv.5" % Meta.gold)
	var row = VBoxContainer.new()
	panel.add_child(row)
	add_button("룬 상자 · 800", func():
		if Meta.gold < 800:
			show_shop("골드가 부족합니다")
			return
		Meta.gold -= 800
		var rune = CrownCatalog.RUNES.pick_random()
		Meta.inventory[rune[0]] = mini(5, int(Meta.inventory.get(rune[0], 0)) + 1)
		if Meta.equipped.size() < 3 and not Meta.equipped.has(rune[0]): Meta.equipped.append(rune[0])
		Meta.save_data()
		show_shop("%s Lv.%d 획득" % [rune[1], Meta.inventory[rune[0]]]), row)
	add_button("Lv.6 시작권 · 1400", func():
		if Meta.gold < 1400:
			show_shop("골드가 부족합니다")
			return
		Meta.gold -= 1400
		Meta.boosts += 1
		Meta.save_data()
		show_shop("시작권 획득"), row)
	if not message.is_empty(): add_label(message, 16, Color("edbb63"))
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var items = VBoxContainer.new()
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items)
	for rune in CrownCatalog.RUNES:
		var id = str(rune[0])
		var owned = int(Meta.inventory.get(id, 0))
		var label = "%s · Lv.%d · %s\n%s" % [rune[1], owned, "장착 중" if Meta.equipped.has(id) else "미장착", rune[2]]
		var b = add_button(label, func():
			if Meta.equipped.has(id): Meta.equipped.erase(id)
			elif Meta.equipped.size() < 3: Meta.equipped.append(id)
			else:
				show_shop("룬은 최대 3개까지 장착할 수 있습니다")
				return
			Meta.save_data()
			show_shop(), items)
		b.disabled = owned <= 0
	add_button("닫기", show_menu)

func update_hud() -> void:
	if arena == null or not is_instance_valid(arena.player): return
	var p = arena.player
	hud.get_node("Info/Name").text = "%s · Lv.%d · SP %d" % [p.display_name, p.level, p.stat_points]
	stat_button.visible = arena.mode == "play"
	stat_button.disabled = p.stat_points <= 0
	stat_button.text = "스탯 투자 +%d" % p.stat_points
	hud.get_node("Info/Health").value = 100 * p.hp / p.max_hp
	hud.get_node("Info/Stamina").value = 100 * p.stamina / p.max_stamina
	hud.get_node("Info/Groggy").value = 100 * p.groggy / arena.balance.groggy_threshold
	hud.get_node("Info/XP").value = 0 if arena.mode in ["duel", "duel_result"] else (100 if p.level >= arena.balance.max_level else 100 * p.xp / arena.balance.xp_needed(p.level))
	hud.get_node("Info/Stats").text = ("HP %d/%d · 기력 %d/%d · 그로기 %d\n공격 %d · 직업 %s" % [ceili(p.hp), roundi(p.max_hp), ceili(p.stamina), roundi(p.max_stamina), floori(p.groggy), roundi(p.damage), p.class_name_text]) if arena.mode in ["duel", "duel_result"] else ("HP %d/%d · 기력 %d/%d · 그로기 %d\n골드 %d · 처치 %d · 공격 %d" % [ceili(p.hp), roundi(p.max_hp), ceili(p.stamina), roundi(p.max_stamina), floori(p.groggy), arena.run_gold, arena.run_kills, roundi(p.damage)])
	if p.guard != null and p.guard.mode == "barrier":
		hud.get_node("Info/Stats").text += " · 방패 %d/%d" % [ceili(p.guard.meter), roundi(p.guard.meter_max)]
	hud.get_node("Info/Status").text = ("탈진 %.1f초" % p.exhaustion_left) if p.exhaustion_left > 0 else (("그로기 %.1f초" % p.groggy_left) if p.groggy_left > 0 else ("전투 중 %.1f초" % p.combat_left if p.combat_left > 0 else p.class_name_text + " · 비전투"))
	if arena.mode in ["duel", "duel_result"] and is_instance_valid(arena.duel_enemy):
		var opponent = arena.duel_enemy
		var opponent_barrier = " · 방패 %d" % ceili(opponent.guard.meter) if opponent.guard != null and opponent.guard.mode == "barrier" else ""
		hud.get_node("Boss").text = "AI %s (%s) · HP %d/%d\n기력 %d · 그로기 %d%s" % [opponent.class_name_text, CrownBuilds.profile_title(opponent.ai_build), ceili(opponent.hp), roundi(opponent.max_hp), ceili(opponent.stamina), floori(opponent.groggy), opponent_barrier]
	elif arena.mode == "boss" and arena.boss != null:
		hud.get_node("Boss").text = "BOSS %s · %s\nHP %d / %d" % [arena.boss.display_name, time_text(arena.boss_timer), ceili(arena.boss.hp), roundi(arena.boss.max_hp)]
	else: hud.get_node("Boss").text = "다음 보스 선정\n" + time_text(arena.boss_countdown)
	var ranking = arena.fighters.filter(func(f): return f.alive)
	ranking.sort_custom(func(a, b): return a.level > b.level if a.level != b.level else a.kills > b.kills)
	var rank_text = "ARENA RANKING\n"
	for f in ranking.slice(0, 5): rank_text += "%s%s Lv.%d\n" % [f.display_name, "" if f.is_player else " [%s]" % CrownBuilds.profile_title(f.ai_build), f.level]
	hud.get_node("Leaderboard").text = "1 VS 1 · %s" % time_text(arena.elapsed) if arena.mode in ["duel", "duel_result"] else rank_text
	var slots = ["평타", "대시", "E", "R", "Q"]
	var keys = ["attack", "dash", "e", "r", "q"]
	for i in 5:
		if i >= 2 and p.evolutions.size() < i - 1 and arena.mode not in ["duel", "duel_result"]: slots[i] += " Lv.%d" % [6, 13, 21][i - 2]
		elif p.cooldown[keys[i]] > 0: slots[i] += " %.1f" % p.cooldown[keys[i]]
	hud.get_node("Skills").text = "   |   ".join(slots)

func notice(title: String, subtitle: String = "") -> void:
	notice_time = 3
	hud.get_node("Notice").text = title + "\n" + subtitle

func feed(text: String) -> void:
	feed_lines.push_front(text)
	feed_lines = feed_lines.slice(0, 4)
	hud.get_node("Feed").text = "\n".join(feed_lines)

static func time_text(seconds: float) -> String:
	return "%02d:%02d" % [int(maxf(0, seconds)) / 60, int(maxf(0, seconds)) % 60]

# Preserve the simulation when the browser viewport / device orientation changes.
func refresh_layout(force: bool = false) -> void:
	var physical = get_window().size
	if physical.x <= 0 or physical.y <= 0: return
	if not force and physical == last_window_size: return
	last_window_size = physical
	var ratio = float(physical.x) / physical.y
	var base_width = maxf(432, 648 * ratio)
	var logical = Vector2i(roundi(base_width), roundi(base_width / ratio))
	get_window().content_scale_size = logical
	compact = logical.x < 1000
	var width = float(logical.x)
	var height = float(logical.y)
	box.custom_minimum_size.x = minf(540, width - 40)
	panel.custom_minimum_size.x = minf(650, width - 40)
	box.get_node("Title").add_theme_font_size_override("font_size", 46 if compact else 58)
	box.get_node("Help").text = "WASD 이동 · 좌클릭 공격 · 우클릭 막기
Shift 달리기 · Space 대시 · E/R/Q 기술
모바일: 조이스틱 + 전투 버튼 / 세로·가로 자동 전환"
	place_hud("Info", Rect2(16, 16, 240 if compact else 282, 172))
	place_hud("Pause", Rect2(width - 112, 16, 96, 48))
	place_hud("StatInvestment", Rect2(width - 156, 68, 140, 42))
	place_hud("Boss", Rect2(16, 202, width - 32, 54) if compact else Rect2(width / 2 - 160, 18, 320, 54))
	hud.get_node("Boss").add_theme_font_size_override("font_size", 15 if compact else 18)
	hud.get_node("Leaderboard").visible = not compact
	hud.get_node("Feed").visible = not compact
	place_hud("Notice", Rect2(16, height * 0.32, width - 32, 80))
	hud.get_node("Notice").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mobile = arena != null and arena.touch_mode
	var bottom = 320 if mobile and ratio < 1 else (280 if mobile else 68)
	place_hud("Skills", Rect2(16, height - bottom, width - 32, 48))
	hud.get_node("Skills").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_hud("Minimap", Rect2(width - 222, height - 168, 198, 136))
	touch.clear_input()
	touch.queue_redraw()

func place_hud(node_name: String, rect: Rect2) -> void:
	var control = hud.get_node(node_name)
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
