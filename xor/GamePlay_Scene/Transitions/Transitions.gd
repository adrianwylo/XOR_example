extends CanvasLayer

@export var pause_menu: PackedScene

var clear: bool

signal pause()

func play_entrance() -> void:
	clear = false
	$Pause_Transition.hide()
	$Pause/CollisionPolygon2D.hide()
	$AnimationPlayer.play("Appear")
	await $AnimationPlayer.animation_finished
	$Pause/CollisionPolygon2D.show()
	clear = true
	
func reset_all() -> void:
	print("resetting")
	$Pause.show()
	$AnimationPlayer2.play("RESET")
	$AnimationPlayer.play("RESET")
	await $AnimationPlayer.animation_finished
	await $AnimationPlayer2.animation_finished
	

func _on_pause_mouse_entered() -> void:
	if clear:
		$AnimationPlayer.play("Pause hover")


func _on_pause_mouse_exited() -> void:
	if clear:
		$AnimationPlayer.play_backwards("Pause hover")


func _on_pause_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed and clear:
		$Pause_Transition.show()
		$AnimationPlayer2.play("Go to pause")
		await $AnimationPlayer2.animation_finished
		emit_signal("pause")
		$Pause.hide()
		$Pause_Transition.hide()
