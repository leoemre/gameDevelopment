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

# Ring boundary damage
const RING_DAMAGE_PER_SEC: int = 5
const RING_DAMAGE_INTERVAL: float = 0.4

# Special move (fireball)
const FIREBALL_DAMAGE: int = (PUNCH_DAMAGE + KICK_DAMAGE) * 2  # 40
const STAMINA_MAX: float = 100.0
const STAMINA_COST: float = 100.0
const STAMINA_REGEN_TIME: float = 5.0  # seconds to fully recover
const FIREBALL_SCENE_PATH: String = "res://scenes/fireball.tscn"

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
var ring_damage_timer: float = 0.0
var at_ring_edge: bool = false
var is_crouching: bool = false

# Stamina for special
var stamina: float = STAMINA_MAX
var fireball_cooldown: float = 0.0
const FIREBALL_ANIM_DURATION: float = 0.4
var fireball_anim_timer: float = 0.0
var is_firing_special: bool = false

# Animation state (0.0 = idle, 1.0 = full extension)
var attack_anim_progress: float = 0.0

# Blood particles
var blood_particles: Array = []  # Array of {pos, vel, life, max_life, size}
const MAX_BLOOD: int = 80
const BLOOD_GRAVITY: float = 600.0

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
signal stamina_changed(new_stamina: float, max_stamina: float)

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
		_update_blood(delta)
		return

	# Timers
	if cooldown_timer > 0:
		cooldown_timer -= delta
	if hit_stun_timer > 0:
		hit_stun_timer -= delta
	if flash_timer > 0:
		flash_timer -= delta

	# Ring edge damage
	if at_ring_edge and not is_dead:
		ring_damage_timer -= delta
		if ring_damage_timer <= 0:
			ring_damage_timer = RING_DAMAGE_INTERVAL
			_take_ring_damage()

	# Stamina regen
	if stamina < STAMINA_MAX:
		stamina += (STAMINA_MAX / STAMINA_REGEN_TIME) * delta
		stamina = minf(stamina, STAMINA_MAX)
		emit_signal("stamina_changed", stamina, STAMINA_MAX)

	# Fireball animation timer
	if is_firing_special:
		fireball_anim_timer -= delta
		if fireball_anim_timer <= 0:
			is_firing_special = false

	# Attack timer and animation
	if is_attacking:
		attack_timer -= delta
		var total_dur = PUNCH_DURATION if attack_type == "punch" else KICK_DURATION
		var elapsed = total_dur - attack_timer
		var ratio = elapsed / total_dur
		if ratio < 0.2:
			attack_anim_progress = ratio / 0.2
		elif ratio < 0.7:
			attack_anim_progress = 1.0
		else:
			attack_anim_progress = 1.0 - ((ratio - 0.7) / 0.3)
		attack_anim_progress = clampf(attack_anim_progress, 0.0, 1.0)

		if attack_timer <= 0:
			_end_attack()
	else:
		attack_anim_progress = 0.0

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Movement
	is_crouching = false
	if not is_attacking and not is_firing_special and hit_stun_timer <= 0:
		var direction := 0.0
		if Input.is_action_pressed(input_left):
			direction -= 1.0
		if Input.is_action_pressed(input_right):
			direction += 1.0

		velocity.x = direction * speed

		if direction != 0:
			facing_right = direction > 0

		if Input.is_action_just_pressed(input_up) and is_on_floor():
			velocity.y = jump_force

		if Input.is_action_pressed(input_down) and is_on_floor():
			velocity.x *= 0.3
			is_crouching = true
	elif is_attacking or is_firing_special:
		velocity.x *= 0.8

	# Attack inputs - check for special first (both pressed at once)
	if not is_attacking and not is_firing_special and cooldown_timer <= 0 and hit_stun_timer <= 0:
		var punch_pressed := Input.is_action_just_pressed(input_punch)
		var kick_pressed := Input.is_action_just_pressed(input_kick)
		# Special: both punch and kick held/pressed together
		if punch_pressed and Input.is_action_pressed(input_kick) or \
		   kick_pressed and Input.is_action_pressed(input_punch):
			_try_fireball()
		elif punch_pressed:
			_start_attack("punch")
		elif kick_pressed:
			_start_attack("kick")

	# Adjust hurtbox for crouching
	if is_crouching:
		hurtbox.position.y = -20
	else:
		hurtbox.position.y = -37

	move_and_slide()
	_update_blood(delta)

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

	# Spawn blood
	_spawn_blood(Vector2(0, -40), knockback_dir, damage)

	emit_signal("health_changed", health, max_health)

	if health <= 0:
		_die()

func _take_ring_damage() -> void:
	if is_dead:
		return
	health -= RING_DAMAGE_PER_SEC
	health = max(health, 0)
	flash_timer = 0.08

	# Spark/burn effect instead of blood for ring damage
	_spawn_ring_sparks()

	emit_signal("health_changed", health, max_health)
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	_spawn_blood(Vector2(0, -35), 0.0, 30)
	emit_signal("player_died", player_id)

func _try_fireball() -> void:
	if stamina < STAMINA_COST:
		return
	stamina -= STAMINA_COST
	emit_signal("stamina_changed", stamina, STAMINA_MAX)
	is_firing_special = true
	fireball_anim_timer = FIREBALL_ANIM_DURATION

	# Spawn fireball after short windup
	get_tree().create_timer(0.15).timeout.connect(func():
		_spawn_fireball()
	)

func _spawn_fireball() -> void:
	var fireball_scene = load(FIREBALL_SCENE_PATH)
	var fireball = fireball_scene.instantiate()
	fireball.direction = 1.0 if facing_right else -1.0
	fireball.damage = FIREBALL_DAMAGE
	fireball.owner_id = player_id
	fireball.global_position = global_position + Vector2((30.0 if facing_right else -30.0), -40.0)
	get_parent().add_child(fireball)

func take_fireball_damage(damage: int, dir: float) -> void:
	# Crouching dodges the fireball
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
	ring_damage_timer = 0.0
	at_ring_edge = false
	is_crouching = false
	stamina = STAMINA_MAX
	is_firing_special = false
	fireball_anim_timer = 0.0
	attack_anim_progress = 0.0
	facing_right = face_right
	blood_particles.clear()
	emit_signal("health_changed", health, max_health)
	emit_signal("stamina_changed", stamina, STAMINA_MAX)

# ── Blood particle system ──

func _spawn_blood(local_hit_pos: Vector2, knockback_dir: float, damage: int) -> void:
	var count = clampi(damage, 4, 15)
	for i in count:
		if blood_particles.size() >= MAX_BLOOD:
			blood_particles.pop_front()
		var spread_x = randf_range(-80, 80) + knockback_dir * 120.0
		var spread_y = randf_range(-200, -40)
		var size = randf_range(1.5, 4.0)
		var life = randf_range(0.5, 1.2)
		blood_particles.append({
			"pos": local_hit_pos,
			"vel": Vector2(spread_x, spread_y),
			"life": life,
			"max_life": life,
			"size": size,
			"is_spark": false
		})

func _spawn_ring_sparks() -> void:
	for i in 6:
		if blood_particles.size() >= MAX_BLOOD:
			blood_particles.pop_front()
		var spread_x = randf_range(-60, 60)
		var spread_y = randf_range(-150, -30)
		blood_particles.append({
			"pos": Vector2(0, -30),
			"vel": Vector2(spread_x, spread_y),
			"life": randf_range(0.3, 0.6),
			"max_life": 0.5,
			"size": randf_range(2.0, 4.0),
			"is_spark": true
		})

func _update_blood(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in blood_particles.size():
		var p = blood_particles[i]
		p["vel"] = p["vel"] as Vector2 + Vector2(0, BLOOD_GRAVITY * delta)
		p["pos"] = p["pos"] as Vector2 + (p["vel"] as Vector2) * delta
		p["life"] = (p["life"] as float) - delta

		# Stop at floor
		if (p["pos"] as Vector2).y > 5.0:
			p["pos"] = Vector2((p["pos"] as Vector2).x, 5.0)
			p["vel"] = Vector2((p["vel"] as Vector2).x * 0.3, 0)

		if (p["life"] as float) <= 0:
			to_remove.append(i)

	# Remove dead particles (back to front)
	to_remove.reverse()
	for i in to_remove:
		blood_particles.remove_at(i)

