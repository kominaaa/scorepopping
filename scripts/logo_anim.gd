extends MeshInstance3D

@export var scale_min: float = 0.27  # Échelle minimale
@export var scale_max: float = 0.3  # Échelle maximale
@export var pulse_speed: float = 1.0  # Vitesse de pulsation

var _current_scale_factor: float = 1.0
var _increasing: bool = true

func _process(delta: float):
	# Détermine si on augmente ou diminue la taille
	if _increasing:
		_current_scale_factor = lerp(_current_scale_factor, scale_max, delta * pulse_speed)
		if _current_scale_factor >= scale_max - 0.01:  # Tolérance pour changer de direction
			_increasing = false
	else:
		_current_scale_factor = lerp(_current_scale_factor, scale_min, delta * pulse_speed)
		if _current_scale_factor <= scale_min + 0.01:  # Tolérance pour changer de direction
			_increasing = true
	
	# Applique l'échelle uniformément
	scale = Vector3.ONE * _current_scale_factor
