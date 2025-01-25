extends Node

var audio_player: AudioStreamPlayer

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var audio_stream = preload("res://sounds/music_loop.mp3")
	if audio_stream is AudioStream:
		audio_stream.loop = true
	
	audio_player.stream = audio_stream
	
	audio_player.volume_db = -10
	
	audio_player.play()

func set_volume(volume_db: float):
	audio_player.volume_db = volume_db
