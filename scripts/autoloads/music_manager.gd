extends Node

@export var music_bus_name: StringName = &"Music"
@export var stream: AudioStream
@export var base_volume_db: float = -10.0

# Référence : doit matcher ton min_timescale (ex: 0.50)
@export_range(0.1, 1.0, 0.01) var min_timescale_ref: float = 0.50

# --- Effets "arcade" pilotés par le slow (sans pitch)
@export var lowpass_effect_index: int = 0
@export_range(500.0, 20000.0, 50.0) var cutoff_normal_hz: float = 18000.0
@export_range(500.0, 20000.0, 50.0) var cutoff_slow_hz: float = 2200.0

@export var enable_pump: bool = true
@export var pump_db_at_max_slow: float = -6.0   # baisse max (arcade “impact”)
@export var smooth: float = 8.0

# (optionnel) Distortion très légère quand slow fort
@export var enable_distortion: bool = false
@export var distortion_effect_index: int = 1
@export_range(0.0, 1.0, 0.01) var distortion_drive_at_max_slow: float = 0.08

var audio_player: AudioStreamPlayer
var bus_idx: int = -1
var lp_fx: AudioEffectLowPassFilter = null
var dist_fx: AudioEffectDistortion = null

var cutoff_current: float = 18000.0
var pump_current_db: float = 0.0
var drive_current: float = 0.0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process(true)

	# --- Player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = String(music_bus_name)
	add_child(audio_player)

	if stream == null:
		stream = preload("res://audio/music_loop.mp3")

	audio_player.stream = stream
	audio_player.volume_db = base_volume_db
	audio_player.play()
	audio_player.finished.connect(_on_music_finished)


	# --- Bus & effects
	bus_idx = AudioServer.get_bus_index(String(music_bus_name))
	if bus_idx < 0:
		push_warning("Bus 'Music' introuvable. Vérifie Audio > Bus Layout.")
		return

	if AudioServer.get_bus_effect_count(bus_idx) > lowpass_effect_index:
		lp_fx = AudioServer.get_bus_effect(bus_idx, lowpass_effect_index) as AudioEffectLowPassFilter
	else:
		push_warning("LowPass manquant sur le bus Music (ou mauvais index).")

	if enable_distortion and AudioServer.get_bus_effect_count(bus_idx) > distortion_effect_index:
		dist_fx = AudioServer.get_bus_effect(bus_idx, distortion_effect_index) as AudioEffectDistortion
	elif enable_distortion:
		push_warning("Distortion manquante sur le bus Music (ou mauvais index).")


func _process(delta: float) -> void:
	if bus_idx < 0:
		return

	var slow_factor: float = _get_slow_factor() # 0..1

	# --- Low-pass (arcade : le son se “resserre”)
	var target_cutoff: float = lerp(cutoff_normal_hz, cutoff_slow_hz, slow_factor)
	cutoff_current = lerp(cutoff_current, target_cutoff, 1.0 - exp(-smooth * delta))
	if lp_fx != null:
		lp_fx.cutoff_hz = cutoff_current

	# --- Pump volume (petite compression arcade)
	if enable_pump:
		var target_pump: float = lerp(0.0, pump_db_at_max_slow, slow_factor) # négatif
		pump_current_db = lerp(pump_current_db, target_pump, 1.0 - exp(-smooth * delta))
		AudioServer.set_bus_volume_db(bus_idx, base_volume_db + pump_current_db)

	# --- Distortion légère (optionnel)
	if enable_distortion and dist_fx != null:
		var target_drive: float = lerp(0.0, distortion_drive_at_max_slow, slow_factor)
		drive_current = lerp(drive_current, target_drive, 1.0 - exp(-smooth * delta))
		# Selon version de Godot, la propriété peut s'appeler drive/amount.
		# Essaie l'une, sinon commente.
		dist_fx.drive = drive_current


func _get_slow_factor() -> float:
	if min_timescale_ref >= 1.0:
		return 0.0
	return clamp((1.0 - Engine.time_scale) / (1.0 - min_timescale_ref), 0.0, 1.0)

func _on_music_finished() -> void:
	audio_player.play()
