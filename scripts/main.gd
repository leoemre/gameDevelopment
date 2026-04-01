extends Node2D

@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
@onready var health_bar_p1: Control = $UI/HealthBarP1
@onready var health_bar_p2: Control = $UI/HealthBarP2
@onready var round_label: Label = $UI/RoundLabel
@onready var info_label: Label = $UI/InfoLabel
@onready var restart_timer: Timer = $RestartTimer

const P1_START = Vector2(300, 500)
const P2_START = Vector2(980, 500)

var round_number: int = 1
var p1_wins: int = 0
var p2_wins: int = 0
var game_active: bool = true

func _ready() -> void:
	# Connect signals
	player1.health_changed.connect(_on_p1_health_changed)
	player2.health_changed.connect(_on_p2_health_changed)
	player1.player_died.connect(_on_player_died)
	player2.player_died.connect(_on_player_died)

	# Link opponents
	player1.opponent = player2
	player2.opponent = player1

	restart_timer.timeout.connect(_on_restart_timeout)

	_start_round()

func _start_round() -> void:
	game_active = true
	player1.reset(P1_START, true)
	player2.reset(P2_START, false)
	round_label.text = "Round " + str(round_number)
	info_label.text = "FIGHT!"

	# Clear fight text after a moment
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
