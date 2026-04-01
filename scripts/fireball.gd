extends Area2D

var direction: float = 1.0
var speed: float = 500.0
var damage: int = 40
var owner_id: int = 0
var lifetime: float = 3.0
var has_hit: bool = false

func _physics_process(delta: float) -> void:
	if has_hit:
		return
	position.x += direction * speed * delta
	lifetime -= delta

	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body is CharacterBody2D and body.has_method("take_fireball_damage"):
			if body.player_id != owner_id:
				has_hit = true
				body.take_fireball_damage(damage, direction)
				queue_free()
				return

	if lifetime <= 0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	# Outer glow
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.3, 0.0, 0.2))
	# Fire body
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.4, 0.0, 0.8))
	# Mid
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.7, 0.1, 0.9))
	# Core
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 0.8, 1.0))

	# Flickering flames
	var t := Time.get_ticks_msec() * 0.01
	for i in 4:
		var angle := t + i * 1.57
		var dist := 7.0 + sin(angle * 2.3) * 3.0
		var fp := Vector2(cos(angle) * dist, sin(angle) * dist)
		draw_circle(fp, 2.5 + sin(angle * 3.7), Color(1.0, 0.5, 0.0, 0.5))

	# Trail
	for i in 3:
		var tx := -direction * (10.0 + i * 8.0)
		draw_circle(Vector2(tx, 0), 4.0 - i, Color(1.0, 0.4, 0.0, 0.3 - i * 0.08))
