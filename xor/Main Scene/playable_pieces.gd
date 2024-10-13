extends Node2D

@export var new_shape: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func shape_create(vertice_list) -> void:
	#create new instance of the playable_shape scene
	var shape = new_shape.instantiate()
	shape.position = Vector2.ZERO
	shape.pass_vertices(vertice_list)
	add_child(shape)

#creates pieces on board from list of list of positions
func _on_solution_create_pieces(shape_pieces: Variant) -> void:
	print("starting to make pieces")
	for polygon in shape_pieces:
		shape_create(polygon)
		
