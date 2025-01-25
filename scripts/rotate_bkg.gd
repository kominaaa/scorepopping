extends MeshInstance3D

# Variables pour contrôler la vitesse de rotation aléatoire sur les deux axes
@export var rotation_speed_x: float = 1.0
@export var rotation_speed_y: float = 1.0

# Variable pour la vitesse de montée sur l'axe Z global
@export var move_speed_y: float = 0.05

# Durée avant que l'objet devienne "queue free"
@export var queue_free_delay: float = 30.0

# Variables pour stocker les vitesses de rotation aléatoires
var random_speed_x: float
var random_speed_y: float

# Temps écoulé
var time_elapsed: float = 0.0

func _ready():
	# Génère des vitesses de rotation aléatoires
	randomize()
	random_speed_x = randf_range(-rotation_speed_x, rotation_speed_x)
	random_speed_y = randf_range(-rotation_speed_y, rotation_speed_y)

	# Donne une rotation initiale aléatoire à l'objet
	rotation_degrees.x = randf_range(0, 360)
	rotation_degrees.y = randf_range(0, 360)

func _process(delta: float):
	# Applique les rotations sur les axes X et Y
	rotation_degrees.x += random_speed_x * delta
	rotation_degrees.y += random_speed_y * delta

	# Monte sur l'axe Z global
	global_transform.origin.y += move_speed_y * delta

	# Met à jour le temps écoulé
	time_elapsed += delta

	# Vérifie si la durée est atteinte pour rendre l'objet queue free
	if time_elapsed >= queue_free_delay:
		queue_free()
