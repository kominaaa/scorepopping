extends Node3D

@export var camera: Camera3D
@export var score_value_label: Label
@export var game_over_label: Label
@export var timer_value_label: Label  # Label pour afficher le temps restant
@export var initial_time: float = 30.0  # Temps initial en secondes avec des décimales
@export var bonus_threshold: int = 500  # Valeur du score à partir de laquelle on gagne du temps
@export var bonus_time_per_threshold: float = 1.0  # Temps bonus ajouté pour chaque seuil atteint

var score: int = 0
var game_over: bool = false
var allow_restart: bool = false
var remaining_time: float = 0.0
var timer: Timer = null

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	
	# Initialisation du score
	score = 0
	if score_value_label:
		score_value_label.text = str(score)
	
	# Cacher le label "Game Over" au début
	if game_over_label:
		game_over_label.hide()
	
	# Initialisation du temps
	remaining_time = initial_time
	if timer_value_label:
		timer_value_label.text = _format_time(remaining_time)
	
	# Démarrer le décompte
	_start_timer()

func increment_score(value: int):
	score += value
	if score_value_label:
		score_value_label.text = str(score)
	
	# Ajoute des secondes au timer si le score dépasse le seuil
	var thresholds_crossed = value / Config.bonus_threshold
	if thresholds_crossed >= 1:
		var bonus_time = thresholds_crossed * Config.bonus_time_per_threshold
		remaining_time += bonus_time
		if timer_value_label:
			timer_value_label.text = _format_time(remaining_time)

func _start_timer():
	timer = Timer.new()
	timer.wait_time = 0.01  # Mise à jour toutes les 0,01 secondes
	timer.one_shot = false  # Timer répété
	timer.connect("timeout", Callable(self, "_update_timer"))
	add_child(timer)
	timer.start()

func _update_timer():
	if game_over:
		return  # Arrête la mise à jour si le jeu est terminé
	
	remaining_time -= 0.01
	if remaining_time <= 0:
		remaining_time = 0
		# Terminer le jeu si le temps est écoulé
		end_game()
	
	if timer_value_label:
		timer_value_label.text = _format_time(remaining_time)

func _format_time(time: float) -> String:
	# Convertit le temps en minutes:secondes:centièmes
	var seconds = int(time)
	var centiseconds = int((time - seconds) * 100)
	return "%02d:%02d" % [seconds, centiseconds]

func end_game():
	game_over = true
	allow_restart = false  # Bloque l'interaction immédiatement
	get_tree().paused = true
	if game_over_label:
		game_over_label.show()
		game_over_label.text = "Game Over! Click to play again."
	# Arrêter le Timer
	if timer:
		timer.stop()
	# Démarre un délai avant d'autoriser le restart
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
