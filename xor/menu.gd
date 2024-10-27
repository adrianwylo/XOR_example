extends CanvasLayer

# Notifies `Main` node that the button has been pressed
signal start_game(intr)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_start_button_pressed():
	print('here')
	$StartButton.hide()
	emit_signal("start_game", 3)
	
