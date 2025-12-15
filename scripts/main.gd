extends Node3D

@export var camera: Camera3D
@export var score_value_label: Label
@export var best_score_label: Label
@export var game_over_label: Label
@export var timer_value_label: Label
@export var initial_time: float = 45.0

# --- Score "roulant"
@export var base_roll_speed: float = 800.0
@export var roll_factor: float = 0.12

# --- Slow-time (piloté par la pression envoyée par le spawner)
@export_range(0.1, 1.0, 0.01) var min_timescale: float = 0.50
@export_range(0.1, 1.0, 0.01) var min_timer_speed: float = 0.50
@export var slow_smooth: float = 8.0

# --- Bonus temps basé sur le score ajouté
@export var points_per_second: float = 20.0          # 20 pts = +1s (chez toi)
@export var max_bonus_seconds_per_pop: float = 0.25  # plafond par bulle
@export var max_remaining_time_cap: float = 45.0     # cap du timer

# --- Late-game : bonus temps amplifié quand il reste peu de temps
@export var low_time_boost_start_seconds: float = 10.0  # en dessous de 10s, bonus augmente
@export var max_low_time_multiplier: float = 2.5        # à 0s => bonus * 2.5

# --- Atténuation du slow-motion en fin de run (timescale uniquement)
@export var timescale_fade_start_seconds: float = 15.0

var score: int = 0
var target_score: int = 0
var display_score: float = 0.0

var game_over: bool = false
var allow_restart: bool = false
var remaining_time: float = 0.0
var timer: Timer = null

var pressure_factor: float = 0.0
var pressure_factor_smoothed: float = 0.0


func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_unhandled_input(true)

	score = 0
	target_score = 0
	display_score = 0.0

	if score_value_label:
		score_value_label.text = str(int(display_score))

	if best_score_label:
		best_score_label.text = "%d" % ScoreManager.get_best_score()

	if game_over_label:
		game_over_label.hide()

	remaining_time = initial_time
	if timer_value_label:
		timer_value_label.text = _format_time(remaining_time)

	Engine.time_scale = 1.0
	_start_timer()


func _process(delta: float) -> void:
	# Lissage de la pression
	if not game_over:
		pressure_factor_smoothed = lerp(
			pressure_factor_smoothed,
			pressure_factor,
			1.0 - exp(-slow_smooth * delta)
		)

		# Atténuation du slow visuel quand le temps est bas (timescale seulement)
		var fade := 1.0
		if timescale_fade_start_seconds > 0.0:
			fade = clamp(remaining_time / timescale_fade_start_seconds, 0.0, 1.0)

		var effective_pressure := pressure_factor_smoothed * fade
		Engine.time_scale = lerp(1.0, min_timescale, effective_pressure)

	# Score roulant
	var cur := int(display_score)
	if cur != target_score:
		var diff: float = abs(float(target_score) - float(cur))
		var speed := base_roll_speed + diff * roll_factor
		display_score = move_toward(display_score, float(target_score), speed * delta)

		if score_value_label:
			score_value_label.text = str(int(display_score))


func set_pressure_factor(f: float) -> void:
	pressure_factor = clamp(f, 0.0, 1.0)


func _get_timer_speed() -> float:
	return lerp(1.0, min_timer_speed, pressure_factor_smoothed)


func increment_score(value: int):
	score += value
	target_score = score

	_add_time_from_score(value)

	if score > ScoreManager.get_best_score():
		ScoreManager.update_score(score)
		if best_score_label:
			best_score_label.text = "%d" % ScoreManager.get_best_score()


func _add_time_from_score(added_score: int) -> void:
	if added_score <= 0:
		return
	if points_per_second <= 0.0:
		return

	# Base : mapping continu
	var bonus := float(added_score) / points_per_second

	# Late-game boost : plus il reste peu de temps, plus le bonus est grand
	# remaining_time <= low_time_boost_start_seconds => multiplier va vers max_low_time_multiplier
	if low_time_boost_start_seconds > 0.0 and max_low_time_multiplier > 1.0:
		var t : float = clamp(1.0 - (remaining_time / low_time_boost_start_seconds), 0.0, 1.0)
		var multiplier : float = lerp(1.0, max_low_time_multiplier, t)
		bonus *= multiplier

	# Plafond par pop (anti spam)
	if max_bonus_seconds_per_pop > 0.0:
		bonus = min(bonus, max_bonus_seconds_per_pop)

	remaining_time += bonus

	# Cap global (évite les runs infinis)
	if max_remaining_time_cap > 0.0:
		remaining_time = min(remaining_time, max_remaining_time_cap)

	if timer_value_label:
		timer_value_label.text = _format_time(remaining_time)


func _start_timer():
	timer = Timer.new()
	timer.wait_time = 0.01
	timer.one_shot = false
	timer.connect("timeout", Callable(self, "_update_timer"))
	add_child(timer)
	timer.start()


func _update_timer():
	if game_over:
		return

	remaining_time -= 0.01 * _get_timer_speed()

	if remaining_time <= 0:
		remaining_time = 0
		end_game()

	if timer_value_label:
		timer_value_label.text = _format_time(remaining_time)


func _format_time(time: float) -> String:
	var seconds = int(time)
	var centiseconds = int((time - seconds) * 100)
	return "%02d:%02d" % [seconds, centiseconds]


func end_game():
	game_over = true
	allow_restart = false
	get_tree().paused = true
	Engine.time_scale = 1.0

	if game_over_label:
		game_over_label.show()
		game_over_label.text = "Game Over! Click to play again."

	if timer:
		timer.stop()

	_create_restart_delay_timer(2.0)


func _unhandled_input(event):
	if game_over and allow_restart and event is InputEventMouseButton and event.pressed:
		_restart_game()


func _restart_game():
	game_over = false
	get_tree().paused = false
	Engine.time_scale = 1.0

	var current_scene_path = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(current_scene_path)


func _create_restart_delay_timer(delay: float):
	var restart_timer = Timer.new()
	restart_timer.one_shot = true
	restart_timer.wait_time = delay
	restart_timer.connect("timeout", Callable(self, "_allow_restart"))
	add_child(restart_timer)
	restart_timer.start()


func _allow_restart():
	allow_restart = true


func _input(event):
	if event.is_action_pressed("quit"):
		get_tree().quit()
