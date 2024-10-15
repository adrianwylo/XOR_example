extends Node2D

@export var new_shape: PackedScene
#reference to child node for timing lock
@onready var lock_timer = $Timer

#Track if the object is being dragged
var dragging = false 

#Current dragged shape index
var dragged_shape_id = -1
#reference to dragged child
var dragged_child
#List of other children that aren't dragged
var other_children

var test = false

#Ack signals for shapes
signal go(id)
signal snap(id, mouse_pos)
signal start_snap(grid_pos, id)

#sends other shape's vertices and position, and current shape's id
signal check_overlap_A(vertices, shape_position, shape_id)
signal check_overlap_B(vertices, shape_position, shape_id)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Checks for overlaps constantly
func _process(delta: float) -> void:
	if test == true and dragging == true:
		for child in other_children:
			#find current shape values
			#[0] = List of fragments:[(shape, parity, index)]
			#[1] = Position
			#[2] = Identification
			var oc = child.return_polygon_info()
			var dc = dragged_child.return_polygon_info()
			
			#signal calc for oc
			emit_signal("check_overlap_B", dc[0], dc[1], oc[2])
			#signal calc for dc
			emit_signal("check_overlap_A", oc[0], oc[1], dc[2])
		test = false

#create new instance of the playable_shape scene
func shape_create(metadata, map) -> void:
	var shape = new_shape.instantiate()
	shape.pass_metadata(metadata.vertices, metadata.tl, metadata.br)
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
		#populate other_children for collision detection
		dragged_child = get_child(dragged_shape_id)
		var all_children = get_children()
		other_children = []
		for i in range(all_children.size()):
			if i != dragged_shape_id and i != 0:
				other_children.append(all_children[i])
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
		lock_timer.start(0.25)

#finishes snap operation after timer and reopens drag
func _on_lock_timer_timeout() -> void:
	dragged_shape_id = -1
	dragging = false 
	lock_timer.stop()

#creates pieces on board from list of list of positions
func _on_solution_create_pieces(shape_pieces: Variant, pos_dic: Variant) -> void:
	for polygon in shape_pieces:
		shape_create(polygon, pos_dic)
