extends Node3D

@export var scale_rate: float = 1.0
@export var max_scale: float = 20.0
@export var min_value: int = 1
@export var max_value: int = 999
@export var gradient_texture: GradientTexture1D
@export var label_3d: Label3D
@export var bubble_mesh: MeshInstance3D
@export var explosion_scene: PackedScene
@export var static_body: StaticBody3D  # Le StaticBody3D pour les clics

signal bubble_destroyed(bubble: Node3D)  # Signal pour notifier le spawner

func _ready():
	scale = Vector3(1, 1, 1)
	set_process(true)

	# Connecter le signal "clicked" depuis le StaticBody3D
	if static_body:
		static_body.clicked.connect(Callable(self, "_on_bubble_clicked"))

func _process(delta):
	if scale.x < max_scale:
		var new_scale = scale + Vector3(scale_rate, scale_rate, scale_rate) * delta
		if new_scale.x > max_scale:
			new_scale = Vector3(max_scale, max_scale, max_scale)
		scale = new_scale
		_update_label_and_colors()
	else:
		print("Reached max scale. Stopping process.")
		set_process(false)

func _update_label_and_colors():
	var progress = (scale.x - 1.0) / (max_scale - 1.0)
	var value = lerp(float(min_value), float(max_value), progress)

	label_3d.text = str(round(value))
	
	var color = gradient_texture.gradient.get_color(progress)
	label_3d.modulate = color

	if bubble_mesh.mesh is SphereMesh:
		var material = bubble_mesh.mesh.material
		if material is ShaderMaterial:
			material.set_shader_parameter("fresnel_color", color)

func _on_bubble_clicked(impact_pos: Vector3) -> void:
	# Instancier l'explosion
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_transform.origin = impact_pos
		get_tree().current_scene.add_child(explosion)

	# Déconnecter le signal pour éviter des erreurs
	if static_body and static_body.is_connected("clicked", Callable(self, "_on_bubble_clicked")):
		static_body.clicked.disconnect(Callable(self, "_on_bubble_clicked"))

	# Émettre un signal pour informer le spawner que la bulle est supprimée
	emit_signal("bubble_destroyed", self)

	# Supprimer la bulle
	queue_free()
