@tool
class_name WeaponData
extends Resource
## One weapon class. Every field maps 1:1 onto the original WEAPONS table.

@export var id := "pulse"
@export var display_name := "VX-9 Helix Carbine"
@export var short_name := "HELIX"
@export var weapon_class := "Assault"
@export_multiline var description := ""
@export var carry := "Low ready"
@export var reload_name := "Magazine swap"
@export var model_scene: PackedScene
@export var icon: Texture2D
@export var color := Color("#21e6ff")

@export_group("Ballistics")
@export var damage := 20.0
@export var fire_interval := 0.09        ## seconds between shots (original `rate`)
@export var magazine := 30
@export var reload_time := 1.4
@export var pellets := 1
@export var spread := 0.004
@export var recoil := 0.012
@export var kick := 0.006
@export var block_break := 0.9           ## radius of crate destruction on impact
@export var max_range := 100.0

@export_group("Fire mode")
## hip: fire while held. ads: aim while held and fire. release: aim while held, fire on release.
## mixed: fire while held, aim after 0.25 s. onetap: one shot per press.
@export_enum("hip", "ads", "release", "mixed", "onetap") var fire_mode := "hip"
@export var ads_time := 0.2
@export var ads_zoom := 0.22             ## fraction of FOV removed at full ADS
@export var scoped := false
@export var sight_height := 0.12         ## gun drops by this so the sights line up when aiming
@export var brass := 0                   ## casings ejected per shot

@export_group("Special")
@export var burst_count := 0             ## rounds per trigger pull (0 = off)
@export var spin_up := 0.0               ## seconds to reach full fire rate (0 = off)
@export var move_multiplier := 1.0
@export var pierce := false              ## passes through every enemy and up to 3 blocks
@export var explosion_radius := 0.0
@export var chill_time := 0.0
@export var gravity_well_time := 0.0
@export var chain_jumps := 0

@export_group("Precision rifle")
@export var bolt_action := false          ## cycle the bolt by hand after every shot
@export var bolt_time := 0.95             ## seconds for the full bolt cycle
@export var bullet_speed := 0.0           ## m/s; 0 = hitscan. Otherwise a real projectile with travel time
@export var bullet_gravity := 9.8         ## m/s² of drop for projectiles
@export var headshot_mult := 1.0          ## damage multiplier on the head (players) / head end (spiders)
@export var scope_zoom := 4.2             ## magnification when scoped
@export var scope_sway := 0.0             ## radians of breathing sway while scoped
@export var hold_breath := 0.0            ## seconds you can steady the scope (sprint key while scoped)
@export var hip_spread := 0.0             ## extra spread when not fully scoped (no-scope penalty)
@export var settle_time := 0.0            ## seconds after scoping in before the shot is fully accurate
