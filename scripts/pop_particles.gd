extends Node3D

@export var particles: GPUParticles3D

func set_progress(progress: float) -> void:
	# Calculer les valeurs interpolées
	var shape_scale = lerp(0.01, 0.5, progress)  # Scale des axes
	var particle_amount = int(lerp(50, 500, progress))  # Nombre de particules

	# Ajuster la quantité de particules directement sur le GPUParticles3D
	if particles:
		particles.amount = particle_amount
		print("Particle amount set to:", particle_amount)

		# Vérifier si le matériau est un ParticlesProcessMaterial
		if particles.process_material is ParticleProcessMaterial:
			var material = particles.process_material as ParticleProcessMaterial

			# Ajuster l'échelle d'émission
			material.emission_shape_scale = Vector3(shape_scale, shape_scale, shape_scale)
			print("Emission shape scale set to:", material.emission_shape_scale)
		else:
			print("process_material is not a ParticlesProcessMaterial.")
	else:
		print("Particles not set or invalid.")

func _ready():
	# Démarrer les particules
	if particles and not particles.emitting:
		particles.emitting = true

	# Créer un Timer pour supprimer l'explosion après la durée de vie des particules
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = particles.lifetime  # Durée de vie définie dans l'éditeur
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
