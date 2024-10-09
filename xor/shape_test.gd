extends Area2D

@export var speed = 400 # How fast the player will move (pixels/sec).
var screen_size # Size of the game window.
var dragging = false # To track if the object is being dragged
var drag_offset = Vector2() # Offset between mouse position and the object when dragging

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		if dragging == true:
			dragging = false
		else:
			if Geometry2D.is_point_in_polygon(to_local(event.position), $CollisionPolygon2D.polygon):
				dragging = true
				drag_offset = position - event.position
			

#determines position
func _process(delta: float) -> void:
	if dragging:
		position = get_global_mouse_position() + drag_offset
		position = position.clamp(Vector2.ZERO, screen_size) # Ensure object stays within screen bounds


func start(pos):
	position = pos
	show()
	
