extends Area2D

var direction: float = 1.0
var speed: float = 500.0
var damage: int = 40
var owner_id: int = 0
var fireball_color: Color = Color.ORANGE
var lifetime: float = 3.0
var particles: Array = []

const PARTICLE_GRAVITY: float = 80.0

func _ready() -> void:
	# Connect body detection
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	lifetime -= delta

	# Spawn trail particles
	_spawn_trail_particle()

	# Update trail particles
	var to_remove: Array[int] = []
	for i in particles.size():
		var p = particles[i]
		p["vel"] = (p["vel"] as Vector2) + Vector2(0, PARTICLE_GRAVITY * delta)
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["life"] = (p["life"] as float) - delta
		if (p["life"] as float) <= 0:
			to_remove.append(i)
	to_remove.reverse()
	for i in to_remove:
		particles.remove_at(i)

	if lifetime <= 0:
		queue_free()

	queue_redraw()

func _spawn_trail_particle() -> void:
	if particles.size() > 30:
		return
	particles.append({
		"pos": Vector2(randf_range(-8, 8), randf_range(-8, 8)),
		"vel": Vector2(randf_range(-30, 30) - direction * 80, randf_range(-40, -10)),
		"life": randf_range(0.15, 0.35),
		"max_life": 0.3,
		"size": randf_range(3.0, 7.0)
	})

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("take_fireball_damage"):
		if body.player_id != owner_id:
			body.take_fireball_damage(damage, direction)
			_explode()
			queue_free()

func _explode() -> void:
	# The explosion effect is handled by the hit fighter's blood system
	pass

func _draw() -> void:
	# Draw trail particles first
	for p in particles:
		var life_ratio: float = (p["life"] as float) / (p["max_life"] as float)
		var alpha := clampf(life_ratio, 0.0, 1.0)
		var sz: float = p["size"] as float
		var pos: Vector2 = p["pos"] as Vector2
		# Orange/yellow fading trail
		draw_circle(pos, sz * life_ratio, Color(1.0, 0.5, 0.0, alpha * 0.6))
		draw_circle(pos, sz * life_ratio * 0.5, Color(1.0, 0.8, 0.2, alpha * 0.8))

	# Outer glow
	draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.3, 0.0, 0.2))
	# Fire body
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.4, 0.0, 0.8))
	# Mid layer
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.7, 0.1, 0.9))
	# Hot core
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.8, 1.0))

	# Flickering flames on edges
	var t := Time.get_ticks_msec() * 0.01
	for i in 5:
		var angle := t + i * 1.25
		var dist := 8.0 + sin(angle * 2.3) * 4.0
		var flame_pos := Vector2(cos(angle) * dist, sin(angle) * dist)
		var flame_size := 3.0 + sin(angle * 3.7) * 1.5
		draw_circle(flame_pos, flame_size, Color(1.0, 0.5, 0.0, 0.5))
