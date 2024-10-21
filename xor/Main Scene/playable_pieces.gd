extends Node2D

@export var new_shape: PackedScene
#reference to child node for timing lock
@onready var lock_timer = $Timer

#Track if the object is being dragged
var dragging = false 

#Current dragged shape index
var dragged_shape_id = -1
#reference to dragged child
var dragged_child: Node

#searching dictionary for child reference nodes
#matches id to node
var all_shapes: Dictionary

#an array of an array of indexes representing what has been overlapped
#note that if A and B are connected, and B and C are connected
#they are all found in the dictionary, but their list of connections won't list
#anything they aren't connected to
var overlap_groups: Dictionary
class overlap:
	#shapes involved in calculation
	var indexes_involved: Dictionary
	#shape chosen to display overlap
	var display_index: int
	
	func _init(indexes: Array, new_dic: Dictionary = {}) -> void:
		# create dic
		if new_dic.size() == 0:
			indexes_involved = {}
			#makes a dictionary that lists involved shapes and their collsions
			for index in indexes:
				var collisions = []
				for collided_index in indexes:
					if collided_index != index:
						collisions.append(collided_index)
				indexes_involved[index] = collisions
		
		# inject dic
		else:
			indexes_involved = new_dic
		
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
				for collision in other.indexes_involved[other_index]:
					if collision not in self.indexes_involved[other_index]:
						self.indexes_involved[other_index].append(collision)
			#create new entry that is a transfer of other account
			else:
				if int(other_index) > cur_display_index:
					self.display_index = int(other_index)
				self.indexes_involved[other_index] = other_index.indexes_involved[other_index]
	
	#check if id is in overlap
	func id_is_in_list(id: int) -> bool:
		return indexes_involved.has(id)
	
	#add a specific collision to overlap
	func add_col_to_list(new_id_1: int, new_id_2: int) -> void:
		var cur_display_index = self.display_index
		var found_1 = new_id_1 in indexes_involved.keys()
		var found_2 = new_id_2 in indexes_involved.keys()
		if found_1 and found_2:
			if new_id_2 not in indexes_involved[new_id_1]:
				indexes_involved[new_id_1].append(new_id_2)
			if new_id_1 not in indexes_involved[new_id_2]:
				indexes_involved[new_id_2].append(new_id_1)
		elif found_1:
			if new_id_2 not in indexes_involved[new_id_1]:
				indexes_involved[new_id_1].append(new_id_2)
			indexes_involved[new_id_2] = [new_id_1]
			if new_id_2 > cur_display_index:
				display_index = new_id_2
		elif found_2:
			if new_id_1 not in indexes_involved[new_id_2]:
				indexes_involved[new_id_2].append(new_id_1)
			indexes_involved[new_id_1] = [new_id_2]
			if new_id_1 > cur_display_index:
				display_index = new_id_1
		else:
			assert(found_1 or found_2, "can't add a connection if no id's are alr there")
	
	#sever a specific collision from overlap
	#creturns an empty array if nothing needs to be done
	#returns the two separated dictionaries if there is something to be done
	func sub_col_from_list(new_id_1: int, new_id_2: int) -> Array:
		var cur_display_index = self.display_index
		var must_reevaluate = false
		var found_1 =new_id_1 in indexes_involved.keys()
		var found_2 = new_id_2 in indexes_involved.keys()
		assert(found_1 and found_2, "Both ids must exist to remove a connection")
		
		#remove connections from 1
		if new_id_2 in indexes_involved[new_id_1]:
			indexes_involved[new_id_1].erase(new_id_2)
			if indexes_involved[new_id_1].is_empty():
				indexes_involved.erase(new_id_1)
				if cur_display_index == new_id_2:
					must_reevaluate = true
					
		#remove connections from 2
		if new_id_1 in indexes_involved[new_id_2]:
			indexes_involved[new_id_2].erase(new_id_1)
			if indexes_involved[new_id_2].is_empty():
				indexes_involved.erase(new_id_2)
				if cur_display_index == new_id_1:
					must_reevaluate = true
		
		#check if this was a grouping of only 2 shapes
		if indexes_involved.size() == 0:
			return [[]]
		
		#check if the leftover dictionary is still connected
		var dictionary_keys = need_to_split(indexes_involved)
		if dictionary_keys.size() < indexes_involved.size():
			print("need to populate return value")
			var split_1 = {}
			var split_2 = {}
			for index in indexes_involved:
				if index in dictionary_keys:
					split_1[index] = dictionary_keys[index]
				else:
					split_2[index] = dictionary_keys[index]
			#returns index groups seperated by cut
			return [split_1, split_2]
		
		#readjustments after divide if there is no splitting in group
		if must_reevaluate:
			#recalc display_index
			display_index = int(indexes_involved.keys()[0])
			for key in indexes_involved.keys():
				var int_key = int(key)
				if int_key > int(display_index):
					display_index = int_key
		return []
	
	#returns array of indexes found from pathfinder
	func need_to_split(index_dic) -> Array:
		var visited_vertices = []
		var stack = [index_dic.keys()[0]]  
		while stack.size() > 0:
			var current_vertex = stack.pop_back() 
			if current_vertex not in visited_vertices:
				visited_vertices.append(current_vertex)
				for neighbor in index_dic[current_vertex]:
					if neighbor not in visited_vertices:
						stack.append(neighbor)
		return visited_vertices
	
	#removes all the keys in the array from indexes_involved
	func remove_indexes(indexes: Array) -> void:
		for key in indexes:
			if key in indexes_involved:
				indexes_involved.erase(key)
	
#Ack signals for shapes
signal go(id)
signal snap(id, mouse_pos)
signal start_snap(grid_pos, id)
signal display_group(display_id, children)
signal no_display_group(id)

#for testing purposes
@onready var timer = $testTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Start the timer with 10 seconds interval for testing purposes
	timer.wait_time = 5
	timer.start()
	overlap_groups = {}
	all_shapes = {}

func find_key_with_id(id) -> int:
	for key in overlap_groups:
		if id in overlap_groups[key].indexes_involved:
			return key
	return -1
# Calculates overlaps constantly and changes views
func _process(delta: float) -> void:
	for id in all_shapes:
		var key = find_key_with_id(id)
		if key != -1:
			var grouped_children = []
			for index in overlap_groups[key].indexes_involved:
				grouped_children.append(all_shapes[index])
			emit_signal("display_group",overlap_groups[key].display_index, grouped_children)
			
		else:
			emit_signal("no_display_group", id)
	
	

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
	all_shapes[get_child_count()-1] = shape
	

#signal from child that theres a collision
func _on_piece_overlap(other_id: int, id: int):
	print("overlapping " + str(other_id) + " and " + str(id))
	var id_group_key = -1
	var other_id_group_key = -1
	
	# Find group keys for both ids
	for key in overlap_groups:
		if overlap_groups[key].id_is_in_list(other_id):
			other_id_group_key = key
		if overlap_groups[key].id_is_in_list(id):
			id_group_key = key

	# Case 1: Neither ID is in any group, create a new group
	if id_group_key == -1 and other_id_group_key == -1:
		var key = -1
		while overlap_groups.has(key) or key == -1:
			key = randi()
		overlap_groups[key] = overlap.new([other_id, id])
		
	
	# Case 2: other_id is in a group, add id to it
	elif id_group_key == -1 and other_id_group_key != -1:
		overlap_groups[other_id_group_key].add_col_to_list(id,other_id)

	# Case 3: id is in a group, add other_id to it
	elif id_group_key != -1 and other_id_group_key == -1:
		overlap_groups[id_group_key].add_col_to_list(id,other_id)

	# Case 4: Both IDs are in different groups, merge the groups
	elif id_group_key != other_id_group_key:
		overlap_groups[id_group_key].merge_with(overlap_groups[other_id_group_key])
		overlap_groups.erase(other_id_group_key)  # Remove the old group
	
# Signal from child indicating there's no more collision
func _on_piece_no_overlap(other_id: int, id: int):
	print("not overlapping " + str(other_id) + " and " + str(id))
	var id_group_key = -1
	var other_id_group_key = -1
	
	# Find group keys for both ids
	for key in overlap_groups:
		if overlap_groups[key].id_is_in_list(other_id):
			other_id_group_key = key
		if overlap_groups[key].id_is_in_list(id):
			id_group_key = key
		if id_group_key != -1 and other_id_group_key != -1:
			break
	
	# means that there is a connection to be severed
	if other_id_group_key == id_group_key and id_group_key != -1:
		#for simplicity's sale
		var old_key = id_group_key
		var sep_vertices = overlap_groups[id_group_key].sub_col_from_list(other_id, id)
		if sep_vertices.size() == 2:
			var group_1 = sep_vertices[0]
			var group_2 = sep_vertices[1]
			var old_group = overlap_groups[id_group_key]
			
			#create new key for new_group
			var new_key = -1
			while overlap_groups.has(new_key) or new_key == -1:
				new_key = randi() # Generate a random unique key
			
			#redefine old group by removing indexes in group 2
			overlap_groups[new_key].remove_indexes(group_2)
			
			#create new group
			var new_group_dic = {}
			for index in group_2:
				#repopulate new dic with group_2 entries
				new_group_dic[index] = overlap_groups[index]
			overlap_groups[new_key] = overlap.new([], new_group_dic)
			
		#the group is empty after operation and must be removed from overlap_groups
		elif sep_vertices.size() == 1:
			overlap_groups.erase(old_key)


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
