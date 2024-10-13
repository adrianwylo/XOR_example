extends Node2D

@export var new_shape: PackedScene

#Track if the object is being dragged
var dragging = false 

#Current dragged shape
var dragged_shape_id

#Ack signals for shapes
signal go(id)
signal stop(id)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#create new instance of the playable_shape scene
func shape_create(metadata, map) -> void:
	var shape = new_shape.instantiate()
	shape.pass_vertices(metadata.vertices)
	shape.pass_metadata(metadata.tl, metadata.br, metadata.id)
	shape.pass_map(map)
	shape.connect("free_drag", _on_piece_free_drag)
	shape.connect("occupy_drag", _on_piece_occupy_drag)
	shape.connect("continue_q", _on_piece_continue_q)
	add_child(shape)

#ack function picking a piece
func _on_piece_occupy_drag(id) -> void:
	if dragging == false:
		dragged_shape_id = id
		dragging = true
		print(str(id) + " can move")
		emit_signal("go", id)
	else:
		print("occupied by " + str(dragged_shape_id) + ", " + str(id) + " cannot move")

#ack function for letting go of piece
func _on_piece_free_drag(id) -> void:
	if dragged_shape_id == id:
		print(str(id) + " can stop")
		emit_signal("stop", id)

#reopen function for next piece picked
func _on_piece_continue_q(id) -> void:
	if dragged_shape_id == id:
		dragged_shape_id = -1
		dragging = false

#creates pieces on board from list of list of positions
func _on_solution_create_pieces(shape_pieces: Variant, pos_dic: Variant) -> void:
	for polygon in shape_pieces:
		shape_create(polygon, pos_dic)
