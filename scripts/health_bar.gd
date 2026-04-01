extends Control

@onready var bar: ProgressBar = $ProgressBar
@onready var name_label: Label = $PlayerName
@onready var hp_label: Label = $HPLabel

@export var bar_color: Color = Color.GREEN
@export var player_name: String = "Player"

func _ready() -> void:
	bar.max_value = 100
	bar.value = 100
	name_label.text = player_name
	_update_hp_text(100, 100)

	# Style the bar
	var style = StyleBoxFlat.new()
	style.bg_color = bar_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg_style)

func update_health(current: int, maximum: int) -> void:
	bar.max_value = maximum
	bar.value = current
	_update_hp_text(current, maximum)

	# Change color based on health percentage
	var percent = float(current) / float(maximum)
	var style = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if style:
		if percent > 0.6:
			style.bg_color = Color.GREEN
		elif percent > 0.3:
			style.bg_color = Color.ORANGE
		else:
			style.bg_color = Color.RED

func _update_hp_text(current: int, maximum: int) -> void:
	hp_label.text = str(current) + " / " + str(maximum)
