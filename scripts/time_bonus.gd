extends Control

@export var animation_player : AnimationPlayer
@export var popup_label : Label

func _ready():
	animation_player.connect("animation_finished",Callable(self, "_on_AnimationPlayer_animation_finished"))

func show_time_bonus(time_bonus: int):
	popup_label.text = "+" + str(time_bonus) + "s"
	
	animation_player.play("fade_out")

func _on_AnimationPlayer_animation_finished(anim_name):
	queue_free()
