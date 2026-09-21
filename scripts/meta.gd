extends Node

var gold: int = 2400
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
			gold = int(saved.get("gold", 2400))
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
				gold = int(saved.get("gold", 2400))
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
	f.damage *= 1 + 0.04 * rune_level("edge")
	f.max_hp *= 1 + 0.05 * rune_level("heart")
	f.hp = f.max_hp
	f.speed *= 1 + 0.03 * rune_level("wind")
	f.xp_gain *= 1 + 0.05 * rune_level("wisdom")
	f.gold_bonus *= 1 + 0.08 * rune_level("fortune")
