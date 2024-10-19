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

#an array of an array of indexes representing what has been overlapped
#note that if A and B are connected, and B and C are connected
#they are all found in the dictionary, but their list of connections won't list
#anything they aren't connected to
var overlap_groups
class overlap:
	#shapes involved in calculation
	var indexes_involved: Dictionary
	#shape chosen to display overlap
	var display_index: int
	
	func _init(indexes: Array) -> void:
		indexes_involved = {}
		
		#makes a dictionary that lists involved shapes and their collsions
		for index in indexes:
			var collisions = []
			for collided_index in indexes:
				if collided_index != index:
					collisions.append(collided_index)
			indexes_involved[str(index)] = collisions
		
		#recalc display_index
		display_index = int(indexes_involved.keys()[0])
		for key in indexes_involved.keys():
			var int_key = int(key)
			if int_key > int(display_index):
				display_index = int_key

	# Merge the current instance with another Overlap instance
	func merge_with(other: overlap) -> void:
		var cur_display_index = self.display_index
		for other_index in other.indexes_involved:
			#modify own entry
			if self.indexes_involved.has(other_index):
				for collision in other_index.indexes_involved[other_index]:
					if collision not in self.indexes_involved[other_index]:
						self.indexes_involved[other_index].append(collision)
			#create new entry that is a transfer of other account
			else:
				if int(other_index) > cur_display_index:
					self.display_index = int(other_index)
				self.indexes_involved[other_index] = other_index.indexes_involved[other_index]
	
	#check if id is in overlap
	func id_is_in_list(id: int) -> bool:
		return indexes_involved.has(str(id))
	
	#add a specific collision to overlap
	func add_id_to_list(new_id_1: int, new_id_2: int) -> void:
		var cur_display_index = self.display_index
		var found_1 = str(new_id_1) in indexes_involved.keys()
		var found_2 = str(new_id_2) in indexes_involved.keys()
		if found_1 and found_2:
			if new_id_2 not in indexes_involved[str(new_id_1)]:
				indexes_involved[str(new_id_1)].append(new_id_2)
			if new_id_1 not in indexes_involved[str(new_id_2)]:
				indexes_involved[str(new_id_2)].append(new_id_1)
		elif found_1:
			if new_id_2 not in indexes_involved[str(new_id_1)]:
				indexes_involved[str(new_id_1)].append(new_id_2)
			indexes_involved[str(new_id_2)] = [new_id_1]
			if new_id_2 > cur_display_index:
				display_index = new_id_2
		elif found_2:
			if new_id_1 not in indexes_involved[str(new_id_2)]:
				indexes_involved[str(new_id_2)].append(new_id_1)
			indexes_involved[str(new_id_1)] = [new_id_2]
			if new_id_1 > cur_display_index:
				display_index = new_id_1
		else:
			assert(found_1 or found_2, "can't add a connection if no id's are alr there")
	
	
	#sever a specific collision from overlap
	func sub_id_from_list(new_id_1: int, new_id_2: int) -> void:
		var cur_display_index = self.display_index
		var must_reevaluate = false
		var found_1 = str(new_id_1) in indexes_involved.keys()
		var found_2 = str(new_id_2) in indexes_involved.keys()
		assert(found_1 and found_2, "can't remove a connection both id's are absent there")
		#remove connections from 1
		if new_id_2 in indexes_involved[str(new_id_1)]:
			indexes_involved[str(new_id_1)].erase(new_id_2)
			if indexes_involved[str(new_id_1)].is_empty():
				indexes_involved.erase(str(new_id_1))
				if cur_display_index == new_id_2:
					must_reevaluate = true
		#remove connections from 2
		if new_id_1 in indexes_involved[str(new_id_2)]:
			indexes_involved[str(new_id_2)].erase(new_id_1)
			if indexes_involved[str(new_id_2)].is_empty():
				indexes_involved.erase(str(new_id_2))
				if cur_display_index == new_id_1:
					must_reevaluate = true
		
		if must_reevaluate:
			#recalc display_index
			display_index = int(indexes_involved.keys()[0])
			for key in indexes_involved.keys():
				var int_key = int(key)
				if int_key > int(display_index):
					display_index = int_key
		
		
#Ack signals for shapes
signal go(id)
signal snap(id, mouse_pos)
signal start_snap(grid_pos, id)

#for testing purposes
@onready var timer = $testTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Start the timer with 10 seconds interval for testing purposes
	timer.wait_time = 5
	timer.start()
	overlap_groups = {}

func _on_test_timer_timeout() -> void:
	pass
	

# Calculates overlaps constantly and changes views
func _process(delta: float) -> void:
	return
	

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
	var id_group_key = ""
	var other_id_group_key = ""
	
	# Find group keys for both ids
	for key in overlap_groups:
		if overlap_groups[key].id_is_in_list(other_id):
			other_id_group_key = key
		if overlap_groups[key].id_is_in_list(id):
			id_group_key = key

	# Case 1: Neither ID is in any group, create a new group
	if id_group_key == "" and other_id_group_key == "":
		var key = ""
		while overlap_groups.has(key) or key == "":
			key = str(randi())  # Generate a random unique key
		overlap_groups[key] = overlap.new([other_id, id])
	
	# Case 2: other_id is in a group, add id to it
	elif id_group_key == "" and other_id_group_key != "":
		overlap_groups[other_id_group_key].add_id_to_list(id)

	# Case 3: id is in a group, add other_id to it
	elif id_group_key != "" and other_id_group_key == "":
		overlap_groups[id_group_key].add_id_to_list(other_id)

	# Case 4: Both IDs are in different groups, merge the groups
	else:
		overlap_groups[id_group_key].merge_with(overlap_groups[other_id_group_key])
		overlap_groups.erase(other_id_group_key)  # Remove the old group
		

# Signal from child indicating there's no more collision
func _on_piece_no_overlap(other_id: int, id: int):
	var id_group_key = ""
	var other_id_group_key = ""
	
	# Find group keys for both ids
	for key in overlap_groups:
		if overlap_groups[key].id_is_in_list(other_id):
			other_id_group_key = key
		if overlap_groups[key].id_is_in_list(id):
			id_group_key = key
	
	# means that there is a connection to be severed
	if other_id_group_key == id_group_key:

#ack function picking a piece
func _on_piece_occupy_drag(id) -> void:
	if dragging == false and dragged_shape_id == -1:
		#id's are the same as indexes because they don't change
		dragged_shape_id = id
		dragged_child = get_child(dragged_shape_id)
		
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

# Reopen for next piece picked
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
