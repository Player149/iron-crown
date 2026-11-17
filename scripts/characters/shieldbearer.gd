extends "res://scripts/fighter.gd"

## 방어 기능은 씬의 Guard 컴포넌트가 담당한다.
func _ready() -> void:
	super._ready()
	class_name_text = definition.title
