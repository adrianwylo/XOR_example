extends CanvasLayer

var new_scene

func change_scene(target: String) -> void:
	new_scene = target
	$AnimationPlayer.play("dissolve")
	await $AnimationPlayer.animation_finished
	
	get_tree().change_scene_to_file(target)
	$AnimationPlayer.play('dissolve_back')
	
