extends MeshInstance3D

@export var scale_min: float = 0.27
@export var scale_max: float = 0.3
@export var pulse_speed: float = 1.0

var _current_scale_factor: float = 1.0
var _increasing: bool = true

func _process(delta: float):
	if _increasing:
		_current_scale_factor = lerp(_current_scale_factor, scale_max, delta * pulse_speed)
		if _current_scale_factor >= scale_max - 0.01:
			_increasing = false
	else:
		_current_scale_factor = lerp(_current_scale_factor, scale_min, delta * pulse_speed)
		if _current_scale_factor <= scale_min + 0.01:
			_increasing = true
	
	scale = Vector3.ONE * _current_scale_factor
