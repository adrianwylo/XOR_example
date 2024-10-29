extends CanvasLayer


var start_menu = "res://Menus/start_menu.tscn"
var gameplay = "res://GamePlay_Scene/Gameplay.tscn"
signal resume()
signal menu_started()


func start_pause() -> void:
	$ColorRect.show()
	$AnimationPlayer.play("Buttons Appear")
	await $AnimationPlayer.animation_finished
	emit_signal("menu_started")


func _on_restart_pressed() -> void:
	$AnimationPlayer.play("NewGame")
	await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file(gameplay)


func _on_continue_pressed() -> void:
	get_parent().show()
	$AnimationPlayer.play("Game")
	emit_signal("resume")
	await $AnimationPlayer.animation_finished
	hide()
	$AnimationPlayer.play("RESET")
	await $AnimationPlayer.animation_finished
	

func _on_exit_pressed() -> void:
	get_parent().hide()
	$AnimationPlayer.play("Exit")
	await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file(start_menu)
	
