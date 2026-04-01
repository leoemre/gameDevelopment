extends ColorRect

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Brick wall pattern on the background
	var brick_w := 64.0
	var brick_h := 28.0
	var line_color := Color(0.15, 0.15, 0.22, 0.4)
	var highlight := Color(0.18, 0.18, 0.26, 0.2)

	# Horizontal mortar lines
	var row := 0
	var y := 0.0
	while y < 580:
		draw_line(Vector2(0, y), Vector2(1280, y), line_color, 1.0)
		# Vertical mortar lines (offset every other row)
		var offset := brick_w * 0.5 if row % 2 == 1 else 0.0
		var x := offset
		while x < 1280:
			draw_line(Vector2(x, y), Vector2(x, y + brick_h), line_color, 1.0)
			# Subtle highlight on top-left of each brick
			draw_line(Vector2(x + 1, y + 1), Vector2(x + brick_w * 0.6, y + 1), highlight, 1.0)
			x += brick_w
		y += brick_h
		row += 1
