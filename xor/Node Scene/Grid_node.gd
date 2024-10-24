extends StaticBody2D

# Reference to the CollisionShape2D node
@onready var collision_shape = $CollisionPolygon2D
# Reference to the Sprite node
@onready var sprite = $Sprite2D 

signal snap_found(grid_coor)

#size scale determined by the main scene
var node_scale
#length of one grid cell
var len_of_cell
#coordinates for collision shape
var collision_array = []
#grid coordinate of node
var grid_location

#passing in size scale and length of cell
func initialize_data(size_scale: float, length: float, grid_coordinate: Vector2i, is_edge: bool) -> void:
	node_scale = size_scale
	len_of_cell = length
	var half_len = len_of_cell/2
	grid_location = grid_coordinate
	if !is_edge:
		collision_array =  [Vector2i(-half_len,-half_len),
							Vector2i(half_len,-half_len),
							Vector2i(half_len,half_len),
							Vector2i(-half_len,half_len)]

func pos_found_in_node(corner_pos) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(corner_pos), collision_shape.polygon)

func ret_grid_location() -> Vector2i:
	return grid_location

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	collision_shape.polygon = PackedVector2Array(collision_array)
	sprite.scale = sprite.scale * node_scale
