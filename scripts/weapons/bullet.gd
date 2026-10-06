extends Node3D
## A real round (precision rifle): flies at the weapon's muzzle velocity, drops under gravity, draws a hot streak,
## and resolves its hit when it gets there. The shooter's peer owns it, like every other hit in the game: spider
## damage goes through Arena.damage_enemy, player hits through Arena.pvp_hit (the duel arena applies them).
## Glass is punched through on the way.

const LIFE := 2.5
const STREAK := 0.045       ## seconds of flight shown as the streak

var shooter: Player
var weapon: WeaponData
var vel := Vector3.ZERO
var _t := 0.0
var _exclude: Array[RID] = []
var _streak: MeshInstance3D
var _from := Vector3.ZERO
var _first := true


func launch(p: Player, w: WeaponData, muzzle: Vector3, origin: Vector3, v: Vector3) -> void:
	shooter = p
	weapon = w
	vel = v
	global_position = origin
	_from = muzzle
	_exclude = [p.get_rid()]
	_streak = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.012, 0.012, 1.0)
	_streak.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(3.0, 0.9, 0.5, 0.9)
	_streak.material_override = mat
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streak.top_level = true
	add_child(_streak)


func _physics_process(delta: float) -> void:
	var a := Arena.current
	if a == null:
		queue_free()
		return
	_t += delta
	var pos := global_position
	var nv := vel + Vector3.DOWN * weapon.bullet_gravity * delta
	var next := pos + (vel + nv) * 0.5 * delta
	vel = nv
	var hit := a.raycast(pos, next, Arena.LAYER_WORLD | Arena.LAYER_ENEMY | Arena.LAYER_PLAYER, _exclude)
	# the first frame starts at the eye; draw the streak from the muzzle so it leaves the barrel
	var tail := _from if _first else pos - vel.normalized() * minf(vel.length() * STREAK, pos.distance_to(_from))
	_first = false
	if hit.is_empty():
		global_position = next
		_draw(tail, next)
		if _t > LIFE or next.distance_to(_from) > weapon.max_range:
			queue_free()
		return
	var pt: Vector3 = hit.position
	_draw(tail, pt)
	var c: Object = hit.collider
	if c is GlassPanel:
		a.shatter_glass(c)
		_exclude.append(hit.rid)
		global_position = pt + vel.normalized() * 0.05
		return
	var dist := pt.distance_to(_from)
	var falloff := 1.0 if dist <= weapon.max_range * 0.5 else maxf(0.35, 1.0 - 0.65 * (dist - weapon.max_range * 0.5) / (weapon.max_range * 0.5))
	var dir := vel.normalized()
	if c is Spider:
		var zone := shooter.weapons.zone_multiplier(c, pos, dir)
		var head := zone > 1.2
		var dmg := weapon.damage * (weapon.headshot_mult if head else zone) * falloff
		a.blood(pt, dir, dmg / 30.0)
		a.damage_enemy(c, dmg, weapon.short_name)
		shooter.confirm_hit(head)
	elif c is Player and c != shooter:
		var target := c as Player
		var head := pt.y > target.head.global_position.y - 0.2
		var dmg := weapon.damage * (weapon.headshot_mult if head else 1.0) * falloff
		a.blood(pt, dir, 2.0 if head else 1.2)
		a.pvp_hit(target, dmg, head)
		shooter.confirm_hit(head)
	else:
		a.destroy_blocks(pt, weapon.block_break * 0.6)
		a.impact(pt, hit.normal, Color("#ffb070"), 1.4)
	_streak.visible = false
	get_tree().create_timer(0.06).timeout.connect(queue_free)
	set_physics_process(false)


func _draw(a: Vector3, b: Vector3) -> void:
	var d := b - a
	if d.length() < 0.01:
		_streak.visible = false
		return
	_streak.visible = true
	_streak.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT), (a + b) * 0.5)
	_streak.scale = Vector3(1, 1, d.length())
