extends Node
## Global state: the item database, the chosen loadout and the player's settings (saved to user://).

signal settings_changed

const DB: GameDatabase = preload("res://data/database.tres")
const SAVE_PATH := "user://viral_vanguard.cfg"

var settings := {
	"weapon": "pulse",
	"armor": "vanguard",
	"skill": "shield",
	"sensitivity": 1.0,
	"fov": 85.0,
	"ads_mode": "toggle",     # toggle | hold (right mouse)
	"vol_game": 0.8,
	"vol_music": 0.6,
	"player_name": "",
}


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in settings:
			settings[k] = cf.get_value("settings", k, settings[k])
	if str(settings.player_name).strip_edges() == "":
		settings.player_name = "OPERATIVE-%03d" % (randi() % 1000)
	apply_audio()


func save() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("settings", k, settings[k])
	cf.save(SAVE_PATH)


func set_setting(key: String, value) -> void:
	settings[key] = value
	if key.begins_with("vol_"):
		apply_audio()
	save()
	settings_changed.emit()


func apply_audio() -> void:
	for pair in [["SFX", "vol_game"], ["Music", "vol_music"]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0:
			var v: float = settings[pair[1]]
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(bus, v <= 0.001)


func weapon(id: String = "") -> WeaponData:
	return _pick(DB.weapons, id if id else settings.weapon)


func armor(id: String = "") -> ArmorData:
	return _pick(DB.armors, id if id else settings.armor)


func skill(id: String = "") -> SkillData:
	return _pick(DB.skills, id if id else settings.skill)


func _pick(arr: Array, id: String):
	for x in arr:
		if x.id == id:
			return x
	return arr[0]
