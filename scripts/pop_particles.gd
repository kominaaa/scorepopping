extends Node3D

@export var particles: GPUParticles3D
@export var pop_sound: AudioStreamPlayer

signal progress_updated(progress: float)

func set_progress(progress: float) -> void:
	# Calculer les valeurs interpolées
	var shape_scale = lerp(0.01, 0.5, progress)  # Taille des axes des particules
	var particle_amount = int(lerp(50, 500, progress))  # Nombre de particules
	var pitch_scale = lerp(2.0, 0.5, progress)  # Pitch du son
	print("Progress:", progress)

	# Ajuster les particules
	if particles:
		particles.amount = particle_amount
		print("Particle amount set to:", particle_amount)

		# Vérifier si le matériau est un ParticleProcessMaterial
		if particles.process_material is ParticleProcessMaterial:
			var material = particles.process_material as ParticleProcessMaterial
			material.emission_shape_scale = Vector3(shape_scale, shape_scale, shape_scale)
			print("Emission shape scale set to:", material.emission_shape_scale)
		else:
			print("process_material is not a ParticleProcessMaterial.")
	else:
		print("Particles not set or invalid.")

	# Ajuster le pitch du son
	if pop_sound:
		pop_sound.pitch_scale = pitch_scale
		print("Sound pitch set to:", pitch_scale)
	else:
		print("Pop sound not set or invalid.")

	# Émettre un signal pour notifier que le progrès a changé (facultatif)
	emit_signal("progress_updated", progress)

func _on_progress_updated(progress: float) -> void:
	print("Progress updated signal received:", progress)
	# Ajoutez ici des comportements supplémentaires si nécessaire

func _ready():
	# Connecter le signal interne si tu en as besoin
	self.progress_updated.connect(Callable(self, "_on_progress_updated"))

	# Démarrer les particules
	if particles and not particles.emitting:
		particles.emitting = true

	# Jouer le son de pop
	if pop_sound:
		pop_sound.play()

	# Créer un Timer pour supprimer ce Node après la durée de vie des particules
	if particles:
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = particles.lifetime  # Durée de vie définie dans l'éditeur
		timer.timeout.connect(queue_free)
		add_child(timer)
		timer.start()
