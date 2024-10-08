extends Area2D

@export var speed = 400 # How fast the player will move (pixels/sec).
var screen_size # Size of the game window.
var dragging = false # To track if the object is being dragged
var drag_offset = Vector2() # Offset between mouse position and the object when dragging

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			if Geometry2D.is_point_in_polygon($CollisionShape2D.to_local())
				dragging = true
				drag_offset = position - event.position

#determines position
func _process(delta: float) -> void:
	if dragging:
		position = get_global_mouse_position() + drag_offset
		position = position.clamp(Vector2.ZERO, screen_size) # Ensure object stays within screen bounds


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#var velocity = Vector2.ZERO # The player's movement vector.
	#if Input.is_action_pressed("move_right"):
		#velocity.x += 1
	#if Input.is_action_pressed("move_left"):
		#velocity.x -= 1
	#if Input.is_action_pressed("move_down"):
		#velocity.y += 1
	#if Input.is_action_pressed("move_up"):
		#velocity.y -= 1
	#
	#if velocity.length() > 0:
		#velocity = velocity.normalized() * speed
		#
	#position += velocity * delta
	#position = position.clamp(Vector2.ZERO, screen_size)
		

func start(pos):
	position = pos
	show()
	$CollisionShape2D.disabled = false
