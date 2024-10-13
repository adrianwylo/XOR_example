extends Area2D
signal click

# Reference to the CollisionPolygon2D node
@onready var col2d = $CollisionPolygon2D
 # Reference to the Polygon2D node
@onready var pol2d = $Polygon2D 

# How fast piece moves when snapping
@export var clip_speed = 400 

# Size of the game window
var screen_size 

# To track if the object is being dragged
var dragging = false 

# Offset between mouse position and the object when dragging
var drag_offset = Vector2() 

#packaged vertices for polygon definition
var packed_vertices

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pol2d.polygon = packed_vertices
	col2d.polygon = packed_vertices
	screen_size = get_viewport_rect().size

#saves in position vectors for when ready
func pass_vertices(vertices) -> void:
	print(vertices)
	packed_vertices = PackedVector2Array(vertices)
	print("created Packed_Vertex")

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
		print(position)
		position = position.clamp(Vector2.ZERO, screen_size) # Ensure object stays within screen bounds



	
