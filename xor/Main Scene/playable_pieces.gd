extends Node2D

@export var new_shape: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#create new instance of the playable_shape scene
func shape_create(metadata) -> void:
	var shape = new_shape.instantiate()
	shape.pass_vertices(metadata.vertices)
	shape.pass_position(metadata.tl, metadata.br)
	add_child(shape)

#creates pieces on board from list of list of positions
func _on_solution_create_pieces(shape_pieces: Variant) -> void:
	for polygon in shape_pieces:
		#remember the format is polygon[0] is positional displacement
		shape_create(polygon)
		
