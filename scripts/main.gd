extends Node3D

@export var camera: Camera3D
@export var score_value_label: Label
@export var best_score_label: Label
@export var difficulty_value_label: Label
@export var survival_time_label: Label

# >>> UI Game Over : parent (avec script pop) + label (texte)
@export var game_over_control: Control
@export var game_over_label: Label

@export var collision_marker_scene: PackedScene

# --- Score "roulant"
@export var base_roll_speed: float = 800.0
@export var roll_factor: float = 0.12

# --- Slowdown basé sur le nombre de bulles
@export_range(0.05, 1.0, 0.01) var min_timescale: float = 0.35
@export var slowdown_smooth: float = 10.0
@export var slowdown_curve_power: float = 1.8
@export var show_timescale_debug: bool = false

# --- Difficulty (infinie) en multiplicateur
@export var base_difficulty_multiplier: float = 1.0
@export var seconds_per_doubling: float = 25.0
@export var curve_power: float = 1.0
@export var difficulty_decimals: int = 2

var score: int = 0
var target_score: int = 0
var display_score: float = 0.0

var game_over: bool = false
var allow_restart: bool = false

var run_time: float = 0.0
var difficulty_multiplier: float = 1.0

var bubble_load_factor: float = 0.0
var bubble_load_smoothed: float = 0.0


func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_unhandled_input(true)

	score = 0
	target_score = 0
	display_score = 0.0
	run_time = 0.0
	difficulty_multiplier = base_difficulty_multiplier

	if score_value_label:
		score_value_label.text = str(int(display_score))

	if best_score_label:
		best_score_label.text = "%d" % ScoreManager.get_best_score()

	# >>> On cache le CONTROLE, pas juste le label
	if game_over_control:
		game_over_control.hide()

	Engine.time_scale = 1.0
	_update_difficulty_label()


func _process(delta: float) -> void:
	if not game_over:
		run_time += delta
		var doubling: float = max(seconds_per_doubling, 0.001)
		var growth_per_second := pow(2.0, 1.0 / doubling)
		var t := pow(run_time, curve_power)
		difficulty_multiplier = base_difficulty_multiplier * pow(growth_per_second, t)

		if survival_time_label:
			survival_time_label.text = _format_survival_time(run_time)
		_update_difficulty_label()

		bubble_load_smoothed = lerp(
			bubble_load_smoothed,
			bubble_load_factor,
			1.0 - exp(-slowdown_smooth * delta)
		)

		var shaped := pow(clamp(bubble_load_smoothed, 0.0, 1.0), slowdown_curve_power)
		Engine.time_scale = lerp(1.0, min_timescale, shaped)

	var cur := int(display_score)
	if cur != target_score:
		var diff: float = abs(float(target_score) - float(cur))
		var speed := base_roll_speed + diff * roll_factor
		display_score = move_toward(display_score, float(target_score), speed * delta)

		if score_value_label:
			score_value_label.text = str(int(display_score))


func set_bubble_load_factor(f: float) -> void:
	bubble_load_factor = clamp(f, 0.0, 1.0)


func get_difficulty_factor() -> float:
	return difficulty_multiplier


func increment_score(value: int) -> void:
	score += value
	target_score = score

	if score > ScoreManager.get_best_score():
		ScoreManager.update_score(score)
		if best_score_label:
			best_score_label.text = "%d" % ScoreManager.get_best_score()


# APPELÉ PAR LE SPAWNER : spawn marker + game over
func trigger_game_over_at(pos: Vector3) -> void:
	if game_over:
		return

	_spawn_collision_marker(pos)
	end_game()


func _spawn_collision_marker(pos: Vector3) -> void:
	if collision_marker_scene == null:
		return

	var marker := collision_marker_scene.instantiate() as Node3D
	if marker == null:
		return

	marker.global_position = pos
	get_tree().current_scene.add_child(marker)


func end_game():
	if game_over:
		return

	game_over = true
	allow_restart = false

	# On met en pause (UI reste en PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	Engine.time_scale = 1.0

	# Texte
	if game_over_label:
		game_over_label.text = "Game Over! Click to play again."

	# >>> On montre le CONTROLE et on déclenche le pop
	if game_over_control:
		game_over_control.show()
		if game_over_control.has_method("pop"):
			game_over_control.call("pop")

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


func _format_survival_time(t: float) -> String:
	var seconds := int(floor(t))
	var centiseconds := int(floor((t - float(seconds)) * 100.0))
	return "%02d:%02d" % [seconds, centiseconds]


func _update_difficulty_label() -> void:
	if not difficulty_value_label:
		return

	var fmt := "%0." + str(max(difficulty_decimals, 0)) + "f"
	difficulty_value_label.text = "x " + (fmt % difficulty_multiplier)
