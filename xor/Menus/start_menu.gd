extends CanvasLayer


var gameplay_ref = "res://GamePlay_Scene/Gameplay.tscn"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Area2D.hide()
	$AnimationPlayer.play("Start")
	await $AnimationPlayer.animation_finished
	
	
func _on_start_button_pressed():
	$StartButton.hide()
	change_scene()

func change_scene() -> void:
	$Area2D.show()
	$AnimationPlayer.play("Move_to_game")
	await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file(gameplay_ref)

	
