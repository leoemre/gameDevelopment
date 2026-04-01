extends Node2D

# This node handles all drawing for the fighter.
# It reads state from its parent (the CharacterBody2D fighter).

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var f = get_parent()
	if f == null:
		return

	# Read state from parent fighter
	var dir := 1.0 if f.facing_right else -1.0
	var is_dead: bool = f.is_dead
	var flash_timer: float = f.flash_timer
	var fighter_color: Color = f.fighter_color
	var is_attacking: bool = f.is_attacking
	var attack_type: String = f.attack_type
	var attack_anim_progress: float = f.attack_anim_progress
	var is_crouching: bool = f.is_crouching
	var is_firing_special: bool = f.is_firing_special
	var hit_stun_timer: float = f.hit_stun_timer
	var at_ring_edge: bool = f.at_ring_edge
	var stamina: float = f.stamina
	var vel: Vector2 = f.velocity
	var on_floor: bool = f.is_on_floor()

	# Blood particles
	_draw_blood(f.blood_particles)

	# Colors
	var skin_color: Color
	var body_color: Color
	var pants_color: Color
	var shoe_color := Color(0.2, 0.15, 0.1)
	var outline_color: Color

	if is_dead:
		skin_color = Color(0.5, 0.5, 0.5)
		body_color = Color(0.35, 0.35, 0.35)
		pants_color = Color(0.25, 0.25, 0.25)
		outline_color = Color(0.2, 0.2, 0.2)
	elif flash_timer > 0:
		skin_color = Color.WHITE
		body_color = Color.WHITE
		pants_color = Color.WHITE
		outline_color = Color.WHITE
		shoe_color = Color.WHITE
	else:
		skin_color = Color(0.92, 0.75, 0.6)
		body_color = fighter_color
		pants_color = fighter_color.darkened(0.3)
		outline_color = fighter_color.darkened(0.5)

	# Body constants
	var HEAD_RADIUS := 9.0
	var HEAD_Y := -68.0
	var NECK_TOP := -60.0
	var SHOULDER_Y := -52.0
	var TORSO_TOP := -55.0
	var TORSO_BOTTOM := -28.0
	var TORSO_HALF_W := 9.0
	var HIP_Y := -28.0
	var KNEE_Y := -14.0
	var FOOT_Y := 0.0
	var LIMB_WIDTH := 5.0
	var HAND_RADIUS := 4.0
	var FOOT_RADIUS := 4.5

	# Crouch
	var crouch_amount := 1.0 if is_crouching else 0.0
	var crouch_drop := crouch_amount * 20.0
	var crouch_knee_spread := crouch_amount * 14.0
	var crouch_lean := crouch_amount * 4.0 * dir
	var kick_lean := 0.0
	if is_attacking and attack_type == "kick":
		kick_lean = attack_anim_progress * -6.0 * dir
	var body_offset_x := crouch_lean + kick_lean
	var body_offset_y := crouch_drop

	# Ring edge warning glow
	if at_ring_edge and not is_dead:
		var pulse = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		draw_circle(Vector2(0, -35), 40.0, Color(1, 0.2, 0, 0.15 + pulse * 0.2))

	var walk_phase := 0.0
	if on_floor and abs(vel.x) > 10 and not is_crouching:
		walk_phase = sin(Time.get_ticks_msec() * 0.01) * 0.3

	# ── LEGS ──
	var left_hip := Vector2(-5.0 * dir + body_offset_x, HIP_Y + body_offset_y)
	var right_hip := Vector2(5.0 * dir + body_offset_x, HIP_Y + body_offset_y)
	var left_knee: Vector2
	var right_knee: Vector2
	var left_foot: Vector2
	var right_foot: Vector2

	if is_attacking and attack_type == "kick":
		var p := attack_anim_progress
		var chamber := clampf(p / 0.3, 0.0, 1.0)
		var extend := clampf((p - 0.3) / 0.4, 0.0, 1.0)
		var retract := clampf((p - 0.7) / 0.3, 0.0, 1.0)
		var knee_lift := chamber * 28.0 - retract * 20.0
		var knee_fwd := chamber * 15.0 + extend * 10.0 - retract * 15.0
		var foot_ext := extend * 40.0 - retract * 30.0
		var foot_lift := chamber * 24.0 - retract * 16.0
		right_knee = Vector2(dir * (6.0 + knee_fwd) + body_offset_x, KNEE_Y - knee_lift + body_offset_y)
		right_foot = Vector2(dir * (8.0 + knee_fwd + foot_ext) + body_offset_x, KNEE_Y - foot_lift + body_offset_y)
		left_knee = Vector2(-3.0 * dir + body_offset_x, KNEE_Y + 2.0 + body_offset_y * 0.3)
		left_foot = Vector2(-5.0 * dir, FOOT_Y)
	elif is_crouching:
		left_knee = Vector2((-8.0 - crouch_knee_spread) * dir + body_offset_x, KNEE_Y + body_offset_y * 0.5)
		left_foot = Vector2((-7.0) * dir, FOOT_Y)
		right_knee = Vector2((8.0 + crouch_knee_spread) * dir + body_offset_x, KNEE_Y + body_offset_y * 0.5)
		right_foot = Vector2((7.0) * dir, FOOT_Y)
	else:
		left_knee = Vector2((-3.0 + walk_phase * 4.0) * dir, KNEE_Y)
		left_foot = Vector2((-4.0 + walk_phase * 8.0) * dir, FOOT_Y)
		right_knee = Vector2((3.0 - walk_phase * 4.0) * dir, KNEE_Y)
		right_foot = Vector2((4.0 - walk_phase * 8.0) * dir, FOOT_Y)

	_draw_limb(left_hip, left_knee, pants_color, LIMB_WIDTH + 1)
	_draw_limb(left_knee, left_foot, pants_color, LIMB_WIDTH)
	draw_circle(left_foot, FOOT_RADIUS, shoe_color)
	_draw_limb(right_hip, right_knee, pants_color, LIMB_WIDTH + 1)
	_draw_limb(right_knee, right_foot, pants_color, LIMB_WIDTH)
	draw_circle(right_foot, FOOT_RADIUS, shoe_color)

	# Kick impact
	if is_attacking and attack_type == "kick" and attack_anim_progress > 0.35 and attack_anim_progress < 0.75:
		var imp := right_foot + Vector2(dir * 6.0, 0)
		var s := 1.0 - abs(attack_anim_progress - 0.55) / 0.2
		draw_circle(imp, 7.0 * s, Color(1, 0.9, 0.2, 0.7 * s))

	# ── TORSO ──
	var tr := Rect2(-TORSO_HALF_W + body_offset_x, TORSO_TOP + body_offset_y, TORSO_HALF_W * 2, TORSO_BOTTOM - TORSO_TOP)
	draw_rect(tr, body_color)
	draw_rect(tr, outline_color, false, 1.5)
	draw_rect(Rect2(-TORSO_HALF_W - 1 + body_offset_x, TORSO_BOTTOM - 3 + body_offset_y, TORSO_HALF_W * 2 + 2, 3), outline_color)

	# ── ARMS ──
	var ls := Vector2(-TORSO_HALF_W * dir + body_offset_x, SHOULDER_Y + body_offset_y)
	var rs := Vector2(TORSO_HALF_W * dir + body_offset_x, SHOULDER_Y + body_offset_y)
	var le: Vector2; var re: Vector2; var lh: Vector2; var rh: Vector2

	if is_firing_special:
		var t := 30.0
		re = Vector2(dir * 14.0 + body_offset_x, SHOULDER_Y - 6.0 + body_offset_y)
		rh = Vector2(dir * (15.0 + t) + body_offset_x, SHOULDER_Y - 10.0 + body_offset_y)
		le = Vector2(dir * 10.0 + body_offset_x, SHOULDER_Y - 2.0 + body_offset_y)
		lh = Vector2(dir * (12.0 + t) + body_offset_x, SHOULDER_Y - 8.0 + body_offset_y)
	elif is_attacking and attack_type == "punch":
		var pe := attack_anim_progress * 40.0
		var pl := attack_anim_progress * 8.0
		re = Vector2(dir * (12.0 + pe * 0.3) + body_offset_x, SHOULDER_Y - pl * 0.3 + body_offset_y)
		rh = Vector2(dir * (15.0 + pe) + body_offset_x, SHOULDER_Y - pl + body_offset_y)
		le = Vector2(-dir * 6.0 + body_offset_x, SHOULDER_Y + 8.0 + body_offset_y)
		lh = Vector2(-dir * 4.0 + body_offset_x, SHOULDER_Y + 4.0 + body_offset_y)
	elif is_attacking and attack_type == "kick":
		le = Vector2(-dir * 12.0 + body_offset_x, SHOULDER_Y + 2.0 + body_offset_y)
		lh = Vector2(-dir * 18.0 + body_offset_x, SHOULDER_Y - 4.0 + body_offset_y)
		re = Vector2(dir * 6.0 + body_offset_x, SHOULDER_Y + 6.0 + body_offset_y)
		rh = Vector2(dir * 4.0 + body_offset_x, SHOULDER_Y + 2.0 + body_offset_y)
	elif is_crouching:
		le = Vector2((-8.0) * dir + body_offset_x, SHOULDER_Y + 8.0 + body_offset_y)
		lh = Vector2((-5.0) * dir + body_offset_x, SHOULDER_Y + 3.0 + body_offset_y)
		re = Vector2((8.0) * dir + body_offset_x, SHOULDER_Y + 8.0 + body_offset_y)
		rh = Vector2((5.0) * dir + body_offset_x, SHOULDER_Y + 3.0 + body_offset_y)
	else:
		le = Vector2((-12.0 - walk_phase * 3.0) * dir, SHOULDER_Y + 12.0)
		lh = Vector2((-10.0 - walk_phase * 6.0) * dir, SHOULDER_Y + 22.0)
		re = Vector2((12.0 + walk_phase * 3.0) * dir, SHOULDER_Y + 12.0)
		rh = Vector2((10.0 + walk_phase * 6.0) * dir, SHOULDER_Y + 22.0)

	_draw_limb(ls, le, skin_color, LIMB_WIDTH)
	_draw_limb(le, lh, skin_color, LIMB_WIDTH - 1)
	draw_circle(lh, HAND_RADIUS, skin_color)
	_draw_limb(rs, re, skin_color, LIMB_WIDTH)
	_draw_limb(re, rh, skin_color, LIMB_WIDTH - 1)
	draw_circle(rh, HAND_RADIUS, skin_color)

	if is_attacking and attack_type == "punch" and attack_anim_progress > 0.5:
		draw_circle(rh + Vector2(dir * 6.0, 0), 5.0 * attack_anim_progress, Color(1, 1, 1, 0.6 * attack_anim_progress))

	if is_firing_special:
		var mid := (rh + lh) * 0.5
		var pulse := (sin(Time.get_ticks_msec() * 0.03) + 1.0) * 0.5
		draw_circle(mid, 14.0 + pulse * 4.0, Color(1, 0.5, 0, 0.3))
		draw_circle(mid, 8.0 + pulse * 2.0, Color(1, 0.8, 0.2, 0.5))
		draw_circle(mid, 4.0, Color(1, 1, 0.8, 0.8))

	# Sleeve cuffs
	_draw_limb(ls, ls + Vector2((-3.0) * dir, 4.0), body_color, LIMB_WIDTH + 2)
	_draw_limb(rs, rs + Vector2((3.0) * dir, 4.0), body_color, LIMB_WIDTH + 2)

	# ── NECK ──
	draw_line(Vector2(body_offset_x, NECK_TOP + body_offset_y), Vector2(body_offset_x, SHOULDER_Y + body_offset_y), skin_color, 4.0)

	# ── HEAD ──
	var hc := Vector2(body_offset_x, HEAD_Y + body_offset_y)
	draw_circle(hc, HEAD_RADIUS, skin_color)
	draw_arc(hc, HEAD_RADIUS, 0, TAU, 20, outline_color, 1.5)
	var hair_c := outline_color if not is_dead and flash_timer <= 0 else skin_color
	draw_arc(hc, HEAD_RADIUS, PI * 0.8, PI * 2.2, 12, hair_c, 3.0)

	if not is_dead and flash_timer <= 0:
		var eox := 3.5 * dir
		var ey := hc.y - 1.0
		draw_circle(Vector2(hc.x + eox - 1.5 * dir, ey), 1.5, Color.WHITE)
		draw_circle(Vector2(hc.x + eox + 1.5 * dir, ey), 1.5, Color.WHITE)
		draw_circle(Vector2(hc.x + eox - 1.5 * dir + dir * 0.5, ey), 0.8, Color.BLACK)
		draw_circle(Vector2(hc.x + eox + 1.5 * dir + dir * 0.5, ey), 0.8, Color.BLACK)
		if is_attacking:
			draw_circle(Vector2(hc.x + 2.0 * dir, hc.y + 4.0), 2.0, Color(0.6, 0.2, 0.2))
		elif hit_stun_timer > 0:
			draw_line(Vector2(hc.x - dir, hc.y + 4.0), Vector2(hc.x + 3.0 * dir, hc.y + 5.0), Color(0.6, 0.2, 0.2), 1.5)
		else:
			draw_arc(Vector2(hc.x + 2.0 * dir, hc.y + 3.0), 2.0, 0.2, PI - 0.2, 8, Color(0.6, 0.2, 0.2), 1.0)
	elif is_dead:
		for ex in [hc.x + 3.0 * dir, hc.x - 1.0 * dir]:
			var ey := hc.y - 1.0
			draw_line(Vector2(ex - 2, ey - 2), Vector2(ex + 2, ey + 2), Color.BLACK, 1.5)
			draw_line(Vector2(ex - 2, ey + 2), Vector2(ex + 2, ey - 2), Color.BLACK, 1.5)

	# Player indicator + stamina
	var iy := hc.y - HEAD_RADIUS - 10.0
	var ic := fighter_color if flash_timer <= 0 else Color.WHITE
	draw_colored_polygon(PackedVector2Array([Vector2(hc.x - 5, iy - 6), Vector2(hc.x + 5, iy - 6), Vector2(hc.x, iy)]), ic)

	if not is_dead:
		var sy := iy - 10.0
		var sr := stamina / f.STAMINA_MAX
		draw_rect(Rect2(hc.x - 10, sy, 20, 3), Color(0.2, 0.2, 0.2, 0.8))
		draw_rect(Rect2(hc.x - 10, sy, 20 * sr, 3), Color(0.2, 0.8, 1.0) if sr > 0.99 else Color(0.4, 0.4, 0.4))

func _draw_blood(particles: Array) -> void:
	for p in particles:
		var lr: float = (p["life"] as float) / (p["max_life"] as float)
		var a := clampf(lr, 0.0, 1.0)
		var pos: Vector2 = p["pos"] as Vector2
		var sz: float = p["size"] as float
		if p["is_spark"] as bool:
			draw_circle(pos, sz * (0.5 + lr * 0.5), Color(1.0, 0.6, 0.1, a))
		else:
			draw_circle(pos, sz, Color(0.7, 0, 0, a))
			if pos.y >= 4.0 and lr < 0.7:
				draw_rect(Rect2(pos.x - sz, pos.y - 1, sz * 2.5, 2), Color(0.5, 0, 0, a * 0.6))

func _draw_limb(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)
