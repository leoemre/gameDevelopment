extends Node2D

# Ring boundaries (must match main.gd)
const RING_LEFT: float = 140.0
const RING_RIGHT: float = 1140.0
const RING_FLOOR_Y: float = 580.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Animated danger zone indicators near edges
	_draw_danger_zone(RING_LEFT)
	_draw_danger_zone(RING_RIGHT)

	# Center ring circle
	var center_x := (RING_LEFT + RING_RIGHT) / 2.0
	draw_circle(Vector2(center_x, RING_FLOOR_Y - 2), 30, Color(0.4, 0.35, 0.3, 0.3))
	draw_arc(Vector2(center_x, RING_FLOOR_Y - 2), 30, 0, TAU, 24, Color(0.5, 0.45, 0.4, 0.4), 1.5)

func _draw_danger_zone(edge_x: float) -> void:
	var pulse := (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
	var alpha := 0.05 + pulse * 0.08
	if edge_x == RING_LEFT:
		for i in 4:
			var a := alpha * (1.0 - float(i) / 4.0)
			draw_rect(Rect2(RING_LEFT + i * 10, RING_FLOOR_Y - 70, 10, 70), Color(1, 0, 0, a))
	else:
		for i in 4:
			var a := alpha * (1.0 - float(i) / 4.0)
			draw_rect(Rect2(RING_RIGHT - (i + 1) * 10, RING_FLOOR_Y - 70, 10, 70), Color(1, 0, 0, a))
