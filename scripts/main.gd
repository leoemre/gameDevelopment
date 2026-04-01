extends Node2D

@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
@onready var health_bar_p1: Control = $UI/HealthBarP1
@onready var health_bar_p2: Control = $UI/HealthBarP2
@onready var round_label: Label = $UI/RoundLabel
@onready var info_label: Label = $UI/InfoLabel
@onready var restart_timer: Timer = $RestartTimer

const P1_START = Vector2(400, 560)
const P2_START = Vector2(880, 560)

# Ring boundaries
const RING_LEFT: float = 140.0
const RING_RIGHT: float = 1140.0
const RING_FLOOR_Y: float = 580.0
const RING_EDGE_ZONE: float = 40.0  # Distance from edge where damage starts
const RING_POST_WIDTH: float = 16.0

var round_number: int = 1
var p1_wins: int = 0
var p2_wins: int = 0
var game_active: bool = true

func _ready() -> void:
	player1.health_changed.connect(_on_p1_health_changed)
	player2.health_changed.connect(_on_p2_health_changed)
	player1.player_died.connect(_on_player_died)
	player2.player_died.connect(_on_player_died)

	player1.opponent = player2
	player2.opponent = player1

	restart_timer.timeout.connect(_on_restart_timeout)

	_start_round()

func _physics_process(_delta: float) -> void:
	if not game_active:
		return

	# Clamp players inside the ring
	_clamp_player(player1)
	_clamp_player(player2)

	# Check ring edge damage
	_check_ring_edge(player1)
	_check_ring_edge(player2)

	queue_redraw()

func _clamp_player(player: CharacterBody2D) -> void:
	if player.global_position.x < RING_LEFT + 15:
		player.global_position.x = RING_LEFT + 15
	elif player.global_position.x > RING_RIGHT - 15:
		player.global_position.x = RING_RIGHT - 15

func _check_ring_edge(player: CharacterBody2D) -> void:
	var dist_left := player.global_position.x - RING_LEFT
	var dist_right := RING_RIGHT - player.global_position.x
	var min_dist := minf(dist_left, dist_right)

	player.at_ring_edge = min_dist < RING_EDGE_ZONE

func _start_round() -> void:
	game_active = true
	# Clean up any remaining fireballs
	for child in get_children():
		if child.has_method("_spawn_trail_particle"):
			child.queue_free()
	player1.reset(P1_START, true)
	player2.reset(P2_START, false)
	round_label.text = "Round " + str(round_number)
	info_label.text = "FIGHT!"

	get_tree().create_timer(1.5).timeout.connect(func():
		if game_active:
			info_label.text = ""
	)

func _on_p1_health_changed(current: int, maximum: int) -> void:
	health_bar_p1.update_health(current, maximum)

func _on_p2_health_changed(current: int, maximum: int) -> void:
	health_bar_p2.update_health(current, maximum)

func _on_player_died(dead_player_id: int) -> void:
	game_active = false
	if dead_player_id == 1:
		p2_wins += 1
		info_label.text = "Player 2 Wins!"
	else:
		p1_wins += 1
		info_label.text = "Player 1 Wins!"

	round_label.text = "Score: P1 " + str(p1_wins) + " - " + str(p2_wins) + " P2"
	restart_timer.start(3.0)

func _on_restart_timeout() -> void:
	round_number += 1
	_start_round()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# ── Draw the ring ──

func _draw() -> void:
	var post_color := Color(0.6, 0.55, 0.5)
	var post_highlight := Color(0.75, 0.7, 0.65)
	var rope_colors := [Color(1.0, 0.15, 0.1), Color.WHITE, Color(0.2, 0.4, 1.0)]

	# Ring mat / canvas floor
	var mat_rect := Rect2(RING_LEFT, RING_FLOOR_Y - 4, RING_RIGHT - RING_LEFT, 8)
	draw_rect(mat_rect, Color(0.35, 0.32, 0.28))
	# Mat surface highlight
	draw_rect(Rect2(RING_LEFT + 2, RING_FLOOR_Y - 4, RING_RIGHT - RING_LEFT - 4, 2), Color(0.45, 0.4, 0.35))

	# Ring apron (below the mat)
	var apron_rect := Rect2(RING_LEFT - 10, RING_FLOOR_Y + 4, RING_RIGHT - RING_LEFT + 20, 50)
	draw_rect(apron_rect, Color(0.15, 0.12, 0.1))
	# Apron stripe
	draw_rect(Rect2(RING_LEFT - 10, RING_FLOOR_Y + 4, RING_RIGHT - RING_LEFT + 20, 4), Color(0.8, 0.65, 0.2))

	# Corner posts
	_draw_post(RING_LEFT, post_color, post_highlight)
	_draw_post(RING_RIGHT, post_color, post_highlight)

	# Ropes (3 ropes at different heights)
	var rope_heights := [RING_FLOOR_Y - 20, RING_FLOOR_Y - 40, RING_FLOOR_Y - 60]
	for i in 3:
		var y := rope_heights[i]
		var color: Color = rope_colors[i]
		# Main rope
		draw_line(Vector2(RING_LEFT, y), Vector2(RING_RIGHT, y), color, 3.0)
		# Rope shadow
		draw_line(Vector2(RING_LEFT, y + 2), Vector2(RING_RIGHT, y + 2), color.darkened(0.5), 1.5)
		# Rope highlight
		draw_line(Vector2(RING_LEFT, y - 1), Vector2(RING_RIGHT, y - 1), color.lightened(0.3), 1.0)

	# Turnbuckles (where ropes meet posts)
	for i in 3:
		var y := rope_heights[i]
		draw_circle(Vector2(RING_LEFT, y), 4.0, Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(RING_RIGHT, y), 4.0, Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(RING_LEFT, y), 2.5, Color(0.6, 0.6, 0.6))
		draw_circle(Vector2(RING_RIGHT, y), 2.5, Color(0.6, 0.6, 0.6))

	# Danger zone indicators (red glow near edges)
	_draw_danger_zone(RING_LEFT)
	_draw_danger_zone(RING_RIGHT)

	# Center ring logo
	var center_x := (RING_LEFT + RING_RIGHT) / 2.0
	draw_circle(Vector2(center_x, RING_FLOOR_Y - 2), 30, Color(0.4, 0.35, 0.3, 0.3))
	draw_arc(Vector2(center_x, RING_FLOOR_Y - 2), 30, 0, TAU, 24, Color(0.5, 0.45, 0.4, 0.4), 1.5)

func _draw_post(x: float, color: Color, highlight: Color) -> void:
	var post_top := RING_FLOOR_Y - 75
	var post_bottom := RING_FLOOR_Y + 50

	# Post body
	draw_rect(Rect2(x - RING_POST_WIDTH / 2, post_top, RING_POST_WIDTH, post_bottom - post_top), color)
	# Highlight stripe
	draw_rect(Rect2(x - 2, post_top, 4, post_bottom - post_top), highlight)
	# Top cap
	draw_rect(Rect2(x - RING_POST_WIDTH / 2 - 2, post_top - 4, RING_POST_WIDTH + 4, 8), Color(0.85, 0.8, 0.2))
	# Post base
	draw_rect(Rect2(x - RING_POST_WIDTH / 2 - 4, RING_FLOOR_Y, RING_POST_WIDTH + 8, 8), color.darkened(0.2))

func _draw_danger_zone(edge_x: float) -> void:
	# Pulsing red glow near the ropes to indicate danger
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
