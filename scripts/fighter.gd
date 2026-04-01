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

# Input mapping
var input_left: String
var input_right: String
var input_up: String
var input_down: String
var input_punch: String
var input_kick: String

# Node references
@onready var body_sprite: ColorRect = $BodySprite
@onready var head_sprite: ColorRect = $HeadSprite
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/AttackShape
@onready var hurtbox: Area2D = $Hurtbox
@onready var anim_player: AnimationPlayer = $AnimationPlayer

signal health_changed(new_health: int, max_hp: int)
signal player_died(player_id: int)

func _ready() -> void:
	health = max_health
	_setup_inputs()
	_update_colors()
	attack_shape.disabled = true

func _setup_inputs() -> void:
	var prefix = "p" + str(player_id) + "_"
	input_left = prefix + "left"
	input_right = prefix + "right"
	input_up = prefix + "up"
	input_down = prefix + "down"
	input_punch = prefix + "punch"
	input_kick = prefix + "kick"

func _update_colors() -> void:
	body_sprite.color = fighter_color
	head_sprite.color = fighter_color.lightened(0.2)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Timers
	if cooldown_timer > 0:
		cooldown_timer -= delta
	if hit_stun_timer > 0:
		hit_stun_timer -= delta

	# Attack timer
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Movement (disabled during attack or hit stun)
	if not is_attacking and hit_stun_timer <= 0:
		var direction := 0.0
		if Input.is_action_pressed(input_left):
			direction -= 1.0
		if Input.is_action_pressed(input_right):
			direction += 1.0

		velocity.x = direction * speed

		# Update facing direction
		if direction != 0:
			facing_right = direction > 0
			_update_facing()

		# Jump
		if Input.is_action_just_pressed(input_up) and is_on_floor():
			velocity.y = jump_force

		# Crouch (slow down)
		if Input.is_action_pressed(input_down) and is_on_floor():
			velocity.x *= 0.3
	elif is_attacking:
		velocity.x *= 0.8  # Slow down during attack

	# Attack inputs
	if not is_attacking and cooldown_timer <= 0 and hit_stun_timer <= 0:
		if Input.is_action_just_pressed(input_punch):
			_start_attack("punch")
		elif Input.is_action_just_pressed(input_kick):
			_start_attack("kick")

	move_and_slide()

func _update_facing() -> void:
	var dir = 1 if facing_right else -1
	# Flip the attack area to face the right direction
	attack_area.position.x = abs(attack_area.position.x) * dir
	# Flip visual body
	body_sprite.position.x = -15 if facing_right else -15
	head_sprite.position.x = -10 if facing_right else -10

func _start_attack(type: String) -> void:
	is_attacking = true
	attack_type = type

	if type == "punch":
		attack_timer = PUNCH_DURATION
		attack_shape.disabled = false
		# Visual feedback - move body forward slightly
		_show_attack_visual("punch")
	elif type == "kick":
		attack_timer = KICK_DURATION
		attack_shape.disabled = false
		_show_attack_visual("kick")

	# Check for hits
	_check_hit()

func _end_attack() -> void:
	is_attacking = false
	attack_type = ""
	attack_shape.disabled = true
	cooldown_timer = ATTACK_COOLDOWN
	_hide_attack_visual()

func _check_hit() -> void:
	if opponent == null:
		return

	var distance = abs(global_position.x - opponent.global_position.x)
	var height_diff = abs(global_position.y - opponent.global_position.y)

	# Check if opponent is in range
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

	# Knockback
	velocity.x = knockback_dir * KNOCKBACK_FORCE
	velocity.y = -150.0

	# Flash effect
	_flash_hit()

	emit_signal("health_changed", health, max_health)

	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	# Turn dark and fall
	body_sprite.color = Color.DIM_GRAY
	head_sprite.color = Color.GRAY
	emit_signal("player_died", player_id)

func _show_attack_visual(type: String) -> void:
	# Extend the body to show attack
	if type == "punch":
		var punch_indicator = body_sprite.duplicate()
		punch_indicator.name = "PunchVFX"
		punch_indicator.size = Vector2(30, 8)
		punch_indicator.color = Color.WHITE
		var dir = 1 if facing_right else -1
		punch_indicator.position = Vector2(15 * dir, -30)
		add_child(punch_indicator)
	elif type == "kick":
		var kick_indicator = body_sprite.duplicate()
		kick_indicator.name = "KickVFX"
		kick_indicator.size = Vector2(35, 8)
		kick_indicator.color = Color.YELLOW
		var dir = 1 if facing_right else -1
		kick_indicator.position = Vector2(15 * dir, -10)
		add_child(kick_indicator)

func _hide_attack_visual() -> void:
	for child in get_children():
		if child.name == "PunchVFX" or child.name == "KickVFX":
			child.queue_free()

func _flash_hit() -> void:
	var original_body = fighter_color
	var original_head = fighter_color.lightened(0.2)
	body_sprite.color = Color.WHITE
	head_sprite.color = Color.WHITE
	# Reset after short delay
	get_tree().create_timer(0.1).timeout.connect(func():
		if not is_dead:
			body_sprite.color = original_body
			head_sprite.color = original_head
	)

func reset(start_pos: Vector2, face_right: bool) -> void:
	global_position = start_pos
	velocity = Vector2.ZERO
	health = max_health
	is_dead = false
	is_attacking = false
	attack_timer = 0.0
	cooldown_timer = 0.0
	hit_stun_timer = 0.0
	facing_right = face_right
	_update_facing()
	_update_colors()
	_hide_attack_visual()
	emit_signal("health_changed", health, max_health)
