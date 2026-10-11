extends CanvasLayer

var arena
var font = preload("res://assets/NotoSansKR.ttf")
var notice_time: float = 0
var feed_lines: Array = []
var last_window_size = Vector2i.ZERO
var last_touch_mode: bool = false
var compact: bool = false
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
	var deathmatch_button := Button.new()
	deathmatch_button.text = "8분 데스매치 · AI 9명 (NEW)"
	deathmatch_button.custom_minimum_size = Vector2(0, 54)
	box.add_child(deathmatch_button)
	box.move_child(deathmatch_button, box.get_node("Start").get_index() + 1)
	deathmatch_button.pressed.connect(func():
		Meta.player_name = box.get_node("Name").text.strip_edges().left(12)
		if Meta.player_name.is_empty(): Meta.player_name = "방랑 기사"
		Meta.save_data()
		get_tree().change_scene_to_file("res://scenes/deathmatch.tscn"))
	box.get_node("Shop").pressed.connect(show_shop)
	box.get_node("Eyebrow").text = "IRON CROWN / TEST 1 / BRANCHING EVOLUTION"
	box.get_node("Subtitle").text = "계보 진화 · 무기별 전투 · 자세 붕괴 실험"
	box.get_node("Tags").text = "Lv.5 / 15 / 25 분기 · 자세 게이지 · AI 테스트"
	hud.get_node("Pause").pressed.connect(func():
		if arena.choice_open: return
		arena.paused = true
		show_pause(true))
	for pair in [["Health", Color("e76078")], ["Stamina", Color("e1b459")], ["XP", Color("58bde4")]]:
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
	box.get_node("Boost").text = "Lv.5 시작권 사용 (%d개)" % Meta.boosts
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

func show_choices(event: Dictionary) -> void:
	var evolution: bool = event.kind == "evolution"
	clear_modal("TEST 1 / 계보 진화" if evolution else "능력 하나를 선택하세요", "LEVEL %d · 현재 직업에 따라 다음 분기가 달라집니다" % event.level if evolution else "LEVEL %d · 이번 생존 동안 유지됩니다" % event.level)
	var options: Array = CrownTest1Rules.options_for(arena.player, int(event.level)) if evolution else CrownCatalog.STATS.duplicate()
	if not evolution:
		options.shuffle()
		options = options.slice(0, 3)
	if options.is_empty():
		add_label("이 단계의 진화가 없습니다.", 15)
		add_button("돌아가기", func():
			modal.hide()
			arena.choice_open = false
			arena.process_choices())
		return
	var parent: Node = panel
	if options.size() >= 5:
		var scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0, minf(365, maxf(185, get_window().content_scale_size.y * 0.46)))
		panel.add_child(scroll)
		var list = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 6)
		scroll.add_child(list)
		parent = list
	for choice in options:
		var selected: Array = choice
		add_button("%s\n%s" % [choice[1], choice[2]], func():
			if evolution: CrownTest1Rules.evolve(arena.player, selected)
			else: CrownCatalog.apply_stat(arena.player, selected[0])
			modal.hide()
			arena.choice_open = false
			arena.process_choices(), parent)

func show_pause(open: bool) -> void:
	if not open:
		modal.hide()
		return
	if arena.has_method("is_deathmatch") and arena.is_deathmatch():
		clear_modal("데스매치 일시정지", "8분 매치 · 부활 시 XP 일부 감소")
	else:
		clear_modal("TEST1 / 잠시 쉬어가기", "다음 진화 즉시 체험 · L 레벨업 · B 보스전")
		add_button("TEST1 · 다음 진화 즉시 체험", func():
			arena.paused = false
			modal.hide()
			arena.test1_next_evolution())
	add_button("계속하기", func():
		arena.paused = false
		modal.hide()
		arena.process_choices())
	add_button("소리 켜기" if Meta.muted else "소리 끄기", func():
		Meta.muted = not Meta.muted
		Meta.save_data()
		show_pause(true))
	add_button("TEST1 메뉴로" if arena.has_method("is_deathmatch") else "메뉴로 · 골드 보관", arena.return_menu)

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
	add_button("Lv.5 시작권 · 1400", func():
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
	hud.get_node("Info/Name").text = "%s · Lv.%d" % [p.display_name, p.level]
	hud.get_node("Info/Health").value = 100 * p.hp / p.max_hp
	hud.get_node("Info/Stamina").value = 100 * p.stamina / p.max_stamina
	hud.get_node("Info/XP").value = 100 if p.level == 40 else 100 * p.xp / arena.balance.xp_needed(p.level)
	hud.get_node("Info/Stats").text = "HP %d/%d   ST %d/%d\n골드 %d · 처치 %d · 공격 %d\n자세 %d/100%s" % [ceili(p.hp), roundi(p.max_hp), floori(p.stamina), roundi(p.max_stamina), arena.run_gold, arena.run_kills, roundi(p.damage), roundi(p.posture), (" · 발열 %d" % roundi(p.robot_heat)) if p.combat_style == "robot" else ""]
	hud.get_node("Info/Status").text = ("자세 붕괴 %.1f초" % p.stagger_left) if p.stagger_left > 0 else (("탈진 %.1f초" % p.exhausted) if p.exhausted > 0 else ("%s · 전투 중" % p.class_name_text if p.combat_left > 0 else p.class_name_text + " · 비전투"))
	if arena.mode == "boss" and arena.boss != null:
		hud.get_node("Boss").text = "BOSS %s · %s\nHP %d / %d" % [arena.boss.display_name, time_text(arena.boss_timer), ceili(arena.boss.hp), roundi(arena.boss.max_hp)]
	else: hud.get_node("Boss").text = "다음 보스 선정\n" + time_text(arena.boss_countdown)
	var ranking = arena.fighters.filter(func(f): return f.alive)
	ranking.sort_custom(func(a, b): return a.level > b.level if a.level != b.level else a.kills > b.kills)
	var rank_text = "ARENA RANKING\n"
	for f in ranking.slice(0, 5): rank_text += "%s  Lv.%d\n" % [f.display_name, f.level]
	hud.get_node("Leaderboard").text = rank_text
	var slots = ["평타", "대시", "E", "R", "Q"]
	var keys = ["attack", "dash", "e", "r", "q"]
	for i in 5:
		if i >= 2 and p.evolutions.size() < i - 1: slots[i] += " Lv.%d" % [5, 15, 25][i - 2]
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
	box.get_node("Help").text = "TEST 1 · 계보형 진화 · 자세 붕괴\nWASD 이동 · 좌클릭 공격 · 우클릭 막기
Shift 달리기 · Space 대시 · E/R/Q 기술
모바일: 조이스틱 + 전투 버튼 / 세로·가로 자동 전환"
	place_hud("Info", Rect2(16, 16, 240 if compact else 282, 172))
	place_hud("Pause", Rect2(width - 112, 16, 96, 48))
	place_hud("Boss", Rect2(16, 197, width - 32, 54) if compact else Rect2(width / 2 - 160, 18, 320, 54))
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
