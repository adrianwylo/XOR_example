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
#A indicates the shape with the shape_id is on top
#B indicates the shape with the shape_id is on bot
signal check_overlap_A(other_vertices, other_shape_position, other_shape_id, shape_id)
signal check_overlap_B(other_vertices, other_shape_position, other_shape_id, shape_id)

#for testing purposes
@onready var timer = $testTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Start the timer with 10 seconds interval for testing purposes
	timer.wait_time = 5
	timer.start()

func _on_test_timer_timeout() -> void:
	print("\nbeen 5 sec")
	if dragging == true:
		for other_id in other_children:
			#the format of return_polygon_info():
			#[0] = List of fragments: references to overlap instance nodes
			#[1] = Position
			#[2] = Identification # (child index)
			var oc = other_children[other_id].return_polygon_info()
			var dc = dragged_child.return_polygon_info()
			
			assert(other_id == oc[2], "mismatch in id's for oc")
			assert(dragged_shape_id == dc[2], "mismatch in id's for dc")
			assert(dc[2] != oc[2],"these pieces have no hierarchy")
			
			#decides what to call between two shapes based on indexing
			if dc[2] > oc[2]:
				print("dragged is on top")
				emit_signal("check_overlap_A", oc[0], oc[1], oc[2], dc[2], )
				emit_signal("check_overlap_B", dc[0], dc[1], dc[2], oc[2])
			else:
				print("dragged is on bot")
				emit_signal("check_overlap_A", dc[0], dc[1], dc[2], oc[2])
				emit_signal("check_overlap_B", oc[0], oc[1], oc[2], dc[2])

# Calculates overlaps constantly and changes views
func _process(delta: float) -> void:
	return
	if dragging == true:
		for other_id in other_children:
			#the format of return_polygon_info():
			#[0] = List of fragments: references to overlap instance nodes
			#[1] = Position
			#[2] = Identification # (child index)
			var oc = other_children[other_id].return_polygon_info()
			var dc = dragged_child.return_polygon_info()
			assert(other_id == oc[2], "mismatch in id's for oc")
			assert(dragged_shape_id == dc[2], "mismatch in id's for dc")
			assert(dc[2] != oc[2],"these pieces have no hierarchy")
			
			#decides what to call between two shapes based on indexing
			if dc[2] > oc[2]:
				emit_signal("check_overlap_A", oc[0], oc[1], oc[2], dc[2], )
				emit_signal("check_overlap_B", dc[0], dc[1], dc[1], oc[2])
			else:
				emit_signal("check_overlap_A", dc[0], dc[1], dc[1], oc[2])
				emit_signal("check_overlap_B", oc[0], oc[1], oc[2], dc[2])

#create new instance of the playable_shape scene
func shape_create(metadata, map) -> void:
	var shape = new_shape.instantiate()
	shape.pass_metadata(metadata.vertices, metadata.tl, metadata.br)
	shape.pass_map(map)
	shape.connect("free_drag", _on_piece_free_drag)
	shape.connect("occupy_drag", _on_piece_occupy_drag)
	shape.connect("continue_q", _on_piece_continue_q)
	shape.connect("overlapping", _on_piece_overlap)
	shape.connect("not_overlapping", _on_piece_no_overlap)
	add_child(shape)

#signal from child that theres a collision
func _on_piece_overlap(other_id: int, id: int):
	if dragged_shape_id == id:
		print(str(id) + " entered " + str(other_id))
		if not other_children.has(other_id):
			other_children[other_id] = get_child(other_id)
			print(str(other_id) + " added to other_children")
	
# Signal from child indicating there's no more collision
func _on_piece_no_overlap(other_id: int, id: int):
	if dragged_shape_id == id:
		print(str(id) + " exited " + str(other_id))
		var child = get_child(id)
		# Signal from child indicating there's no more collision
		# Check if the other_id exists in the dictionary
		if other_children.has(other_id):
			other_children.erase(other_id)
			print("Child with other_id ", other_id, " removed from other_children")
		else:
			print("Error: Child with other_id ", other_id, " not found in other_children")


#ack function picking a piece
func _on_piece_occupy_drag(id) -> void:
	if dragging == false and dragged_shape_id == -1:
		#id's are the same as indexes because they don't change
		dragged_shape_id = id
		dragged_child = get_child(dragged_shape_id)
		
		#populate other_children for collision detection
		#redeclaration clears it 
		other_children = {}
		#turn on flag for going
		dragging = true
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
