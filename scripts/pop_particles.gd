extends Node3D

@export var particles : GPUParticles3D

func _ready():
	# Démarrer les particules (si nécessaire)
	if particles and not particles.emitting:
		particles.emitting = true

	# Créer un Timer pour supprimer l'explosion après sa durée de vie
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = particles.lifetime  # Durée de vie définie dans l'éditeur
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
