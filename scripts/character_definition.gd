class_name CrownCharacterDefinition
extends Resource

@export var id: String = "knight"
@export var title: String = "초보 기사"
@export_multiline var description: String = ""
@export var unlock_level: int = 1
## Empty permits every previous evolution. Otherwise requires the latest selected class ID.
@export var parent_ids: PackedStringArray = []
@export var multipliers: Dictionary = {}
@export var additions: Dictionary = {}
@export_enum("none", "e", "r", "q") var skill_slot: String = "none"
@export var ability: CrownAbility
## Optional scene instantiated on evolution; retains the existing fighter state.
@export var evolution_scene: PackedScene
@export var attack_animation: Animation
@export var attack_cooldown: float = 0.56
@export var attack_target_limit: int = 2
