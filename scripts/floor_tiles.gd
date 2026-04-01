extends ColorRect

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Checkered floor tiles
	var tile_size := 48.0
	var floor_w := size.x
	var floor_h := size.y
	var dark_tile := Color(0.22, 0.19, 0.17, 1)
	var grout := Color(0.18, 0.15, 0.13, 0.5)

	var col := 0
	var x := 0.0
	while x < floor_w:
		var row := 0
		var y := 0.0
		while y < floor_h:
			if (col + row) % 2 == 0:
				draw_rect(Rect2(x, y, tile_size, tile_size), dark_tile)
			# Grout lines
			draw_line(Vector2(x, y), Vector2(x, y + tile_size), grout, 1.0)
			draw_line(Vector2(x, y), Vector2(x + tile_size, y), grout, 1.0)
			y += tile_size
			row += 1
		x += tile_size
		col += 1
