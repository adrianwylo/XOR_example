extends StaticBody2D

# Reference to the CollisionShape2D node
@onready var collision_shape = $CollisionPolygon2D
# Reference to the Sprite node
@onready var sprite = $Sprite2D 


#size scale determined by the main scene
var node_scale

#passing in size scale before initializing child
func initialize_size_scale(size_scale: float) -> void:
	node_scale = size_scale

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	collision_shape.scale = collision_shape.scale * node_scale
	sprite.scale = sprite.scale * node_scale

func _process(delta: float) -> void:
	pass
