extends Node

const STARTING_GOLD := 2400
const RUNE_CHEST_COST := 800
const START_TICKET_COST := 1400
const RUNE_LEVEL_CAP := 5
const EQUIPPED_RUNE_CAP := 3
const RUNE_BONUS := {"edge": 0.04, "heart": 0.05, "wind": 0.03, "wisdom": 0.05, "fortune": 0.08}

var gold: int = STARTING_GOLD
var inventory: Dictionary = {}
var equipped: Array = []
var boosts: int = 0
var player_name: String = "방랑 기사"
var muted: bool = false
const SAVE_PATH = "user://iron_crown_v2.json"

func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if saved is Dictionary:
			gold = int(saved.get("gold", STARTING_GOLD))
			inventory = saved.get("inventory", {})
			equipped = saved.get("equipped", [])
			boosts = int(saved.get("boosts", 0))
			player_name = str(saved.get("name", "방랑 기사"))
			muted = bool(saved.get("muted", false))
	elif OS.has_feature("web"):
		# Same-origin migration from the old Canvas game, only on first launch.
		var raw = JavaScriptBridge.eval("localStorage.getItem('ironCrownMeta')", true)
		if raw is String:
			var saved = JSON.parse_string(raw)
			if saved is Dictionary:
				gold = int(saved.get("gold", STARTING_GOLD))
				inventory = saved.get("inventory", {})
				equipped = saved.get("equipped", [])
				boosts = int(saved.get("boosts", 0))
				player_name = str(saved.get("name", "방랑 기사"))
				save_data()

func save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"gold": gold, "inventory": inventory, "equipped": equipped, "boosts": boosts, "name": player_name, "muted": muted}))

func rune_level(id: String) -> int:
	return int(inventory.get(id, 0)) if equipped.has(id) else 0

func apply_runes(f) -> void:
	f.damage *= 1 + RUNE_BONUS.edge * rune_level("edge")
	f.max_hp *= 1 + RUNE_BONUS.heart * rune_level("heart")
	f.hp = f.max_hp
	f.speed *= 1 + RUNE_BONUS.wind * rune_level("wind")
	f.xp_gain *= 1 + RUNE_BONUS.wisdom * rune_level("wisdom")
	f.gold_bonus *= 1 + RUNE_BONUS.fortune * rune_level("fortune")
