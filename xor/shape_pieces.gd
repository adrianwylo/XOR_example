extends Node2D

@export var new_shape: PackedScene



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

	

	


		
	

func shape_create(vertice_list) -> void:
	# Create a new instance of the node scene.
	var shape = new_shape.instantiate()
	shape.create_2D(vertice_list)
	# Spawn the node into Main.
	add_child(shape)	
