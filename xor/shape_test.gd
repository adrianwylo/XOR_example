extends Area2D
signal click

# How fast piece moves when snapping
@export var clip_speed = 400 
var screen_size # Size of the game window.
var dragging = false # To track if the object is being dragged
var drag_offset = Vector2() # Offset between mouse position and the object when dragging


# Define the polygon points


# Causes entry
func start(pos):
	position = pos
	show()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

#creates nodes for shape
func create_2D(vertices) -> void:
	#Create Polygon2D child
	var polygon2d = Polygon2D.new()
	polygon2d.polygon = vertices
	add_child(polygon2d)  # Add Polygon2D to the parent node

	# Create the CollisionPolygon2D child
	var collision_polygon = CollisionPolygon2D.new()
	collision_polygon.polygon = vertices
	add_child(collision_polygon)  # Add CollisionPolygon2D to the parent node

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		emit_signal("click")
		#currently dragging
		if dragging == true:
			dragging = false
		#not currently dragging
		else:
			if Geometry2D.is_point_in_polygon(to_local(event.position), $CollisionPolygon2D.polygon):
				dragging = true
				drag_offset = position - event.position
			


#determines position
func _process(delta: float) -> void:
	if dragging:
		position = get_global_mouse_position() + drag_offset
		position = position.clamp(Vector2.ZERO, screen_size) # Ensure object stays within screen bounds



	
