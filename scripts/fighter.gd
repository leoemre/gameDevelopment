extends CharacterBody2D

# Configuration
@export var player_id: int = 1
@export var fighter_color: Color = Color.CORNFLOWER_BLUE
@export var speed: float = 300.0
@export var jump_force: float = -500.0
@export var gravity: float = 1200.0
@export var max_health: int = 100

# Attack properties
const PUNCH_DAMAGE: int = 8
const KICK_DAMAGE: int = 12
const PUNCH_RANGE: float = 70.0
const KICK_RANGE: float = 90.0
const PUNCH_DURATION: float = 0.3
const KICK_DURATION: float = 0.4
const ATTACK_COOLDOWN: float = 0.15
const KNOCKBACK_FORCE: float = 400.0
const HIT_STUN_DURATION: float = 0.2

# Fireball
const FIREBALL_DAMAGE: int = 40
const STAMINA_MAX: float = 100.0
const STAMINA_REGEN_RATE: float = 20.0  # per second

# State
var health: int
var facing_right: bool = true
var is_attacking: bool = false
var attack_type: String = ""
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var hit_stun_timer: float = 0.0
var is_dead: bool = false
var opponent: CharacterBody2D = null
var flash_timer: float = 0.0
var is_crouching: bool = false
var stamina: float = STAMINA_MAX
var is_firing_special: bool = false
var fireball_anim_timer: float = 0.0

# Animation state (0.0 = idle, 1.0 = full extension)
var attack_anim_progress: float = 0.0

# Input mapping
var input_left: String
var input_right: String
var input_up: String
var input_down: String
var input_punch: String
var input_kick: String

# Node references
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/AttackShape
@onready var hurtbox: Area2D = $Hurtbox

signal health_changed(new_health: int, max_hp: int)
signal player_died(player_id: int)

# Body dimensions
const HEAD_RADIUS: float = 9.0
const HEAD_Y: float = -68.0
const NECK_TOP: float = -60.0
const SHOULDER_Y: float = -52.0
const TORSO_TOP: float = -55.0
const TORSO_BOTTOM: float = -28.0
const TORSO_HALF_W: float = 9.0
const HIP_Y: float = -28.0
const KNEE_Y: float = -14.0
const FOOT_Y: float = 0.0
const LIMB_WIDTH: float = 5.0
const HAND_RADIUS: float = 4.0
const FOOT_RADIUS: float = 4.5

func _ready() -> void:
	health = max_health
	_setup_inputs()
	attack_shape.disabled = true

func _setup_inputs() -> void:
	var prefix = "p" + str(player_id) + "_"
	input_left = prefix + "left"
	input_right = prefix + "right"
	input_up = prefix + "up"
	input_down = prefix + "down"
	input_punch = prefix + "punch"
	input_kick = prefix + "kick"

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Timers
	if cooldown_timer > 0:
		cooldown_timer -= delta
	if hit_stun_timer > 0:
		hit_stun_timer -= delta
	if flash_timer > 0:
		flash_timer -= delta

	# Stamina regen
	if stamina < STAMINA_MAX:
		stamina = minf(stamina + STAMINA_REGEN_RATE * delta, STAMINA_MAX)

	# Fireball anim
	if is_firing_special:
		fireball_anim_timer -= delta
		if fireball_anim_timer <= 0:
			is_firing_special = false

	# Attack timer and animation
	if is_attacking:
		attack_timer -= delta
		# Animate: quick extend, hold, retract
		var total_dur = PUNCH_DURATION if attack_type == "punch" else KICK_DURATION
		var elapsed = total_dur - attack_timer
		var ratio = elapsed / total_dur
		if ratio < 0.2:
			attack_anim_progress = ratio / 0.2  # extend
		elif ratio < 0.7:
			attack_anim_progress = 1.0  # hold
		else:
			attack_anim_progress = 1.0 - ((ratio - 0.7) / 0.3)  # retract
		attack_anim_progress = clampf(attack_anim_progress, 0.0, 1.0)

		if attack_timer <= 0:
			_end_attack()
	else:
		attack_anim_progress = 0.0

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Movement (disabled during attack or hit stun)
	is_crouching = false
	if not is_attacking and not is_firing_special and hit_stun_timer <= 0:
		var direction := 0.0
		if Input.is_action_pressed(input_left):
			direction -= 1.0
		if Input.is_action_pressed(input_right):
			direction += 1.0

		velocity.x = direction * speed

		# Update facing direction
		if direction != 0:
			facing_right = direction > 0

		# Jump
		if Input.is_action_just_pressed(input_up) and is_on_floor():
			velocity.y = jump_force

		# Crouch (slow down + dodge fireballs)
		if Input.is_action_pressed(input_down) and is_on_floor():
			velocity.x *= 0.3
			is_crouching = true
	elif is_attacking or is_firing_special:
		velocity.x *= 0.8

	# Attack inputs - special (both) checked first
	if not is_attacking and not is_firing_special and cooldown_timer <= 0 and hit_stun_timer <= 0:
		var punch_pressed := Input.is_action_just_pressed(input_punch)
		var kick_pressed := Input.is_action_just_pressed(input_kick)
		if (punch_pressed and Input.is_action_pressed(input_kick)) or \
		   (kick_pressed and Input.is_action_pressed(input_punch)):
			_try_fireball()
		elif punch_pressed:
			_start_attack("punch")
		elif kick_pressed:
			_start_attack("kick")

	move_and_slide()
	queue_redraw()

func _start_attack(type: String) -> void:
	is_attacking = true
	attack_type = type
	attack_anim_progress = 0.0

	if type == "punch":
		attack_timer = PUNCH_DURATION
	elif type == "kick":
		attack_timer = KICK_DURATION

	attack_shape.disabled = false
	_check_hit()

func _end_attack() -> void:
	is_attacking = false
	attack_type = ""
	attack_shape.disabled = true
	cooldown_timer = ATTACK_COOLDOWN
	attack_anim_progress = 0.0

func _check_hit() -> void:
	if opponent == null:
		return

	var distance = abs(global_position.x - opponent.global_position.x)
	var height_diff = abs(global_position.y - opponent.global_position.y)

	var range = PUNCH_RANGE if attack_type == "punch" else KICK_RANGE
	var is_facing_opponent = (facing_right and opponent.global_position.x > global_position.x) or \
							(not facing_right and opponent.global_position.x < global_position.x)

	if distance <= range and height_diff < 60 and is_facing_opponent:
		var damage = PUNCH_DAMAGE if attack_type == "punch" else KICK_DAMAGE
		var knockback_dir = 1.0 if facing_right else -1.0
		opponent.take_damage(damage, knockback_dir)

func take_damage(damage: int, knockback_dir: float) -> void:
	if is_dead:
		return

	health -= damage
	health = max(health, 0)
	hit_stun_timer = HIT_STUN_DURATION
	flash_timer = 0.12

	velocity.x = knockback_dir * KNOCKBACK_FORCE
	velocity.y = -150.0

	emit_signal("health_changed", health, max_health)

	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	emit_signal("player_died", player_id)

func _try_fireball() -> void:
	if stamina < STAMINA_MAX:
		return
	stamina = 0.0
	is_firing_special = true
	fireball_anim_timer = 0.35
	get_tree().create_timer(0.15).timeout.connect(func():
		var fireball_scene = load("res://scenes/fireball.tscn")
		var fb = fireball_scene.instantiate()
		fb.direction = 1.0 if facing_right else -1.0
		fb.damage = FIREBALL_DAMAGE
		fb.owner_id = player_id
		fb.global_position = global_position + Vector2((30.0 if facing_right else -30.0), -40.0)
		get_parent().add_child(fb)
	)

func take_fireball_damage(damage: int, dir: float) -> void:
	if is_crouching:
		return
	take_damage(damage, dir)

func reset(start_pos: Vector2, face_right: bool) -> void:
	global_position = start_pos
	velocity = Vector2.ZERO
	health = max_health
	is_dead = false
	is_attacking = false
	attack_timer = 0.0
	cooldown_timer = 0.0
	hit_stun_timer = 0.0
	flash_timer = 0.0
	is_crouching = false
	stamina = STAMINA_MAX
	is_firing_special = false
	fireball_anim_timer = 0.0
	attack_anim_progress = 0.0
	facing_right = face_right
	emit_signal("health_changed", health, max_health)
	queue_redraw()

# ── Drawing the humanoid figure ──

func _draw() -> void:
	var dir := 1.0 if facing_right else -1.0

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

	# Crouch offset — upper body drops, feet stay planted
	var crouch_drop := 18.0 if is_crouching else 0.0
	var crouch_spread := 12.0 if is_crouching else 0.0
	var crouch_lean := (3.0 * dir) if is_crouching else 0.0
	var bo_x := crouch_lean  # body offset x
	var bo_y := crouch_drop  # body offset y

	# Idle walk cycle hint: slight arm/leg sway based on velocity
	var walk_phase := 0.0
	if is_on_floor() and abs(velocity.x) > 10 and not is_crouching:
		walk_phase = sin(Time.get_ticks_msec() * 0.01) * 0.3

	# ── LEGS ──
	var left_hip := Vector2(-5.0 * dir + bo_x, HIP_Y + bo_y)
	var right_hip := Vector2(5.0 * dir + bo_x, HIP_Y + bo_y)
	var left_knee: Vector2
	var right_knee: Vector2
	var left_foot: Vector2
	var right_foot: Vector2

	if is_attacking and attack_type == "kick":
		# Realistic 3-phase kick:
		# Phase 1 (0-0.25): Chamber - knee lifts up toward chest
		# Phase 2 (0.25-0.6): Snap - lower leg extends outward from knee
		# Phase 3 (0.6-1.0): Retract - leg pulls back
		var p := attack_anim_progress
		var chamber := clampf(p / 0.25, 0.0, 1.0)
		var snap := clampf((p - 0.25) / 0.35, 0.0, 1.0)
		var retract := clampf((p - 0.6) / 0.4, 0.0, 1.0)

		# Knee rises up and forward during chamber, stays during snap, lowers on retract
		var knee_up := chamber * 22.0 - retract * 16.0
		var knee_fwd := chamber * 12.0 + snap * 8.0 - retract * 14.0
		# Foot: tucked behind knee during chamber, snaps straight out, retracts
		var foot_fwd := snap * 42.0 - retract * 32.0
		var foot_up := chamber * 20.0 - retract * 14.0
		# During chamber, foot tucks up near knee (bent leg)
		var foot_tuck_back := (1.0 - snap) * chamber * 10.0

		right_knee = Vector2(dir * (6.0 + knee_fwd), KNEE_Y - knee_up)
		right_foot = Vector2(
			dir * (6.0 + knee_fwd + foot_fwd - foot_tuck_back),
			KNEE_Y - foot_up + (1.0 - snap) * 4.0
		)
		# Support leg bends slightly for balance
		left_knee = Vector2((-4.0 - chamber * 2.0) * dir, KNEE_Y + chamber * 3.0)
		left_foot = Vector2(-5.0 * dir, FOOT_Y)
	elif is_crouching:
		# Crouching: knees bend outward, feet planted wider
		left_knee = Vector2((-8.0 - crouch_spread) * dir + bo_x, KNEE_Y + bo_y * 0.5)
		left_foot = Vector2(-7.0 * dir, FOOT_Y)
		right_knee = Vector2((8.0 + crouch_spread) * dir + bo_x, KNEE_Y + bo_y * 0.5)
		right_foot = Vector2(7.0 * dir, FOOT_Y)
	else:
		# Normal legs with walk cycle
		left_knee = Vector2((-3.0 + walk_phase * 4.0) * dir, KNEE_Y)
		left_foot = Vector2((-4.0 + walk_phase * 8.0) * dir, FOOT_Y)
		right_knee = Vector2((3.0 - walk_phase * 4.0) * dir, KNEE_Y)
		right_foot = Vector2((4.0 - walk_phase * 8.0) * dir, FOOT_Y)

	# Draw legs (back leg first)
	_draw_limb(left_hip, left_knee, pants_color, LIMB_WIDTH + 1)
	_draw_limb(left_knee, left_foot, pants_color, LIMB_WIDTH)
	draw_circle(left_foot, FOOT_RADIUS, shoe_color)

	_draw_limb(right_hip, right_knee, pants_color, LIMB_WIDTH + 1)
	_draw_limb(right_knee, right_foot, pants_color, LIMB_WIDTH)
	draw_circle(right_foot, FOOT_RADIUS, shoe_color)

	# Kick impact effect - peaks during the snap phase
	if is_attacking and attack_type == "kick" and attack_anim_progress > 0.3 and attack_anim_progress < 0.7:
		var impact_pos := right_foot + Vector2(dir * 6.0, 0)
		var strength := 1.0 - abs(attack_anim_progress - 0.5) / 0.2
		strength = clampf(strength, 0.0, 1.0)
		draw_circle(impact_pos, 7.0 * strength, Color(1, 0.9, 0.2, 0.6 * strength))
		# Speed lines behind the foot during snap
		if strength > 0.3:
			for i in 3:
				var lx := right_foot.x - dir * (8.0 + i * 7.0)
				draw_line(Vector2(lx, right_foot.y - 1), Vector2(lx - dir * 10.0, right_foot.y - 1), Color(1, 1, 1, 0.25 * strength), 1.5)

	# ── TORSO ──
	var torso_rect := Rect2(-TORSO_HALF_W + bo_x, TORSO_TOP + bo_y, TORSO_HALF_W * 2, TORSO_BOTTOM - TORSO_TOP)
	draw_rect(torso_rect, body_color)
	draw_rect(torso_rect, outline_color, false, 1.5)

	# Belt
	var belt_rect := Rect2(-TORSO_HALF_W - 1 + bo_x, TORSO_BOTTOM - 3 + bo_y, TORSO_HALF_W * 2 + 2, 3)
	draw_rect(belt_rect, outline_color)

	# ── ARMS ──
	var left_shoulder := Vector2(-TORSO_HALF_W * dir + bo_x, SHOULDER_Y + bo_y)
	var right_shoulder := Vector2(TORSO_HALF_W * dir + bo_x, SHOULDER_Y + bo_y)
	var left_elbow: Vector2
	var right_elbow: Vector2
	var left_hand: Vector2
	var right_hand: Vector2

	if is_firing_special:
		var thrust := 30.0
		right_elbow = Vector2(dir * 14.0 + bo_x, SHOULDER_Y - 6.0 + bo_y)
		right_hand = Vector2(dir * (15.0 + thrust) + bo_x, SHOULDER_Y - 10.0 + bo_y)
		left_elbow = Vector2(dir * 10.0 + bo_x, SHOULDER_Y - 2.0 + bo_y)
		left_hand = Vector2(dir * (12.0 + thrust) + bo_x, SHOULDER_Y - 8.0 + bo_y)
	elif is_attacking and attack_type == "punch":
		var punch_extend := attack_anim_progress * 40.0
		var punch_lift := attack_anim_progress * 8.0
		right_elbow = Vector2(dir * (12.0 + punch_extend * 0.3) + bo_x, SHOULDER_Y - punch_lift * 0.3 + bo_y)
		right_hand = Vector2(dir * (15.0 + punch_extend) + bo_x, SHOULDER_Y - punch_lift + bo_y)
		left_elbow = Vector2(-dir * 6.0 + bo_x, SHOULDER_Y + 8.0 + bo_y)
		left_hand = Vector2(-dir * 4.0 + bo_x, SHOULDER_Y + 4.0 + bo_y)
	elif is_crouching:
		# Guard position - fists up near face
		left_elbow = Vector2(-8.0 * dir + bo_x, SHOULDER_Y + 6.0 + bo_y)
		left_hand = Vector2(-5.0 * dir + bo_x, SHOULDER_Y + 1.0 + bo_y)
		right_elbow = Vector2(8.0 * dir + bo_x, SHOULDER_Y + 6.0 + bo_y)
		right_hand = Vector2(5.0 * dir + bo_x, SHOULDER_Y + 1.0 + bo_y)
	else:
		left_elbow = Vector2((-12.0 - walk_phase * 3.0) * dir, SHOULDER_Y + 12.0)
		left_hand = Vector2((-10.0 - walk_phase * 6.0) * dir, SHOULDER_Y + 22.0)
		right_elbow = Vector2((12.0 + walk_phase * 3.0) * dir, SHOULDER_Y + 12.0)
		right_hand = Vector2((10.0 + walk_phase * 6.0) * dir, SHOULDER_Y + 22.0)

	# Draw back arm
	_draw_limb(left_shoulder, left_elbow, skin_color, LIMB_WIDTH)
	_draw_limb(left_elbow, left_hand, skin_color, LIMB_WIDTH - 1)
	draw_circle(left_hand, HAND_RADIUS, skin_color)
	# Hand outline
	draw_arc(left_hand, HAND_RADIUS, 0, TAU, 12, outline_color, 1.0)

	# Draw front arm
	_draw_limb(right_shoulder, right_elbow, skin_color, LIMB_WIDTH)
	_draw_limb(right_elbow, right_hand, skin_color, LIMB_WIDTH - 1)
	draw_circle(right_hand, HAND_RADIUS, skin_color)
	draw_arc(right_hand, HAND_RADIUS, 0, TAU, 12, outline_color, 1.0)

	# Punch impact effect
	if is_attacking and attack_type == "punch" and attack_anim_progress > 0.5:
		var impact_pos := right_hand + Vector2(dir * 6.0, 0)
		draw_circle(impact_pos, 5.0 * attack_anim_progress, Color(1, 1, 1, 0.6 * attack_anim_progress))

	# Fireball glow on hands
	if is_firing_special:
		var mid := (right_hand + left_hand) * 0.5
		var pulse := (sin(Time.get_ticks_msec() * 0.03) + 1.0) * 0.5
		draw_circle(mid, 12.0 + pulse * 3.0, Color(1, 0.5, 0, 0.3))
		draw_circle(mid, 6.0 + pulse * 2.0, Color(1, 0.8, 0.2, 0.5))
		draw_circle(mid, 3.0, Color(1, 1, 0.8, 0.8))

	# Sleeve cuffs on shoulders
	_draw_limb(left_shoulder, left_shoulder + Vector2((-3.0) * dir, 4.0), body_color, LIMB_WIDTH + 2)
	_draw_limb(right_shoulder, right_shoulder + Vector2((3.0) * dir, 4.0), body_color, LIMB_WIDTH + 2)

	# ── NECK ──
	draw_line(Vector2(bo_x, NECK_TOP + bo_y), Vector2(bo_x, SHOULDER_Y + bo_y), skin_color, 4.0)

	# ── HEAD ──
	var head_center := Vector2(bo_x, HEAD_Y + bo_y)
	# Head
	draw_circle(head_center, HEAD_RADIUS, skin_color)
	# Head outline
	draw_arc(head_center, HEAD_RADIUS, 0, TAU, 20, outline_color, 1.5)
	# Hair on top
	var hair_color := outline_color if not is_dead and flash_timer <= 0 else skin_color
	draw_arc(head_center, HEAD_RADIUS, PI * 0.8, PI * 2.2, 12, hair_color, 3.0)

	# Eyes
	if not is_dead and flash_timer <= 0:
		var eye_offset_x := 3.5 * dir
		var eye_y := HEAD_Y - 1.0
		draw_circle(Vector2(eye_offset_x - 1.5 * dir, eye_y), 1.5, Color.WHITE)
		draw_circle(Vector2(eye_offset_x + 1.5 * dir, eye_y), 1.5, Color.WHITE)
		# Pupils look toward opponent
		var pupil_dir := dir
		draw_circle(Vector2(eye_offset_x - 1.5 * dir + pupil_dir * 0.5, eye_y), 0.8, Color.BLACK)
		draw_circle(Vector2(eye_offset_x + 1.5 * dir + pupil_dir * 0.5, eye_y), 0.8, Color.BLACK)

		# Mouth - determined by state
		if is_attacking:
			# Open mouth (yelling)
			draw_circle(Vector2(2.0 * dir, HEAD_Y + 4.0), 2.0, Color(0.6, 0.2, 0.2))
		elif hit_stun_timer > 0:
			# Ouch face
			draw_line(Vector2(-1.0 * dir, HEAD_Y + 4.0), Vector2(3.0 * dir, HEAD_Y + 5.0), Color(0.6, 0.2, 0.2), 1.5)
		else:
			# Neutral/slight smile
			draw_arc(Vector2(2.0 * dir, HEAD_Y + 3.0), 2.0, 0.2, PI - 0.2, 8, Color(0.6, 0.2, 0.2), 1.0)
	elif is_dead:
		# X eyes
		var eye_x := 3.0 * dir
		var eye_y := HEAD_Y - 1.0
		draw_line(Vector2(eye_x - 2, eye_y - 2), Vector2(eye_x + 2, eye_y + 2), Color.BLACK, 1.5)
		draw_line(Vector2(eye_x - 2, eye_y + 2), Vector2(eye_x + 2, eye_y - 2), Color.BLACK, 1.5)
		eye_x = -1.0 * dir
		draw_line(Vector2(eye_x - 2, eye_y - 2), Vector2(eye_x + 2, eye_y + 2), Color.BLACK, 1.5)
		draw_line(Vector2(eye_x - 2, eye_y + 2), Vector2(eye_x + 2, eye_y - 2), Color.BLACK, 1.5)

	# Player indicator (small colored triangle above head)
	var indicator_y := head_center.y - HEAD_RADIUS - 10.0
	var indicator_color := fighter_color if flash_timer <= 0 else Color.WHITE
	var tri := PackedVector2Array([
		Vector2(head_center.x - 5, indicator_y - 6),
		Vector2(head_center.x + 5, indicator_y - 6),
		Vector2(head_center.x, indicator_y)
	])
	draw_colored_polygon(tri, indicator_color)

	# Stamina bar
	if not is_dead:
		var stam_y := indicator_y - 10.0
		var stam_ratio := stamina / STAMINA_MAX
		draw_rect(Rect2(head_center.x - 10, stam_y, 20, 3), Color(0.2, 0.2, 0.2, 0.8))
		var sc := Color(0.2, 0.8, 1.0) if stam_ratio > 0.99 else Color(0.4, 0.4, 0.4)
		draw_rect(Rect2(head_center.x - 10, stam_y, 20 * stam_ratio, 3), sc)

func _draw_limb(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)
