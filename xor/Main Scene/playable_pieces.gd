extends Node2D

@export var new_shape: PackedScene

#reference to child node for timing lock
@onready var lock_timer = $Timer

#Track if the object is being dragged
var dragging = false 

#Current dragged shape
var dragged_shape_id = -1

#Ack signals for shapes
signal go(id)
signal snap(id, mouse_pos)
signal start_snap(grid_pos, id)

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
	if dragging == false and dragged_shape_id == -1:
		dragged_shape_id = id
		dragging = true
		print(str(id) + " can move")
		emit_signal("go", id)
	else:
		print("occupied by " + str(dragged_shape_id) + ", " + str(id) + " cannot move")

#ack function for letting go of piece (requests grid nodes for info)
func _on_piece_free_drag(id, corner_pos) -> void:
	print(dragged_shape_id)
	if dragged_shape_id == id:
		emit_signal("snap", id, corner_pos)

#pipe grid coordinates to shape
func _on_grid_pieces_snap_info(grid_pos: Variant) -> void:
	emit_signal("start_snap", grid_pos, dragged_shape_id)

# Reopen function for next piece picked
func _on_piece_continue_q(id) -> void:
	if dragged_shape_id == id:
		#gives time for snap so piece can't be taken
		lock_timer.start(0.5)

#finishes snap operation after timer and reopens drag
func _on_lock_timer_timeout() -> void:
	dragged_shape_id = -1
	dragging = false 
	lock_timer.stop()

#creates pieces on board from list of list of positions
func _on_solution_create_pieces(shape_pieces: Variant, pos_dic: Variant) -> void:
	for polygon in shape_pieces:
		shape_create(polygon, pos_dic)
