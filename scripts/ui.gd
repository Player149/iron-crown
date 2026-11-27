extends CanvasLayer

var arena
var font = preload("res://assets/NotoSansKR.ttf")
var notice_time: float = 0
var feed_lines: Array = []
var last_window_size = Vector2i.ZERO
var last_touch_mode: bool = false
var compact: bool = false
var stat_rows: Dictionary = {}
var evolution_choice_count: int = 0
var balance_lab_running := false
var balance_lab_status: Label
@onready var stat_panel: PanelContainer = $Root/HUD/StatPanel
@onready var stat_items: VBoxContainer = $Root/HUD/StatPanel/Items
@onready var evolution_panel: PanelContainer = $Root/HUD/EvolutionPanel
@onready var evolution_items: HBoxContainer = $Root/HUD/EvolutionPanel/Items/Choices
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
		arena.start_coronation())
	box.get_node("Start").text = "영광의 대관 · 데스매치"
	box.get_node("Tags").text = "철혈 순위전  /  중앙 결전  /  최대 Lv.25"
	box.get_node("Shop").pressed.connect(show_shop)
	var duel_button := Button.new()
	duel_button.name = "DuelTest"
	duel_button.text = "1대1 전투 테스트 (플레이어 VS AI)"
	duel_button.custom_minimum_size = Vector2(0, 50)
	box.add_child(duel_button)
	box.move_child(duel_button, box.get_node("Shop").get_index())
	duel_button.pressed.connect(show_duel_select)
	var lab_button := Button.new()
	lab_button.name = "BalanceLab"
	lab_button.text = "AI 자동 전투 · 밸런스 실험실"
	lab_button.custom_minimum_size = Vector2(0, 50)
	box.add_child(lab_button)
	box.move_child(lab_button, box.get_node("Shop").get_index())
	lab_button.pressed.connect(show_balance_lab)
	# Build small click targets inside the editor-authored HUD panel.
	for i in CrownBuilds.ORDER.size():
		var stat: String = CrownBuilds.ORDER[i]
		var row = HBoxContainer.new()
		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var add = Button.new()
		add.text = "+"
		add.custom_minimum_size = Vector2(30, 30)
		add.pressed.connect(func(): invest_stat(stat))
		row.add_child(add)
		stat_items.add_child(row)
		stat_rows[stat] = {"row": row, "label": label, "button": add}
	hud.get_node("FastForward").pressed.connect(func(): arena.toggle_coronation_fast_forward())
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
	if OS.has_feature("web"):
		print_web_menu_ready.call_deferred()

func print_web_menu_ready() -> void:
	# Report normalized button coordinates for the exported-browser smoke test.
	await get_tree().process_frame
	await get_tree().process_frame
	var extent := get_viewport().get_visible_rect().size
	var start: Control = box.get_node("Start")
	var point := start.get_global_rect().get_center() / extent
	print("IRON_CROWN_MENU_READY %.6f %.6f" % [point.x, point.y])

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
	if hud.visible: update_hud()


func show_menu() -> void:
	stat_panel.hide()
	evolution_panel.hide()
	menu.show()
	hud.hide()
	modal.hide()
	touch.hide()
	box.get_node("Name").text = Meta.player_name
	box.get_node("Gold").text = "보유 골드 %d   ·   장착 룬 %d/3" % [Meta.gold, Meta.equipped.size()]
	box.get_node("Boost").hide()

func show_game() -> void:
	if OS.has_feature("web"):
		print("IRON_CROWN_GAME_STARTED " + arena.mode)
	menu.hide()
	modal.hide()
	evolution_panel.hide()
	hud.show()
	refresh_growth_panels()
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

## Stats are always visible when points remain and never open a blocking modal.
func invest_stat(stat: String) -> void:
	if arena == null or arena.mode != "play" or arena.paused or not is_instance_valid(arena.player): return
	if CrownBuilds.invest(arena.player, stat): refresh_growth_panels()

func refresh_growth_panels() -> void:
	if arena == null or not is_instance_valid(arena.player): return
	if arena.mode != "play": evolution_panel.hide()
	var f = arena.player
	var show_stats: bool = arena.mode == "play" and f.alive and f.stat_points > 0
	stat_panel.visible = show_stats
	if show_stats:
		stat_items.get_node("Title").text = "스탯 포인트 %d · 1~6" % f.stat_points
		for i in CrownBuilds.ORDER.size():
			var id: String = CrownBuilds.ORDER[i]
			var rank: int = int(f.stat_allocations.get(id, 0))
			var entry: Dictionary = stat_rows[id]
			entry.label.text = "%d %s %d/%d" % [i + 1, CrownBuilds.STAT_INFO[id][0], rank, CrownBuilds.MAX_RANK]
			entry.button.disabled = not CrownBuilds.can_spend(f, id)

func show_choices(event: Dictionary) -> void:
	# Evolution is an in-game overlay. Player, AI and physics keep running.
	if event.kind != "evolution":
		arena.choice_open = false
		arena.process_choices()
		return
	var options: Array = CrownCatalog.options_for(arena.player, event.level)
	if options.is_empty():
		arena.choice_open = false
		arena.process_choices()
		return
	for child in evolution_items.get_children():
		evolution_items.remove_child(child)
		child.queue_free()
	evolution_choice_count = options.size()
	evolution_panel.show()
	evolution_panel.get_node("Items/Title").text = "Lv.%d 진화 선택 · 전투 진행 중" % event.level
	for choice in options:
		var selected: Array = choice
		var button = Button.new()
		button.text = "%s\n%s" % [choice[1], choice[2]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 72
		button.pressed.connect(func(): select_evolution(selected))
		evolution_items.add_child(button)
		style_buttons(button)
	layout_evolution_panel(float(get_window().content_scale_size.x))

func select_evolution(selected: Array) -> void:
	if not evolution_panel.visible or arena == null or arena.mode != "play": return
	CrownCatalog.evolve(arena.player, selected)
	evolution_panel.hide()
	arena.choice_open = false
	refresh_growth_panels()
	arena.process_choices()

## Developer tool: run the real fighter AI in batches from the shipped menu.
func show_balance_lab() -> void:
	if balance_lab_running: return
	clear_modal("AI 전투 밸런스 실험실", "4직업 자동 교차전 · 이번 실험의 대진별 통계와 경기별 상세 결과")
	for rounds in [10, 100, 1000]:
		var requested: int = rounds
		add_button("%d판 자동 실행" % rounds, func(): start_balance_lab(requested))
	add_button("메인 메뉴", show_menu)

func start_balance_lab(rounds: int) -> void:
	if balance_lab_running: return
	balance_lab_running = true
	var runner = load("res://tests/balance_lab.gd").new()
	runner.embedded = true
	arena.add_child(runner)
	runner.batch_progress.connect(func(completed: int, total: int):
		if not balance_lab_running: return
		# start_duel resets the normal HUD/modal, so restore the lab overlay.
		if balance_lab_status == null or not is_instance_valid(balance_lab_status) or not modal.visible:
			clear_modal("AI 자동 전투 실행 중", "실제 AI 판단·공격 판정을 사용해 전투를 빠르게 계산합니다.")
			balance_lab_status = add_label("", 20)
		if is_instance_valid(balance_lab_status):
			balance_lab_status.text = "%d / %d 경기 완료 (%.0f%%)" % [completed, total, 100.0 * completed / maxi(1, total)]
	)
	runner.batch_finished.connect(func(records: Array, failures: int):
		balance_lab_running = false
		balance_lab_status = null
		show_balance_results(records, failures)
	)
	runner.run_embedded(arena, rounds)

func show_balance_results(records: Array, failures: int) -> void:
	var wins: Dictionary = {}
	var decided := 0
	var timeouts := 0
	for entry in records:
		var winner: String = str(entry.get("winner_class", ""))
		if winner.is_empty():
			timeouts += 1
			continue
		wins[winner] = int(wins.get(winner, 0)) + 1
		decided += 1
	clear_modal("AI 대전 %d판 종료" % records.size(), "승부 결정 %d · 시간 초과 %d · 시작 실패 %d" % [decided, timeouts, failures])
	var labels: Dictionary = preload("res://tests/balance_lab.gd").CLASS_NAMES
	var class_totals := PackedStringArray()
	for id in labels:
		class_totals.append("%s %d승" % [labels[id], wins.get(id, 0)])
	add_label("  ·  ".join(class_totals), 16)
	var report := RichTextLabel.new()
	report.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y * 0.35, 120.0, 360.0)
	report.selection_enabled = true
	report.text = preload("res://tests/balance_lab.gd").format_report(records)
	panel.add_child(report)
	add_button("다시 실험하기", show_balance_lab)
	add_button("메인 메뉴", show_menu)

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
	var details := "L: 레벨업 테스트 · B: 보스전 테스트 (Lv.10 이상)"
	if arena.mode == "duel": details = "1대1 테스트 · 같은 레벨의 AI와 대전 중"
	elif arena.coronation != null: details = "영광의 대관 · 철혈 순위 경쟁"
	clear_modal("잠시 쉬어가기", details)
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

func show_coronation_result(ranking: Array) -> void:
	var winner = ranking[0]
	var placement := ranking.find(arena.player) + 1
	clear_modal("철의 왕관 · %s" % winner.display_name, "내 순위 %d위 · 철혈 %d" % [placement, arena.player.iron_score])
	for i in mini(5, ranking.size()):
		add_label("%d위  %s   철혈 %d" % [i + 1, ranking[i].display_name, ranking[i].iron_score])
	add_button("영광의 대관 다시 시작", arena.start_coronation)
	add_button("메뉴로", arena.return_menu)

func show_result(title: String, details: String) -> void:
	clear_modal(title, details)
	add_button("전장으로 돌아가기", func():
		modal.hide()
		arena.paused = false
		arena.process_choices())

func show_gameover() -> void:
	clear_modal("왕관을 놓쳤습니다", "Lv.%d  /  처치 %d  /  생존 %s\n획득 골드는 보관되었습니다" % [arena.player.level, arena.run_kills, time_text(arena.elapsed)])
	if arena.revives < arena.balance.revive_costs.size():
		var cost = arena.balance.revive_costs[arena.revives]
		var b = add_button("%d 골드 · 부활 (%d/%d)" % [cost, arena.revives, arena.balance.revive_costs.size()], arena.revive)
		b.disabled = Meta.gold < cost
	add_button("메뉴로", arena.return_menu)

func show_shop(message: String = "") -> void:
	clear_modal("룬 · 장비 보관함", "보유 %d 골드 · 최대 3개 장착 · 룬 최대 Lv.5" % Meta.gold)
	var row = VBoxContainer.new()
	panel.add_child(row)
	add_button("룬 상자 · %d" % Meta.RUNE_CHEST_COST, func():
		if Meta.gold < Meta.RUNE_CHEST_COST:
			show_shop("골드가 부족합니다")
			return
		Meta.gold -= Meta.RUNE_CHEST_COST
		var rune = CrownCatalog.RUNES.pick_random()
		Meta.inventory[rune[0]] = mini(Meta.RUNE_LEVEL_CAP, int(Meta.inventory.get(rune[0], 0)) + 1)
		if Meta.equipped.size() < Meta.EQUIPPED_RUNE_CAP and not Meta.equipped.has(rune[0]): Meta.equipped.append(rune[0])
		Meta.save_data()
		show_shop("%s Lv.%d 획득" % [rune[1], Meta.inventory[rune[0]]]), row)
	add_button("Lv.6 시작권 · %d" % Meta.START_TICKET_COST, func():
		if Meta.gold < Meta.START_TICKET_COST:
			show_shop("골드가 부족합니다")
			return
		Meta.gold -= Meta.START_TICKET_COST
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
			elif Meta.equipped.size() < Meta.EQUIPPED_RUNE_CAP: Meta.equipped.append(id)
			else:
				show_shop("룬은 최대 %d개까지 장착할 수 있습니다" % Meta.EQUIPPED_RUNE_CAP)
				return
			Meta.save_data()
			show_shop(), items)
		b.disabled = owned <= 0
	add_button("닫기", show_menu)

func update_hud() -> void:
	if arena == null or not is_instance_valid(arena.player): return
	var fast_forward: Button = hud.get_node("FastForward")
	fast_forward.visible = arena.coronation != null and arena.active()
	fast_forward.text = "1× 되돌리기" if arena.coronation_fast_forward else "%d× 빨리감기" % arena.CORONATION_FAST_FORWARD_RATE
	var p = arena.player
	hud.get_node("Info/Name").text = "%s · Lv.%d · SP %d" % [p.display_name, p.level, p.stat_points]
	refresh_growth_panels()
	hud.get_node("Info/Health").value = 100 * p.hp / p.max_hp
	hud.get_node("Info/Stamina").value = 100 * p.stamina / p.max_stamina
	hud.get_node("Info/Groggy").value = 100 * p.groggy / arena.balance.groggy_threshold
	hud.get_node("Info/XP").value = 0 if arena.mode in ["duel", "duel_result"] else (100 if p.level >= arena.balance.max_level else 100 * p.xp / arena.balance.xp_needed(p.level))
	hud.get_node("Info/Stats").text = ("HP %d/%d · 기력 %d/%d · 그로기 %d\n공격 %d · 직업 %s" % [ceili(p.hp), roundi(p.max_hp), ceili(p.stamina), roundi(p.max_stamina), floori(p.groggy), roundi(p.damage), p.class_name_text]) if arena.mode in ["duel", "duel_result"] else ("HP %d/%d · 기력 %d/%d · 그로기 %d\n골드 %d · 처치 %d · 공격 %d" % [ceili(p.hp), roundi(p.max_hp), ceili(p.stamina), roundi(p.max_stamina), floori(p.groggy), arena.run_gold, arena.run_kills, roundi(p.damage)])
	if p.guard != null and p.guard.mode == "barrier":
		hud.get_node("Info/Stats").text += " · 방패 %d/%d" % [ceili(p.guard.meter), roundi(p.guard.meter_max)]
	hud.get_node("Info/Status").text = ("탈진 %.1f초" % p.exhaustion_left) if p.exhaustion_left > 0 else (("그로기 %.1f초" % p.groggy_left) if p.groggy_left > 0 else (("경직 %.2f초" % p.hitstun_left) if p.hitstun_left > 0 else ("전투 중 %.1f초" % p.combat_left if p.combat_left > 0 else p.class_name_text + " · 비전투")))
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
	if arena.coronation != null:
		var match_data = arena.coronation
		var phase_text: String = ["전장 성장", "중앙으로 이동", "중앙 결전"][match_data.phase]
		if match_data.phase == 2:
			var bracket = match_data.bracket
			var title := "최종전" if match_data.final_tournament else "1차전"
			phase_text = "%s · %dR" % [title, bracket.round_number]
		if match_data.phase == 1 and p.position.distance_to(arena.world_dimensions() / 2.0) > match_data.safe_radius():
			var direction: Vector2 = arena.world_dimensions() / 2.0 - p.position
			var compass := ["동", "남동", "남", "남서", "서", "북서", "북", "북동"]
			phase_text = "위험 구역 · %s쪽으로" % compass[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]
		var match_clock := time_text(ceili(maxf(0.0, match_data.rules.match_seconds - arena.elapsed)))
		hud.get_node("Boss").text = "%s\n%s · 철혈 %d" % [match_clock, phase_text, p.iron_score]
		var leaders := "철혈 순위\n"
		for f in match_data.ranking().slice(0, 5):
			leaders += "%s  %d\n" % [f.display_name, f.iron_score]
		hud.get_node("Leaderboard").text = leaders
		if not p.alive:
			hud.get_node("Info/Status").text = ("다음 라운드 대기" if p.match_slot in match_data.bracket.advancing and not match_data.winner_announced else "중앙 토너먼트 관전 중") if match_data.phase == 2 else "부활까지 %.1f초" % maxf(0.0, p.respawn_timer)
		elif p.coronation_effect > 0.0:
			hud.get_node("Info/Status").text = "가속 %.1f초" % p.coronation_effect
		elif p.coronation_effect < 0.0:
			hud.get_node("Info/Status").text = "둔화 %.1f초" % -p.coronation_effect
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
	place_hud("FastForward", Rect2(width - 146, 72, 130, 44) if compact else Rect2(width - 250, 16, 130, 48))
	# Keep stats beneath health bars and away from the center of combat.
	var stats_width: float = 166 if compact else 198
	var stat_y: float = 196
	place_hud("StatPanel", Rect2(12, stat_y, stats_width, 254))
	stat_items.get_node("Title").add_theme_font_size_override("font_size", 12 if compact else 14)
	for entry in stat_rows.values():
		entry.label.add_theme_font_size_override("font_size", 11 if compact else 13)
	layout_evolution_panel(width)
	place_hud("Boss", Rect2(12 + stats_width + 8, 202, maxf(116, width - stats_width - 40), 64) if compact else Rect2(width / 2 - 160, 18, 320, 54))
	hud.get_node("Boss").add_theme_font_size_override("font_size", 15 if compact else 18)
	hud.get_node("Leaderboard").visible = not compact
	hud.get_node("Feed").visible = not compact
	place_hud("Notice", Rect2(16, maxf(300, height * 0.47), width - 32, 80))
	hud.get_node("Notice").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mobile = arena != null and arena.touch_mode
	var bottom = 320 if mobile and ratio < 1 else (280 if mobile else 68)
	place_hud("Skills", Rect2(16, height - bottom, width - 32, 48))
	hud.get_node("Skills").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_hud("Minimap", Rect2(width - 222, height - 168, 198, 136))
	touch.clear_input()
	touch.queue_redraw()

func layout_evolution_panel(width: float) -> void:
	# Choice count determines a centered width; no scene resize or input reset.
	var count: int = maxi(1, evolution_choice_count)
	var evolution_width: float = minf(width - 24, float(count) * (114 if compact else 172) + 16)
	place_hud("EvolutionPanel", Rect2((width - evolution_width) * 0.5, 80 if compact else 88, evolution_width, 104))
	for choice_button in evolution_items.get_children():
		if choice_button is Button:
			choice_button.add_theme_font_size_override("font_size", 11 if compact else 14)

func place_hud(node_name: String, rect: Rect2) -> void:
	var control = hud.get_node(node_name)
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
