extends Node3D

@export var particles: GPUParticles3D
@export var pop_sound: AudioStreamPlayer

signal progress_updated(progress: float)

func set_progress(progress: float) -> void:
	var shape_scale = lerp(0.01, 0.5, progress)
	var particle_amount = int(lerp(50, 500, progress))
	var pitch_scale = lerp(2.0, 0.8, progress)

	# Ajuster les particules
	if particles:
		particles.amount = particle_amount

		if particles.process_material is ParticleProcessMaterial:
			var material = particles.process_material as ParticleProcessMaterial
			material.emission_shape_scale = Vector3(shape_scale, shape_scale, shape_scale)

	if pop_sound:
		pop_sound.pitch_scale = pitch_scale
	emit_signal("progress_updated", progress)

func _on_progress_updated(progress: float) -> void:
	pass

func _ready() -> void:
	self.progress_updated.connect(Callable(self, "_on_progress_updated"))

	if particles and not particles.emitting:
		particles.emitting = true

	if pop_sound:
		pop_sound.volume_db = randf_range(-5.0, 0.0)
		pop_sound.play()

	if particles:
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = particles.lifetime
		timer.timeout.connect(queue_free)
		add_child(timer)
		timer.start()
