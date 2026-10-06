@tool
class_name SkillData
extends Resource
## One active skill (original SKILLS table).

@export var id := "shield"
@export var display_name := "Overshield"
@export var short_name := "SHIELD"
@export var cooldown := 14.0
@export var color := Color("#7ad7ff")
@export_multiline var description := ""
@export var icon: Texture2D
