extends "res://scripts/fighter.gd"

## 창병 확장 지점. 이동, 공격, 자원, 그로기는 공통 Fighter가 처리한다.
func _ready() -> void:
	super._ready()
	class_name_text = definition.title
