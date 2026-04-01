extends Node2D

# Ring boundaries (must match main.gd)
const RING_LEFT: float = 140.0
const RING_RIGHT: float = 1140.0
const RING_FLOOR_Y: float = 580.0
const RING_POST_WIDTH: float = 16.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var post_color := Color(0.6, 0.55, 0.5)
	var post_highlight := Color(0.75, 0.7, 0.65)
	var rope_colors := [Color(1.0, 0.15, 0.1), Color.WHITE, Color(0.2, 0.4, 1.0)]

	# Ring mat / canvas floor
	var mat_rect := Rect2(RING_LEFT, RING_FLOOR_Y - 4, RING_RIGHT - RING_LEFT, 8)
	draw_rect(mat_rect, Color(0.35, 0.32, 0.28))
	draw_rect(Rect2(RING_LEFT + 2, RING_FLOOR_Y - 4, RING_RIGHT - RING_LEFT - 4, 2), Color(0.45, 0.4, 0.35))

	# Ring apron (below the mat)
	var apron_rect := Rect2(RING_LEFT - 10, RING_FLOOR_Y + 4, RING_RIGHT - RING_LEFT + 20, 50)
	draw_rect(apron_rect, Color(0.15, 0.12, 0.1))
	draw_rect(Rect2(RING_LEFT - 10, RING_FLOOR_Y + 4, RING_RIGHT - RING_LEFT + 20, 4), Color(0.8, 0.65, 0.2))

	# Corner posts
	_draw_post(RING_LEFT, post_color, post_highlight)
	_draw_post(RING_RIGHT, post_color, post_highlight)

	# Ropes (3 at different heights)
	var rope_heights := [RING_FLOOR_Y - 20, RING_FLOOR_Y - 40, RING_FLOOR_Y - 60]
	for i in 3:
		var y := rope_heights[i]
		var color: Color = rope_colors[i]
		draw_line(Vector2(RING_LEFT, y), Vector2(RING_RIGHT, y), color, 3.0)
		draw_line(Vector2(RING_LEFT, y + 2), Vector2(RING_RIGHT, y + 2), color.darkened(0.5), 1.5)
		draw_line(Vector2(RING_LEFT, y - 1), Vector2(RING_RIGHT, y - 1), color.lightened(0.3), 1.0)

	# Turnbuckles
	for i in 3:
		var y := rope_heights[i]
		draw_circle(Vector2(RING_LEFT, y), 4.0, Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(RING_RIGHT, y), 4.0, Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(RING_LEFT, y), 2.5, Color(0.6, 0.6, 0.6))
		draw_circle(Vector2(RING_RIGHT, y), 2.5, Color(0.6, 0.6, 0.6))

	# Danger zone indicators
	_draw_danger_zone(RING_LEFT)
	_draw_danger_zone(RING_RIGHT)

	# Center ring logo
	var center_x := (RING_LEFT + RING_RIGHT) / 2.0
	draw_circle(Vector2(center_x, RING_FLOOR_Y - 2), 30, Color(0.4, 0.35, 0.3, 0.3))
	draw_arc(Vector2(center_x, RING_FLOOR_Y - 2), 30, 0, TAU, 24, Color(0.5, 0.45, 0.4, 0.4), 1.5)

func _draw_post(x: float, color: Color, highlight: Color) -> void:
	var post_top := RING_FLOOR_Y - 75
	var post_bottom := RING_FLOOR_Y + 50
	draw_rect(Rect2(x - RING_POST_WIDTH / 2, post_top, RING_POST_WIDTH, post_bottom - post_top), color)
	draw_rect(Rect2(x - 2, post_top, 4, post_bottom - post_top), highlight)
	draw_rect(Rect2(x - RING_POST_WIDTH / 2 - 2, post_top - 4, RING_POST_WIDTH + 4, 8), Color(0.85, 0.8, 0.2))
	draw_rect(Rect2(x - RING_POST_WIDTH / 2 - 4, RING_FLOOR_Y, RING_POST_WIDTH + 8, 8), color.darkened(0.2))

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
