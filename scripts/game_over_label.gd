extends Label

func _ready():
	set_process_unhandled_input(true)
	process_mode = PROCESS_MODE_ALWAYS
