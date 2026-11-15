class_name CrownCharacterRoster
extends Resource

@export var characters: Array[CrownCharacterDefinition] = []

func find(id: String) -> CrownCharacterDefinition:
	for definition in characters:
		if definition.id == id: return definition
	return null
