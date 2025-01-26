extends Node3D

@export var camera: Camera3D
@export var score_value_label: Label
@export var best_score_label: Label
@export var game_over_label: Label
@export var timer_value_label: Label
@export var initial_time: float = 45.0

var score: int = 0
var game_over: bool = false
var allow_restart: bool = false
var remaining_time: float = 0.0
var timer: Timer = null

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	
	score = 0
	if score_value_label:
		score_value_label.text = str(score)
	
	if best_score_label:
		best_score_label.text = "%d" % ScoreManager.get_best_score()
	
	if game_over_label:
		game_over_label.hide()
	
	remaining_time = initial_time
	if timer_value_label:
		timer_value_label.text = _format_time(remaining_time)
	
	_start_timer()

func increment_score(value: int):
	score += value
	if score_value_label:
		score_value_label.text = str(score)
	
	if score > ScoreManager.get_best_score():
		ScoreManager.update_score(score)
		if best_score_label:
			best_score_label.text = "Best: %d" % ScoreManager.get_best_score()
	
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
	
	remaining_time -= 0.01
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
