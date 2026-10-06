@tool
class_name GameDatabase
extends Resource
## Master list of everything selectable in the hangar. Add a new .tres here to make it appear in the menus.

@export var weapons: Array[WeaponData] = []
@export var armors: Array[ArmorData] = []
@export var skills: Array[SkillData] = []
