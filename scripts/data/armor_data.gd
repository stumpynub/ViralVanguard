@tool
class_name ArmorData
extends Resource
## One armour frame (original ARMORS table).

@export var id := "vanguard"
@export var display_name := "Vanguard"
@export var armor_class := "Medium"
@export_multiline var perk := ""
@export var tier := 0                    ## 0 = base suit, 1..3 = Mk II..IV (jetpack from tier 2)
@export var primary_color := Color("#ff2bd6")
@export var secondary_color := Color("#cfcae8")
@export var icon: Texture2D

@export_group("Stats")
@export var max_health := 110
@export var speed := 1.0
@export var damage_reduction := 0.1
@export var regen := 2.0                 ## health per second
@export var cooldown_reduction := 0.0
@export var enemy_slow := 1.0            ## multiplier on infected speed
@export var jump_multiplier := 1.0
