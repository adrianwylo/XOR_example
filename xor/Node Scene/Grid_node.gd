extends StaticBody2D

# Reference to the CollisionShape2D node
@onready var collision_shape = $CollisionPolygon2D
# Reference to the Sprite node
@onready var sprite = $Sprite2D 


#size scale determined by the main scene
var node_scale
#length of one grid cell
var len_of_cell

#passing in size scale and length of cell
func initialize_data(size_scale: float, length: float) -> void:
	node_scale = size_scale
	len_of_cell = length

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var half_len = len_of_cell/2
	collision_shape.polygon = PackedVector2Array([Vector2(-half_len,-half_len),
												  Vector2(half_len,-half_len),
												  Vector2(half_len,half_len),
												  Vector2(-half_len,half_len),
												  Vector2(-half_len,-half_len)])
	print(collision_shape.polygon)
	sprite.scale = sprite.scale * node_scale

func _process(delta: float) -> void:
	pass
